`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: agc_mode_ctrl
// Description: TXRX mode 切換控制 (Reg5)
//              reg5_cfg (AGC_REG5, PS 寫入的 Reg5 byte) 為 AGC mode 的唯一來源:
//                TXRX_SW = reg5_cfg[7] (TXRX_SW_TX_LEVEL: TX)
//              1. reg5_cfg 改變時, 先把 Reg5 寫到 Shift Register
//              2. 若 TXRX_SW 有改變: 等 Reg5 傳完 + mode_settle_cycle (AGC_MODE_SETTLE_CYCLE) 後,
//                 才切換 agc_mode; 切換期間 agc_mode_valid = 0 (RXAGC / TXAGC 皆暫停)
//              3. 上電 (reset 後, 等 cfg_valid) 一定先寫一次 Reg5, 完成後 agc_mode_valid 才拉高
//              4. hold = 1 (bypass_agc): 暫停, agc_mode_valid = 0, Reg5 由 bypass 路徑控制;
//                 hold 解除後同上電流程, 重新寫 Reg5 並切換 mode
//////////////////////////////////////////////////////////////////////////////////


module agc_mode_ctrl #(
    parameter TXRX_SW_TX_LEVEL  = 1'b0      // TXRX_SW = 0 : TX mode, 1 : RX mode (RFIC spec. 1/4)
)(
    input  wire        clk,
    input  wire        resetn,

    input  wire [7:0]  reg5_cfg,            // AGC_REG5 {TXRX_SW, Vc2,Vc1,Vc0,Vc3,Vc4, PA_VC_D, PA_VC_G}
    input  wire        cfg_valid,           // agc_cdc: reg map 設定已同步 (之前不寫 Reg5)
    input  wire        hold,                // bypass_agc
    input  wire [15:0] mode_settle_cycle,   // Reg5 寫入後, 等待 TXRX_SW 生效的時間 (agc_cdc 已處理下限 1)

    // --- Reg5 Shift Register 介面 ---
    output reg  [7:0]  reg5_data,
    output reg         reg5_update,
    input  wire        reg5_busy,

    // --- 生效中的 AGC mode ---
    output reg         agc_mode,            // 0: RX Mode, 1: TX Mode
    output reg         agc_mode_valid,      // 0: 上電初始化 / 切換中 / bypass
    output wire        rx_agc_enable,       // 至 rxagc.agc_enable
    output wire        tx_agc_enable        // TX mode 生效中 (status)
);

    assign rx_agc_enable = agc_mode_valid & ~agc_mode;
    assign tx_agc_enable = agc_mode_valid &  agc_mode;

    localparam S_INIT    = 2'd0;
    localparam S_IDLE    = 2'd1;
    localparam S_WAIT_SR = 2'd2;
    localparam S_SETTLE  = 2'd3;

    reg [1:0]  curr_state;
    reg [15:0] timer;
    reg        mode_target;
    reg        mode_change;

    wire txrx_mode_req = (reg5_cfg[7] == TXRX_SW_TX_LEVEL);   // 1: TX

    always @(posedge clk) begin
        if (!resetn || hold || !cfg_valid) begin
            curr_state     <= S_INIT;
            timer          <= 16'd0;
            reg5_update    <= 1'b0;
            mode_change    <= 1'b0;
            agc_mode_valid <= 1'b0;
            if (!resetn) begin
                reg5_data   <= 8'd0;
                mode_target <= 1'b0;
                agc_mode    <= 1'b0;
            end
        end else begin
            reg5_update <= 1'b0;

            case (curr_state)
                S_INIT, S_IDLE: begin
                    if ((curr_state == S_INIT) || (reg5_cfg != reg5_data)) begin
                        // 寫入 Reg5
                        reg5_data   <= reg5_cfg;
                        reg5_update <= 1'b1;
                        mode_target <= txrx_mode_req;
                        if ((curr_state == S_INIT) || (txrx_mode_req != agc_mode)) begin
                            // TXRX_SW 改變: 暫停 AGC, 等硬體生效後再切換
                            mode_change    <= 1'b1;
                            agc_mode_valid <= 1'b0;
                        end else begin
                            mode_change    <= 1'b0;
                        end
                        curr_state <= S_WAIT_SR;
                    end
                end

                S_WAIT_SR: begin
                    // reg5_busy 在 reg5_update 送出當拍即為 1, 傳完後降為 0
                    if (!reg5_busy && !reg5_update)
                        curr_state <= mode_change ? S_SETTLE : S_IDLE;
                end

                S_SETTLE: begin
                    if (timer >= mode_settle_cycle - 1'b1) begin
                        timer          <= 16'd0;
                        agc_mode       <= mode_target;
                        agc_mode_valid <= 1'b1;
                        mode_change    <= 1'b0;
                        curr_state     <= S_IDLE;
                    end else begin
                        timer <= timer + 1'b1;
                    end
                end

                default: curr_state <= S_INIT;
            endcase
        end
    end

endmodule
