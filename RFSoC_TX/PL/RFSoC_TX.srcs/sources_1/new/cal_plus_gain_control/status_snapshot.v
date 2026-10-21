`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: status_snapshot
// Description: 通道狀態暫存器的同步鎖存 (reg map mem64~70, 2026-10-10)
//   - snapshot_trig (S_AXI_ACLK 1 拍脈衝, mem64 寫 1) -> xpm_cdc_pulse 到 clk / adc_clk
//   - clk 與 adc_clk 各自在收到脈衝的那一拍鎖存 (兩個 domain 相差 < 約 20 ns, 同一次觸發)
//   - 鎖存值保持不變, 以 xpm_cdc_array_single 同步回 S_AXI_ACLK
//   - 兩個 domain 都鎖存完成 (ack 脈衝回到 S_AXI_ACLK) 後 snapshot_cnt + 1; 軟體看到計數改變再讀狀態
//////////////////////////////////////////////////////////////////////////////////
module status_snapshot (
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 reg_clk CLK" *)
    input  wire        reg_clk,
    input  wire        snapshot_trig,
    output reg  [15:0] snapshot_cnt = 16'd0,

    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK" *)
    input  wire        clk,
    input  wire [15:0] power_amp,
    input  wire [9:0]  gain_index_power_fit,
    input  wire [11:0] goal_db,
    input  wire [9:0]  goal_rel_db,
    input  wire [11:0] gain_index_tx,

    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 adc_clk CLK" *)
    input  wire        adc_clk,
    input  wire        over_threshold1,
    input  wire        over_threshold2,
    input  wire        over_range,
    input  wire        over_voltage,

    // S_AXI_ACLK domain -> addressable_reg_map
    output wire [15:0] st_power_amp,
    output wire [9:0]  st_gain_index_power_fit,
    output wire [11:0] st_goal_db,
    output wire [9:0]  st_goal_rel_db,
    output wire [11:0] st_gain_index_tx,
    output wire [3:0]  st_adc_flags
);

    localparam CW = 16 + 10 + 12 + 10 + 12;   // 60

    // ---------------- trigger -> clk / adc_clk ----------------
    wire trig_clk, trig_adc;
    xpm_cdc_pulse #(.DEST_SYNC_FF(4), .INIT_SYNC_FF(1), .REG_OUTPUT(1), .RST_USED(0), .SIM_ASSERT_CHK(0)) u_trig_clk (
        .src_clk(reg_clk), .src_pulse(snapshot_trig), .src_rst(1'b0),
        .dest_clk(clk), .dest_pulse(trig_clk), .dest_rst(1'b0));
    xpm_cdc_pulse #(.DEST_SYNC_FF(4), .INIT_SYNC_FF(1), .REG_OUTPUT(1), .RST_USED(0), .SIM_ASSERT_CHK(0)) u_trig_adc (
        .src_clk(reg_clk), .src_pulse(snapshot_trig), .src_rst(1'b0),
        .dest_clk(adc_clk), .dest_pulse(trig_adc), .dest_rst(1'b0));

    // ---------------- latch ----------------
    reg [CW-1:0] lat_clk = {CW{1'b0}};
    reg          ack_clk = 1'b0;
    always @(posedge clk) begin
        ack_clk <= trig_clk;
        if (trig_clk) lat_clk <= {power_amp, gain_index_power_fit, goal_db, goal_rel_db, gain_index_tx};
    end

    reg [3:0] lat_adc = 4'd0;
    reg       ack_adc = 1'b0;
    always @(posedge adc_clk) begin
        ack_adc <= trig_adc;
        if (trig_adc) lat_adc <= {over_voltage, over_range, over_threshold2, over_threshold1};
    end

    // ---------------- 鎖存值 -> reg_clk (值在下次觸發前不變) ----------------
    wire [CW-1:0] st_clk;
    xpm_cdc_array_single #(.DEST_SYNC_FF(2), .INIT_SYNC_FF(1), .SIM_ASSERT_CHK(0), .SRC_INPUT_REG(0), .WIDTH(CW)) u_st_clk (
        .src_clk(clk), .src_in(lat_clk), .dest_clk(reg_clk), .dest_out(st_clk));
    xpm_cdc_array_single #(.DEST_SYNC_FF(2), .INIT_SYNC_FF(1), .SIM_ASSERT_CHK(0), .SRC_INPUT_REG(0), .WIDTH(4)) u_st_adc (
        .src_clk(adc_clk), .src_in(lat_adc), .dest_clk(reg_clk), .dest_out(st_adc_flags));
    assign {st_power_amp, st_gain_index_power_fit, st_goal_db, st_goal_rel_db, st_gain_index_tx} = st_clk;

    // ---------------- 完成計數 (兩個 domain 的 ack 都回來才 + 1) ----------------
    wire done_clk, done_adc;
    xpm_cdc_pulse #(.DEST_SYNC_FF(4), .INIT_SYNC_FF(1), .REG_OUTPUT(1), .RST_USED(0), .SIM_ASSERT_CHK(0)) u_ack_clk (
        .src_clk(clk), .src_pulse(ack_clk), .src_rst(1'b0),
        .dest_clk(reg_clk), .dest_pulse(done_clk), .dest_rst(1'b0));
    xpm_cdc_pulse #(.DEST_SYNC_FF(4), .INIT_SYNC_FF(1), .REG_OUTPUT(1), .RST_USED(0), .SIM_ASSERT_CHK(0)) u_ack_adc (
        .src_clk(adc_clk), .src_pulse(ack_adc), .src_rst(1'b0),
        .dest_clk(reg_clk), .dest_pulse(done_adc), .dest_rst(1'b0));

    reg got_clk = 1'b0, got_adc = 1'b0;
    always @(posedge reg_clk) begin
        if ((got_clk | done_clk) & (got_adc | done_adc)) begin
            got_clk <= 1'b0; got_adc <= 1'b0;
            snapshot_cnt <= snapshot_cnt + 1'b1;
        end else begin
            if (done_clk) got_clk <= 1'b1;
            if (done_adc) got_adc <= 1'b1;
        end
    end

endmodule
