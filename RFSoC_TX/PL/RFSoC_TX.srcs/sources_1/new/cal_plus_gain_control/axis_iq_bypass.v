`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: axis_iq_bypass
// Description: 通道輸入 / 輸出的 bypass 選擇 (除錯用, 2026-10-12)
//   s_axis_iq  (Signal Source Mux 輸出, 2026-10-14 起; 原為 container 輸入) -> m_axis_cal (直通給 axis_iq_split, 正常處理路徑)
//   s_axis_cal (calibration 輸出) -+
//   s_axis_iq                      +-> m_axis_iq (container 輸出 -> DAC)
//   bypass = 0: m_axis_iq = s_axis_cal (FIR + calibration + gain control)
//   bypass = 1: m_axis_iq = s_axis_iq  (輸入直接輸出, 不經 FIR / calibration / gain control)
//   純組合 mux (正常路徑 latency 不變); bypass 由 reg map mem38 經 cal_cdc_0 同步到 clk
//   bypass 時正常路徑照常運作 (AGC / power fit 繼續計算), 只是不送到輸出
//   資料格式不變: 每拍 5 sample x {Q[15:0], I[15:0]}
//////////////////////////////////////////////////////////////////////////////////
module axis_iq_bypass #(
    parameter WIDTH = 160
)(
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 aclk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axis_iq:m_axis_cal:s_axis_cal:m_axis_iq" *)
    input  wire             aclk,
    input  wire             bypass,

    // container 輸入
    input  wire [WIDTH-1:0] s_axis_iq_tdata,
    input  wire             s_axis_iq_tvalid,
    output wire             s_axis_iq_tready,
    // 直通到正常處理路徑 (axis_iq_split)
    output wire [WIDTH-1:0] m_axis_cal_tdata,
    output wire             m_axis_cal_tvalid,
    input  wire             m_axis_cal_tready,
    // calibration 輸出
    input  wire [WIDTH-1:0] s_axis_cal_tdata,
    input  wire             s_axis_cal_tvalid,
    output wire             s_axis_cal_tready,
    // container 輸出
    output wire [WIDTH-1:0] m_axis_iq_tdata,
    output wire             m_axis_iq_tvalid,
    input  wire             m_axis_iq_tready
);

    assign m_axis_cal_tdata  = s_axis_iq_tdata;
    assign m_axis_cal_tvalid = s_axis_iq_tvalid;
    // bypass 時輸入也要等輸出端 ready (DAC 端恆為 1, 實際上不會停)
    assign s_axis_iq_tready  = bypass ? (m_axis_cal_tready & m_axis_iq_tready) : m_axis_cal_tready;

    assign m_axis_iq_tdata   = bypass ? s_axis_iq_tdata  : s_axis_cal_tdata;
    assign m_axis_iq_tvalid  = bypass ? s_axis_iq_tvalid : s_axis_cal_tvalid;
    assign s_axis_cal_tready = m_axis_iq_tready;

endmodule
