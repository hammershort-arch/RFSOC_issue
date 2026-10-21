`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/09/2026 01:53:37 PM
// Design Name: 
// Module Name: power_computation
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


module power_computation(
input logic i_clk,
input logic i_reset,
input logic i_valid,
input logic[15:0] i_inphase,
input logic[15:0] i_quadrature,

output logic o_valid = 'd0,
output logic[15:0] o_power
    );
    logic [31:0] inp_squ ;
    logic [31:0] qua_squ ;
    logic [30:0] inp_squ_reg = 'd0;
    logic [30:0] qua_squ_reg = 'd0;
    logic [31:0] inp_qua_add_reg = 'd0;
    logic [1:0] valid = 'd0;
    
    assign inp_squ = $signed(i_inphase) * $signed(i_inphase) ;
    assign qua_squ = $signed(i_quadrature) * $signed(i_quadrature) ;
    
    always_ff@(posedge i_clk)begin
        if(i_reset)
            valid <= 0;
        else begin
            valid[0] <= i_valid;
            valid[1] <= valid[0];
        end
    end
    
    
    always_ff@(posedge i_clk)begin
        inp_squ_reg <= inp_squ[30:0] ;
        qua_squ_reg <= qua_squ[30:0] ;
        inp_qua_add_reg <= inp_squ_reg + qua_squ_reg ;
    end
    
    
    square_root u_square_root(
        .i_clk(i_clk),
        .i_rst(i_reset),
        .i_valid(valid[1]),
        .i_data(inp_qua_add_reg),
        .o_out(o_power),
        .o_ready(o_valid)
    );
    
    
    
endmodule
