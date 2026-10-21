`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: cal_cdc
// Description: Calibration / Power Fit 設定的跨時脈 (reg_clk 100MHz -> clk 256MHz)
//              xpm_cdc_array_single + 穩定濾波 (連續 STABLE_CYCLES 拍不變才採用),
//              避免多 bit 欄位在變化那一拍讀到新舊混合值
//   (RegMap v8, 2026-10-10)
//   channel mem17 coarse_delay_offset        [3:0]
//   channel mem18 fractional_delay_offset    [2:0]
//   channel mem19 phase_offset               [15:0]
//   channel mem20 gain_index_mode_sel        [0]
//   channel mem21 gain_index_manual          [10:0]  S6.4
//   channel mem26 goal_ref_dbfs              [10:0]  S6.4 dBFS, dac_output_ref_dbm 量測時的 goal
//   system  sys0  signal_mode_select         [0]     0: CW, 1: Pulse
//   system  sys1  power_limit_margin         [2:0]   U3.0 dB
//   system  sys2  cw_mode_goal_dbfs          [10:0]  S6.4 dBFS (硬體另限制 <= -margin)
//   system  sys3  pulse_update_stable_cycle  [3:0]   clk
//   system  sys15 cw_power_avg_log2          [3:0]   CW 平均 N = 2^k
//   channel mem38 bypass_axis_iq             [0]     1: axis_iq_bypass_0 輸入直接輸出 (除錯, 2026-10-12)
//   channel mem39 signal_source_select       [1:0]   axis_iq_source_mux_0: 0 = s_axis_iq_in_0, 1 = s_axis_iq_in_1 (2026-10-14),
//                                                    2/3 = all_zero (Debug_008, 2026-10-19; 原為 [0])
//   (gain index offset / dac_output_ref_dbm / AGC 設定由 agc_cdc 同步到 adc_clk; FIR 係數 mem0~16 維持 false path)
//////////////////////////////////////////////////////////////////////////////////
module cal_cdc #(
    parameter STABLE_CYCLES = 4
)(
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 reg_clk CLK" *)
    input  wire        reg_clk,
    input  wire [31:0] reg_coarse_delay,           // mem17
    input  wire [31:0] reg_fractional_delay,       // mem18
    input  wire [31:0] reg_phase_offset,           // mem19
    input  wire [31:0] reg_cw_mode_goal_dbfs,      // sys2
    input  wire [31:0] reg_gain_index_mode_sel,    // mem20
    input  wire [31:0] reg_gain_index_manual,      // mem21
    input  wire [31:0] reg_signal_mode_select,     // sys0
    input  wire [31:0] reg_power_limit_margin,     // sys1
    input  wire [31:0] reg_goal_ref_dbfs,          // mem26
    input  wire [31:0] reg_pulse_update_stable_cycle, // sys3
    input  wire [31:0] reg_cw_power_avg_log2,      // sys15
    input  wire [31:0] reg_bypass_axis_iq,         // mem38
    input  wire [31:0] reg_signal_source_select,   // mem39

    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_RESET rst_n" *)
    input  wire        clk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rst_n RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input  wire        rst_n,

    output reg  [3:0]  delay_coarse,
    output reg  [2:0]  delay_fractional,
    output reg  [15:0] phase_offset,
    output reg  [10:0] cw_mode_goal_dbfs,
    output reg         gain_index_mode_sel,
    output reg  [10:0] gain_index_manual,
    output reg         signal_mode_select,
    output reg  [2:0]  power_limit_margin,
    output reg  [10:0] goal_ref_dbfs,
    output reg  [3:0]  pulse_update_stable_cycle,
    output reg  [3:0]  cw_power_avg_log2,
    output reg         bypass_axis_iq,
    output reg  [1:0]  signal_source_select
);

    localparam CFG_W = 4 + 3 + 16 + 11 + 1 + 11 + 1 + 3 + 11 + 4 + 4 + 1 + 2;   // 72

    wire [CFG_W-1:0] cfg_reg = {
        reg_coarse_delay[3:0], reg_fractional_delay[2:0], reg_phase_offset[15:0], reg_cw_mode_goal_dbfs[10:0],
        reg_gain_index_mode_sel[0], reg_gain_index_manual[10:0], reg_signal_mode_select[0],
        reg_power_limit_margin[2:0], reg_goal_ref_dbfs[10:0], reg_pulse_update_stable_cycle[3:0], reg_cw_power_avg_log2[3:0],
        reg_bypass_axis_iq[0], reg_signal_source_select[1:0] };
    wire [CFG_W-1:0] cfg_sync;

    xpm_cdc_array_single #(
        .DEST_SYNC_FF   (3),
        .INIT_SYNC_FF   (1),
        .SIM_ASSERT_CHK (0),
        .SRC_INPUT_REG  (1),
        .WIDTH          (CFG_W)
    ) u_cdc_cfg (
        .src_clk  (reg_clk),
        .src_in   (cfg_reg),
        .dest_clk (clk),
        .dest_out (cfg_sync)
    );

    // 穩定濾波: cfg_sync 連續 STABLE_CYCLES 拍相同才更新輸出
    reg [CFG_W-1:0] cfg_sync_d;
    reg [3:0]       stable_cnt;
    always @(posedge clk) begin
        if (!rst_n) begin
            cfg_sync_d <= {CFG_W{1'b0}};
            stable_cnt <= 4'd0;
            {delay_coarse, delay_fractional, phase_offset, cw_mode_goal_dbfs, gain_index_mode_sel,
             gain_index_manual, signal_mode_select, power_limit_margin, goal_ref_dbfs, pulse_update_stable_cycle, cw_power_avg_log2, bypass_axis_iq, signal_source_select} <= {CFG_W{1'b0}};
        end else begin
            cfg_sync_d <= cfg_sync;
            if (cfg_sync != cfg_sync_d)
                stable_cnt <= 4'd0;
            else if (stable_cnt < STABLE_CYCLES - 1)
                stable_cnt <= stable_cnt + 1'b1;
            else
                {delay_coarse, delay_fractional, phase_offset, cw_mode_goal_dbfs, gain_index_mode_sel,
                 gain_index_manual, signal_mode_select, power_limit_margin, goal_ref_dbfs, pulse_update_stable_cycle, cw_power_avg_log2, bypass_axis_iq, signal_source_select} <= cfg_sync_d;
        end
    end

endmodule
