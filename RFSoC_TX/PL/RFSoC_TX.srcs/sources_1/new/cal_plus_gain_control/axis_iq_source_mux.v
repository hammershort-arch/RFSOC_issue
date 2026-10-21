`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: axis_iq_source_mux
// Description: Signal Source Mux (2026-10-14)
//   s_axis_iq0 (container s_axis_iq_in_0) -+
//   s_axis_iq1 (container s_axis_iq_in_1) -+-> m_axis_iq -> axis_iq_bypass_0 (-> Power Fit / Calibration)
//   all_zero (內部常數 0)                 -+
//   sel = 0: m_axis_iq = s_axis_iq0
//   sel = 1: m_axis_iq = s_axis_iq1
//   sel = 2: m_axis_iq = all_zero (tdata = 0, tvalid = 1; Debug_008, 2026-10-19; sel 原為 1 bit)
//   sel = 3: 同 sel = 2 (保留, 輸出全 0)
//   純組合 mux (latency 0); sel 由 reg map mem39 signal_source_select[1:0] 經 cal_cdc_0 同步到 aclk
//   沒被選到的那一路 tready 恆為 1 (資料直接丟掉, 不對上游 back-pressure)
//   兩路輸入須在同一個 aclk (256 MHz); 資料格式不變: 每拍 5 sample x {Q[15:0], I[15:0]}
//////////////////////////////////////////////////////////////////////////////////
module axis_iq_source_mux #(
    parameter WIDTH = 160
)(
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 aclk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axis_iq0:s_axis_iq1:m_axis_iq" *)
    input  wire             aclk,
    input  wire [1:0]       sel,

    // source 0
    input  wire [WIDTH-1:0] s_axis_iq0_tdata,
    input  wire             s_axis_iq0_tvalid,
    output wire             s_axis_iq0_tready,
    // source 1
    input  wire [WIDTH-1:0] s_axis_iq1_tdata,
    input  wire             s_axis_iq1_tvalid,
    output wire             s_axis_iq1_tready,
    // 輸出
    output wire [WIDTH-1:0] m_axis_iq_tdata,
    output wire             m_axis_iq_tvalid,
    input  wire             m_axis_iq_tready
);

    wire sel_zero = sel[1];   // 2 / 3 = all_zero

    assign m_axis_iq_tdata   = sel_zero ? {WIDTH{1'b0}} : (sel[0] ? s_axis_iq1_tdata  : s_axis_iq0_tdata);
    assign m_axis_iq_tvalid  = sel_zero ? 1'b1          : (sel[0] ? s_axis_iq1_tvalid : s_axis_iq0_tvalid);
    assign s_axis_iq0_tready = (sel == 2'd0) ? m_axis_iq_tready : 1'b1;
    assign s_axis_iq1_tready = (sel == 2'd1) ? m_axis_iq_tready : 1'b1;

endmodule
