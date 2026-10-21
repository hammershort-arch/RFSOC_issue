`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/03/2026 11:41:56 AM
// Design Name: 
// Module Name: timer
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


module timer#(
	parameter TIME_WIDTH = 40
)(
	input 							aclk,
	input 							aresetn,
	input                           start,
	output reg [TIME_WIDTH-1:0]		timestamp
    );
	
	always@(posedge aclk) begin
		if(!aresetn)
			timestamp <= 'b0;
		else begin
		  if(start)
			timestamp <= timestamp + 1;
	      else
	        timestamp <= timestamp;
	    end   
	end
	
endmodule
