# Debug_009 — RFSoC_TX：XDC 補 PL_SYSREF 約束（PL Build Report）

> 本文件複製自 `RFSoC_TX/PL/Debug_009_PL_Build_Report.md`，文中的相對路徑（`../output_data/`、`scripts/`、`reports/` 等）以 `RFSoC_TX/PL/` 為準。

- 日期：2026-10-20
- 基準：`PJ22045_Release_Debug/Debug_008_TX_ch1_all_zero/RFSoC_TX`（v1.0.0_Debug7 + all_zero mux；PL / PS / Reg_map / reg_runtime 都沿用）
  - 「改動前」數據 = Debug_008 的 `reports/`（同一份 RTL / BD，只差 XDC）
- 工具：Vivado 2025.2，part xczu47dr-ffvg1517-2-i
- 輸出名稱：`RFSoC_TX_Debug_009`（`../output_data/`）
- 目的：補上 reference 有、v1.0.0 漏掉的 PL_SYSREF 約束，排除 SYSREF 接收 / MTS 的變因

## 1. 改動內容

只改 `RFSoC_TX.srcs/constrs_1/new/overvoltage_sign.xdc`；RTL、BD、IP、其他 XDC、PS 都沒動。細節見同資料夾 `XDC_Constraints_Debug_009.md`。

| 約束 | 結果 |
|---|---|
| `DIFF_TERM_ADV TERM_100`（PL_SYSREF p/n） | io_placed termination NONE → **100Ohm Differential** |
| `set_input_delay` min/max（PL_SYSREF p） | `check_timing` no_input_delay 1 → **0** |
| 11 條 `set_max_delay -datapath_only` | Non-existent path（無作用、無害） |
| BUFGCE `PROHIBIT` | **不加**（Rex 決定，Aurora sys_clk 保持在 BUFGCE_X0Y40） |

## 2. 流程 / Script

| 步驟 | Script / Log |
|---|---|
| synth → impl → bitstream → reports → XSA | `../../scripts/build_pl.sh RFSoC_TX` → `scripts/build_full_xsa.tcl RFSoC_TX_Debug_009`（log：`scripts/log/build.log`；variant 檢查為 0 或 8 個的通用版） |
| PS / BOOT.bin | `../PS/scripts/build_ps.sh RFSoC_TX_Debug_009 app_tx` |
| XDC 生效驗證 | `../../scripts/check_exc.tcl`、`../../scripts/sysref_in.tcl` → `reports/xdc_check/` |

## 3. Timing（impl_1，`reports/timing_summary.rpt`）

| | WNS | TNS | WHS | THS | WPWS | 失敗 endpoint |
|---|---|---|---|---|---|---|
| Debug_008 | +0.033 ns | 0 | +0.010 ns | 0 | +0.369 ns | 0 |
| **Debug_009** | **+0.006 ns** | 0 | **+0.010 ns** | 0 | +0.369 ns | 0 |

| Clock（intra） | WNS (ns) | WHS (ns) |
|---|---|---|
| FPGA_clk（256 MHz） | +0.006 | +0.010 |
| RFADC0_CLK（240 MHz） | +0.210 | +0.011 |
| RFDAC0_CLK | +1.931 | +0.086 |
| clk_pl_0（100 MHz） | +1.236 | +0.016 |
| sys_clk（Aurora 100 MHz） | +6.948 | +0.028 |

- 最差 setup path：`hier_rx_x0y2/data_aligner_0/sys_time_reg[12]` → `hier_rx_x0y2/axis_data_fifo_0` 的 xpm memory（Aurora RX 端，同事設計），與 SYSREF / XDC 無關；Debug_008 的最差 path 也在 `hier_rx_x0y2`。WNS 從 +0.033 變成 +0.006 是重新 place & route 的差異。
- route 過程 intermediate WNS 曾到 −0.342 ns，router 最後收斂到 +0.005 ns（post-route phys_opt 後 +0.006 ns）。
- PL_SYSREF input（新增有分析的路徑）：`pl_sysref_r_reg` setup +0.973 / hold +1.264 ns，`level_ref_reg` setup +0.791 / hold +1.449 ns。

## 4. Power（`reports/power.rpt` vs Debug_008）

| 項目 | Debug_008 | Debug_009 | 差異 |
|---|---|---|---|
| **Total On-Chip Power** | 29.957 W | **29.907 W** | −0.050 W |
| Dynamic | 28.105 W | 28.056 W | −0.049 W |
| Device Static | 1.852 W | 1.851 W | −0.001 W |
| Junction Temperature | 50.2 °C | 50.2 °C | 0 |
| Vccint 0.85 V | 11.157 A | 11.097 A | −0.060 A |

