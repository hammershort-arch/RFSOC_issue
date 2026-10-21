`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: power_fit_db
// Description: dB 域 Power Fit (2026-10-10, 取代 goal_amp_calc + power_fit + u_goal_rel), clk 256 MHz
//   1. 輸入更新
//      Pulse (signal_mode_select = 1): pulse_avg_amp / pulse_papr 改變後連續 M 拍 (pulse_update_stable_cycle)
//             不再變才一起鎖存 (自動觸發, 不需外部 valid; reset 後也先鎖存一次)
//      CW    (signal_mode_select = 0): cw_amp 區塊平均 N = 2^cw_power_avg_log2 個 cw_valid (2026-10-10, 預設 256),
//             每 N 個 sample 更新一次 (cw_power_calc 是單一 sample 的瞬間振幅, 每拍晃動)
//   2. goal (dBFS, 16384 = 0 dBFS, S?.4 1/16 dB)
//      Pulse: -(margin + PAPR)          CW: min(cw_mode_goal_dbfs, -margin)   (power limit = -margin dBFS)
//   3. input dBFS = (p - 14) x 6.0206 dB + 20log10(1 + m/1024)   (p = 最高位 1 的位置, m = 其後 10 bit, 誤差 <= 0.009 dB)
//   4. gain_index_power_fit = round(goal - input) (S5.4, 飽和 +-511)
//      goal_rel_db          = goal - goal_ref_dbfs (S5.4, 飽和 +-511)
//      goal_db              = goal (S7.4 dBFS)
//      三個輸出在同一拍更新 (同一組鎖存值算出), 鎖存後 6 拍輸出; 每拍都可出新結果 (無逐步逼近迴圈)
//////////////////////////////////////////////////////////////////////////////////
module power_fit_db (
    input  wire               clk,
    input  wire               rst_n,

    input  wire               signal_mode_select,        // 0: CW, 1: Pulse
    input  wire        [2:0]  power_limit_margin,        // U3.0 dB
    input  wire signed [10:0] cw_mode_goal_dbfs,         // S6.4 dBFS
    input  wire signed [10:0] goal_ref_dbfs,             // S6.4 dBFS
    input  wire        [3:0]  pulse_update_stable_cycle, // M (clk)
    input  wire        [3:0]  cw_power_avg_log2,         // CW 平均 N = 2^k (k > 12 視為 12)

    input  wire        [15:0] cw_amp,                    // cw_power_calc_IQ_0/o_power_amp
    input  wire               cw_valid,
    input  wire        [15:0] pulse_avg_amp,
    input  wire        [8:0]  pulse_papr,                // U5.4 dB

    output reg  signed [9:0]  gain_index_power_fit = 10'sd0,  // S5.4
    output reg  signed [9:0]  goal_rel_db          = 10'sd0,  // S5.4
    output reg  signed [11:0] goal_db              = 12'sd0   // S7.4 dBFS
);

    // =========================================================================
    // 0. 輸入鎖存
    // =========================================================================
    reg [15:0] avg_d = 16'd0;
    reg [8:0]  papr_d = 9'd0;
    reg        pend = 1'b1;
    reg [3:0]  stable_cnt = 4'd0;
    reg [15:0] snap_avg = 16'd0;
    reg [8:0]  snap_papr = 9'd0;
    reg [15:0] snap_cw = 16'd0;

    always @(posedge clk) begin
        avg_d  <= pulse_avg_amp;
        papr_d <= pulse_papr;
        if (!rst_n) begin
            pend       <= 1'b1;
            stable_cnt <= 4'd0;
            snap_avg   <= 16'd0;
            snap_papr  <= 9'd0;
        end else begin
            if (pulse_avg_amp != avg_d || pulse_papr != papr_d) begin
                pend       <= 1'b1;
                stable_cnt <= 4'd0;
            end else if (pend) begin
                if ({1'b0, stable_cnt} + 5'd1 >= {1'b0, pulse_update_stable_cycle}) begin   // 改變後已連續 M 拍不變
                    snap_avg  <= avg_d;
                    snap_papr <= papr_d;
                    pend      <= 1'b0;
                end else begin
                    stable_cnt <= stable_cnt + 1'b1;
                end
            end
        end
    end

    // CW: 區塊平均 (integrate-and-dump), N = 2^k 個 cw_valid 取一次平均
    wire [3:0]  avg_k   = (cw_power_avg_log2 > 4'd12) ? 4'd12 : cw_power_avg_log2;
    wire [12:0] avg_nm1 = (13'd1 << avg_k) - 13'd1;
    reg  [27:0] cw_acc = 28'd0;
    reg  [27:0] cw_sum = 28'd0;
    reg  [12:0] cw_cnt = 13'd0;
    reg         cw_done = 1'b0;
    reg  [3:0]  cw_k = 4'd0;
    always @(posedge clk) begin
        if (!rst_n) begin
            cw_acc  <= 28'd0;
            cw_cnt  <= 13'd0;
            cw_done <= 1'b0;
            snap_cw <= 16'd0;
        end else begin
            cw_done <= 1'b0;
            if (cw_valid) begin
                if (cw_cnt >= avg_nm1) begin
                    cw_sum  <= cw_acc + {12'd0, cw_amp};
                    cw_k    <= avg_k;
                    cw_done <= 1'b1;
                    cw_acc  <= 28'd0;
                    cw_cnt  <= 13'd0;
                end else begin
                    cw_acc  <= cw_acc + {12'd0, cw_amp};
                    cw_cnt  <= cw_cnt + 1'b1;
                end
            end
            if (cw_done) snap_cw <= cw_sum >> cw_k;
        end
    end

    // =========================================================================
    // 1. 輸入 / goal 選擇
    // =========================================================================
    wire signed [11:0] lim  = -$signed({5'd0, power_limit_margin, 4'd0});          // -margin (1/16 dB)
    wire signed [11:0] cwg  = {cw_mode_goal_dbfs[10], cw_mode_goal_dbfs};
    wire signed [11:0] pulg = -$signed({1'b0, {power_limit_margin, 4'd0} + {1'b0, snap_papr}});  // -(margin + PAPR)

    reg [15:0]        x1 = 16'd1;
    reg signed [11:0] g1 = 12'sd0;
    always @(posedge clk) begin
        x1 <= signal_mode_select ? ((snap_avg == 16'd0) ? 16'd1 : snap_avg)
                                 : ((snap_cw  == 16'd0) ? 16'd1 : snap_cw);
        g1 <= signal_mode_select ? pulg : ((cwg > lim) ? lim : cwg);
    end

    // =========================================================================
    // 2. 正規化: p = 最高位 1 的位置, m = 其後 10 bit
    // =========================================================================
    function [3:0] msb_pos(input [15:0] v);
        integer i;
        begin
            msb_pos = 4'd0;
            for (i = 0; i < 16; i = i + 1) if (v[i]) msb_pos = i[3:0];
        end
    endfunction
    wire [3:0]  p1   = msb_pos(x1);
    wire [15:0] norm = x1 << (4'd15 - p1);       // bit15 = 1

    reg [3:0]         p2 = 4'd0;
    reg [9:0]         m2 = 10'd0;
    reg signed [11:0] g2 = 12'sd0;
    always @(posedge clk) begin
        p2 <= p1;
        m2 <= norm[14:5];
        g2 <= g1;
    end

    // =========================================================================
    // 3~4. log ROM (2 拍)
    // =========================================================================
    wire [10:0] q4;
    db_log_rom u_rom (.clk(clk), .m(m2), .q(q4));
    reg [3:0]         p3 = 4'd0, p4 = 4'd0;
    reg signed [11:0] g3 = 12'sd0, g4 = 12'sd0;
    always @(posedge clk) begin
        p3 <= p2; p4 <= p3;
        g3 <= g2; g4 <= g3;
    end

    // =========================================================================
    // 5. input dBFS (1/256 dB) 與 goal - input
    // =========================================================================
    function signed [15:0] pk(input [3:0] p);   // round(256 x 20log10(2) x (p - 14))
        case (p)
            4'd0:  pk = -16'sd21578;  4'd1:  pk = -16'sd20037;  4'd2:  pk = -16'sd18495;  4'd3:  pk = -16'sd16954;
            4'd4:  pk = -16'sd15413;  4'd5:  pk = -16'sd13871;  4'd6:  pk = -16'sd12330;  4'd7:  pk = -16'sd10789;
            4'd8:  pk = -16'sd9248;   4'd9:  pk = -16'sd7706;   4'd10: pk = -16'sd6165;   4'd11: pk = -16'sd4624;
            4'd12: pk = -16'sd3083;   4'd13: pk = -16'sd1541;   4'd14: pk =  16'sd0;      default: pk = 16'sd1541;
        endcase
    endfunction
    wire signed [16:0] in_q8   = pk(p4) + $signed({6'd0, q4});
    wire signed [16:0] goal_q8 = $signed({g4, 4'd0});        // concat 為無號, 需轉回有號再符號擴展
    reg  signed [17:0] diff5 = 18'sd0;
    reg  signed [11:0] g5 = 12'sd0;
    always @(posedge clk) begin
        diff5 <= goal_q8 - in_q8;
        g5    <= g4;
    end

    // =========================================================================
    // 6. 四捨五入 + 飽和, 三個輸出同一拍更新
    // =========================================================================
    wire signed [13:0] pf_r = (diff5 + 18'sd8) >>> 4;                  // 1/16 dB
    wire signed [12:0] rel  = g5 - goal_ref_dbfs;                      // 兩者皆有號, 自動符號擴展
    always @(posedge clk) begin
        gain_index_power_fit <= (pf_r > 14'sd511) ? 10'sd511 : (pf_r < -14'sd511) ? -10'sd511 : pf_r[9:0];
        goal_rel_db          <= (rel  > 13'sd511) ? 10'sd511 : (rel  < -13'sd511) ? -10'sd511 : rel[9:0];
        goal_db              <= g5;
    end

endmodule
