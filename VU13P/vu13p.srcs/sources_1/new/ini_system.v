`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/23/2026 03:25:08 PM
// Design Name: 
// Module Name: ini_pma
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


module ini_system(
input i_clk,
input i_pma_rst,

output reg ini_pma ='d1
    );
    
    
    reg[8:0] cnt = 'd0;
    
    always@(posedge i_clk)begin
        if(&cnt)
            cnt <= cnt;
        else    
            cnt <= cnt + 1;
    end
    
    
    always@(posedge i_clk)begin
        if(i_pma_rst || ~(&cnt[7:0])) 
            ini_pma <= 1;
        else
            ini_pma <= 0;
    end
    
endmodule
