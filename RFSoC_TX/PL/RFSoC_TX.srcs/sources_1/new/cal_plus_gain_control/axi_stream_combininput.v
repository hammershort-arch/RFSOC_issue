`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/08/27 19:14:12
// Design Name: 
// Module Name: axi_stream_combin
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


module axi_stream_combininput(
    input                          clk     ,
    // Input Stream 0
    input  wire [79:0]             s0_tdata,
    input  wire                    s0_tvalid,
    output wire                    s0_tready,

    // Input Stream 1
    input  wire [79:0]             s1_tdata,
    input  wire                    s1_tvalid,
    output wire                    s1_tready,

    // Output Stream
    output reg  [159:0]             m_tdata,
    output reg                     m_tvalid,
    input  wire                    m_tready

);

    assign s0_tready = m_tready;
    assign s1_tready = m_tready;
     
    always@(posedge clk )begin
        if(s0_tvalid&&s1_tvalid)begin
            m_tdata <= {s1_tdata[79:64],s0_tdata[79:64],s1_tdata[63:48],s0_tdata[63:48],s1_tdata[47:32],s0_tdata[47:32],s1_tdata[31:16],s0_tdata[31:16],s1_tdata[15:0],s0_tdata[15:0]};                     
            m_tvalid <= 1'b1;
        end
        else begin
            m_tdata <= 0;
            m_tvalid <= 0;
        end
    end

endmodule
