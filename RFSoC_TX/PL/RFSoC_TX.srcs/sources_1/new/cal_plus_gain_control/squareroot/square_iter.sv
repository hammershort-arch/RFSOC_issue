`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/07/2026 01:32:43 PM
// Design Name: 
// Module Name: square_iter
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


module square_iter#(parameter bit ENABLE_PIPE = 0 )
(
    sqrt_iter_if.stage_in  in,   
    input  logic [1:0] i_pair,
    input  logic  i_clk,
    input  logic  i_rst,
    sqrt_iter_if.stage_out out 
);
  
    localparam int TEST_WIDTH = $bits(out.rem);
    logic [TEST_WIDTH-1:0] v_test;
    logic [TEST_WIDTH-1:0] v_current_rem;

    assign v_test = {in.root, 2'b01};
    assign v_current_rem = {in.rem, i_pair};

/*    always_comb begin
        if (v_current_rem >= v_test) begin
            out.rem  = v_current_rem - v_test;
            out.root = {in.root, 1'b1};
        end 
        else begin
            out.rem  = v_current_rem;
            out.root = {in.root, 1'b0};
        end
    end*/
    
    generate
        if (ENABLE_PIPE) begin : pipe_gen
            always_ff @(posedge i_clk) begin
                out.rem <= (v_current_rem >= v_test) ? (v_current_rem - v_test) : v_current_rem;
                out.root <= (v_current_rem >= v_test) ? {in.root, 1'b1} : {in.root, 1'b0};
            end
        end 
        else begin : comb_gen
            assign out.rem  = (v_current_rem >= v_test) ? (v_current_rem - v_test) : v_current_rem;
            assign out.root = (v_current_rem >= v_test) ? {in.root, 1'b1} : {in.root, 1'b0};
        end
    endgenerate

endmodule
