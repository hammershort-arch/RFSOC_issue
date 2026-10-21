`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/22/2026 03:14:17 PM
// Design Name: 
// Module Name: axis_demux_1to5
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


module axis_demux_1to5(
    input  wire         clk,
    input  wire         rst_n,

    // Input AXI-Stream (160-bit)
    input  wire [159:0] s_axis_tdata,
    input  wire         s_axis_tvalid,
    output wire         s_axis_tready,

    // Output AXI-Stream (5 x 32-bit to CORDICs)
    output reg  [31:0]  m0_axis_tdata, output reg  m0_axis_tvalid, input wire m0_axis_tready,
    output reg  [31:0]  m1_axis_tdata, output reg  m1_axis_tvalid, input wire m1_axis_tready,
    output reg  [31:0]  m2_axis_tdata, output reg  m2_axis_tvalid, input wire m2_axis_tready,
    output reg  [31:0]  m3_axis_tdata, output reg  m3_axis_tvalid, input wire m3_axis_tready,
    output reg  [31:0]  m4_axis_tdata, output reg  m4_axis_tvalid, input wire m4_axis_tready
    );
    
        // 允許接收上游資料的條件
    assign s_axis_tready = m0_axis_tready & m1_axis_tready & m2_axis_tready & m3_axis_tready & m4_axis_tready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m0_axis_tvalid <= 1'b0;
            m1_axis_tvalid <= 1'b0;
            m2_axis_tvalid <= 1'b0;
            m3_axis_tvalid <= 1'b0;
            m4_axis_tvalid <= 1'b0;  // reset
            m0_axis_tdata  <= 32'd0;
            m1_axis_tdata  <= 32'd0;
            m2_axis_tdata  <= 32'd0;
            m3_axis_tdata  <= 32'd0;
            m4_axis_tdata  <= 32'd0;
        end else if (s_axis_tready) begin
            m0_axis_tvalid <= s_axis_tvalid;
            m1_axis_tvalid <= s_axis_tvalid;
            m2_axis_tvalid <= s_axis_tvalid;
            m3_axis_tvalid <= s_axis_tvalid;
            m4_axis_tvalid <= s_axis_tvalid;

            if (s_axis_tvalid) begin
                m0_axis_tdata <= s_axis_tdata[31:0];
                m1_axis_tdata <= s_axis_tdata[63:32];
                m2_axis_tdata <= s_axis_tdata[95:64];
                m3_axis_tdata <= s_axis_tdata[127:96];
                m4_axis_tdata <= s_axis_tdata[159:128];
            end
        end
    end
    
endmodule
