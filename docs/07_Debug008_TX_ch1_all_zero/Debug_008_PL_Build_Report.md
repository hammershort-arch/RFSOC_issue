# Debug_008 — RFSoC_TX：Signal Source Mux 加 all_zero（PL Build Report）

> 本文件複製自 `PJ22045_Release_Debug/Debug_008_TX_ch1_all_zero/RFSoC_TX/PL/Debug_008_PL_Build_Report.md`（Debug_009 的 RFSoC_TX 以 Debug_008 為基準），文中相對路徑以原位置為準。

- 日期：2026-10-19
- 基準：`PJ22045_Release/v1.0.0_Debug7/source_code_v1.0.0_Debug7/RFSoC_TX/PL`（與 v1.0.0 RFSoC_TX byte-identical，`diff -rq` 確認；原始檔未動，本資料夾為副本）
  - 「改動前」數據沿用 Debug_002 的 `reports/baseline_v1.0.0/`（v1.0.0 = rev0.1 build 01 routed dcp）
- 工具：Vivado 2025.2，part xczu47dr-ffvg1517-2-i
- 輸出名稱：`RFSoC_TX_Debug_008`（`../output_data/`）
- 目的：ch1 送全 0 的 160-bit AXIS 到 DAC s00，觀察 DAC 本身在 SA 上的頻譜

## 1. 改動內容

`cal_plus_gain_control.bd` 是 8 通道共用的 BDC，所以 **8 個通道的硬體都有 all_zero 選項**；哪個通道用它由 PS 預設值決定（Debug_008 只有 ch1）。

| 檔案 | 改動 |
|---|---|
| `new/cal_plus_gain_control/axis_iq_source_mux.v` | `sel` 1 → 2 bit；sel = 2/3 → `m_axis_iq_tdata = 160'd0`、`tvalid = 1`（仍是 5 sample × {Q[15:0], I[15:0]} 的 160-bit AXIS）；sel = 0/1 行為不變；沒被選到的輸入 tready 恆為 1 |
| `new/cal_plus_gain_control/cal_cdc.v` | `signal_source_select` 1 → 2 bit（`mem39[1:0]`），CFG_W 71 → 72 |
| `new/cal_plus_gain_control/addressable_reg_map.v` | 只改 mem39 註解（暫存器本來就存 32 bit，邏輯不變） |
| `bd/cal_plus_gain_control/cal_plus_gain_control.bd` | `update_module_reference`（source_mux / cal_cdc），`signal_source_select` net 變 2 bit |
| `bd/design_1/design_1.bd` | 8 個 BDC cell `upgrade_bd_cells`：design_checksum 更新，另有 Vivado 自動同步的 BDC 邊界 metadata（S_AXI ADDR_WIDTH 15/16 → 32、ASSOCIATED_BUSIF 順序、移除舊 aclken、TDATA left/right 標註）。**連線、位址表、其他 IP 參數完全不變**（JSON 逐項比對） |

mem39 編碼：0 = in_0（Aurora）、1 = in_1（ADC loopback）、**2 = all_zero**、3 = all_zero（保留）。

驗證：
- xsim（`axis_iq_source_mux` 單元測試，sel 0～3 × tready 0/1）：ERRORS = 0，sel = 2/3 輸出 160 bit 全 0、tvalid = 1
- routed netlist：ch1 / ch2 / ch8 的 `cal_cdc_0/signal_source_select_reg[1:0]` 都是 2 個 FF；DAC `s00_axis_tdata` 160 個 pin

## 2. 流程 / Script

| 步驟 | Script / Log |
|---|---|
| 修改 BD | `scripts/debug008_all_zero.tcl`（log：`scripts/log/modify.log`） |
| synth → impl → bitstream → reports → XSA | `scripts/build_full_xsa.tcl RFSoC_TX_Debug_008`（log：`scripts/log/build.log`；variant 檢查改為預期 8 個） |
| Reports | `reports/`；改動前：`reports/baseline_v1.0.0/` |

## 3. Power（`reports/power.rpt` vs v1.0.0）

Vivado vectorless 估計（Confidence Medium）。

| 項目 | v1.0.0 | Debug_008 | 差異 |
|---|---|---|---|
| **Total On-Chip Power** | 29.669 W | **29.957 W** | +0.288 W（+1.0%） |
| Dynamic | 27.824 W | 28.105 W | +0.281 W |
| Device Static | 1.845 W | 1.852 W | +0.007 W |
| Junction Temperature | 50.0 °C | 50.2 °C | +0.2 °C |
| Clocks / CLB Logic / Signals | 3.107 / 0.639 / 1.003 | 3.097 / 0.696 / 1.150 | −0.010 / +0.057 / +0.147 |
| DSPs / Block RAM | 1.093 / 1.429 | 1.180 / 1.430 | +0.087 / +0.001 |
| GTY / RFAMS / PS8 | 9.250 / 9.054 / 2.197 | 同左 | 0 |
| **Vccint 0.85 V** | 10.820 A | **11.157 A** | +0.337 A |

