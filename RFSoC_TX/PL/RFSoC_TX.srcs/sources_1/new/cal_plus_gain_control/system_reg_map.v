`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: system_reg_map
// ** 由 hardware/scripts/gen_reg_maps.py 依 doc/tools/regmap_def.py 產生, 請勿手改 **
// Description: 系統共用 AXI-Lite reg map (design_1, 8 通道共用, 2026-10-10)
//   sys0~13 設定 (R/W, 32-bit, 上電初值) -> 各通道 cal_plus_gain_control_chN 的 reg_* pin
//   sys14   build_version (唯讀, 參數 BUILD_VERSION, build_full_xsa.tcl 設定)
//   sys15~16 之後新增的設定 (R/W)
//   sys0   0x000 signal_mode_select               [0:0] reset 0x0  bit
//   sys1   0x004 power_limit_margin               [2:0] reset 0x3  U3.0 dB
//   sys2   0x008 cw_mode_goal_dbfs                [10:0] reset 0x7A0  S6.4 dBFS (16384 = 0 dBFS)
//   sys3   0x00C pulse_update_stable_cycle        [3:0] reset 0x4  unsigned, clk (3.906 ns)
//   sys4   0x010 agc_tx_power_mode                [0:0] reset 0x0  bit
//   sys5   0x014 digital_apply_delay              [7:0] reset 0x23  unsigned, adc_clk (4.167 ns)
//   sys6   0x018 agc_sr_update_period             [7:0] reset 0x32  unsigned, adc_clk
//   sys7   0x01C agc_mode_settle_cycle            [15:0] reset 0x40  unsigned, adc_clk
//   sys8   0x020 agc_rx_watch_cycle               [31:0] reset 0x3E8  unsigned, adc_clk
//   sys9   0x024 agc_rx_wait_dsa_cycle            [7:0] reset 0x6  unsigned, adc_clk
//   sys10  0x028 agc_rx_set_dsa_cycle             [7:0] reset 0x6  unsigned, adc_clk
//   sys11  0x02C agc_rx_wait_cycle                [7:0] reset 0x32  unsigned, adc_clk
//   sys12  0x030 agc_rx_set_clear_cycle           [7:0] reset 0x6  unsigned, adc_clk
//   sys13  0x034 agc_rx_wait_clear_cycle          [7:0] reset 0x10  unsigned, adc_clk
//   sys15  0x03C cw_power_avg_log2                [3:0] reset 0x8  log2(N), CW samples (clk)
//   sys16  0x040 agc_tx_att_hysteresis            [7:0] reset 0x10  U4.4 dB (1/16 dB)
//   sys14  0x038 build_version                    [31:0] reset 0x0  unsigned
//////////////////////////////////////////////////////////////////////////////////
module system_reg_map #(
    parameter integer C_S_AXI_ADDR_WIDTH = 8,
    parameter integer BUILD_VERSION = 0
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
    output wire [31:0] sys0,   // signal_mode_select
    output wire [31:0] sys1,   // power_limit_margin
    output wire [31:0] sys2,   // cw_mode_goal_dbfs
    output wire [31:0] sys3,   // pulse_update_stable_cycle
    output wire [31:0] sys4,   // agc_tx_power_mode
    output wire [31:0] sys5,   // digital_apply_delay
    output wire [31:0] sys6,   // agc_sr_update_period
    output wire [31:0] sys7,   // agc_mode_settle_cycle
    output wire [31:0] sys8,   // agc_rx_watch_cycle
    output wire [31:0] sys9,   // agc_rx_wait_dsa_cycle
    output wire [31:0] sys10,   // agc_rx_set_dsa_cycle
    output wire [31:0] sys11,   // agc_rx_wait_cycle
    output wire [31:0] sys12,   // agc_rx_set_clear_cycle
    output wire [31:0] sys13,   // agc_rx_wait_clear_cycle
    output wire [31:0] sys15,   // cw_power_avg_log2
    output wire [31:0] sys16   // agc_tx_att_hysteresis
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

    reg [31:0] cfg_r0 = 32'h00000000;   // signal_mode_select
    assign sys0 = cfg_r0;
    reg [31:0] cfg_r1 = 32'h00000003;   // power_limit_margin
    assign sys1 = cfg_r1;
    reg [31:0] cfg_r2 = 32'h000007A0;   // cw_mode_goal_dbfs
    assign sys2 = cfg_r2;
    reg [31:0] cfg_r3 = 32'h00000004;   // pulse_update_stable_cycle
    assign sys3 = cfg_r3;
    reg [31:0] cfg_r4 = 32'h00000000;   // agc_tx_power_mode
    assign sys4 = cfg_r4;
    reg [31:0] cfg_r5 = 32'h00000023;   // digital_apply_delay
    assign sys5 = cfg_r5;
    reg [31:0] cfg_r6 = 32'h00000032;   // agc_sr_update_period
    assign sys6 = cfg_r6;
    reg [31:0] cfg_r7 = 32'h00000040;   // agc_mode_settle_cycle
    assign sys7 = cfg_r7;
    reg [31:0] cfg_r8 = 32'h000003E8;   // agc_rx_watch_cycle
    assign sys8 = cfg_r8;
    reg [31:0] cfg_r9 = 32'h00000006;   // agc_rx_wait_dsa_cycle
    assign sys9 = cfg_r9;
    reg [31:0] cfg_r10 = 32'h00000006;   // agc_rx_set_dsa_cycle
    assign sys10 = cfg_r10;
    reg [31:0] cfg_r11 = 32'h00000032;   // agc_rx_wait_cycle
    assign sys11 = cfg_r11;
    reg [31:0] cfg_r12 = 32'h00000006;   // agc_rx_set_clear_cycle
    assign sys12 = cfg_r12;
    reg [31:0] cfg_r13 = 32'h00000010;   // agc_rx_wait_clear_cycle
    assign sys13 = cfg_r13;
    reg [31:0] cfg_r15 = 32'h00000008;   // cw_power_avg_log2
    assign sys15 = cfg_r15;
    reg [31:0] cfg_r16 = 32'h00000010;   // agc_tx_att_hysteresis
    assign sys16 = cfg_r16;

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
                15: cfg_r15 <= wmerge(cfg_r15, wdat, wstrb);
                16: cfg_r16 <= wmerge(cfg_r16, wdat, wstrb);
                default: ;
            endcase
        end
    end

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
            15: rd_mux = cfg_r15;
            16: rd_mux = cfg_r16;
            14: rd_mux = BUILD_VERSION;
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
