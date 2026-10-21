`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/09/01 15:51:03
// Design Name: 
// Module Name: rxagc_fsm
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


module rxagc_fsm (
    input  wire       clk,
    input  wire       resetn,
    input  wire       agc_enable,      // 0: FSM 停在 S_IDLE (ex: EMU 在 TX mode)

    // Cycle settings (AGC_RX_* registers, agc_cdc 已處理下限)
    input  wire [31:0] watch_cycle,       // S_WATCHING 等待時間
    input  wire [7:0]  wait_dsa_cycle,    // S_WAIT_DSA 等待時間
    input  wire [7:0]  set_dsa_cycle,     // S_SET_DSA 脈衝寬度
    input  wire [7:0]  wait_cycle,        // S_WAIT (RF settling)
    input  wire [7:0]  set_clear_cycle,   // S_SET_CLEAR 脈衝寬度
    input  wire [7:0]  wait_clear_cycle,  // S_WAIT_CLEAR 等待硬體復位
    
    // RFDC Flags
    input  wire       over_voltage,
    input  wire       over_range,
    input  wire       over_thres_high,
    input  wire       over_thres_low,
    
    // Outputs
    output reg  [2:0] rx_att_state,
    output reg        rx_att_update,
    output reg        rx_att_ready,
    output reg        clear_or,
    output reg        clear_ov
);

    // FSM state (Aligned with new flow)
    localparam S_IDLE       = 4'd0; 
    localparam S_EVALUATE   = 4'd1; 
    localparam S_WATCHING   = 4'd2; 
    localparam S_TOO_HIGH   = 4'd3; 
    localparam S_TOO_LOW    = 4'd4; 
    localparam S_WAIT_DSA   = 4'd5; 
    localparam S_SET_DSA    = 4'd6; 
    localparam S_WAIT       = 4'd7; 
    localparam S_SET_CLEAR  = 4'd8; 
    localparam S_WAIT_CLEAR = 4'd9; 

    // DSA related localparam
    localparam ATT_MAX_CODE = 3'd6;  // Attenuation 60dB (最大衰減)
    localparam ATT_MIN_CODE = 3'd0;  // Attenuation  0dB (最小衰減)

    reg [3:0] curr_state;
    reg [3:0] next_state;

    // Counters
    reg [31:0] watch_cnt;      
    reg [15:0] wait_cnt;       
    reg [7:0]  wait_clear_cnt; 
    reg [7:0]  wait_dsa_cnt;
    reg [7:0]  set_dsa_cnt;
    reg [7:0]  set_clear_cnt;
    
    // Internal wires
    wire sig_ov          = over_voltage;
    wire sig_or          = over_range;
    wire sig_over_thres_high = over_thres_high;
    wire sig_over_thres_low = over_thres_low;

    // =========== 1. FSM state update ============
    always @(posedge clk) begin
        if (!resetn || !agc_enable)
            curr_state <= S_IDLE;
        else
            curr_state <= next_state;
    end

    // ========== 2. FSM state transfer (Combinational) ================ 
    always @(*) begin
        next_state = curr_state; 
        
        case (curr_state)
            S_IDLE: next_state = S_WAIT_DSA;
            
            S_EVALUATE: begin
                // Any high flag goes to TOO_HIGH directly
                if (sig_ov || sig_or || sig_over_thres_high)
                    next_state = S_TOO_HIGH;
                else if (!sig_over_thres_high && !sig_over_thres_low)
                    next_state = S_WATCHING;
                else
                    next_state = S_EVALUATE;
            end

            S_WATCHING: begin
                if(sig_over_thres_low)
                    next_state = S_EVALUATE;
                else if(watch_cnt >= watch_cycle)
                    next_state = S_TOO_LOW;
                else
                    next_state = S_WATCHING;
                
            end    

            S_TOO_HIGH, S_TOO_LOW: begin
                next_state = S_WAIT_DSA;
            end

            S_WAIT_DSA:   if (wait_dsa_cnt   >= (wait_dsa_cycle -1'b1))    next_state = S_SET_DSA;
            S_SET_DSA:    if (set_dsa_cnt    >= (set_dsa_cycle - 1'b1))    next_state = S_WAIT;
            S_WAIT:       if (wait_cnt       >= (wait_cycle - 1'b1))       next_state = S_SET_CLEAR;
            S_SET_CLEAR:  if (set_clear_cnt  >= (set_clear_cycle - 1'b1))  next_state = S_WAIT_CLEAR;
            S_WAIT_CLEAR: if (wait_clear_cnt >= (wait_clear_cycle -1'b1))  next_state = S_EVALUATE;

            default: next_state = S_IDLE;
        endcase
    end

    // ========== 3. FSM sequential logic (Outputs & Counters) ================ 
    always @(posedge clk) begin
        if (!resetn || !agc_enable) begin
            rx_att_state   <= ATT_MIN_CODE; // Initialize with ATT 0dB
            clear_or       <= 1'b0;
            clear_ov       <= 1'b0;
            rx_att_update  <= 1'b0; 
            rx_att_ready   <= 1'b0;
            watch_cnt      <= 32'd0;
            wait_cnt       <= 16'd0;
            wait_clear_cnt <= 8'd0;
            wait_dsa_cnt   <= 8'd0;
            set_dsa_cnt    <= 8'd0;
            set_clear_cnt  <= 8'd0;
        end else begin
            // Default reset pulses
            rx_att_update <= 1'b0;
            rx_att_ready  <= 1'b0;
            clear_or      <= 1'b0;
            clear_ov      <= 1'b0;  
            
            case (curr_state)
                S_IDLE: begin 
                    rx_att_state   <= ATT_MIN_CODE; 
                    watch_cnt      <= 32'd0;
                    wait_cnt       <= 16'd0;
                    wait_clear_cnt <= 8'd0;
                    wait_dsa_cnt   <= 8'd0;
                    set_dsa_cnt    <= 8'd0;
                    set_clear_cnt  <= 8'd0;
                end
                    
                S_EVALUATE: begin
                    // Reset all counters when back to evaluation
                    watch_cnt      <= 32'd0;
                    wait_cnt       <= 16'd0;
                    wait_clear_cnt <= 8'd0;
                    wait_dsa_cnt   <= 8'd0;
                    set_dsa_cnt    <= 8'd0;
                    set_clear_cnt  <= 8'd0;
                end
                
                S_WATCHING: begin
                    watch_cnt <= watch_cnt + 1'b1;
                end

                S_TOO_HIGH: begin
                    if(rx_att_state < ATT_MAX_CODE)
                        rx_att_state <= rx_att_state + 1;   // ATT + 10dB
                    else 
                        rx_att_state <= ATT_MAX_CODE;    
                end

                S_TOO_LOW: begin
                    rx_att_state <= ATT_MIN_CODE;       // Set ATT = 0dB
                end

                S_WAIT_DSA: begin
                    wait_dsa_cnt <= wait_dsa_cnt + 1'b1;
                end 
                
                S_SET_DSA: begin
                    rx_att_update   <= 1'b1;            // Raise rx_att_update pulse
                    set_dsa_cnt  <= set_dsa_cnt + 1'b1;
                end
                
                S_WAIT: begin
                    wait_cnt <= wait_cnt + 1'b1;
                end
                
                S_SET_CLEAR: begin
                    clear_ov      <= 1'b1; // Raise clear pulses
                    clear_or      <= 1'b1;
                    rx_att_ready  <= 1'b1; // Mark AGC ready
                    set_clear_cnt <= set_clear_cnt + 1'b1;
                end

                S_WAIT_CLEAR: begin 
                    wait_clear_cnt <= wait_clear_cnt + 1'b1;
                end 

                default: begin
                    rx_att_update <= 1'b0;
                end
            endcase
        end
    end
    
endmodule