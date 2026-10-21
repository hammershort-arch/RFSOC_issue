`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/09/03 10:50:34
// Design Name: 
// Module Name: txagc_calc
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Revision 0.02 - 3-stage pipeline (256MHz), /5 /4 改為等價的乘法/位移
// Revision 0.06 - (2026-10-10) 換檔遲滯: 目前檔位在 T 超出 [類比 - H, 上一檔 + H) 才換檔 (H = tx_att_hysteresis),
//                 R 範圍 -H ~ 79 + H; 多一級 pipeline (latency 3 -> 4); H = 0 時與 0.05 相同
// Revision 0.05 - (2026-10-09) 類比優先分配: 目標總衰減 T 加入 Power Fit / gain index offset / algo_analog_ATT_dB,
//                 rx_att 改為 rx_att_index (x10 dB); Manual mode 以 dac_output_ref_dbm + goal_rel_db 推算 DAC 輸出;
//                 類比鎖在 5 ~ 130 dB, 數位殘差 R 限制 0 ~ 4.9375 dB, 數位 gain_index = pf - R
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module txagc_calc(
    input  wire               clk,
    input  wire               resetn,
    input  wire               in_valid,              // 輸入有效 (持續計算時固定 1)

    // --- Inputs (1/16 dB 欄位為 S?.4) ---
    input  wire        [2:0]  rx_att_index,          // RSP RX 衰減 index, x10 dB (0~6, >6 視為 6)
    input  wire signed [9:0]  gain_index_power_fit,  // S5.4, Power Fit (+ = gain)
    input  wire signed [9:0]  goal_rel_db,           // S5.4, 20log10(goal / goal_ref)
    input  wire signed [10:0] dac_output_ref_dbm,    // S6.4, goal_ref 下的 DAC 輸出 (dBm)
    input  wire signed [8:0]  gain_index_ch_offset,  // S4.4 (+ = gain)
    input  wire signed [7:0]  gain_index_rf_freq_offset,      // S3.4
    input  wire signed [7:0]  gain_index_temperature_offset,  // S3.4
    input  wire signed [8:0]  algo_analog_att_db,    // S8.0, 1 dB (+ = 衰減)
    input  wire signed [7:0]  target_power,          // 1 dBm (Manual mode)

    input  wire               tx_mode,               // 0: Linear Mode, 1: Manual Mode
    input  wire               manual_tx_att_enable,  // 1: T = manual_tx_att_db (其他項不加)
    input  wire        [7:0]  manual_tx_att_db,      // 1 dB (Unsigned)

    input  wire signed [11:0] linear_mode_offset,    // 1/16 dB
    input  wire signed [11:0] manual_mode_offset,    // 1/16 dB
    input  wire        [7:0]  tx_att_hysteresis,     // U4.4, 1/16 dB (換檔遲滯 H)

    // --- Outputs (Latency = 4 clk) ---
    output reg                out_valid,
    output reg         [4:0]  tx_att_state,          // 0~27 檔位 (0 = 130 dB ... 27 = 5 dB)
    output reg  signed [9:0]  digital_comp_index,    // 數位殘差 R (衰減), -H ~ 79 + H (1/16 dB)
    output reg  signed [11:0] gain_index_digital,    // 數位端 gain index = pf - R (1/16 dB, + = gain)
    output reg                analog_clamp_hi,       // T > 類比上限 (130 dB) 範圍 (鎖住)
    output reg                analog_clamp_lo        // T < 類比下限 (5 dB) (鎖住)
);

    localparam signed [17:0] LINEAR_BASE = 18'sd1545;   // TRM_RX_Gain + TRM_TX_Gain = 96.5625 dB
    localparam signed [17:0] G_TX        = 18'sd800;    // TRM_TX_Gain 50 dB (Manual mode)
    localparam signed [9:0]  R_MAX       = 10'sd79;     // 4.9375 dB

    // =========================================================================
    // Stage 1: 目標總衰減 T (1/16 dB)
    //   Linear : T = 1545 + linear_offset - rx_att_index x 160 + pf - offs + algo x 16
    //   Manual : T = dac_ref + goal_rel + 800 - target x 16 + manual_offset - offs + algo x 16
    //   手動 TX: T = manual_tx_att_db x 16
    //   offs = ch + rf_freq + temperature
    // =========================================================================
    wire [2:0]         rx_idx = (rx_att_index > 3'd6) ? 3'd6 : rx_att_index;
    wire [10:0]        rx_att16 = rx_idx * 11'd160;           // x10 dB, 1/16 dB 單位 (0 ~ 960)
    wire signed [17:0] offs   = gain_index_ch_offset + gain_index_rf_freq_offset + gain_index_temperature_offset;
    wire signed [17:0] algo16 = algo_analog_att_db <<< 4;
    reg  signed [17:0] target_att_1in16;
    always @(*) begin
        if (manual_tx_att_enable)
            target_att_1in16 = $signed({1'b0, manual_tx_att_db}) <<< 4;
        else if (tx_mode == 1'b0)
            target_att_1in16 = LINEAR_BASE + linear_mode_offset - $signed({1'b0, rx_att16})
                             + gain_index_power_fit - offs + algo16;
        else
            target_att_1in16 = dac_output_ref_dbm + goal_rel_db + G_TX - (target_power <<< 4)
                             + manual_mode_offset - offs + algo16;
    end

    // =========================================================================
    // Stage 2: 類比檔位 (不超過 T 的最大檔位, 鎖在 5 ~ 130 dB)
    // =========================================================================
    reg signed [17:0] s1_target_att_1in16;
    reg signed [13:0] target_att_int;
    reg signed [9:0]  analog_att_db;
    reg        [4:0]  att_state;
    reg        [15:0] div5_tmp;
    always @(*) begin
        target_att_int = s1_target_att_1in16 >>> 4;      // floor (1 dB)
        div5_tmp       = 16'd0;
        if (target_att_int >= 14'sd130) begin
            att_state     = 5'd0;
            analog_att_db = 10'sd130;
        end else if (target_att_int >= 14'sd45) begin
            // state = (134 - T) / 5, x / 5 = (x * 205) >> 10 (x = 5~89)
            div5_tmp      = (10'd134 - target_att_int[9:0]) * 16'd205;
            att_state     = div5_tmp[14:10];
            analog_att_db = 10'sd130 - ($signed({1'b0, att_state}) * 10'sd5);
        end else if (target_att_int >= 14'sd5) begin
            att_state     = 5'd17 + ((10'd48 - target_att_int[9:0]) >> 2);
            analog_att_db = 10'sd45 - (($signed({1'b0, att_state}) - 10'sd17) * 10'sd4);
        end else begin
            att_state     = 5'd27;
            analog_att_db = 10'sd5;
        end
    end

    // =========================================================================
    // Pipeline
    //   s1: T / pf   s2: 名目類比檔位 (無遲滯)   s3: 遲滯判斷   out: R / 數位 gain index / clamp 旗標
    // =========================================================================
    reg signed [17:0] s2_target_att_1in16, s3_target_att_1in16;
    reg signed [9:0]  s2_analog_att_db, s3_analog_att_db;
    reg        [4:0]  s2_tx_att_state;
    reg        [4:0]  h_state;                       // 遲滯後的檔位 (= 目前送給硬體的檔位)
    reg signed [9:0]  s1_pf, s2_pf, s3_pf;
    reg               s1_valid, s2_valid, s3_valid;

    // 檔位 -> 類比衰減 (dB)
    function [7:0] att_of(input [4:0] st);
        att_of = (st <= 5'd17) ? (8'd130 - 8'd5 * st) : (8'd45 - 8'd4 * (st - 5'd17));
    endfunction

    // 遲滯: 目前檔位 h_state 的範圍 [A(h) - H, A(h-1) + H) (h = 0 時無上限), T 在範圍內就維持
    wire signed [12:0] hyst    = $signed({5'd0, tx_att_hysteresis});
    wire        [7:0]  a_cur   = att_of(h_state);
    wire        [7:0]  a_up    = att_of(h_state - 5'd1);
    wire signed [17:0] lo_b    = $signed({6'd0, a_cur, 4'd0}) - hyst;
    wire signed [17:0] hi_b    = $signed({6'd0, a_up,  4'd0}) + hyst;
    wire               keep    = (s2_target_att_1in16 >= lo_b) && ((h_state == 5'd0) || (s2_target_att_1in16 < hi_b));

    wire signed [17:0] r_raw = s3_target_att_1in16 - (s3_analog_att_db <<< 4);
    wire signed [17:0] r_lo  = -hyst;
    wire signed [17:0] r_hi  = R_MAX + hyst;
    wire signed [9:0]  r_sat = (r_raw < r_lo) ? r_lo[9:0] : (r_raw > r_hi) ? r_hi[9:0] : r_raw[9:0];

    always @(posedge clk) begin
        if (!resetn) begin
            s1_valid            <= 1'b0;
            s2_valid            <= 1'b0;
            s3_valid            <= 1'b0;
            out_valid           <= 1'b0;
            s1_target_att_1in16 <= 18'sd0;
            s2_target_att_1in16 <= 18'sd0;
            s3_target_att_1in16 <= 18'sd0;
            s1_pf               <= 10'sd0;
            s2_pf               <= 10'sd0;
            s3_pf               <= 10'sd0;
            s2_analog_att_db    <= 10'sd130;
            s3_analog_att_db    <= 10'sd130;
            s2_tx_att_state     <= 5'd0;
            h_state             <= 5'd0;
            tx_att_state        <= 5'd0;     // 預設 -130dB
            digital_comp_index  <= 10'sd0;
            gain_index_digital  <= 12'sd0;
            analog_clamp_hi     <= 1'b0;
            analog_clamp_lo     <= 1'b0;
        end else begin
            s1_valid  <= in_valid;
            s2_valid  <= s1_valid;
            s3_valid  <= s2_valid;
            out_valid <= s3_valid;

            if (in_valid) begin
                s1_target_att_1in16 <= target_att_1in16;
                s1_pf               <= gain_index_power_fit;
            end
            if (s1_valid) begin
                s2_target_att_1in16 <= s1_target_att_1in16;
                s2_pf               <= s1_pf;
                s2_analog_att_db    <= analog_att_db;
                s2_tx_att_state     <= att_state;
            end
            if (s2_valid) begin
                s3_target_att_1in16 <= s2_target_att_1in16;
                s3_pf               <= s2_pf;
                if (keep) begin
                    s3_analog_att_db <= $signed({2'b00, a_cur});
                end else begin
                    h_state          <= s2_tx_att_state;
                    s3_analog_att_db <= s2_analog_att_db;
                end
            end
            if (s3_valid) begin
                tx_att_state       <= h_state;
                digital_comp_index <= r_sat;
                gain_index_digital <= s3_pf - r_sat;
                analog_clamp_hi    <= (s3_target_att_1in16 >= 18'sd2160 + hyst);   // 類比已到 130 dB 且 R 飽和
                analog_clamp_lo    <= (s3_target_att_1in16 <  18'sd80 - hyst);     // < 5 dB - H
            end
        end
    end

endmodule
