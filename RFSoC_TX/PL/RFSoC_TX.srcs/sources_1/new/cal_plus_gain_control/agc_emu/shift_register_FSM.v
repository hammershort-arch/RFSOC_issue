`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/08/25 14:45:37
// Design Name: 
// Module Name: shift_register_FSM
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module shift_register_FSM #(
    // 透過參數化控制等待週期，適應不同電壓與頻率
    // SN74LVC595A @ VCC=1.8V: tw>=7ns, tsu>=5.5ns, th>=2ns, latch tsu>=8.5ns
    // 預設 2 個 cycles (2 * 4.167ns = 8.33ns) @ adc_clk 240MHz (2026-10-12 註解更新)
    parameter WAIT_CYCLES = 2 
)(
    input  wire       clk,       // adc_clk 240MHz (RFDC clk_adcN)
    input  wire       rst_n,
    input  wire       start,
    input  wire [7:0] data_in,
    
    output reg        ser,
    output reg        srclk, 
    output reg        rclk,
    output reg        busy
);

    // 定義狀態機狀態 (使用 localparam 取代 enum)
    localparam IDLE       = 3'd0;
    localparam SHIFT_LOW  = 3'd1; // SRCLK=0, 準備資料並滿足 Setup time
    localparam SHIFT_HIGH = 3'd2; // SRCLK=1, 觸發移位並滿足 Pulse duration & Hold time
    localparam LATCH_WAIT = 3'd3; // 等待 SRCLK 到 RCLK 的 Setup time
    localparam LATCH_HIGH = 3'd4; // RCLK=1, 鎖存輸出

    reg [2:0] state, next_state;

    reg [7:0] shift_reg;
    reg [2:0] bit_cnt;
    reg [3:0] wait_cnt;  // 支援最高等待 15 個 cycles，可依需求調整位寬

    // ==========================================
    // Block 1: 狀態記憶體 (State Register)
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end

    // ==========================================
    // Block 2: 下一個狀態邏輯 (Next State Logic)
    // ==========================================
    always @(*) begin
        next_state = state; 
        case (state)
            IDLE: begin
                if (start) next_state = SHIFT_LOW;
            end
            
            SHIFT_LOW: begin
                if (wait_cnt == (WAIT_CYCLES - 1)) 
                    next_state = SHIFT_HIGH;
            end
            
            SHIFT_HIGH: begin
                if (wait_cnt == (WAIT_CYCLES - 1)) begin
                    if (bit_cnt == 3'd7) 
                        next_state = LATCH_WAIT;
                    else                 
                        next_state = SHIFT_LOW;
                end
            end
            
            LATCH_WAIT: begin
                if (wait_cnt == (WAIT_CYCLES - 1)) 
                    next_state = LATCH_HIGH;
            end
            
            LATCH_HIGH: begin
                if (wait_cnt == (WAIT_CYCLES - 1)) 
                    next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // ==========================================
    // Block 3: 輸出與資料路徑邏輯 (Output & Datapath)
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 8'd0;
            bit_cnt   <= 3'd0;
            wait_cnt  <= 4'd0;
            ser       <= 1'b0;
            srclk     <= 1'b0;
            rclk      <= 1'b0;
            busy      <= 1'b0;
        end else begin
            // 預設控制訊號
            srclk <= 1'b0;
            rclk  <= 1'b0;

            case (state)
                IDLE: begin
                    wait_cnt <= 4'd0;
                    bit_cnt  <= 3'd0;
                    if (start) begin
                        shift_reg <= data_in;
                        busy      <= 1'b1;
                    end else begin
                        busy      <= 1'b0;
                        ser       <= 1'b0;
                    end
                end

                SHIFT_LOW: begin
                    ser <= shift_reg[0]; // LSB First
                    if (wait_cnt == (WAIT_CYCLES - 1)) begin
                        wait_cnt <= 4'd0;
                    end else begin
                        wait_cnt <= wait_cnt + 1'b1;
                    end
                end

                SHIFT_HIGH: begin
                    srclk <= 1'b1;
                    if (wait_cnt == (WAIT_CYCLES - 1)) begin
                        wait_cnt  <= 4'd0;
                        shift_reg <= {1'b0, shift_reg[7:1]}; // data right shift
                        bit_cnt   <= bit_cnt + 1'b1;
                    end else begin
                        wait_cnt <= wait_cnt + 1'b1;
                    end
                end

                LATCH_WAIT: begin
                    // 確保 SRCLK 降回 0 後，有一段安全距離才觸發 RCLK
                    if (wait_cnt == (WAIT_CYCLES - 1)) begin
                        wait_cnt <= 4'd0;
                    end else begin
                        wait_cnt <= wait_cnt + 1'b1;
                    end
                end

                LATCH_HIGH: begin
                    rclk <= 1'b1;
                    if (wait_cnt == (WAIT_CYCLES - 1)) begin
                        wait_cnt <= 4'd0;
                        busy     <= 1'b0; // 傳輸完成，降下 busy
                    end else begin
                        wait_cnt <= wait_cnt + 1'b1;
                    end
                end
            endcase
        end
    end

endmodule
