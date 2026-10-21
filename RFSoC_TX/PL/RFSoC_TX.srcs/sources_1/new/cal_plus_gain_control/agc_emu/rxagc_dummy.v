`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/09/03 19:14:08
// Design Name: 
// Module Name: rxagc_dummy
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


module rxagc_dummy(
    output wire [2:0] sw_rx_att,
    output wire [1:0] rx_att2,
    output wire [7:0] rx_att_db
    );
    // 預設靜態 Bypass/最小衰減狀態
    assign sw_rx_att     = 3'b111;
    assign rx_att2       = 2'b00;
    assign rx_att_db     = 8'd0;
endmodule
