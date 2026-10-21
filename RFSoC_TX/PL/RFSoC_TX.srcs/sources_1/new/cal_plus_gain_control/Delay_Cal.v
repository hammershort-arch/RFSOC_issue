`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/22/2026 04:12:59 PM
// Design Name: 
// Module Name: Delay_Cal
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


module Delay_Cal#(
    parameter DATA_WIDTH = 160,          // RFDC 5-sample IQ 資料寬度
    parameter MAX_DELAY_CYCLES = 15,     // 支援的最大延遲週期數 (可依需求加大)
    parameter NUM_SAMPLES = 5            // 每個 Clock 包含的取樣點數量
)(
    input  wire                        clk,           // AXI-Stream Clock (e.g., 125MHz)
    input  wire                        rst_n,         // Active-low Reset
    
    // Control Interface (From VIO or PS AXI-Lite Register)
    input  wire [3:0]                  delay_coarse,     // 粗調延遲 (0 ~ 15 cycles)
    input  wire [2:0]                  delay_fractional, // 微調延遲 (0 ~ 4 samples)
    
    // AXI-Stream Input (來自上游 DSP 或 FIFO)
    input  wire [DATA_WIDTH-1:0]       s_axis_tdata,
    input  wire                        s_axis_tvalid,
    output wire                        s_axis_tready,
    
    // AXI-Stream Output (送往 RFDC)
    output reg  [DATA_WIDTH-1:0]       m_axis_tdata,
    output reg                         m_axis_tvalid,
    input  wire                        m_axis_tready
    );
    
    // 每個 Sample 的 Bit 數 (160 / 5 = 32 bits)
    localparam SW = DATA_WIDTH / NUM_SAMPLES; 
    
    // 宣告移位暫存器陣列 (Shift Register Pipeline)
    reg [DATA_WIDTH-1:0] data_pipe  [0:MAX_DELAY_CYCLES-1];
    reg                  valid_pipe [0:MAX_DELAY_CYCLES-1];
    integer i;

    // --------------------------------------------------
    // AXI-Stream 反壓 (Backpressure) 邏輯
    // --------------------------------------------------
    // 只有當後級準備好 (m_axis_tready = 1) 時，管線才允許移位。
    // 同時，直接將後級的 ready 狀態 Bypass 給前級，這在純 Delay Line 設計中是最穩定的做法。
    wire shift_en = m_axis_tready;
    assign s_axis_tready = m_axis_tready;

    // --------------------------------------------------
    // 1. Shift Register Pipeline (處理 Coarse Delay)
    // --------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < MAX_DELAY_CYCLES; i = i + 1) begin
                data_pipe[i]  <= {DATA_WIDTH{1'b0}};
                valid_pipe[i] <= 1'b0;
            end
        end else if (shift_en) begin
            data_pipe[0]  <= s_axis_tdata;
            valid_pipe[0] <= s_axis_tvalid;
            
            for (i = 1; i < MAX_DELAY_CYCLES; i = i + 1) begin
                data_pipe[i]  <= data_pipe[i-1];
                valid_pipe[i] <= valid_pipe[i-1];
            end
        end
    end
    
    // --------------------------------------------------
    // 2. Coarse MUX (選出粗調後的當前週期資料)
    // --------------------------------------------------
    reg [DATA_WIDTH-1:0] coarse_data;
    reg                  coarse_valid;
    
    always @(*) begin
        if (delay_coarse == 4'd0) begin
            coarse_data  = s_axis_tdata;
            coarse_valid = s_axis_tvalid;
        end else if (delay_coarse <= MAX_DELAY_CYCLES) begin
            coarse_data  = data_pipe[delay_coarse - 1];
            coarse_valid = valid_pipe[delay_coarse - 1];
        end else begin
            coarse_data  = data_pipe[MAX_DELAY_CYCLES - 1];
            coarse_valid = valid_pipe[MAX_DELAY_CYCLES - 1];
        end
    end
    
    // --------------------------------------------------
    // 3. Previous Data Register (保存上一拍資料供微調使用)
    // --------------------------------------------------
    reg [DATA_WIDTH-1:0] prev_coarse_data;
    reg                  prev_coarse_valid;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prev_coarse_data  <= {DATA_WIDTH{1'b0}};
            prev_coarse_valid <= 1'b0;
        end else if (shift_en) begin
            prev_coarse_data  <= coarse_data;
            prev_coarse_valid <= coarse_valid;
        end
    end
    
    // --------------------------------------------------
    // 4. Fine Delay / Barrel Shifter (處理 Fractional Delay)
    // --------------------------------------------------
    reg [DATA_WIDTH-1:0] shifted_data;
    reg                  shifted_valid;

    always @(*) begin
        // Valid 訊號處理：
        // 若 fractional > 0，資料會跨越 current 與 previous，因此兩者皆須 valid 才能輸出有效資料
        if (delay_fractional == 3'd0)
            shifted_valid = coarse_valid;
        else
            shifted_valid = coarse_valid & prev_coarse_valid;

        // Data 拼接處理：
        // 假設時間順序為 LSB 到 MSB (S0 最早，S4 最晚)
        // coarse_data      (Current) = {C4, C3, C2, C1, C0}
        // prev_coarse_data (Previous)= {P4, P3, P2, P1, P0}
        case (delay_fractional)
            3'd0: shifted_data = coarse_data;
            
            // 延遲 1 sample: 取 Current 前 4 筆 + Previous 最後 1 筆
            // {C3, C2, C1, C0, P4}
            3'd1: shifted_data = {coarse_data[0 +: 4*SW], prev_coarse_data[4*SW +: 1*SW]};
            
            // 延遲 2 samples: 取 Current 前 3 筆 + Previous 最後 2 筆
            // {C2, C1, C0, P4, P3}
            3'd2: shifted_data = {coarse_data[0 +: 3*SW], prev_coarse_data[3*SW +: 2*SW]};
            
            // 延遲 3 samples: 取 Current 前 2 筆 + Previous 最後 3 筆
            // {C1, C0, P4, P3, P2}
            3'd3: shifted_data = {coarse_data[0 +: 2*SW], prev_coarse_data[2*SW +: 3*SW]};
            
            // 延遲 4 samples: 取 Current 前 1 筆 + Previous 最後 4 筆
            // {C0, P4, P3, P2, P1}
            3'd4: shifted_data = {coarse_data[0 +: 1*SW], prev_coarse_data[1*SW +: 4*SW]};
            
            default: shifted_data = coarse_data;
        endcase
    end
    
    // --------------------------------------------------
    // 5. Output Register (維持時序與 AXI-Stream 規範)
    // --------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_axis_tdata  <= {DATA_WIDTH{1'b0}};
            m_axis_tvalid <= 1'b0;
        end else if (shift_en) begin
            m_axis_tdata  <= shifted_data;
            m_axis_tvalid <= shifted_valid;
        end
    end
    
    
endmodule
