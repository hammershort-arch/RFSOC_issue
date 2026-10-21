`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: axis_iq_split
// Description: IQ 合併格式 (axi_stream_combininput 輸出格式) 拆成 I / Q 兩路
//              每個 sample 32-bit = {Q[15:0], I[15:0]}, 共 NUM_PARALLEL 個 sample
//                s_axis_iq_tdata[32k+15 : 32k]    = I_k  -> m_axis_i_tdata[16k+15 : 16k]
//                s_axis_iq_tdata[32k+31 : 32k+16] = Q_k  -> m_axis_q_tdata[16k+15 : 16k]
//              純組合邏輯 (無 latency)
//////////////////////////////////////////////////////////////////////////////////


module axis_iq_split #(
    parameter DATA_WIDTH   = 16,
    parameter NUM_PARALLEL = 5
)(
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 aclk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axis_iq:m_axis_i:m_axis_q" *)
    input  wire                                 aclk,

    input  wire [2*DATA_WIDTH*NUM_PARALLEL-1:0] s_axis_iq_tdata,
    input  wire                                 s_axis_iq_tvalid,
    output wire                                 s_axis_iq_tready,

    output wire [DATA_WIDTH*NUM_PARALLEL-1:0]   m_axis_i_tdata,
    output wire                                 m_axis_i_tvalid,
    input  wire                                 m_axis_i_tready,

    output wire [DATA_WIDTH*NUM_PARALLEL-1:0]   m_axis_q_tdata,
    output wire                                 m_axis_q_tvalid,
    input  wire                                 m_axis_q_tready
);

    genvar k;
    generate
        for (k = 0; k < NUM_PARALLEL; k = k + 1) begin : g_split
            assign m_axis_i_tdata[DATA_WIDTH*k +: DATA_WIDTH] = s_axis_iq_tdata[2*DATA_WIDTH*k              +: DATA_WIDTH];
            assign m_axis_q_tdata[DATA_WIDTH*k +: DATA_WIDTH] = s_axis_iq_tdata[2*DATA_WIDTH*k + DATA_WIDTH +: DATA_WIDTH];
        end
    endgenerate

    assign m_axis_i_tvalid  = s_axis_iq_tvalid;
    assign m_axis_q_tvalid  = s_axis_iq_tvalid;
    assign s_axis_iq_tready = m_axis_i_tready & m_axis_q_tready;

endmodule
