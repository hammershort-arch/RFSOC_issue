`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/09/02 10:58:57
// Design Name: 
// Module Name: txagc_dummy
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


module txagc_dummy(
    //input  wire       clk,
    //input  wire       resetn,
    output wire [2:0]  tx_att2,
    output wire [2:0]  tx_att3,
    output wire [2:0]  tx_att4,
    output wire [3:0]  sw_tx_att
    );
    
    // Set TX_ATT = -130dB as a dummy value 
    assign tx_att2   = 3'b110;   // ATT = 30dB  
    assign tx_att3   = 3'b110;   // ATT = 30dB 
    assign tx_att4   = 3'b110;   // ATT = 30dB 
    assign sw_tx_att = 4'b0000;  // ATT = 40dB 
        
endmodule
