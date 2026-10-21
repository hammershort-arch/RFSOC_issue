`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/09/02 09:05:40
// Design Name: 
// Module Name: rxagc
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


module rxagc (
    input  wire       clk,
    input  wire       resetn,
    input  wire       agc_enable,      // 0: RXAGC FSM 停在 S_IDLE

    // --- Cycle settings (AGC_RX_* registers) ---
    input  wire [31:0] watch_cycle,
    input  wire [7:0]  wait_dsa_cycle,
    input  wire [7:0]  set_dsa_cycle,
    input  wire [7:0]  wait_cycle,
    input  wire [7:0]  set_clear_cycle,
    input  wire [7:0]  wait_clear_cycle,
    
    // --- RFDC Flags Inputs ---
    input  wire       over_voltage,
    input  wire       over_range,
    input  wire       over_threshold1,
    input  wire       over_threshold2,
    
    // -- Manual Control 
    input  wire [2:0] manual_rx_att_state,
    input  wire       manual_rx_att_enable,
    
    // --- AGC Control Outputs ---
    output wire [2:0] rx_att_state,
    output wire       rx_att_update,
    output wire       rx_att_ready,
    output wire       clear_or,
    output wire       clear_ov,
    output reg  [2:0] sw_rx_att,
    output reg  [1:0] rx_att2,
    output reg  [7:0] rx_att_db
);

    wire [2:0] fsm_rx_att_state;

    // =========================================================================
    // 實例化 (Instantiate) RXAGC Finite State Machine
    // =========================================================================
    rxagc_fsm u_rxagc_fsm (
        .clk             (clk),
        .resetn          (resetn),
        .agc_enable      (agc_enable),
        .watch_cycle      (watch_cycle),
        .wait_dsa_cycle   (wait_dsa_cycle),
        .set_dsa_cycle    (set_dsa_cycle),
        .wait_cycle       (wait_cycle),
        .set_clear_cycle  (set_clear_cycle),
        .wait_clear_cycle (wait_clear_cycle),
        
        // RFDC Flags Inputs
        .over_voltage    (over_voltage),
        .over_range      (over_range),
        .over_thres_high (over_threshold1),  // 映射至原本的 over_thres1
        .over_thres_low  (over_threshold2),  // 映射至原本的 over_thres2
        
        // Control Outputs
        .rx_att_state    (fsm_rx_att_state),
        .rx_att_update   (rx_att_update),
        .rx_att_ready    (rx_att_ready),
        .clear_or        (clear_or),
        .clear_ov        (clear_ov)
    );


    assign  rx_att_state = (manual_rx_att_enable) ? manual_rx_att_state : fsm_rx_att_state;


    always @(*) begin
        case (rx_att_state)  
            3'd6: begin 
                sw_rx_att = 3'b001;
                rx_att2   = 2'b11;
                rx_att_db = 8'd60;
            end
            3'd5: begin 
                sw_rx_att = 3'b001;
                rx_att2   = 2'b10;
                rx_att_db = 8'd50;
            end
            3'd4: begin 
                sw_rx_att = 3'b101;
                rx_att2   = 2'b10;
                rx_att_db = 8'd40;
            end
            3'd3: begin 
                sw_rx_att = 3'b011;
                rx_att2   = 2'b10;
                rx_att_db = 8'd30;
            end
            3'd2: begin
                sw_rx_att = 3'b111;
                rx_att2   = 2'b10; 
                rx_att_db = 8'd20;
            end
            3'd1: begin
                sw_rx_att = 3'b111;
                rx_att2   = 2'b01;  
                rx_att_db = 8'd10;
            end
            3'd0: begin
                sw_rx_att = 3'b111;
                rx_att2   = 2'b00; 
                rx_att_db = 8'd0;
            end 
            default: begin
                sw_rx_att = 3'b111;
                rx_att2   = 2'b00; 
                rx_att_db = 8'd0;
            end 
        endcase
    end
endmodule
