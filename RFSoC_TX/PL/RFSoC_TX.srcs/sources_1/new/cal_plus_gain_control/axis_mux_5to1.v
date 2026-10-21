`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/22/2026 03:15:16 PM
// Design Name: 
// Module Name: axis_mux_5to1
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


module axis_mux_5to1(
    input  wire         clk,
    input  wire         rst_n,

    // Upstream AXI-Stream (5 x 32-bit from CORDICs)
    input  wire [31:0]  s0_axis_tdata, input wire s0_axis_tvalid, output wire s0_axis_tready,
    input  wire [31:0]  s1_axis_tdata, input wire s1_axis_tvalid, output wire s1_axis_tready,
    input  wire [31:0]  s2_axis_tdata, input wire s2_axis_tvalid, output wire s2_axis_tready,
    input  wire [31:0]  s3_axis_tdata, input wire s3_axis_tvalid, output wire s3_axis_tready,
    input  wire [31:0]  s4_axis_tdata, input wire s4_axis_tvalid, output wire s4_axis_tready,

    // Downstream AXI-Stream (160-bit)
    output reg  [159:0] m_axis_tdata,
    output reg          m_axis_tvalid,
    input  wire         m_axis_tready
    );
    
        // 1. 只有當 5 個 CORDIC 都輸出 Valid 時，才代表這一組 160-bit 資料有效
    wire all_s_valid = s0_axis_tvalid & s1_axis_tvalid & s2_axis_tvalid & s3_axis_tvalid & s4_axis_tvalid;

    // 2. 允許收下 CORDIC 資料的條件：
    //    下游 Master 準備好了 (m_axis_tready == 1)，或者目前輸出暫存器空著 (m_axis_tvalid == 0)
    //wire in_ready = m_axis_tready || !m_axis_tvalid;
    
    // 3. 將內部的 Ready 狀態同步廣播給 upstream 5 個 CORDIC
    //    當內部有空位可收資料時，通知 5 個 CORDIC 可以同時吐出運算結果
    assign s0_axis_tready = m_axis_tready;
    assign s1_axis_tready = m_axis_tready;
    assign s2_axis_tready = m_axis_tready;
    assign s3_axis_tready = m_axis_tready;
    assign s4_axis_tready = m_axis_tready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_axis_tvalid <= 1'b0;
            m_axis_tdata  <= 160'd0;
        end else if (m_axis_tready) begin
            m_axis_tvalid <= all_s_valid;
            if (all_s_valid) begin
                m_axis_tdata <= {s4_axis_tdata, s3_axis_tdata, s2_axis_tdata, s1_axis_tdata, s0_axis_tdata};
            end
        end
    end
    
endmodule
