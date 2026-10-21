`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: sr_src_mux
// Description: Shift Register 資料來源選擇
//   bypass_agc = 0 : Reg1~4 = AGC 結果 (內容改變即自動送出), Reg5 = agc_mode_ctrl
//   bypass_agc = 1 : Reg1~4 = AGC 結果 (TX = AGC_BYPASS_TX_ATT_STATE, RX = dummy), 由 AGC_BYPASS_SR_UPDATE[0] 送出
//                    Reg5   = AGC_REG5,                           由 AGC_BYPASS_SR_UPDATE[1] 送出
//////////////////////////////////////////////////////////////////////////////////


module sr_src_mux (
    input  wire       bypass_agc,

    // --- AGC (agc_reg_pack / agc_mode_ctrl) ---
    input  wire [7:0] agc_reg1,
    input  wire [7:0] agc_reg2,
    input  wire [7:0] agc_reg3,
    input  wire [7:0] agc_reg4,
    input  wire [7:0] agc_reg5,
    input  wire       agc_reg5_update,

    // --- Bypass (PS) ---
    input  wire [7:0] bypass_reg5,          // AGC_REG5
    input  wire       bypass_update_reg1_to_4,
    input  wire       bypass_update_reg5,

    // --- 至 agc_shift_register ---
    output wire [7:0] sr_reg1,
    output wire [7:0] sr_reg2,
    output wire [7:0] sr_reg3,
    output wire [7:0] sr_reg4,
    output wire       sr_att_auto,          // 1: Reg1~4 內容改變即自動送出
    output wire       sr_att_update,        // Reg1~4 觸發 (bypass)
    output wire [7:0] sr_reg5,
    output wire       sr_reg5_update
);

    assign sr_reg1        = agc_reg1;
    assign sr_reg2        = agc_reg2;
    assign sr_reg3        = agc_reg3;
    assign sr_reg4        = agc_reg4;
    assign sr_att_auto    = ~bypass_agc;
    assign sr_att_update  = bypass_agc & bypass_update_reg1_to_4;

    assign sr_reg5        = bypass_agc ? bypass_reg5        : agc_reg5;
    assign sr_reg5_update = bypass_agc ? bypass_update_reg5 : agc_reg5_update;

endmodule
