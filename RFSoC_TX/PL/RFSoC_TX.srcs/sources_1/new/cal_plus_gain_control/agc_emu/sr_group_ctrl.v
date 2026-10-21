`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: sr_group_ctrl
// Description: 一組 (N 顆) 74LVC595 的共同控制
//              N 個獨立的 shift_register_FSM (各自的 SER / SRCLK / RCLK), 同一拍啟動、同時輸出
//              - auto_send = 1: data_in 與上次送出的內容不同時自動送出 (傳送中的變化不排隊,
//                               傳完後若內容仍不同, 以最新 data_in 再送)
//              - trig_update 正緣: 送出目前 data_in (傳送中收到則記成 pending, 傳完再送)
//              - update_period: 一輪更新的時間 (AGC_SR_UPDATE_PERIOD, 從 start 起算), 包含 SER 傳輸 + 硬體生效;
//                               時間到才抓取最新 data_in 做下一輪, 期間 busy 維持 1; 每輪 start 時鎖存
//              - busy  : 一輪更新期間 (含 trig 正緣當拍)
//              - synced: 未在傳送, 且 (auto_send 時) 硬體內容 = data_in
//              - start : 一輪開始的 1 拍脈衝 (前一拍鎖存 data_in), 給 gain_apply_sync 計時
//////////////////////////////////////////////////////////////////////////////////


module sr_group_ctrl #(
    parameter N_REG       = 4,
    parameter WAIT_CYCLES   = 2
)(
    input  wire               clk,
    input  wire               rst_n,
    input  wire               auto_send,        // 1: 內容改變即自動送出
    // 一輪 = SER 傳輸 (WAIT_CYCLES=2 時約 37 拍) + 硬體生效 (595 RCLK->Q worst 18.2 ns + 衰減器切換)
    // reset 50 x 4.17 ns = 208 ns (agc_cdc 下限 50); 若小於傳輸時間, 以傳輸完成為準
    input  wire [7:0]         update_period,
    input  wire               trig_update,      // 正緣觸發
    input  wire [8*N_REG-1:0] data_in,          // {Reg_N, ..., Reg_1}, 每顆 8-bit, bit7 = QA

    output wire [N_REG-1:0]   ser,
    output wire [N_REG-1:0]   srclk,
    output wire [N_REG-1:0]   rclk,
    output wire               busy,
    output wire               synced,
    output reg                start
);

    reg                 trig_d;
    reg                 pending;
    reg [8*N_REG-1:0]   data_q;
    wire [N_REG-1:0]    fsm_busy;
    reg                 in_period;
    reg  [7:0]          period_cnt;
    reg  [7:0]          period_q;

    wire trig_rise = trig_update & ~trig_d;
    wire fsm_idle  = ~|fsm_busy & ~in_period;
    wire changed   = auto_send & (data_in != data_q);   // data_q = 最後一次送出的內容

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            trig_d  <= 1'b0;
            pending <= 1'b0;
            start   <= 1'b0;
            data_q  <= {8*N_REG{1'b0}};
        end else begin
            trig_d <= trig_update;
            start  <= 1'b0;

            if ((pending || trig_rise || changed) && fsm_idle && !start) begin
                // 鎖存最新資料並啟動傳送
                data_q  <= data_in;
                start   <= 1'b1;
                pending <= 1'b0;
            end else if (trig_rise) begin
                // 傳送中收到新的更新要求, 傳完後再送一次
                pending <= 1'b1;
            end
        end
    end

    // 一輪更新時間: start 起算 update_period 拍 (啟動傳送時鎖存, 修改從下一輪生效)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            in_period  <= 1'b0;
            period_cnt <= 8'd0;
            period_q   <= 8'd0;
        end else if ((pending || trig_rise || changed) && fsm_idle && !start) begin
            period_q   <= update_period;         // 與 data_q 同一拍鎖存
        end else if (start) begin
            in_period  <= (period_q > 8'd2);
            period_cnt <= 8'd2;                  // start 當拍 = 第 1 拍, 下一拍 = 第 2 拍
        end else if (in_period) begin
            if (period_cnt >= period_q - 1'b1)
                in_period  <= 1'b0;
            period_cnt <= period_cnt + 1'b1;
        end
    end

    // trig_rise 也算進 busy, 讓上游在送出 trig 的下一拍就能看到 busy
    assign busy   = trig_rise | pending | start | ~fsm_idle;
    assign synced = ~busy & ~changed;

    genvar i;
    generate
        for (i = 0; i < N_REG; i = i + 1) begin : g_reg
            shift_register_FSM #(
                .WAIT_CYCLES (WAIT_CYCLES)
            ) u_shift_register_fsm (
                .clk     (clk),
                .rst_n   (rst_n),
                .start   (start),
                .data_in (data_q[8*i +: 8]),
                .ser     (ser[i]),
                .srclk   (srclk[i]),
                .rclk    (rclk[i]),
                .busy    (fsm_busy[i])
            );
        end
    endgenerate

endmodule
