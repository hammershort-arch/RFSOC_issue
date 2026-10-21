`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: gain_apply_sync
// Description: 數位端 gain index 與類比衰減器同步套用 (adc_clk)
//   - sr_start (sr_att_group 一輪開始, 前一拍鎖存 data_in) 當拍抓下與該類比檔位成對的 gain_req (延遲一拍),
//     於 start 後第 apply_delay 拍 (AGC_DIGITAL_APPLY_DELAY = N) 套用
//     N = 35 時與 RCLK 同一拍 (WAIT_CYCLES = 2); 數位路徑 (CDC + Gain_Compensation + RFDC) 較慢時調小 N,
//     衰減器較慢時調大 N (N 應小於 SR_UPDATE_PERIOD)
//   - 其餘時間: sr 未在一輪更新中且 sr_synced (硬體內容 = 目前要求的類比檔位) 才採用最新 gain_req
//   => 類比換檔時, 數位值在 start + N 拍更新; 類比不變 (只有 pf / R 改變) 時立即更新
//   bypass (auto_send = 0) 時 synced = ~busy, 數位端跟隨 gain_req
//////////////////////////////////////////////////////////////////////////////////
module gain_apply_sync (
    input  wire               clk,
    input  wire               rst_n,
    input  wire signed [11:0] gain_req,       // txagc gain_index_digital
    input  wire               sr_start,       // sr_att_group/start
    input  wire               sr_busy,        // sr_att_group/busy
    input  wire               sr_synced,      // sr_att_group/synced
    input  wire        [7:0]  apply_delay,    // N: start 後第 N 拍套用
    output reg  signed [11:0] gain_applied
);

    reg signed [11:0] gain_req_d;             // 與 sr_group_ctrl 鎖存 data_q 同一拍的 gain_req
    reg signed [11:0] gain_snap;
    reg               pend;
    reg        [7:0]  cnt;

    always @(posedge clk) begin
        if (!rst_n) begin
            gain_req_d   <= 12'sd0;
            gain_snap    <= 12'sd0;
            pend         <= 1'b0;
            cnt          <= 8'd0;
            gain_applied <= 12'sd0;
        end else begin
            gain_req_d <= gain_req;
            if (sr_start) begin
                if (apply_delay == 8'd0) begin
                    gain_applied <= gain_req_d;
                    pend         <= 1'b0;
                end else begin
                    gain_snap <= gain_req_d;
                    cnt       <= apply_delay - 1'b1;
                    pend      <= 1'b1;
                end
            end else if (pend) begin
                if (cnt == 8'd0) begin
                    gain_applied <= gain_snap;
                    pend         <= 1'b0;
                end else begin
                    cnt <= cnt - 1'b1;
                end
            end else if (!sr_busy && sr_synced) begin
                gain_applied <= gain_req;
            end
        end
    end

endmodule
