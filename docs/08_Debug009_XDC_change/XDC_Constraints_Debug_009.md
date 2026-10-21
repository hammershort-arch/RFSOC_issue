# XDC 約束整理（Debug_009）

- 日期：2026-10-20
- 適用：RFSoC_TX、RFSoC_RX（兩邊 `constrs_1/new/overvoltage_sign.xdc` 內容相同）
- 參考來源：`reference/xczu47dr_new_adcdac_source/{native,remote}/vivado/48dr_lmk04828.srcs/constrs_1/new/overvoltage_sign.xdc`（native / remote 兩份 md5 相同）
- 路徑寫法：`scripts/` = `Debug_009_XDC_change/scripts/`；`reports/xdc_check/` = build 目錄 `Debug_009_XDC_change/RFSoC_TX/PL/reports/xdc_check/`、`.../RFSoC_RX/PL/reports/xdc_check/`（本文件在 `Debug_009_XDC_change_source/docs/08_Debug009_XDC_change/`）
- v1.0.0 原檔備份：`scripts/overvoltage_sign.xdc.v1.0.0_orig`

## 1. 專案用到的 XDC

| 檔案 | TX | RX | 內容 |
|---|---|---|---|
| `constrs_1/new/overvoltage_sign.xdc` | ✔ | ✔ | 腳位、FPGA_clk、PL_SYSREF、PMA_RST；**Debug_009 改這個** |
| `constrs_1/imports/new/design.xdc` | ✔ | ✔ | Aurora（同事設計）：sys_clk 100 MHz、GT refclk ×4、async clock group、hier_mts waitsysref false path。Debug_009 **沒動** |
| `constrs_1/new/cal_plus_gain_control.xdc` | ✔ | — | reg map → FIR 係數的 false path（Rex 整合時加）。Debug_009 **沒動** |

## 2. Debug_009 加入的約束（相對 v1.0.0）

| # | 約束 | reference 行號 | 實際效果 |
|---|---|---|---|
| 1 | `DIFF_TERM_ADV TERM_100` on `PL_SYSREF_clk_p/n[0]` | 28929–28930 | **生效**：io_placed 的 termination NONE → **100Ohm Differential**（FPGA 內部 100 Ω 差動終端） |
| 2 | `set_input_delay -clock FPGA_clk -min 3.90625 / -max 3.93625` on `PL_SYSREF_clk_p[0]` | 28953–28954 | **生效**：`check_timing` no_input_delay 1 → **0**；PL_SYSREF → `pl_sysref_r_reg` / `level_ref_reg` 從「unconstrained（slack inf）」變成有 setup / hold 分析 |
| 3 | 11 條 `set_max_delay -datapath_only 3.90625`（`*user_sysref_adc/dac*/C` → RFDC MTS FF、ILA） | 28940–28951 | **沒有作用**（Vivado：Non-existent path，見 §3） |

只改 port 名稱（reference 的 `PL_SYSREF_P/N` → 本專案 BD interface port `PL_SYSREF_clk_p/n[0]`），寫法與原檔一致不加大括號。

## 3. 為什麼 11 條 max_delay 沒有作用

```
pl_sysref_int_0/user_sysref_adc ─► regs_4_sysref_0（多一級 FF）─► usp_rf_data_converter_1/user_sysref_adc ─► RFDC 內部 MTS FF
```

- 約束是 `user_sysref_*/C` → RFDC 內部 FF 的 **直接** 路徑，但中間隔了 `regs_4_sysref_0` 的暫存器，所以路徑不存在。pin 都找得到（from 1 個、to 1～256 個），`report_exceptions -ignored` 標 **Non-existent path**。
- **reference 的 BD 也是同樣接法**（`regs_4_sysref_0` 在中間），所以這 11 條在 reference 裡同樣沒作用，推測是照 Xilinx MTS 範例（pl_sysref 直接接 RFDC）複製過來。
- 結果：無害，不影響 timing / 功能。TX 這條 `-to [get_cells ... *ila_core_inst*]` 抓到 11 萬個 cell，impl 多 1 個 CRITICAL WARNING `[Vivado 12-4439]`（物件數很大，可能影響效能）；RX ILA 較少，沒有觸發。之後若要清理，可以把這 11 條拿掉。
- 驗證資料：`reports/xdc_check/max_delay_targets.txt`、`ignored_exceptions.rpt`；腳本 `scripts/check_exc.tcl`。

## 4. 沒有搬的 reference 約束

| reference 行號 | 內容 | 原因 |
|---|---|---|
| 1–28901 | max_delay + 寫死的 ILA cell 清單（`design_1_wrapper_i/...hier_adcbram/...`） | Vivado 自動展開存檔，路徑在 reference 自己的 BD 都不存在 |
| 28916 | `LOC HPIOBDIFFINBUF_X0Y36` | 原檔已註解；PACKAGE_PIN 已決定位置 |
| 28936 | `create_generated_clock ... clk_wiz_1` | 兩邊 BD 都沒有 clk_wiz_1 |
| 28971–28981 | `PROHIBIT` BUFGCE_X0Y40～49、X0Y4 | **Rex 決定不加**（2026-10-20）：會把 Aurora sys_clk 的 BUFG（目前 BUFGCE_X0Y40）移走，Aurora 是同事設計，減少變因 |
| 28982–28985 | dbg_hub（`C_CLK_INPUT_FREQ_HZ`、`connect_debug_port dbg_hub/clk [get_nets clk]`） | 本專案沒有叫 `clk` 的 net；只影響 ILA |

## 5. PL_SYSREF input timing（routed，`reports/xdc_check/sysref_input_slack.txt`）

| 終點 | TX setup | TX hold | RX setup | RX hold |
|---|---|---|---|---|
| `pl_sysref_int_0/pl_sysref_r_reg/D`（SYSREF 取樣） | +0.973 ns | +1.264 ns | +0.901 ns | +1.339 ns |
| `sync_pulse_to_level_1/level_ref_reg/D` | +0.791 ns | +1.449 ns | +0.122 ns | +2.180 ns |

- input delay 數值（min 3.90625 / max 3.93625 ns，相對 FPGA_clk）照抄 reference，**沒有依板子實際走線 / LMK04828 輸出 skew 重新計算**；這些 slack 只代表「以 reference 的假設」可以收斂。
- 腳本：`scripts/sysref_in.tcl`。
