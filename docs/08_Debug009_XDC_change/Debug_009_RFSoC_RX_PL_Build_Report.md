# Debug_009 — RFSoC_RX：XDC 補 PL_SYSREF 約束（PL Build Report）

> 本文件複製自 `RFSoC_RX/PL/Debug_009_PL_Build_Report.md`，文中的相對路徑（`../output_data/`、`scripts/`、`reports/` 等）以 `RFSoC_RX/PL/` 為準。

- 日期：2026-10-20
- 基準：`PJ22045_Release/v1.0.0_Debug7/source_code_v1.0.0_Debug7/RFSoC_RX`（PL：xpr / srcs / ip_repo；PS：`PS_Integrated/app_rx/src` → `PS/app_src`；docs）
  - 「改動前」數據 = Debug_001 保存的 v1.0.0 RX baseline（`Debug_001_.../RFSoC_RX/PL/reports/baseline_v1.0.0/`）
- 工具：Vivado 2025.2，part xczu47dr-ffvg1517-2-i
- 輸出名稱：`RFSoC_RX_Debug_009`（`../output_data/`）

## 1. 改動內容

RX 的 `overvoltage_sign.xdc` 原檔與 TX **byte-identical**，SYSREF 架構也相同（`PL_SYSREF` → `util_ds_buf_3` → `pl_sysref_int_0` → `regs_4_sysref_0` / `hier_mts` → RFDC 2.6），所以套用與 TX 完全相同的改動（兩邊改後的檔案 `cmp` 相同）。細節見同資料夾 `XDC_Constraints_Debug_009.md`。

| 約束 | 結果 |
|---|---|
| `DIFF_TERM_ADV TERM_100`（PL_SYSREF p/n） | io_placed termination → **100Ohm Differential** |
| `set_input_delay` min/max（PL_SYSREF p） | `check_timing` no_input_delay 1（v1.0.0）→ **0** |
| 11 條 `set_max_delay -datapath_only` | Non-existent path（無作用、無害） |
| BUFGCE `PROHIBIT` | 不加 |

## 2. 流程 / Script

| 步驟 | Script / Log |
|---|---|
| synth → impl → bitstream → reports → XSA | `../../scripts/build_pl.sh RFSoC_RX` → `scripts/build_full_xsa.tcl RFSoC_RX_Debug_009`（複製自 Debug_001，log：`scripts/log/build.log`） |
| PS / BOOT.bin | `../PS/scripts/build_ps.sh RFSoC_RX_Debug_009 app_rx`（複製自 Debug_001，stdin/stdout = psu_uart_1） |
| XDC 生效驗證 | `../../scripts/check_exc.tcl`、`../../scripts/sysref_in.tcl` → `reports/xdc_check/` |

- build 後 PL 下會多一個 `RFSoC_TX.gen/`（18 MB，只有 `onebit_cdc_fifo` IP）：該 IP 的 xci 沿用 TX 專案的 gen 路徑名稱，v1.0.0 / Debug_001 RX 也一樣，不影響結果。

## 3. Timing（impl_1，`reports/timing_summary.rpt`）

| | WNS | TNS | WHS | THS | WPWS | 失敗 endpoint |
|---|---|---|---|---|---|---|
| v1.0.0 | +0.063 ns | 0 | +0.010 ns | 0 | +0.369 ns | 0 |
| **Debug_009** | **+0.052 ns** | 0 | **+0.010 ns** | 0 | +0.369 ns | 0 |

| Clock（intra） | v1.0.0 WNS / WHS | Debug_009 WNS / WHS |
|---|---|---|
| FPGA_clk（256 MHz） | +0.161 / +0.013 | +0.122 / +0.022 |
| RFADC0_CLK | +31.757 / +0.093 | +31.751 / +0.093 |
| RFDAC0_CLK | +2.125 / +0.078 | +1.755 / +0.083 |
| clk_pl_0（100 MHz） | +1.610 / +0.012 | +2.928 / +0.013 |
| sys_clk（Aurora 100 MHz） | +7.465 / +0.017 | +7.409 / +0.019 |

