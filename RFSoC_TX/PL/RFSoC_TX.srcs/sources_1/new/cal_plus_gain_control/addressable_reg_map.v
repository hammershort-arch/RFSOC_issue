`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: addressable_reg_map
// ** 由 hardware/scripts/gen_reg_maps.py 依 doc/tools/regmap_def.py 產生, 請勿手改 **
// Description: 每個通道的 AXI-Lite reg map (RegMap v8, 2026-10-10; mem38 2026-10-12; mem39 2026-10-14)
//   mem0~39  設定 (R/W, 32-bit, 上電初值); mem40~63 保留 (讀 0)
//   mem64    status_snapshot: 寫 bit0 = 1 -> snapshot 脈衝; 讀 = 完成的 snapshot 次數
//   mem65~70 狀態 (唯讀, 由 status_snapshot_0 鎖存後同步到 S_AXI_ACLK; 有號欄位讀回時符號擴展)
//   mem0   0x000 fir_enable                       [0:0] reset 0x0  bit
//   mem1   0x004 fir_tap00                        [31:0] reset 0x0  [15:0] I, [31:16] Q (S1.14 each)
//   mem2   0x008 fir_tap01                        [31:0] reset 0x0  [15:0] I, [31:16] Q (S1.14 each)
//   mem3   0x00C fir_tap02                        [31:0] reset 0x0  [15:0] I, [31:16] Q (S1.14 each)
//   mem4   0x010 fir_tap03                        [31:0] reset 0x0  [15:0] I, [31:16] Q (S1.14 each)
//   mem5   0x014 fir_tap04                        [31:0] reset 0x0  [15:0] I, [31:16] Q (S1.14 each)
//   mem6   0x018 fir_tap05                        [31:0] reset 0x0  [15:0] I, [31:16] Q (S1.14 each)
//   mem7   0x01C fir_tap06                        [31:0] reset 0x0  [15:0] I, [31:16] Q (S1.14 each)
//   mem8   0x020 fir_tap07                        [31:0] reset 0x0  [15:0] I, [31:16] Q (S1.14 each)
//   mem9   0x024 fir_tap08                        [31:0] reset 0x0  [15:0] I, [31:16] Q (S1.14 each)
//   mem10  0x028 fir_tap09                        [31:0] reset 0x0  [15:0] I, [31:16] Q (S1.14 each)
//   mem11  0x02C fir_tap10                        [31:0] reset 0x0  [15:0] I, [31:16] Q (S1.14 each)
//   mem12  0x030 fir_tap11                        [31:0] reset 0x0  [15:0] I, [31:16] Q (S1.14 each)
//   mem13  0x034 fir_tap12                        [31:0] reset 0x0  [15:0] I, [31:16] Q (S1.14 each)
//   mem14  0x038 fir_tap13                        [31:0] reset 0x0  [15:0] I, [31:16] Q (S1.14 each)
//   mem15  0x03C fir_tap14                        [31:0] reset 0x0  [15:0] I, [31:16] Q (S1.14 each)
//   mem16  0x040 fir_tap15                        [31:0] reset 0x0  [15:0] I, [31:16] Q (S1.14 each)
//   mem17  0x044 coarse_delay_offset              [3:0] reset 0x0  unsigned, cycles
//   mem18  0x048 fractional_delay_offset          [2:0] reset 0x0  unsigned, samples
//   mem19  0x04C phase_offset                     [15:0] reset 0x0  CORDIC phase
//   mem20  0x050 gain_index_mode_sel              [0:0] reset 0x0  bit
//   mem21  0x054 gain_index_manual                [10:0] reset 0x0  S6.4, 1/16 dB
//   mem22  0x058 gain_index_ch_offset             [8:0] reset 0x0  S4.4, 1/16 dB
//   mem23  0x05C gain_index_rf_freq_offset        [7:0] reset 0x0  S3.4, 1/16 dB
//   mem24  0x060 gain_index_temperature_offset    [7:0] reset 0x0  S3.4, 1/16 dB
//   mem25  0x064 dac_output_ref_dbm               [10:0] reset 0x670  S6.4 dBm
//   mem26  0x068 goal_ref_dbfs                    [10:0] reset 0x7A0  S6.4 dBFS (16384 = 0 dBFS)
//   mem27  0x06C agc_reg5                         [7:0] reset 0x80  bits
//   mem28  0x070 agc_bypass_agc                   [0:0] reset 0x0  bit
//   mem29  0x074 agc_bypass_tx_att_state          [4:0] reset 0x0  unsigned state
//   mem30  0x078 agc_bypass_sr_update             [1:0] reset 0x0  bits, rising edge
//   mem31  0x07C agc_manual_tx_att_en             [0:0] reset 0x0  bit
//   mem32  0x080 agc_manual_tx_att_db             [7:0] reset 0x0  unsigned, 1 dB
//   mem33  0x084 agc_target_power                 [7:0] reset 0x0  signed, 1 dBm
//   mem34  0x088 agc_linear_mode_offset           [11:0] reset 0x0  signed, 1/16 dB
//   mem35  0x08C agc_manual_mode_offset           [11:0] reset 0x0  signed, 1/16 dB
//   mem36  0x090 agc_manual_rx_att_en             [0:0] reset 0x0  bit
//   mem37  0x094 agc_manual_rx_att_state          [2:0] reset 0x0  unsigned state
//   mem38  0x098 bypass_axis_iq                   [0:0] reset 0x0  bit
//   mem39  0x09C signal_source_select             [1:0] reset 0x0  0 = in_0 (Aurora), 1 = in_1 (ADC), 2/3 = all_zero (Debug_008, 2026-10-19)
//   mem64  0x100 status_snapshot                  [15:0] reset 0x0  W: bit0 = 1 trigger; R: [15:0] completed snapshot count
//   mem65  0x104 st_power_amp                     [15:0] reset 0x0  unsigned amplitude
//   mem66  0x108 st_gain_index_power_fit          [9:0] reset 0x0  S5.4, 1/16 dB (sign-extended)
//   mem67  0x10C st_goal_db                       [11:0] reset 0x0  S7.4 dBFS (sign-extended)
//   mem68  0x110 st_goal_rel_db                   [9:0] reset 0x0  S5.4, 1/16 dB (sign-extended)
//   mem69  0x114 st_gain_index_tx                 [11:0] reset 0x0  S7.4, 1/16 dB (sign-extended)
//   mem70  0x118 st_adc_flags                     [3:0] reset 0x0  bits
//////////////////////////////////////////////////////////////////////////////////
module addressable_reg_map #(
    parameter integer C_S_AXI_ADDR_WIDTH = 9
)(
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 S_AXI_ACLK CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF S_AXI" *)
    input  wire                          S_AXI_ACLK,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    input  wire [2:0]                    S_AXI_AWPROT,
    input  wire                          S_AXI_AWVALID,
    output wire                          S_AXI_AWREADY,
    input  wire [31:0]                   S_AXI_WDATA,
    input  wire [3:0]                    S_AXI_WSTRB,
    input  wire                          S_AXI_WVALID,
    output wire                          S_AXI_WREADY,
    output wire [1:0]                    S_AXI_BRESP,
    output reg                           S_AXI_BVALID = 1'b0,
    input  wire                          S_AXI_BREADY,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    input  wire [2:0]                    S_AXI_ARPROT,
    input  wire                          S_AXI_ARVALID,
    output wire                          S_AXI_ARREADY,
    output reg  [31:0]                   S_AXI_RDATA = 32'd0,
    output wire [1:0]                    S_AXI_RRESP,
    output reg                           S_AXI_RVALID = 1'b0,
    input  wire                          S_AXI_RREADY,
    output wire [31:0] mem0,   // fir_enable
    output wire [31:0] mem1,   // fir_tap00
    output wire [31:0] mem2,   // fir_tap01
    output wire [31:0] mem3,   // fir_tap02
    output wire [31:0] mem4,   // fir_tap03
    output wire [31:0] mem5,   // fir_tap04
    output wire [31:0] mem6,   // fir_tap05
    output wire [31:0] mem7,   // fir_tap06
    output wire [31:0] mem8,   // fir_tap07
    output wire [31:0] mem9,   // fir_tap08
    output wire [31:0] mem10,   // fir_tap09
    output wire [31:0] mem11,   // fir_tap10
    output wire [31:0] mem12,   // fir_tap11
    output wire [31:0] mem13,   // fir_tap12
    output wire [31:0] mem14,   // fir_tap13
    output wire [31:0] mem15,   // fir_tap14
    output wire [31:0] mem16,   // fir_tap15
    output wire [31:0] mem17,   // coarse_delay_offset
    output wire [31:0] mem18,   // fractional_delay_offset
    output wire [31:0] mem19,   // phase_offset
    output wire [31:0] mem20,   // gain_index_mode_sel
    output wire [31:0] mem21,   // gain_index_manual
    output wire [31:0] mem22,   // gain_index_ch_offset
    output wire [31:0] mem23,   // gain_index_rf_freq_offset
    output wire [31:0] mem24,   // gain_index_temperature_offset
    output wire [31:0] mem25,   // dac_output_ref_dbm
    output wire [31:0] mem26,   // goal_ref_dbfs
    output wire [31:0] mem27,   // agc_reg5
    output wire [31:0] mem28,   // agc_bypass_agc
    output wire [31:0] mem29,   // agc_bypass_tx_att_state
    output wire [31:0] mem30,   // agc_bypass_sr_update
    output wire [31:0] mem31,   // agc_manual_tx_att_en
    output wire [31:0] mem32,   // agc_manual_tx_att_db
    output wire [31:0] mem33,   // agc_target_power
    output wire [31:0] mem34,   // agc_linear_mode_offset
    output wire [31:0] mem35,   // agc_manual_mode_offset
    output wire [31:0] mem36,   // agc_manual_rx_att_en
    output wire [31:0] mem37,   // agc_manual_rx_att_state
    output wire [31:0] mem38,   // bypass_axis_iq
    output wire [31:0] mem39,   // signal_source_select
    // status (S_AXI_ACLK domain)
    output reg         snapshot_trig = 1'b0,   // mem64 寫 bit0 = 1 -> 1 拍脈衝
    input  wire [15:0] snapshot_cnt,
    input  wire [15:0] st_power_amp,   // mem65
    input  wire [9:0] st_gain_index_power_fit,   // mem66
    input  wire [11:0] st_goal_db,   // mem67
    input  wire [9:0] st_goal_rel_db,   // mem68
    input  wire [11:0] st_gain_index_tx,   // mem69
    input  wire [3:0] st_adc_flags   // mem70
);

    // ------------------------------------------------------------------
    // AXI4-Lite (無 reset, 上電初值; AW / W 可同拍或分開到達)
    // ------------------------------------------------------------------
    localparam integer NREG = 2 ** (C_S_AXI_ADDR_WIDTH - 2);
    reg                          aw_ok = 1'b0, w_ok = 1'b0;
    reg [C_S_AXI_ADDR_WIDTH-1:0] awaddr_q = 0;
    reg [31:0]                   wdata_q  = 32'd0;
    reg [3:0]                    wstrb_q  = 4'd0;

    assign S_AXI_AWREADY = ~aw_ok & ~S_AXI_BVALID;
    assign S_AXI_WREADY  = ~w_ok  & ~S_AXI_BVALID;
    assign S_AXI_BRESP   = 2'b00;
    assign S_AXI_ARREADY = ~S_AXI_RVALID;
    assign S_AXI_RRESP   = 2'b00;

    wire aw_fire = S_AXI_AWVALID & S_AXI_AWREADY;
    wire w_fire  = S_AXI_WVALID  & S_AXI_WREADY;
    wire [C_S_AXI_ADDR_WIDTH-1:0] waddr = aw_fire ? S_AXI_AWADDR : awaddr_q;
    wire [31:0] wdat  = w_fire ? S_AXI_WDATA : wdata_q;
    wire [3:0]  wstrb = w_fire ? S_AXI_WSTRB : wstrb_q;
    wire        wr_en = (aw_fire | aw_ok) & (w_fire | w_ok);
    wire [C_S_AXI_ADDR_WIDTH-3:0] widx = waddr[C_S_AXI_ADDR_WIDTH-1:2];
    wire [C_S_AXI_ADDR_WIDTH-3:0] ridx = S_AXI_ARADDR[C_S_AXI_ADDR_WIDTH-1:2];

    always @(posedge S_AXI_ACLK) begin
        if (wr_en) begin
            aw_ok <= 1'b0; w_ok <= 1'b0; S_AXI_BVALID <= 1'b1;
        end else begin
            if (aw_fire) begin aw_ok <= 1'b1; awaddr_q <= S_AXI_AWADDR; end
            if (w_fire)  begin w_ok  <= 1'b1; wdata_q  <= S_AXI_WDATA; wstrb_q <= S_AXI_WSTRB; end
            if (S_AXI_BVALID & S_AXI_BREADY) S_AXI_BVALID <= 1'b0;
        end
    end

    function [31:0] wmerge(input [31:0] old, input [31:0] d, input [3:0] s);
        integer b;
        begin
            wmerge = old;
            for (b = 0; b < 4; b = b + 1) if (s[b]) wmerge[b*8 +: 8] = d[b*8 +: 8];
        end
    endfunction

    reg [31:0] cfg_r0 = 32'h00000000;   // fir_enable
    assign mem0 = cfg_r0;
    reg [31:0] cfg_r1 = 32'h00000000;   // fir_tap00
    assign mem1 = cfg_r1;
    reg [31:0] cfg_r2 = 32'h00000000;   // fir_tap01
    assign mem2 = cfg_r2;
    reg [31:0] cfg_r3 = 32'h00000000;   // fir_tap02
    assign mem3 = cfg_r3;
    reg [31:0] cfg_r4 = 32'h00000000;   // fir_tap03
    assign mem4 = cfg_r4;
    reg [31:0] cfg_r5 = 32'h00000000;   // fir_tap04
    assign mem5 = cfg_r5;
    reg [31:0] cfg_r6 = 32'h00000000;   // fir_tap05
    assign mem6 = cfg_r6;
    reg [31:0] cfg_r7 = 32'h00000000;   // fir_tap06
    assign mem7 = cfg_r7;
    reg [31:0] cfg_r8 = 32'h00000000;   // fir_tap07
    assign mem8 = cfg_r8;
    reg [31:0] cfg_r9 = 32'h00000000;   // fir_tap08
    assign mem9 = cfg_r9;
    reg [31:0] cfg_r10 = 32'h00000000;   // fir_tap09
    assign mem10 = cfg_r10;
    reg [31:0] cfg_r11 = 32'h00000000;   // fir_tap10
    assign mem11 = cfg_r11;
    reg [31:0] cfg_r12 = 32'h00000000;   // fir_tap11
    assign mem12 = cfg_r12;
    reg [31:0] cfg_r13 = 32'h00000000;   // fir_tap12
    assign mem13 = cfg_r13;
    reg [31:0] cfg_r14 = 32'h00000000;   // fir_tap13
    assign mem14 = cfg_r14;
    reg [31:0] cfg_r15 = 32'h00000000;   // fir_tap14
    assign mem15 = cfg_r15;
    reg [31:0] cfg_r16 = 32'h00000000;   // fir_tap15
    assign mem16 = cfg_r16;
    reg [31:0] cfg_r17 = 32'h00000000;   // coarse_delay_offset
    assign mem17 = cfg_r17;
    reg [31:0] cfg_r18 = 32'h00000000;   // fractional_delay_offset
    assign mem18 = cfg_r18;
    reg [31:0] cfg_r19 = 32'h00000000;   // phase_offset
    assign mem19 = cfg_r19;
    reg [31:0] cfg_r20 = 32'h00000000;   // gain_index_mode_sel
    assign mem20 = cfg_r20;
    reg [31:0] cfg_r21 = 32'h00000000;   // gain_index_manual
    assign mem21 = cfg_r21;
    reg [31:0] cfg_r22 = 32'h00000000;   // gain_index_ch_offset
    assign mem22 = cfg_r22;
    reg [31:0] cfg_r23 = 32'h00000000;   // gain_index_rf_freq_offset
    assign mem23 = cfg_r23;
    reg [31:0] cfg_r24 = 32'h00000000;   // gain_index_temperature_offset
    assign mem24 = cfg_r24;
    reg [31:0] cfg_r25 = 32'h00000670;   // dac_output_ref_dbm
    assign mem25 = cfg_r25;
    reg [31:0] cfg_r26 = 32'h000007A0;   // goal_ref_dbfs
    assign mem26 = cfg_r26;
    reg [31:0] cfg_r27 = 32'h00000080;   // agc_reg5
    assign mem27 = cfg_r27;
    reg [31:0] cfg_r28 = 32'h00000000;   // agc_bypass_agc
    assign mem28 = cfg_r28;
    reg [31:0] cfg_r29 = 32'h00000000;   // agc_bypass_tx_att_state
    assign mem29 = cfg_r29;
    reg [31:0] cfg_r30 = 32'h00000000;   // agc_bypass_sr_update
    assign mem30 = cfg_r30;
    reg [31:0] cfg_r31 = 32'h00000000;   // agc_manual_tx_att_en
    assign mem31 = cfg_r31;
    reg [31:0] cfg_r32 = 32'h00000000;   // agc_manual_tx_att_db
    assign mem32 = cfg_r32;
    reg [31:0] cfg_r33 = 32'h00000000;   // agc_target_power
    assign mem33 = cfg_r33;
    reg [31:0] cfg_r34 = 32'h00000000;   // agc_linear_mode_offset
    assign mem34 = cfg_r34;
    reg [31:0] cfg_r35 = 32'h00000000;   // agc_manual_mode_offset
    assign mem35 = cfg_r35;
    reg [31:0] cfg_r36 = 32'h00000000;   // agc_manual_rx_att_en
    assign mem36 = cfg_r36;
    reg [31:0] cfg_r37 = 32'h00000000;   // agc_manual_rx_att_state
    assign mem37 = cfg_r37;
    reg [31:0] cfg_r38 = 32'h00000000;   // bypass_axis_iq
    assign mem38 = cfg_r38;
    reg [31:0] cfg_r39 = 32'h00000000;   // signal_source_select
    assign mem39 = cfg_r39;

    always @(posedge S_AXI_ACLK) begin
        if (wr_en) begin
            case (widx)
                0: cfg_r0 <= wmerge(cfg_r0, wdat, wstrb);
                1: cfg_r1 <= wmerge(cfg_r1, wdat, wstrb);
                2: cfg_r2 <= wmerge(cfg_r2, wdat, wstrb);
                3: cfg_r3 <= wmerge(cfg_r3, wdat, wstrb);
                4: cfg_r4 <= wmerge(cfg_r4, wdat, wstrb);
                5: cfg_r5 <= wmerge(cfg_r5, wdat, wstrb);
                6: cfg_r6 <= wmerge(cfg_r6, wdat, wstrb);
                7: cfg_r7 <= wmerge(cfg_r7, wdat, wstrb);
                8: cfg_r8 <= wmerge(cfg_r8, wdat, wstrb);
                9: cfg_r9 <= wmerge(cfg_r9, wdat, wstrb);
                10: cfg_r10 <= wmerge(cfg_r10, wdat, wstrb);
                11: cfg_r11 <= wmerge(cfg_r11, wdat, wstrb);
                12: cfg_r12 <= wmerge(cfg_r12, wdat, wstrb);
                13: cfg_r13 <= wmerge(cfg_r13, wdat, wstrb);
                14: cfg_r14 <= wmerge(cfg_r14, wdat, wstrb);
                15: cfg_r15 <= wmerge(cfg_r15, wdat, wstrb);
                16: cfg_r16 <= wmerge(cfg_r16, wdat, wstrb);
                17: cfg_r17 <= wmerge(cfg_r17, wdat, wstrb);
                18: cfg_r18 <= wmerge(cfg_r18, wdat, wstrb);
                19: cfg_r19 <= wmerge(cfg_r19, wdat, wstrb);
                20: cfg_r20 <= wmerge(cfg_r20, wdat, wstrb);
                21: cfg_r21 <= wmerge(cfg_r21, wdat, wstrb);
                22: cfg_r22 <= wmerge(cfg_r22, wdat, wstrb);
                23: cfg_r23 <= wmerge(cfg_r23, wdat, wstrb);
                24: cfg_r24 <= wmerge(cfg_r24, wdat, wstrb);
                25: cfg_r25 <= wmerge(cfg_r25, wdat, wstrb);
                26: cfg_r26 <= wmerge(cfg_r26, wdat, wstrb);
                27: cfg_r27 <= wmerge(cfg_r27, wdat, wstrb);
                28: cfg_r28 <= wmerge(cfg_r28, wdat, wstrb);
                29: cfg_r29 <= wmerge(cfg_r29, wdat, wstrb);
                30: cfg_r30 <= wmerge(cfg_r30, wdat, wstrb);
                31: cfg_r31 <= wmerge(cfg_r31, wdat, wstrb);
                32: cfg_r32 <= wmerge(cfg_r32, wdat, wstrb);
                33: cfg_r33 <= wmerge(cfg_r33, wdat, wstrb);
                34: cfg_r34 <= wmerge(cfg_r34, wdat, wstrb);
                35: cfg_r35 <= wmerge(cfg_r35, wdat, wstrb);
                36: cfg_r36 <= wmerge(cfg_r36, wdat, wstrb);
                37: cfg_r37 <= wmerge(cfg_r37, wdat, wstrb);
                38: cfg_r38 <= wmerge(cfg_r38, wdat, wstrb);
                39: cfg_r39 <= wmerge(cfg_r39, wdat, wstrb);
                default: ;
            endcase
        end
    end

    // status snapshot (mem64)
    always @(posedge S_AXI_ACLK)
        snapshot_trig <= wr_en && (widx == 64) && wstrb[0] && wdat[0];

    reg [31:0] rd_mux;
    always @(*) begin
        case (ridx)
            0: rd_mux = cfg_r0;
            1: rd_mux = cfg_r1;
            2: rd_mux = cfg_r2;
            3: rd_mux = cfg_r3;
            4: rd_mux = cfg_r4;
            5: rd_mux = cfg_r5;
            6: rd_mux = cfg_r6;
            7: rd_mux = cfg_r7;
            8: rd_mux = cfg_r8;
            9: rd_mux = cfg_r9;
            10: rd_mux = cfg_r10;
            11: rd_mux = cfg_r11;
            12: rd_mux = cfg_r12;
            13: rd_mux = cfg_r13;
            14: rd_mux = cfg_r14;
            15: rd_mux = cfg_r15;
            16: rd_mux = cfg_r16;
            17: rd_mux = cfg_r17;
            18: rd_mux = cfg_r18;
            19: rd_mux = cfg_r19;
            20: rd_mux = cfg_r20;
            21: rd_mux = cfg_r21;
            22: rd_mux = cfg_r22;
            23: rd_mux = cfg_r23;
            24: rd_mux = cfg_r24;
            25: rd_mux = cfg_r25;
            26: rd_mux = cfg_r26;
            27: rd_mux = cfg_r27;
            28: rd_mux = cfg_r28;
            29: rd_mux = cfg_r29;
            30: rd_mux = cfg_r30;
            31: rd_mux = cfg_r31;
            32: rd_mux = cfg_r32;
            33: rd_mux = cfg_r33;
            34: rd_mux = cfg_r34;
            35: rd_mux = cfg_r35;
            36: rd_mux = cfg_r36;
            37: rd_mux = cfg_r37;
            38: rd_mux = cfg_r38;
            39: rd_mux = cfg_r39;
            64: rd_mux = {16'd0, snapshot_cnt};
            65: rd_mux = {16'd0, st_power_amp};
            66: rd_mux = {{22{st_gain_index_power_fit[9]}}, st_gain_index_power_fit};
            67: rd_mux = {{20{st_goal_db[11]}}, st_goal_db};
            68: rd_mux = {{22{st_goal_rel_db[9]}}, st_goal_rel_db};
            69: rd_mux = {{20{st_gain_index_tx[11]}}, st_gain_index_tx};
            70: rd_mux = {28'd0, st_adc_flags};
            default: rd_mux = 32'd0;
        endcase
    end

    always @(posedge S_AXI_ACLK) begin
        if (S_AXI_ARVALID & S_AXI_ARREADY) begin
            S_AXI_RDATA  <= rd_mux;
            S_AXI_RVALID <= 1'b1;
        end else if (S_AXI_RVALID & S_AXI_RREADY) begin
            S_AXI_RVALID <= 1'b0;
        end
    end

endmodule
