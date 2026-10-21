`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/29/2026 06:46:13 PM
// Design Name: 
// Module Name: axis_spliter_iq
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


module axis_spliter_iq #(
    parameter DATA_WIDTH   = 16,  // 單一 sample 的 bit 數 (I 或 Q 各自)
    parameter NUM_PARALLEL = 5    // 每個 cycle 平行處理的 sample 數
)(
    //(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 aclk CLK" *)
    //(* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axis_i:s_axis_q:m0_axis_i:m0_axis_q:m1_axis_i:m1_axis_q" *)
    input wire aclk,
 
    // =========================================================================
    // 1. Slave Interface (接入 ADC 之後、進 Complex FIR 之前的 I bus / Q bus)
    // =========================================================================
    input  wire [DATA_WIDTH*NUM_PARALLEL-1:0] s_axis_i_tdata,
    input  wire                               s_axis_i_tvalid,
    output wire                               s_axis_i_tready,
 
    input  wire [DATA_WIDTH*NUM_PARALLEL-1:0] s_axis_q_tdata,
    input  wire                               s_axis_q_tvalid,
    output wire                               s_axis_q_tready,
 
    // =========================================================================
    // 2. Master 0 Interface (分流第 1 路: 給 Complex FIR 主資料路徑)
    // =========================================================================
    output wire [DATA_WIDTH*NUM_PARALLEL-1:0] m0_axis_i_tdata,
    output wire                               m0_axis_i_tvalid,
    input  wire                               m0_axis_i_tready,
 
    output wire [DATA_WIDTH*NUM_PARALLEL-1:0] m0_axis_q_tdata,
    output wire                               m0_axis_q_tvalid,
    input  wire                               m0_axis_q_tready,
 
    // =========================================================================
    // 3. Master 1 Interface (分流第 2 路: 給 cw_power_calc_IQ 旁路量測)
    // =========================================================================
    output wire [DATA_WIDTH*NUM_PARALLEL-1:0] m1_axis_i_tdata,
    output wire                               m1_axis_i_tvalid,
    input  wire                               m1_axis_i_tready,
 
    output wire [DATA_WIDTH*NUM_PARALLEL-1:0] m1_axis_q_tdata,
    output wire                               m1_axis_q_tvalid,
    input  wire                               m1_axis_q_tready
);
 
    // =========================================================================
    // Data (tdata) 廣播邏輯: 純組合邏輯直通 (Fan-out)，I / Q 各自獨立處理
    // =========================================================================
    assign m0_axis_i_tdata = s_axis_i_tdata;
    assign m1_axis_i_tdata = s_axis_i_tdata;
 
    assign m0_axis_q_tdata = s_axis_q_tdata;
    assign m1_axis_q_tdata = s_axis_q_tdata;
 
    // =========================================================================
    // Control (tvalid) 廣播邏輯: 同時發送給兩路 Slaves
    // =========================================================================
    assign m0_axis_i_tvalid = s_axis_i_tvalid;
    assign m1_axis_i_tvalid = s_axis_i_tvalid;
 
    assign m0_axis_q_tvalid = s_axis_q_tvalid;
    assign m1_axis_q_tvalid = s_axis_q_tvalid;
 
    // =========================================================================
    // Handshake (tready) 控制邏輯:
    // 上游 I bus / Q bus 的 Ready 分別由各自兩路 Slaves 的 Ready 共同決定 (AND Gate)
    // 只有當兩邊都 Ready 時，才允許上游 Handshake
    // (若 cw_power_calc_IQ 內部固定為 1，則主要跟隨 m0_axis_*_tready，
    //  也就是 Complex FIR 那一路的節奏)
    // =========================================================================
    assign s_axis_i_tready = m0_axis_i_tready && m1_axis_i_tready;
    assign s_axis_q_tready = m0_axis_q_tready && m1_axis_q_tready;
 
endmodule