- 邏輯只多 8 組 2-bit mux / FF，差異主要是重新 place & route 後 vectorless 估計的 Signals / Logic toggle 不同（資源用量幾乎不變，見 §5），不是 all_zero 本身造成。
- 估計假設預設 toggle rate；上板時 ch1 送全 0、且不經 FIR / calibration，實際 ch1 DAC 路徑的動態功耗會比估計低。

## 4. Timing（impl_1，`reports/timing_summary.rpt`）

| | WNS | TNS | WHS | THS | WPWS | 失敗 endpoint |
|---|---|---|---|---|---|---|
| v1.0.0 | 0.000 ns | 0 | +0.010 ns | 0 | +0.369 ns | 0 |
| **Debug_008** | **+0.033 ns** | 0 | **+0.010 ns** | 0 | +0.369 ns | 0 |

| Clock（intra） | WNS (ns) | WHS (ns) |
|---|---|---|
| FPGA_clk（256 MHz） | +0.033 | +0.010 |
| RFADC0_CLK（240 MHz） | +0.219 | +0.015 |
| clk_pl_0（100 MHz） | +1.294 | +0.021 |

- 最差 setup path：`timer_1/timestamp_reg[0]` → `hier_rx_x0y2` 內 system_ila（同事設計），與 Debug_002 同類路徑，和 mux 無關。
- route 過程中 intermediate WNS 曾到 −0.188 ns，router 最後收斂到 +0.033 ns。

## 5. Utilization（`reports/utilization.rpt`）

| 資源 | v1.0.0 | Debug_008 | 差異 |
|---|---|---|---|
| CLB LUTs | 213,477（50.20%） | 213,314（50.16%） | −163 |
| CLB Registers | 343,806（40.42%） | 343,739（40.41%） | −67 |
| Block RAM Tile | 566.5 | 566.5 | 0 |
| DSPs | 2,904 | 2,904 | 0 |

差異在 P&R / opt 的雜訊範圍內（all_zero 只是在既有 mux 前多一層 AND）。

## 6. DRC / Critical Warning

- Critical Warning：synth_1 / impl_1 runme.log 都是 **0**。
- 修改 BD 時有 2 個 `[IP_Flow 19-4751] bram_clk FREQ_HZ missing`（module_ref 重新封裝，與 Debug_002 相同，未出現在 synth / impl）。
- DRC（Warning only）：DPIP-2 ×120、DPOP-3 ×88、DPOP-4 ×264、PDCN-1569 ×3、REQP-1774 ×16、RTSTAT-10 ×1（8 通道版，數量與 v1.0.0 同類）。

## 7. Build 時間

Vivado session 15:24:04 → 17:47:06，**總共約 2 小時 23 分**（`-jobs 4`）。

| 階段 | 開始 | 結束 | 耗時 | 備註 |
|---|---|---|---|---|
| open_project + validate + generate_target | 15:24:04 | 15:28:03 | 4.0 min | |
| OOC IP synth 第 1 輪（465 個 run） | 15:28:03 | 16:09:40 | 41.6 min | BDC 改了，8 個 variant 全部重新 synth；9 個 run 失敗 |
| OOC 第 2 輪（重跑 9 個） | 16:09:40 | 16:10:57 | 1.3 min | script 自動 reset 重跑，全部成功 |
| synth_1（top） | 16:10:57 | 16:12:13 | 1.3 min | synth_design elapsed 41 s |
| impl_1（含 write_bitstream） | 16:12:13 | 17:29 | 約 77 min | |
| reports + write_hw_platform（XSA） | 17:29 | 17:47:06 | 約 18 min | |

impl_1 各步驟（elapsed）：link_design 8.0 min、opt_design 4.1 min、place_design 22.9 min、phys_opt_design 5.5 min、route_design 28.3 min、write_bitstream 0.9 min。

OOC 失敗的 9 個 run：`design_1_axis_data_fifo_1_0`、`design_1_util_ds_buf_0_0`、`cal_plus_gain_control_inst_14_system_ila_ch0_0`、`aurora_..._cdc_fifo_0`、`inst_9_axis_iq_split_0_0`、`inst_14_status_snapshot_0_0`、`inst_12_agc_reg_pack_0_0`、`inst_12_TOP_complex_FIR_modu_1_0`、`inst_13_agc_att_mux_0_0`。失敗 log 在 reset 時被清掉，無法確認原因；分布隨機、重跑即過，與之前共用 `~/.Xilinx` 的平行啟動問題現象一致（推測，未證實）。

## 8. 輸出（`../output_data/`）

| 檔案 | 說明 |
|---|---|
| `RFSoC_TX_Debug_008.bit` / `.ltx` / `.xsa` | bitstream / ILA + VIO probes / XSA（fixed，include bit） |
