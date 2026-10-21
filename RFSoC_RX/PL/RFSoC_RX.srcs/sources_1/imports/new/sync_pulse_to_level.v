`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/05/2026 05:35:53 PM
// Design Name: 
// Module Name: sync_pulse_to_level
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


module sync_pulse_to_level(
    input   clk,
    input   rst_n,
    input   pulse_ref,
    output  reg level_ref
    );
    
    always@(posedge clk) begin
        if(!rst_n)
            level_ref <= 0;
        else begin
            if(pulse_ref)
                level_ref <= 1;
            else
                level_ref <= level_ref;
        end
    end
endmodule
