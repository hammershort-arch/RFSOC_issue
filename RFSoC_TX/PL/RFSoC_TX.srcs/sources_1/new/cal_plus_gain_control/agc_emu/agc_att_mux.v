`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: agc_att_mux
// Description: 依生效中的 agc_mode 選擇送往 Shift Register (Reg1~4) 的衰減欄位
//              agc_mode = 0 (RX) : RXAGC 結果 + TXAGC dummy (-130dB)
//              agc_mode = 1 (TX) : RXAGC dummy (0dB) + TXAGC 結果
//              bypass_agc = 1    : RXAGC dummy (0dB) + TXAGC 結果 (bypass_tx_att_state), 不看 agc_mode
//////////////////////////////////////////////////////////////////////////////////


module agc_att_mux (
    input  wire       agc_mode,             // 0: RX, 1: TX
    input  wire       bypass_agc,           // 1: 固定 TX 欄位 = txagc, RX 欄位 = dummy

    // RX mode 來源: rxagc + txagc_dummy
    input  wire [2:0] rx_sw_rx_att,
    input  wire [1:0] rx_rx_att2,
    input  wire [2:0] txd_tx_att2,
    input  wire [2:0] txd_tx_att3,
    input  wire [2:0] txd_tx_att4,
    input  wire [3:0] txd_sw_tx_att,

    // TX mode 來源: rxagc_dummy + txagc
    input  wire [2:0] rxd_sw_rx_att,
    input  wire [1:0] rxd_rx_att2,
    input  wire [2:0] tx_tx_att2,
    input  wire [2:0] tx_tx_att3,
    input  wire [2:0] tx_tx_att4,
    input  wire [3:0] tx_sw_tx_att,

    // 至 agc_reg_pack
    output wire [2:0] sw_rx_att,
    output wire [1:0] rx_att2,
    output wire [2:0] tx_att2,
    output wire [2:0] tx_att3,
    output wire [2:0] tx_att4,
    output wire [3:0] sw_tx_att
);

    wire   sel_tx     = agc_mode | bypass_agc;

    assign sw_rx_att  = sel_tx   ? rxd_sw_rx_att : rx_sw_rx_att;
    assign rx_att2    = sel_tx   ? rxd_rx_att2   : rx_rx_att2;
    assign tx_att2    = sel_tx   ? tx_tx_att2    : txd_tx_att2;
    assign tx_att3    = sel_tx   ? tx_tx_att3    : txd_tx_att3;
    assign tx_att4    = sel_tx   ? tx_tx_att4    : txd_tx_att4;
    assign sw_tx_att  = sel_tx   ? tx_sw_tx_att  : txd_sw_tx_att;

endmodule
