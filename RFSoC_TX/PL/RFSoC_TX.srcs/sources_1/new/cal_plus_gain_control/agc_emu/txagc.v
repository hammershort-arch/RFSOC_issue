`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/09/03 10:29:16
// Design Name: 
// Module Name: txagc
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Revision 0.03 - 移除 FSM: 持續以最新輸入計算, Shift Register 於內容改變時自動送出
// Revision 0.04 - bypass_agc: tx_att_state 改用 bypass_tx_att_state (PS 指定檔位), digital_comp_index = 0
// Revision 0.05 - (2026-10-09) 類比優先分配 (txagc_calc): pf / gain index offset / algo / rx_att_index / Manual DAC 推算;
//                 輸出數位端 gain_index_digital = pf - R (bypass 時 = pf), 類比上下限旗標
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module txagc (
    input  wire               clk,
    input  wire               resetn,

    // --- 計算輸入 (持續使用最新值) ---
    input  wire        [2:0]  rx_att_index,           // RSP RX 衰減 index (x10 dB)
    input  wire signed [9:0]  gain_index_power_fit,   // S5.4
    input  wire signed [9:0]  goal_rel_db,            // S5.4
    input  wire signed [10:0] dac_output_ref_dbm,     // S6.4
    input  wire signed [8:0]  gain_index_ch_offset,   // S4.4
    input  wire signed [7:0]  gain_index_rf_freq_offset,      // S3.4
    input  wire signed [7:0]  gain_index_temperature_offset,  // S3.4
    input  wire signed [8:0]  algo_analog_att_db,     // S8.0
    input  wire signed [7:0]  target_power,
    input  wire               tx_power_mode,          // 0: Linear, 1: Manual
    input  wire               manual_tx_att_enable,
    input  wire        [7:0]  manual_tx_att_db,
    input  wire signed [11:0] linear_mode_offset,
    input  wire signed [11:0] manual_mode_offset,
    input  wire        [7:0]  tx_att_hysteresis,      // U4.4 dB, 換檔遲滯 (system sys16)

    // --- Bypass (PS 直接指定類比檔位) ---
    input  wire               bypass_agc,
    input  wire        [4:0]  bypass_tx_att_state,    // 0~27

    // --- TXAGC 輸出 ---
    output wire [4:0]         tx_att_state,           // 送往 decoder 的檔位 (bypass 時 = bypass_tx_att_state)

    // --- 實體板載控制腳位 (至 agc_att_mux -> Shift Register) ---
    output reg  [2:0]         tx_att2,
    output reg  [2:0]         tx_att3,
    output reg  [2:0]         tx_att4,
    output reg  [3:0]         sw_tx_att,

    // --- 數位端 ---
    output wire signed [9:0]  digital_comp_index,     // 數位殘差 R (0 ~ 79), bypass 時 = 0
    output wire signed [11:0] gain_index_digital,     // pf - R (bypass 時 = pf), 經 gain_apply_sync 與類比同步
    output wire               analog_clamp_hi,
    output wire               analog_clamp_lo
);

    wire [4:0]         calc_tx_att_state;
    wire signed [9:0]  calc_digital_comp_index;
    wire signed [11:0] calc_gain_index_digital;
    wire               calc_clamp_hi, calc_clamp_lo;

    assign tx_att_state       = bypass_agc ? bypass_tx_att_state : calc_tx_att_state;
    assign digital_comp_index = bypass_agc ? 10'sd0              : calc_digital_comp_index;
    assign gain_index_digital = bypass_agc ? {{2{gain_index_power_fit[9]}}, gain_index_power_fit} : calc_gain_index_digital;
    assign analog_clamp_hi    = bypass_agc ? 1'b0 : calc_clamp_hi;
    assign analog_clamp_lo    = bypass_agc ? 1'b0 : calc_clamp_lo;

    // 1. TXAGC 計算核心 (4-stage pipeline, build 13 加換檔遲滯; 每拍以最新輸入重算)
    txagc_calc u_txagc_calc (
        .clk                           (clk),
        .resetn                        (resetn),
        .in_valid                      (1'b1),
        .rx_att_index                  (rx_att_index),
        .gain_index_power_fit          (gain_index_power_fit),
        .goal_rel_db                   (goal_rel_db),
        .dac_output_ref_dbm            (dac_output_ref_dbm),
        .gain_index_ch_offset          (gain_index_ch_offset),
        .gain_index_rf_freq_offset     (gain_index_rf_freq_offset),
        .gain_index_temperature_offset (gain_index_temperature_offset),
        .algo_analog_att_db            (algo_analog_att_db),
        .target_power                  (target_power),
        .tx_mode                       (tx_power_mode),
        .manual_tx_att_enable          (manual_tx_att_enable),
        .manual_tx_att_db              (manual_tx_att_db),
        .linear_mode_offset            (linear_mode_offset),
        .manual_mode_offset            (manual_mode_offset),
        .tx_att_hysteresis             (tx_att_hysteresis),
        .out_valid                     (),
        .tx_att_state                  (calc_tx_att_state),
        .digital_comp_index            (calc_digital_comp_index),
        .gain_index_digital            (calc_gain_index_digital),
        .analog_clamp_hi               (calc_clamp_hi),
        .analog_clamp_lo               (calc_clamp_lo)
    );

    // 2. Case Decoder (將 tx_att_state 0~27 對應至實體硬體開關碼)
    always @(*) begin
        case (tx_att_state)
            // State 0~27 解碼 (此處以示意解碼排列，可依實體板載 DSA 腳位對應修改)
            5'd0: begin // -130dB 
                sw_tx_att = 4'b0000;
                tx_att2   = 3'b110;
                tx_att3   = 3'b110;
                tx_att4   = 3'b110; 
            end
            5'd1: begin // -125dB 
                sw_tx_att = 4'b0000;
                tx_att2   = 3'b101;
                tx_att3   = 3'b110;
                tx_att4   = 3'b110; 
            end
            5'd2: begin // -120dB 
                sw_tx_att = 4'b0000;
                tx_att2   = 3'b100;
                tx_att3   = 3'b110;
                tx_att4   = 3'b110; 
            end
            5'd3: begin // -115dB 
                sw_tx_att = 4'b0000;
                tx_att2   = 3'b011;
                tx_att3   = 3'b110;
                tx_att4   = 3'b110; 
            end
            5'd4: begin // -110dB 
                sw_tx_att = 4'b0000;
                tx_att2   = 3'b010;
                tx_att3   = 3'b110;
                tx_att4   = 3'b110; 
            end
            5'd5: begin // -105dB 
                sw_tx_att = 4'b0000;
                tx_att2   = 3'b001;
                tx_att3   = 3'b110;
                tx_att4   = 3'b110; 
            end
            5'd6: begin // -100dB 
                sw_tx_att = 4'b0000;
                tx_att2   = 3'b000;
                tx_att3   = 3'b110;
                tx_att4   = 3'b110; 
            end
            5'd7: begin // -95dB 
                sw_tx_att = 4'b0000;
                tx_att2   = 3'b000;
                tx_att3   = 3'b101;
                tx_att4   = 3'b110; 
            end
            5'd8: begin // -90dB 
                sw_tx_att = 4'b0000;
                tx_att2   = 3'b000;
                tx_att3   = 3'b100;
                tx_att4   = 3'b110; 
            end
            5'd9: begin // -85dB 
                sw_tx_att = 4'b0000;
                tx_att2   = 3'b000;
                tx_att3   = 3'b011;
                tx_att4   = 3'b110; 
            end
            5'd10: begin // -80dB 
                sw_tx_att = 4'b0000;
                tx_att2   = 3'b000;
                tx_att3   = 3'b010;
                tx_att4   = 3'b110; 
            end
            5'd11: begin // -75dB 
                sw_tx_att = 4'b0000;
                tx_att2   = 3'b000;
                tx_att3   = 3'b001;
                tx_att4   = 3'b110; 
            end
            5'd12: begin // -70dB 
                sw_tx_att = 4'b0000;
                tx_att2   = 3'b000;
                tx_att3   = 3'b001;
                tx_att4   = 3'b101; 
            end
            5'd13: begin // -65dB 
                sw_tx_att = 4'b0000;
                tx_att2   = 3'b000;
                tx_att3   = 3'b001;
                tx_att4   = 3'b100; 
            end
            5'd14: begin // -60dB 
                sw_tx_att = 4'b0000;
                tx_att2   = 3'b000;
                tx_att3   = 3'b001;
                tx_att4   = 3'b011; 
            end
            5'd15: begin // -55dB 
                sw_tx_att = 4'b0000;
                tx_att2   = 3'b000;
                tx_att3   = 3'b001;
                tx_att4   = 3'b010; 
            end
            5'd16: begin // -50dB 
                sw_tx_att = 4'b0000;
                tx_att2   = 3'b000;
                tx_att3   = 3'b001;
                tx_att4   = 3'b001; 
            end
            5'd17: begin // -45dB 
                sw_tx_att = 4'b0000;
                tx_att2   = 3'b000;
                tx_att3   = 3'b001;
                tx_att4   = 3'b000; 
            end
            5'd18: begin // -41dB 
                sw_tx_att = 4'b1000;
                tx_att2   = 3'b000;
                tx_att3   = 3'b001;
                tx_att4   = 3'b000; 
            end
            5'd19: begin // -37dB 
                sw_tx_att = 4'b0100;
                tx_att2   = 3'b000;
                tx_att3   = 3'b001;
                tx_att4   = 3'b000; 
            end
            5'd20: begin // -33dB 
                sw_tx_att = 4'b0010;
                tx_att2   = 3'b000;
                tx_att3   = 3'b001;
                tx_att4   = 3'b000; 
            end
            5'd21: begin // -29dB 
                sw_tx_att = 4'b0001;
                tx_att2   = 3'b000;
                tx_att3   = 3'b001;
                tx_att4   = 3'b000; 
            end
            5'd22: begin // -25dB 
                sw_tx_att = 4'b1001;
                tx_att2   = 3'b000;
                tx_att3   = 3'b001;
                tx_att4   = 3'b000; 
            end
            5'd23: begin // -21dB 
                sw_tx_att = 4'b0101;
                tx_att2   = 3'b000;
                tx_att3   = 3'b001;
                tx_att4   = 3'b000; 
            end
            5'd24: begin // -17dB 
                sw_tx_att = 4'b0011;
                tx_att2   = 3'b000;
                tx_att3   = 3'b001;
                tx_att4   = 3'b000; 
            end
            5'd25: begin // -13dB 
                sw_tx_att = 4'b1011;
                tx_att2   = 3'b000;
                tx_att3   = 3'b001;
                tx_att4   = 3'b000; 
            end
            5'd26: begin // -9dB 
                sw_tx_att = 4'b0111;
                tx_att2   = 3'b000;
                tx_att3   = 3'b001;
                tx_att4   = 3'b000; 
            end
            5'd27: begin // -5dB 
                sw_tx_att = 4'b1111;
                tx_att2   = 3'b000;
                tx_att3   = 3'b001;
                tx_att4   = 3'b000; 
            end
            default: begin // -130dB 
                sw_tx_att = 4'b0000;
                tx_att2   = 3'b110;
                tx_att3   = 3'b110;
                tx_att4   = 3'b110; 
            end
        endcase
    end
endmodule