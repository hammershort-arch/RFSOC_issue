`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: agc_cdc
// Description: AGC_EMU 的所有跨時脈處理 (agc_emu hierarchy 內)
//   reg_clk (100MHz) -> adc_clk : channel reg map (mem22~37) + system_reg_map (sys4~13)   (RegMap v8, 2026-10-10)
//                                  xpm_cdc_array_single + 穩定濾波 (值連續 STABLE_CYCLES 拍不變才採用,
//                                  避免多 bit 欄位跨時脈時出現一拍新舊混合值被即時送進衰減器)
//   clk (256MHz)     -> adc_clk : rst_n (xpm_cdc_async_rst)
//                                  rx_att_index / algo_analog_att_db (xpm_cdc_array_single + 穩定濾波; 持續使用最新值)
//                                  gain_index_power_fit / goal_rel_db (xpm_cdc_handshake, 每次改變都送到, 2026-10-10)
//   adc_clk          -> clk     : gain_index_tx (與類比同步後的數位 gain index) / tx_att_clamp
//   adc_clk          -> reg_clk : clear_or / clear_ov (RFDC 以 s_axi_aclk 取樣, xpm_cdc_single)
//
// Gain index / TXAGC (channel): mem22 gain_index_ch_offset [8:0] S4.4, mem23 gain_index_rf_freq_offset [7:0] S3.4,
//   mem24 gain_index_temperature_offset [7:0] S3.4, mem25 dac_output_ref_dbm [10:0] S6.4 (+10 ~ -40 dBm)
// system_reg_map: sys5 digital_apply_delay [7:0] (adc_clk, sr start 後第 N 拍套用數位 gain, reset 35 = RCLK)
// 設定暫存器位置 (channel = addressable_reg_map, system = system_reg_map), 欄位定義見 doc/tools/regmap_def.py
//   控制  ch  mem27 0x6C agc_reg5                  [7:0]   Reg5 byte {TXRX_SW, Vc2,Vc1,Vc0,Vc3,Vc4, PA_VC_D, PA_VC_G}
//                                                         TXRX_SW = mode 來源 (0 TX / 1 RX), reset 0x80
//         ch  mem28 0x70 agc_bypass_agc            [0]     1: AGC 暫停, TX 衰減改用 agc_bypass_tx_att_state, RX 給 dummy
//         ch  mem29 0x74 agc_bypass_tx_att_state   [4:0]   0~27
//         ch  mem30 0x78 agc_bypass_sr_update      [0] 送 Reg1~4, [1] 送 Reg5 (正緣, bypass 時有效)
//   TX    sys sys4  0x10 agc_tx_power_mode         [0]     0: Linear, 1: Manual
//         ch  mem31 0x7C agc_manual_tx_att_en      [0]
//         ch  mem32 0x80 agc_manual_tx_att_db      [7:0]   unsigned, 1dB
//         ch  mem33 0x84 agc_target_power          [7:0]   signed, 1dBm
//         ch  mem34 0x88 agc_linear_mode_offset    [11:0]  signed, 1/16dB
//         ch  mem35 0x8C agc_manual_mode_offset    [11:0]  signed, 1/16dB
//   RX    ch  mem36 0x90 agc_manual_rx_att_en      [0]
//         ch  mem37 0x94 agc_manual_rx_att_state   [2:0]   0~6 (0~60dB)
//         sys sys8  0x20 agc_rx_watch_cycle        [31:0]  reset 1000, 下限 1
//         sys sys9  0x24 agc_rx_wait_dsa_cycle     [7:0]   reset 6,    下限 1
//         sys sys10 0x28 agc_rx_set_dsa_cycle      [7:0]   reset 6,    下限 1
//         sys sys11 0x2C agc_rx_wait_cycle         [7:0]   reset 50,   下限 1
//         sys sys12 0x30 agc_rx_set_clear_cycle    [7:0]   reset 6,    下限 6 (clear 脈衝 > 2 個 s_axi_aclk)
//         sys sys13 0x34 agc_rx_wait_clear_cycle   [7:0]   reset 16,   下限 1
//   時序  sys sys6  0x18 agc_sr_update_period      [7:0]   SR 一輪更新時間 (adc_clk), reset 50, 下限 50
//         sys sys7  0x1C agc_mode_settle_cycle     [15:0]  reset 64,   下限 1
//   寫入值低於下限時, 硬體以下限值使用 (讀回仍為寫入值)
//////////////////////////////////////////////////////////////////////////////////


module agc_cdc #(
    parameter STABLE_CYCLES = 4         // 設定值需連續穩定的 adc_clk 拍數
)(
    // --- addressable_reg_map domain (S_AXI_ACLK, 100MHz) ---
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 reg_clk CLK" *)
    input  wire        reg_clk,
    input  wire [31:0] reg_tx_power_mode,          // sys4
    input  wire [31:0] reg_manual_rx_att_en,       // mem36
    input  wire [31:0] reg_manual_rx_att_state,    // mem37
    input  wire [31:0] reg_manual_tx_att_en,       // mem31
    input  wire [31:0] reg_manual_tx_att_db,       // mem32
    input  wire [31:0] reg_target_power,           // mem33
    input  wire [31:0] reg_linear_mode_offset,     // mem34
    input  wire [31:0] reg_manual_mode_offset,     // mem35
    input  wire [31:0] reg_reg5,                   // mem27
    input  wire [31:0] reg_bypass_agc,             // mem28
    input  wire [31:0] reg_bypass_tx_att_state,    // mem29
    input  wire [31:0] reg_bypass_sr_update,       // mem30
    input  wire [31:0] reg_sr_update_period,       // sys6
    input  wire [31:0] reg_mode_settle_cycle,      // sys7
    input  wire [31:0] reg_rx_watch_cycle,         // sys8
    input  wire [31:0] reg_rx_wait_dsa_cycle,      // sys9
    input  wire [31:0] reg_rx_set_dsa_cycle,       // sys10
    input  wire [31:0] reg_rx_wait_cycle,          // sys11
    input  wire [31:0] reg_rx_set_clear_cycle,     // sys12
    input  wire [31:0] reg_rx_wait_clear_cycle,    // sys13
    input  wire [31:0] reg_gain_index_ch_offset,           // mem22
    input  wire [31:0] reg_gain_index_rf_freq_offset,      // mem23
    input  wire [31:0] reg_gain_index_temperature_offset,  // mem24
    input  wire [31:0] reg_dac_output_ref_dbm,             // mem25
    input  wire [31:0] reg_digital_apply_delay,            // sys5
    input  wire [31:0] reg_tx_att_hysteresis,              // sys16 (U4.4 dB)

    // --- BD clk domain (256MHz): reset, 外部輸入 (rx_att_index / algo_analog_att_db), power_fit_top 輸出 ---
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_RESET rst_n" *)
    input  wire        clk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rst_n RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input  wire        rst_n,
    input  wire [2:0]  rx_att_index,               // RSP RX 衰減 index (x10 dB), 持續輸入
    input  wire [8:0]  algo_analog_att_db,         // S8.0, 算法要求的額外類比衰減
    input  wire [9:0]  gain_index_power_fit,       // S5.4, power_fit_top
    input  wire [9:0]  goal_rel_db,                // S5.4, power_fit_top (20log10(goal / goal_ref))
    output reg  [11:0] gain_index_tx,              // clk domain: 與類比同步後的數位 gain index -> gain_index_mux
    output reg  [1:0]  tx_att_clamp,               // clk domain: {clamp_hi, clamp_lo} -> ILA

    // --- AGC clock domain (RFDC clk_adc0, 240MHz) ---
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 adc_clk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_RESET rst_n_adc" *)
    input  wire        adc_clk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rst_n_adc RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    output wire        rst_n_adc,
    output reg         cfg_valid,                  // 1: reg map 設定已同步 (reset 後第一次穩定)

    output reg         tx_power_mode,
    output reg         manual_rx_att_enable,
    output reg  [2:0]  manual_rx_att_state,
    output reg         manual_tx_att_enable,
    output reg  [7:0]  manual_tx_att_db,
    output reg  [7:0]  target_power,
    output reg  [11:0] linear_mode_offset,
    output reg  [11:0] manual_mode_offset,
    output reg  [7:0]  reg5_cfg,
    output reg         bypass_agc,
    output reg  [4:0]  bypass_tx_att_state,
    output wire        bypass_update_reg1_to_4,    // 單拍
    output wire        bypass_update_reg5,         // 單拍
    output reg  [2:0]  rx_att_index_adc,           // 以下為 adc_clk domain
    output reg  [8:0]  algo_analog_att_db_adc,
    output reg  [9:0]  gain_index_power_fit_adc,
    output reg  [9:0]  goal_rel_db_adc,
    output wire [8:0]  gain_index_ch_offset,
    output wire [7:0]  gain_index_rf_freq_offset,
    output wire [7:0]  gain_index_temperature_offset,
    output wire [10:0] dac_output_ref_dbm,         // S6.4, 限制在 +10 ~ -40 dBm
    output wire [7:0]  digital_apply_delay,
    output wire [7:0]  tx_att_hysteresis,          // U4.4 dB -> txagc
    input  wire [11:0] gain_index_applied,         // adc_clk: gain_apply_sync 輸出
    input  wire        analog_clamp_hi,            // adc_clk: txagc
    input  wire        analog_clamp_lo,

    // --- Cycle settings (已處理下限) ---
    output wire [7:0]  sr_update_period,
    output wire [15:0] mode_settle_cycle,
    output wire [31:0] rx_watch_cycle,
    output wire [7:0]  rx_wait_dsa_cycle,
    output wire [7:0]  rx_set_dsa_cycle,
    output wire [7:0]  rx_wait_cycle,
    output wire [7:0]  rx_set_clear_cycle,
    output wire [7:0]  rx_wait_clear_cycle,

    // --- RFDC clear: adc_clk -> reg_clk ---
    input  wire        clear_or_adc,
    input  wire        clear_ov_adc,
    output wire        clear_or,
    output wire        clear_ov
);

    // =========================================================================
    // 1. Reset -> adc_clk
    // =========================================================================
    xpm_cdc_async_rst #(
        .DEST_SYNC_FF    (4),
        .INIT_SYNC_FF    (1),
        .RST_ACTIVE_HIGH (0)
    ) u_cdc_rst (
        .src_arst  (rst_n),
        .dest_clk  (adc_clk),
        .dest_arst (rst_n_adc)
    );

    // =========================================================================
    // 2. Reg map -> adc_clk (xpm_cdc_array_single + 穩定濾波)
    // =========================================================================
    localparam EXT_W = 9 + 8 + 8 + 11 + 8 + 8;                                   // 52 (+ tx_att_hysteresis)
    localparam CYC_W = 8 + 16 + 32 + 8*5;                                        // 96
    localparam CFG_W = EXT_W + CYC_W + 1 + 1 + 3 + 1 + 8 + 8 + 12 + 12 + 8 + 1 + 5 + 2;   // 210

    wire [CFG_W-1:0] cfg_reg = {
        reg_gain_index_ch_offset[8:0], reg_gain_index_rf_freq_offset[7:0], reg_gain_index_temperature_offset[7:0],
        reg_dac_output_ref_dbm[10:0],  reg_digital_apply_delay[7:0], reg_tx_att_hysteresis[7:0],
        reg_sr_update_period[7:0],   reg_mode_settle_cycle[15:0],  reg_rx_watch_cycle[31:0],
        reg_rx_wait_dsa_cycle[7:0],  reg_rx_set_dsa_cycle[7:0],    reg_rx_wait_cycle[7:0],
        reg_rx_set_clear_cycle[7:0], reg_rx_wait_clear_cycle[7:0],
        reg_tx_power_mode[0],        reg_manual_rx_att_en[0],      reg_manual_rx_att_state[2:0],
        reg_manual_tx_att_en[0],     reg_manual_tx_att_db[7:0],
        reg_target_power[7:0],       reg_linear_mode_offset[11:0], reg_manual_mode_offset[11:0],
        reg_reg5[7:0],               reg_bypass_agc[0],
        reg_bypass_tx_att_state[4:0], reg_bypass_sr_update[1:0] };
    wire [CFG_W-1:0] cfg_sync;

    xpm_cdc_array_single #(
        .DEST_SYNC_FF   (3),
        .INIT_SYNC_FF   (1),
        .SIM_ASSERT_CHK (0),
        .SRC_INPUT_REG  (1),
        .WIDTH          (CFG_W)
    ) u_cdc_cfg (
        .src_clk  (reg_clk),
        .src_in   (cfg_reg),
        .dest_clk (adc_clk),
        .dest_out (cfg_sync)
    );

    // 穩定濾波: cfg_sync 連續 STABLE_CYCLES 拍相同才更新 cfg_q
    reg [CFG_W-1:0] cfg_sync_d, cfg_q;
    reg [3:0]       stable_cnt;
    always @(posedge adc_clk) begin
        if (!rst_n_adc) begin
            cfg_sync_d <= {CFG_W{1'b0}};
            cfg_q      <= {CFG_W{1'b0}};
            stable_cnt <= 4'd0;
            cfg_valid  <= 1'b0;
        end else begin
            cfg_sync_d <= cfg_sync;
            if (cfg_sync != cfg_sync_d)
                stable_cnt <= 4'd0;
            else if (stable_cnt < STABLE_CYCLES - 1)
                stable_cnt <= stable_cnt + 1'b1;
            else begin
                cfg_q     <= cfg_sync_d;
                cfg_valid <= 1'b1;
            end
        end
    end

    wire [7:0]  sr_update_period_r, rx_wait_dsa_cycle_r, rx_set_dsa_cycle_r, rx_wait_cycle_r,
                rx_set_clear_cycle_r, rx_wait_clear_cycle_r;
    wire [15:0] mode_settle_cycle_r;
    wire [31:0] rx_watch_cycle_r;
    assign {sr_update_period_r, mode_settle_cycle_r, rx_watch_cycle_r,
            rx_wait_dsa_cycle_r, rx_set_dsa_cycle_r, rx_wait_cycle_r,
            rx_set_clear_cycle_r, rx_wait_clear_cycle_r} = cfg_q[CFG_W-EXT_W-1 -: CYC_W];

    wire signed [10:0] dac_ref_r;
    assign {gain_index_ch_offset, gain_index_rf_freq_offset, gain_index_temperature_offset,
            dac_ref_r, digital_apply_delay, tx_att_hysteresis} = cfg_q[CFG_W-1 -: EXT_W];
    // dac_output_ref_dbm 限制 +10 ~ -40 dBm (S6.4: +160 ~ -640)
    assign dac_output_ref_dbm = (dac_ref_r > 11'sd160)  ? 11'sd160 :
                                (dac_ref_r < -11'sd640) ? -11'sd640 : dac_ref_r;

    // 下限
    assign sr_update_period    = (sr_update_period_r    < 8'd50) ? 8'd50  : sr_update_period_r;
    assign mode_settle_cycle   = (mode_settle_cycle_r   == 16'd0) ? 16'd1 : mode_settle_cycle_r;
    assign rx_watch_cycle      = (rx_watch_cycle_r      == 32'd0) ? 32'd1 : rx_watch_cycle_r;
    assign rx_wait_dsa_cycle   = (rx_wait_dsa_cycle_r   == 8'd0)  ? 8'd1  : rx_wait_dsa_cycle_r;
    assign rx_set_dsa_cycle    = (rx_set_dsa_cycle_r    == 8'd0)  ? 8'd1  : rx_set_dsa_cycle_r;
    assign rx_wait_cycle       = (rx_wait_cycle_r       == 8'd0)  ? 8'd1  : rx_wait_cycle_r;
    assign rx_set_clear_cycle  = (rx_set_clear_cycle_r  < 8'd6)   ? 8'd6  : rx_set_clear_cycle_r;
    assign rx_wait_clear_cycle = (rx_wait_clear_cycle_r == 8'd0)  ? 8'd1  : rx_wait_clear_cycle_r;

    always @(*) begin
        {tx_power_mode, manual_rx_att_enable, manual_rx_att_state,
         manual_tx_att_enable, manual_tx_att_db,
         target_power, linear_mode_offset, manual_mode_offset,
         reg5_cfg, bypass_agc,
         bypass_tx_att_state} = cfg_q[CFG_W-EXT_W-CYC_W-1:2];
    end

    // AGC_BYPASS_SR_UPDATE: 正緣 -> 單拍
    reg [1:0] bypass_upd_d;
    always @(posedge adc_clk) begin
        if (!rst_n_adc) bypass_upd_d <= 2'b00;
        else            bypass_upd_d <= cfg_q[1:0];
    end
    assign bypass_update_reg1_to_4 = cfg_q[0] & ~bypass_upd_d[0];
    assign bypass_update_reg5  = cfg_q[1] & ~bypass_upd_d[1];

    // =========================================================================
    // 3. clk -> adc_clk: rx_att_index / algo_analog_att_db (xpm_cdc_array_single + 穩定濾波; 持續使用最新值)
    // =========================================================================
    localparam IN_W = 3 + 9;                                                    // 12
    wire [IN_W-1:0] in_sync;
    reg  [IN_W-1:0] in_sync_d;
    reg  [3:0]      in_stable_cnt;

    xpm_cdc_array_single #(
        .DEST_SYNC_FF   (3),
        .INIT_SYNC_FF   (1),
        .SIM_ASSERT_CHK (0),
        .SRC_INPUT_REG  (1),
        .WIDTH          (IN_W)
    ) u_cdc_in (
        .src_clk  (clk),
        .src_in   ({rx_att_index, algo_analog_att_db}),
        .dest_clk (adc_clk),
        .dest_out (in_sync)
    );

    always @(posedge adc_clk) begin
        if (!rst_n_adc) begin
            in_sync_d     <= {IN_W{1'b0}};
            in_stable_cnt <= 4'd0;
            {rx_att_index_adc, algo_analog_att_db_adc} <= {IN_W{1'b0}};
        end else begin
            in_sync_d <= in_sync;
            if (in_sync != in_sync_d)
                in_stable_cnt <= 4'd0;
            else if (in_stable_cnt < STABLE_CYCLES - 1)
                in_stable_cnt <= in_stable_cnt + 1'b1;
            else
                {rx_att_index_adc, algo_analog_att_db_adc} <= in_sync_d;
        end
    end

    // =========================================================================
    // 3a. clk -> adc_clk: gain_index_power_fit / goal_rel_db (xpm_cdc_handshake, 2026-10-10)
    //     power_fit 的結果一改變就送一次 (傳送中又改變: 傳完再送最新值), 兩個欄位同時到達;
    //     不再使用穩定濾波 (v12: pf 每拍變動時濾波一直不放行, TXAGC 用的 pf 卡住)
    // =========================================================================
    localparam PF_W = 10 + 10;
    wire [PF_W-1:0] pf_cur = {gain_index_power_fit, goal_rel_db};
    reg  [PF_W-1:0] pf_last, pf_hs_data;
    reg             pf_hs_send;
    wire            pf_hs_rcv, pf_hs_req;
    wire [PF_W-1:0] pf_hs_out;

    always @(posedge clk) begin
        if (!rst_n) begin
            pf_last    <= {PF_W{1'b0}};
            pf_hs_data <= {PF_W{1'b0}};
            pf_hs_send <= 1'b0;
        end else if (!pf_hs_send && !pf_hs_rcv && (pf_cur != pf_last)) begin
            pf_hs_data <= pf_cur;
            pf_last    <= pf_cur;
            pf_hs_send <= 1'b1;
        end else if (pf_hs_send && pf_hs_rcv) begin
            pf_hs_send <= 1'b0;
        end
    end

    xpm_cdc_handshake #(
        .DEST_EXT_HSK   (0),
        .DEST_SYNC_FF   (3),
        .INIT_SYNC_FF   (1),
        .SIM_ASSERT_CHK (0),
        .SRC_SYNC_FF    (3),
        .WIDTH          (PF_W)
    ) u_cdc_pf (
        .src_clk  (clk),
        .src_in   (pf_hs_data),
        .src_send (pf_hs_send),
        .src_rcv  (pf_hs_rcv),
        .dest_clk (adc_clk),
        .dest_req (pf_hs_req),
        .dest_ack (1'b0),
        .dest_out (pf_hs_out)
    );

    reg pf_hs_req_d;
    always @(posedge adc_clk) begin
        if (!rst_n_adc) begin
            pf_hs_req_d <= 1'b0;
            {gain_index_power_fit_adc, goal_rel_db_adc} <= {PF_W{1'b0}};
        end else begin
            pf_hs_req_d <= pf_hs_req;
            if (pf_hs_req && !pf_hs_req_d)
                {gain_index_power_fit_adc, goal_rel_db_adc} <= pf_hs_out;
        end
    end

    // =========================================================================
    // 3b. adc_clk -> clk: gain_index_applied / analog clamp (-> gain_index_mux / ILA)
    // =========================================================================
    localparam OUT_W = 12 + 2;
    wire [OUT_W-1:0] out_sync;
    reg  [OUT_W-1:0] out_sync_d;
    reg  [3:0]       out_stable_cnt;

    xpm_cdc_array_single #(
        .DEST_SYNC_FF   (3),
        .INIT_SYNC_FF   (1),
        .SIM_ASSERT_CHK (0),
        .SRC_INPUT_REG  (1),
        .WIDTH          (OUT_W)
    ) u_cdc_out (
        .src_clk  (adc_clk),
        .src_in   ({gain_index_applied, analog_clamp_hi, analog_clamp_lo}),
        .dest_clk (clk),
        .dest_out (out_sync)
    );

    always @(posedge clk) begin
        if (!rst_n) begin
            out_sync_d     <= {OUT_W{1'b0}};
            out_stable_cnt <= 4'd0;
            gain_index_tx  <= 12'd0;
            tx_att_clamp   <= 2'b00;
        end else begin
            out_sync_d <= out_sync;
            if (out_sync != out_sync_d)
                out_stable_cnt <= 4'd0;
            else if (out_stable_cnt < STABLE_CYCLES - 1)
                out_stable_cnt <= out_stable_cnt + 1'b1;
            else
                {gain_index_tx, tx_att_clamp} <= out_sync_d;
        end
    end

    // =========================================================================
    // 4. clear_or / clear_ov: adc_clk -> reg_clk
    //    RXAGC 送出 SET_CLEAR_CYCLE (6) 拍 @240MHz = 25ns > 2 個 reg_clk (100MHz) 週期
    // =========================================================================
    xpm_cdc_single #(
        .DEST_SYNC_FF   (3),
        .INIT_SYNC_FF   (1),
        .SIM_ASSERT_CHK (0),
        .SRC_INPUT_REG  (1)
    ) u_cdc_clear_or (
        .src_clk  (adc_clk),
        .src_in   (clear_or_adc),
        .dest_clk (reg_clk),
        .dest_out (clear_or)
    );

    xpm_cdc_single #(
        .DEST_SYNC_FF   (3),
        .INIT_SYNC_FF   (1),
        .SIM_ASSERT_CHK (0),
        .SRC_INPUT_REG  (1)
    ) u_cdc_clear_ov (
        .src_clk  (adc_clk),
        .src_in   (clear_ov_adc),
        .dest_clk (reg_clk),
        .dest_out (clear_ov)
    );

endmodule