差異是 P&R 後 vectorless 估計的雜訊；100 Ω 終端的功耗在估計裡可忽略。

## 5. Utilization（`reports/utilization.rpt`）

| 資源 | Debug_008 | Debug_009 | 差異 |
|---|---|---|---|
| CLB LUTs | 213,314（50.16%） | 213,589（50.22%） | +275 |
| CLB Registers | 343,739（40.41%） | 343,753（40.41%） | +14 |
| Block RAM Tile | 566.5 | 566.5 | 0 |
| DSPs | 2,904 | 2,904 | 0 |

邏輯沒改，差異在 opt / P&R 雜訊範圍內。`.ltx` sha256 與 Debug_008 相同（probe 沒變）。

## 6. Clock 擺放（`RFSoC_TX.runs/impl_1/*clock_utilization_routed.rpt`）

| Clock | Debug_008 | Debug_009 |
|---|---|---|
| FPGA_clk BUFG | BUFGCE_X0Y29 | BUFGCE_X0Y39（同 region X4Y1，placer 選的） |
| sys_clk（Aurora）BUFG | BUFGCE_X0Y40 | BUFGCE_X0Y40（沒加 PROHIBIT，位置不變） |

## 7. DRC / Critical Warning

- Critical Warning：synth_1 **0**、impl_1 **1** — `[Vivado 12-4439]` 第 11 條 max_delay 的 `-to` 抓到 111,543 個 ILA cell（物件數過大警告；該約束本身是 Non-existent path）。Debug_008 為 0。
- 開 BD 時 2 個 `[IP_Flow 19-4751] bram_clk FREQ_HZ missing`（與 Debug_008 相同，未出現在 synth / impl）。
- DRC（Warning only）：DPIP-2 ×120、DPOP-3 ×89、DPOP-4 ×263、PDCN-1569 ×3、REQP-1774 ×16、REQP-1680 ×1、RTSTAT-10 ×1（與 Debug_008 同類，多 1 個 REQP-1680）。

## 8. Build 時間

Vivado session 10:46:41 → 13:04:04，**約 2 小時 17 分**（`-jobs 4`，與 RFSoC_RX build 同時跑）。

| 階段 | 開始 | 結束 | 耗時 | 備註 |
|---|---|---|---|---|
| open_project + validate + generate_target（含 8 個 BDC variant） | 10:46:41 | 11:00:36 | 13.9 min | 全新 copy，沒有 .gen，全部重新產生 |
| OOC IP synth 第 1 輪（465 個 run） | 11:00:36 | 11:45:50 | 45.2 min | 14 個 run 失敗 |
| OOC 第 2 輪 + synth_1 + impl_1 + bitstream | 11:45:50 | 12:50 | 約 64 min | 重跑 14 個全部成功 |
| reports + write_hw_platform（XSA） | 12:50 | 13:04:04 | 約 14 min | |

impl_1 各步驟（elapsed）：link_design 9.2 min、opt_design 4.4 min、place_design 21.0 min、phys_opt_design 0.9 min、route_design 17.4 min、write_bitstream 0.8 min。

OOC 第 1 輪失敗的 14 個 run（重跑即過，分布隨機，與 Debug_008 現象相同，推測為平行啟動共用 `~/.Xilinx` 的問題，未證實）：`design_1_data_delay_0_4`、`design_1_axi_gpio_0_2`、`design_1_system_reg_map_0`、`design_1_axi_stream_combininp_0_0`、`inst_13_cal_cdc_0_0`、`inst_11_addressable_reg_map_0`、`inst_11_sr_att_group_0`、`inst_11_cordic_0_0`、`inst_9_agc_att_mux_0_0`、`inst_9_axis_demux_1to5_0_0`、`inst_8_sr_att_pins_0_0`、`inst_8_status_snapshot_0_0`、`aurora_..._header_insertion_v2_0_4`、`aurora_..._ila_x0y3_0`。

## 9. 輸出（`../output_data/`）

| 檔案 | 說明 |
|---|---|
| `RFSoC_TX_Debug_009.bit` / `.ltx` / `.xsa` | bitstream / ILA + VIO probes / XSA（fixed，include bit） |
| `BOOT.bin` | fsbl.elf + bit + app_tx.elf（no PMUFW，同 v1.0.0 格式）；彙整版改名 `BOOT_TX_DEBUG_009.bin` |
| `app_tx.elf` / `fsbl.elf` / `boot.bif` / `MANIFEST.txt` | PS（同 Debug_008 原始碼）/ FSBL / bootgen 輸入 / sha256 |
