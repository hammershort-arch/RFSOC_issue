`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/29/2026 02:47:10 PM
// Design Name: 
// Module Name: cw_power_calc_IQ
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


module cw_power_calc_IQ(
    input  wire         clk,
    input  wire         resetn,              // Active-low 非同步/同步 Reset

    // 1. AXIS 訊號輸入: I / Q 各 80-bit (5 Samples/cycle x 16-bit)
    input  wire [79:0]  s_axis_i_tdata,
    input  wire         s_axis_i_tvalid,
    output wire         s_axis_i_tready,
    
    input  wire [79:0]  s_axis_q_tdata,
    input  wire         s_axis_q_tvalid,
    output wire         s_axis_q_tready,

    // 2. 算出的 CW 振幅輸出 (提供給外部 Mux / Switch 選擇)
    output wire         o_power_valid,       // 振幅計算完成 Flag (給外部 Mux)
    output wire [15:0]  o_power_amp          // 當前 CW 振幅 (給外部 Mux)
);

    // 由於是 Streaming 流水線計算，隨時準備好接收 input
    assign s_axis_i_tready = 1'b1;
    assign s_axis_q_tready = 1'b1;

    // =========================================================================
    // Step 1: 擷取第 3 組 Sample (0-based sample 2)
    // 位元映射 (2026-10-12 註解更新, I / Q 為分開的 80-bit bus):
    // s_axis_i_tdata[47:32] --> Sample 2 Inphase (I)
    // s_axis_q_tdata[47:32] --> Sample 2 Quadrature (Q)
    // =========================================================================
    wire [15:0] sample3_i = s_axis_i_tdata[47:32];
    wire [15:0] sample3_q = s_axis_q_tdata[47:32];
    
    wire sample_valid = s_axis_i_tvalid && s_axis_q_tvalid;

    // 同步轉換 active-low resetn 為 active-high reset 給 power_computation_wrapper 使用
    wire sys_reset = ~resetn;

    // =========================================================================
    // Step 2: 例化 power_computation_wrapper 進行單點 CW 振幅計算
    // =========================================================================
    power_computation_wrapper u_power_computation_wrapper (
        .i_clk       (clk),
        .i_reset     (sys_reset),
        .i_valid     (sample_valid),
        .i_inphase   (sample3_i),
        .i_quadrature(sample3_q),
        .o_valid     (o_power_valid),
        .o_power     (o_power_amp)
    );

endmodule
