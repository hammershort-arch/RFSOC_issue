`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/17/2026 06:15:45 PM
// Design Name: 
// Module Name: FIR_coef_unpack
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


module FIR_coef_unpack(

    input clk,
    // -------------------------------------------------------------------------
    // 16 組 32-bit Packed 暫存器輸入 ([31:16] = Q, [15:0] = I)
    // -------------------------------------------------------------------------
    input wire [31:0] in_tap00,
    input wire [31:0] in_tap01,
    input wire [31:0] in_tap02,
    input wire [31:0] in_tap03,
    input wire [31:0] in_tap04,
    input wire [31:0] in_tap05,
    input wire [31:0] in_tap06,
    input wire [31:0] in_tap07,
    input wire [31:0] in_tap08,
    input wire [31:0] in_tap09,
    input wire [31:0] in_tap10,
    input wire [31:0] in_tap11,
    input wire [31:0] in_tap12,
    input wire [31:0] in_tap13,
    input wire [31:0] in_tap14,
    input wire [31:0] in_tap15,
 
    // -------------------------------------------------------------------------
    // 32 條獨立 16-bit 輸出 (對應到 TOP_complex_FIR 的獨立 Ports)
    // -------------------------------------------------------------------------
    output wire signed [15:0] tap00_i, output wire signed [15:0] tap00_q,
    output wire signed [15:0] tap01_i, output wire signed [15:0] tap01_q,
    output wire signed [15:0] tap02_i, output wire signed [15:0] tap02_q,
    output wire signed [15:0] tap03_i, output wire signed [15:0] tap03_q,
    output wire signed [15:0] tap04_i, output wire signed [15:0] tap04_q,
    output wire signed [15:0] tap05_i, output wire signed [15:0] tap05_q,
    output wire signed [15:0] tap06_i, output wire signed [15:0] tap06_q,
    output wire signed [15:0] tap07_i, output wire signed [15:0] tap07_q,
    output wire signed [15:0] tap08_i, output wire signed [15:0] tap08_q,
    output wire signed [15:0] tap09_i, output wire signed [15:0] tap09_q,
    output wire signed [15:0] tap10_i, output wire signed [15:0] tap10_q,
    output wire signed [15:0] tap11_i, output wire signed [15:0] tap11_q,
    output wire signed [15:0] tap12_i, output wire signed [15:0] tap12_q,
    output wire signed [15:0] tap13_i, output wire signed [15:0] tap13_q,
    output wire signed [15:0] tap14_i, output wire signed [15:0] tap14_q,
    output wire signed [15:0] tap15_i, output wire signed [15:0] tap15_q
);
 
    // 位元拆解：bit[15:0] 為 I，bit[31:16] 為 Q
    assign tap00_i = in_tap00[15:0];  assign tap00_q = in_tap00[31:16];
    assign tap01_i = in_tap01[15:0];  assign tap01_q = in_tap01[31:16];
    assign tap02_i = in_tap02[15:0];  assign tap02_q = in_tap02[31:16];
    assign tap03_i = in_tap03[15:0];  assign tap03_q = in_tap03[31:16];
    assign tap04_i = in_tap04[15:0];  assign tap04_q = in_tap04[31:16];
    assign tap05_i = in_tap05[15:0];  assign tap05_q = in_tap05[31:16];
    assign tap06_i = in_tap06[15:0];  assign tap06_q = in_tap06[31:16];
    assign tap07_i = in_tap07[15:0];  assign tap07_q = in_tap07[31:16];
    assign tap08_i = in_tap08[15:0];  assign tap08_q = in_tap08[31:16];
    assign tap09_i = in_tap09[15:0];  assign tap09_q = in_tap09[31:16];
    assign tap10_i = in_tap10[15:0];  assign tap10_q = in_tap10[31:16];
    assign tap11_i = in_tap11[15:0];  assign tap11_q = in_tap11[31:16];
    assign tap12_i = in_tap12[15:0];  assign tap12_q = in_tap12[31:16];
    assign tap13_i = in_tap13[15:0];  assign tap13_q = in_tap13[31:16];
    assign tap14_i = in_tap14[15:0];  assign tap14_q = in_tap14[31:16];
    assign tap15_i = in_tap15[15:0];  assign tap15_q = in_tap15[31:16];
 
endmodule
