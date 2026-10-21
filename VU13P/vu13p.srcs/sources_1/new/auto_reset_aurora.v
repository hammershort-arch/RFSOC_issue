`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/20/2026 12:52:22 PM
// Design Name: 
// Module Name: auto_reset_aurora
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


module auto_reset_aurora(
input i_clk,
input pll_lock,
output reg reset_pb = 'd1
    );
    
    reg[3:0] pll_lock_reg = 'd0;
    
    always@(posedge i_clk)begin
        pll_lock_reg[0] <= pll_lock ;
        pll_lock_reg[1] <= pll_lock_reg[0] ;
        pll_lock_reg[2] <= pll_lock_reg[1] ;
        pll_lock_reg[3] <= pll_lock_reg[2] ;
    end
        

        
    always@(posedge i_clk)
        if(&pll_lock_reg)begin
            reset_pb <= 0;
        end
        else begin
            reset_pb <= 1;
        end
    
   
                  
    
    
    
    
    
endmodule
