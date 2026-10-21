`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/09/2026 03:35:20 PM
// Design Name: 
// Module Name: aurora_rstn
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


module aurora_rstn(
    input channel_up,
    input system_rst,
    output arstn
    );
    
    assign arstn = !system_rst & channel_up;
endmodule
