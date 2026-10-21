`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/23/2026 12:10:56 PM
// Design Name: 
// Module Name: axis_packetizer
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


module axis_packetizer #(
    parameter DATA_WIDTH = 160,
    parameter USER_WIDTH = 64,
    parameter PACKET_LENGTH = 1024
)(
    input                       aclk,
    input                       aresetn,
    input                       start,

    // Slave AXIS
    input  [DATA_WIDTH-1:0]     s_axis_tdata,
    input                       s_axis_tvalid,
    input  [USER_WIDTH-1:0]     s_axis_tuser,
    output                      s_axis_tready,

    // Master AXIS
    output [DATA_WIDTH-1:0]     m_axis_tdata,
    output                      m_axis_tvalid,
    input                       m_axis_tready,
    output                      m_axis_tlast,
    output [USER_WIDTH-1:0]     m_axis_tuser
);

assign m_axis_tdata  = s_axis_tdata;
assign m_axis_tvalid = s_axis_tvalid && start;
assign s_axis_tready = m_axis_tready;

reg [$clog2(PACKET_LENGTH)-1:0] cnt;

always @(posedge aclk) begin
    if (!aresetn)
        cnt <= 0;
    else if (s_axis_tvalid && m_axis_tready && start) begin
        if (cnt == PACKET_LENGTH-1)
            cnt <= 0;
        else
            cnt <= cnt + 1;
    end
end

assign m_axis_tlast = (cnt == PACKET_LENGTH-1);

assign m_axis_tuser = s_axis_tuser;   // Start of packet

endmodule