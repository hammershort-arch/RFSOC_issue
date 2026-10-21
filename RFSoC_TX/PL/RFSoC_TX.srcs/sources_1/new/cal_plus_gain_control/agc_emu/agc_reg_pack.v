`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: agc_reg_pack
// Description: 衰減器欄位 -> Reg1~4 的 8-bit 內容 (TRM8_SDR 控制腳位定義表, bit7 = QA ... bit0 = QH)
//              Vc_Bar 與 Vc 給相同設定 (反向在元件內處理, 見 RFIC spec. 4/4)
//   Reg1 = {TX_ATT2_Vc[A0:A2], TX_ATT2_Vc_Bar[A0:A2], Rx_ATT2_Vc[A0:A1]}
//   Reg2 = {TX_ATT3_Vc,        TX_ATT3_Vc_Bar,        Rx_ATT2_Vc_Bar}
//   Reg3 = {TX_ATT4_Vc,        TX_ATT4_Vc_Bar,        N/C (00)}
//   Reg4 = {SW_TX_ATT[Vc1:Vc4], SW_RX_ATT[Vc1:Vc3], LNA_10dB_ATT_Vc}
//////////////////////////////////////////////////////////////////////////////////


module agc_reg_pack (
    input  wire [1:0] rx_att2,
    input  wire [2:0] sw_rx_att,
    input  wire [2:0] tx_att2,
    input  wire [2:0] tx_att3,
    input  wire [2:0] tx_att4,
    input  wire [3:0] sw_tx_att,
    input  wire       lna_10db_att_vc,   // 1: LNA 衰減 0dB, 0: LNA 衰減 10dB

    output wire [7:0] reg1,
    output wire [7:0] reg2,
    output wire [7:0] reg3,
    output wire [7:0] reg4
);

    assign reg1 = { tx_att2, tx_att2, rx_att2 };
    assign reg2 = { tx_att3, tx_att3, rx_att2 };
    assign reg3 = { tx_att4, tx_att4, 2'b00 };
    assign reg4 = { sw_tx_att, sw_rx_att, lna_10db_att_vc };

endmodule
