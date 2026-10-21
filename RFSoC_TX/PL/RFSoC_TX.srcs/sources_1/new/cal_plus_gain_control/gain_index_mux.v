`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: gain_index_mux
// Description: Gain Compensation 的 gain index 選擇 (單位 1/16 dB)
//   gain_index_mode_sel = 0 : gain_index_in     (agc_emu/gain_index_tx: TXAGC 數位 gain = pf - R, 已與類比同步, S7.4)
//   gain_index_mode_sel = 1 : gain_index_manual (AGC 以外的手動設定, S6.4 11-bit, 不加 offset)
//   純組合邏輯 (0 拍), clk 未使用 (2026-10-12 註解更新; offset 自 2026-10-09 起併入 TXAGC 目標)
//   輸出 12-bit (signed); BRAM 只使用低 11 bit (2048 entry, 11-bit 二補數排列)
//////////////////////////////////////////////////////////////////////////////////
module gain_index_mux #(
    parameter GAIN_WIDTH = 12
)(
    input                          clk,
    input  wire                    gain_index_mode_sel,
    input  wire [GAIN_WIDTH-1:0]   gain_index_in,
    input  wire [10:0]             gain_index_manual,
    output reg  [GAIN_WIDTH-1:0]   gain_index_out
);
    wire [GAIN_WIDTH-1:0] manual_ext = {{(GAIN_WIDTH-11){gain_index_manual[10]}}, gain_index_manual};

    always @(*) begin
        if (gain_index_mode_sel)
            gain_index_out = manual_ext;
        else
            gain_index_out = gain_index_in;
    end
endmodule
