`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/30/2026 03:52:10 PM
// Design Name: 
// Module Name: data_delay
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


module data_delay #(
    parameter   DATA_WIDTH = 160,
    parameter   USER_DATA_WIDTH = 64,
    parameter   TIME_WIDTH = 40
)(
    input                               aclk,
    input                               aresetn,
    input   [32-1:0]                    delay,
    
    input   [DATA_WIDTH-1:0]            s_axis_tdata,
    input                               s_axis_tvalid,
    output                              s_axis_tready,
    input   [USER_DATA_WIDTH-1:0]       s_axis_tuser,
    
    output  reg [DATA_WIDTH-1:0]        m_axis_tdata,
    output  reg                         m_axis_tvalid,
    input                               m_axis_tready,
    output  reg [USER_DATA_WIDTH-1:0]   m_axis_tuser
    
    );
    
    wire    [TIME_WIDTH-1:0] delayed_time;
    
    assign  delayed_time = (s_axis_tuser[TIME_WIDTH-1:0] > m_axis_tuser[TIME_WIDTH-1:0] + 1024) ? m_axis_tuser[TIME_WIDTH-1:0] : s_axis_tuser[TIME_WIDTH-1:0]  + delay;
    
    assign  s_axis_tready = 1;
    
    always@(posedge aclk) begin
        if(!aresetn)
            m_axis_tdata <= 0;
        else begin
            if(s_axis_tvalid & s_axis_tready)
                m_axis_tdata <= s_axis_tdata;
            else
                m_axis_tdata <= m_axis_tdata;
        end
    end
    
    always@(posedge aclk) begin
        if(!aresetn)
            m_axis_tuser <= 0;
        else begin
            if(s_axis_tvalid & s_axis_tready)
                m_axis_tuser <= {s_axis_tuser[USER_DATA_WIDTH-TIME_WIDTH], delayed_time};
            else
                m_axis_tuser <= m_axis_tuser;
        end
    end
    
    always@(posedge aclk) begin
        if(!aresetn)
            m_axis_tvalid <= 0;
        else 
            m_axis_tvalid <= s_axis_tvalid;
    end
            
endmodule