- 最差 setup path（+0.052 ns）：Aurora `ila_x0y4_0` 內部（`txoutclk_out[0]_6`，同事設計），與 XDC 改動無關。
- FPGA_clk 的最差 path 現在是新加 input delay 後才有分析的 **PL_SYSREF → `sync_pulse_to_level_1/level_ref_reg`**（setup +0.122 ns）；`pl_sysref_int_0/pl_sysref_r_reg` setup +0.901 / hold +1.339 ns。

## 4. Power（`reports/power.rpt` vs v1.0.0）

| 項目 | v1.0.0 | Debug_009 | 差異 |
|---|---|---|---|
| **Total On-Chip Power** | 24.626 W | **24.661 W** | +0.035 W |
| Dynamic | 22.903 W | 22.938 W | +0.035 W |
| Device Static | 1.722 W | 1.723 W | +0.001 W |
| Junction Temperature | 45.7 °C | 45.8 °C | +0.1 °C |
| Vccint 0.85 V | 4.999 A | 5.039 A | +0.040 A |

## 5. Utilization（`reports/utilization.rpt`）

| 資源 | v1.0.0 | Debug_009 | 差異 |
|---|---|---|---|
| CLB LUTs | 62,320（14.65%） | 62,250（14.64%） | −70 |
| CLB Registers | 85,553（10.06%） | 85,553（10.06%） | 0 |
| Block RAM Tile | 224.5 | 224.5 | 0 |
| DSPs | 0 | 0 | 0 |

## 6. DRC / Critical Warning

- Critical Warning：synth_1 / impl_1 都是 **0**（ILA cell 約 3.2 萬個，沒有觸發 TX 那個 12-4439）。
- DRC（Warning only）：PDCN-1569 ×3、RTSTAT-10 ×1。

## 7. Build 時間

Vivado session 10:46:41 → 11:24:44，**約 38 分鐘**（`-jobs 4`，與 RFSoC_TX 同時跑）。

| 階段 | 開始 | 結束 | 耗時 | 備註 |
|---|---|---|---|---|
| open_project + validate + generate_target | 10:46:41 | 10:53:25 | 6.7 min | |
| OOC IP synth 第 1 輪（128 個 run） | 10:53:25 | 11:05:06 | 11.7 min | 7 個 run 失敗 |
| OOC 第 2 輪 + synth_1 + impl_1 + bitstream | 11:05:06 | 11:21 | 約 16 min | 重跑 7 個全部成功 |
| reports + XSA | 11:21 | 11:24:44 | 約 4 min | |

impl_1 各步驟（elapsed）：link_design 1.6 min、opt_design 1.3 min、place_design 5.6 min、phys_opt_design 0.2 min、route_design 2.9 min、write_bitstream 0.5 min。

OOC 第 1 輪失敗 7 個（重跑即過）：`design_1_regs_4_sysref_0_0`、`design_1_timer_0_1`、`aurora_..._out_fifo_0`、`aurora_..._ini_system_0_0`、`aurora_..._x0y3_core_status_1_0`、`aurora_..._aurora_x0y3_1_0`、`aurora_..._axis_rst_sync_c0_2`。

## 8. 輸出（`../output_data/`）

| 檔案 | 說明 |
|---|---|
| `RFSoC_RX_Debug_009.bit` / `.ltx` / `.xsa` | bitstream / ILA probes / XSA |
| `BOOT.bin` | fsbl.elf + bit + app_rx.elf（no PMUFW）；彙整版改名 `BOOT_RX_DEBUG_009.bin` |
| `app_rx.elf` / `fsbl.elf` / `boot.bif` / `MANIFEST.txt` | PS（v1.0.0_Debug7 原始碼，未改）/ FSBL / bootgen 輸入 / sha256 |
