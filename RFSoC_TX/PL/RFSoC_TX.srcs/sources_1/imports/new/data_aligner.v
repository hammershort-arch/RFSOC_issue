`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/30/2026 01:34:22 PM
// Design Name: 
// Module Name: data_aligner
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


module data_aligner#(
    parameter DATA_WIDTH = 160,
    parameter USER_DATA_WIDTH = 64,
    parameter TIME_WIDTH = 40
)(
    input                           aclk,
    input                           aresetn,
    
    input   [TIME_WIDTH-1:0]        timestamp,                        
    
    input   [DATA_WIDTH-1:0]        s_axis_tdata,
    input                           s_axis_tvalid,
    output                          s_axis_tready,
    input   [USER_DATA_WIDTH-1:0]   s_axis_tuser,
    
    
    output  [DATA_WIDTH-1:0]        m_axis_tdata,
    output                          m_axis_tvalid, 
    input                           m_axis_tready,
    
    output reg    [TIME_WIDTH:0]       sys_time,
    output reg    [TIME_WIDTH:0]       data_time,
    output wire   [TIME_WIDTH-1:0]     end_time
);
    
    //(*mark_debug = "true"*)reg    [TIME_WIDTH:0]       sys_time;
    //(*mark_debug = "true"*)reg    [TIME_WIDTH:0]       data_time;    
    reg    [DATA_WIDTH-1:0]     data_temp;
    
    //(*mark_debug = "true"*)wire   [TIME_WIDTH-1:0]     end_time; 
    //(*mark_debug = "true"*)wire    out_valid;
    
    assign  out_valid = (sys_time == data_time) |  (sys_time[TIME_WIDTH-1:0] < data_time[TIME_WIDTH-1:0] && sys_time[TIME_WIDTH] != data_time[TIME_WIDTH]) |
                        (sys_time[TIME_WIDTH-1:0] > data_time[TIME_WIDTH-1:0] && sys_time[TIME_WIDTH] == data_time[TIME_WIDTH]);
                        
    assign  s_axis_tready   =   out_valid;
        
    assign  m_axis_tdata    =   out_valid ? data_temp : 'd0;
    assign  m_axis_tvalid   =   out_valid && s_axis_tvalid;
    
    assign  end_time = timestamp + 2; // 2 cycle compensation    
    
    always@(posedge aclk) begin
        if(!aresetn)
            sys_time <= 'd0;
        else begin
            if(end_time < sys_time[TIME_WIDTH-1:0])
                sys_time <= {~sys_time[TIME_WIDTH], end_time};
            else
                sys_time <= {sys_time[TIME_WIDTH], end_time};
        end
    end
    
    always@(posedge aclk) begin
        if(!aresetn)
            data_time <= 'd0;
        else begin
            if(s_axis_tuser[TIME_WIDTH-1:0] < data_time[TIME_WIDTH-1:0])
                data_time <= {~data_time[TIME_WIDTH], s_axis_tuser[TIME_WIDTH-1:0]};
            else
                data_time <= {data_time[TIME_WIDTH], s_axis_tuser[TIME_WIDTH-1:0]};
        end
    end
            
    always@(posedge aclk) begin
        if(!aresetn)
            data_temp <= 'd0;
        else begin
            if(s_axis_tvalid & s_axis_tready)
                data_temp <= s_axis_tdata;
            else
                data_temp <= data_temp;
        end
    end
            
endmodule
