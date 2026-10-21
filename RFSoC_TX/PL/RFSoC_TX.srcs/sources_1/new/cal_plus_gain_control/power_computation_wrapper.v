`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/09/2026 02:53:20 PM
// Design Name: 
// Module Name: power_computation_wrapper
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


module power_computation_wrapper(
    input wire        i_clk,
    input wire        i_reset,
    input wire        i_valid,
    input wire [15:0] i_inphase,
    input wire [15:0] i_quadrature,
    output wire       o_valid,
    output wire [15:0] o_power
);

    power_computation u_power_computation (
        .i_clk(i_clk),
        .i_reset(i_reset),
        .i_valid(i_valid),
        .i_inphase(i_inphase),
        .i_quadrature(i_quadrature),
        .o_valid(o_valid),
        .o_power(o_power)
    );

endmodule
