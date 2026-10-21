# RFSoC_TX — Follow-up 清單

- 專案：PJ22045_1R8T_release_Rex_rev0.1_20261015 / RFSoC_TX（z2）
- 適用版本：RFSoC_TX build 01（2026-10-15）
- 文件版本：v0.1（2026-10-16）

## 1. 閱讀指引

本文件集中記錄 rev0.1 已知、但**本版不修改**的項目：觀察到的現象、原因、建議做法。分成兩類：

| 類別 | 說明 | 章節 |
|---|---|---|
| 後續版本優化 | 本版功能正常，下一版（或之後的版本）再優化 | 第 2 節（F1 ~ F5） |
| TRM 上線後處理 | 本版只針對 **IF 輸出端**做驗證，TRM 板尚未上線；這些是 TRM 上線後才需要的功能 | 第 3 節（T1 ~ T3） |

各項的完整說明見表中標示的文件與章節。所有項目都**尚未上板驗證**。

## 2. 後續版本優化

| # | 項目 | 建議時機 |
|---|---|---|
| F1 | Timing 餘裕幾乎為 0 | **下一版修正** |
| F2 | 無訊號 / 未設定時 pf = +511 且沒有 flag | 後續版本 |
| F3 | Power Fit 設定 8 通道共用 | 後續版本（依需求） |
| F4 | sys14 build_version 讀回 0 | 下一版（改 build 腳本即可） |
| F5 | FIR 係數尚未依本板量測 | 上板量測後 |

### F1. Timing 餘裕幾乎為 0（下一版修正）

**現象**：build 01 WNS 0.000 ns（All user specified timing constraints are met），但多條路徑餘裕極小：

| 路徑 | Clock | Slack | 說明 |
|---|---|---|---|
| `timer_1/timestamp_reg[39]` → `hier_rx_x0y1/system_ila_0_2` | FPGA_clk | 0.000 ns | 同事的 debug ILA，1 級邏輯、95% 繞線 |
| `hier_rx_x0y3/data_aligner_0/sys_time_reg` → ch5 `axis_iq_source_mux_0` → `cw_power_calc_IQ_0` 平方 DSP | FPGA_clk | +0.003 ns | 10 級邏輯，乘法器輸入端沒有暫存器 |
| `agc_emu/txagc_calc` s1_target → s2_analog_att_db | RFADC0~3（240 MHz） | +0.127 / +0.080 / +0.065 / +0.093 ns | source build 14 為 +0.39 ~ +0.57 ns，餘裕明顯變小 |

**影響**：之後任何改動（加 ILA、改擺放、加通道邏輯）都可能讓 timing 失敗。

**建議**：

1. `cw_power_calc_IQ` 輸入端加一級暫存器（約 160 FF / 通道，CW 結果晚 1 拍，對 Power Fit 無影響）。
2. `txagc_calc` stage 2 改查表或拆成兩級。
3. 同事 debug ILA 的 timestamp probe 前加一級暫存器，或移除不需要的 ILA（會動到同事設計，需先和同事討論）。

詳見 `Power_Fit.md` 12.1 第 1 項、`Gain_Control.md` §14 第 5 項、`RFSoC_TX_Top_Architecture.md` 第 8 節。

### F2. 無訊號 / 未設定時 pf = +511，沒有任何 flag

**現象**：以下情況 Power Fit 輸出 pf 會停在 +511（+31.94 dB，正向飽和）：

- 切到 Pulse mode 但沒有設 VIO：VIO probe_out 初值全為 0 → `pulse_avg_amp` = 0。
- Aurora 沒有送資料（link 未建立、data_aligner 未釋放）：`cw_valid` 一直為 0，CW 平均值停在舊值；reset 後為 0。
- reset 放開後、第一個 CW 區塊完成前（預設約 1 µs）。

RTL 把輸入振幅 0 當作 1（−84.29 dBFS）處理，所以 pf 飽和在 +511。以上情況都沒有 status flag，PS / reg_dump 無法分辨「真的訊號很小」還是「沒有量測」。

**影響**：下游 TXAGC 會看到 +31.94 dB 的修正量；IF 驗證時可能看到雜訊被放大到接近滿刻度。

**建議**（後續版本擇一或組合）：

1. 加 status sticky flag：pf 飽和、輸入 = 0、CW 無 valid timeout，並把 `snap_cw` 放進 status_snapshot。
2. reset / 無訊號時輸出 0 或保持前值，而不是 +511（需同步修改 TB D5）。
3. IF 驗證時先確認 Aurora link 與 data_aligner 已釋放，Pulse mode 前先設好 VIO。

詳見 `Power_Fit.md` 6.6、12.1 第 5 項、12.2 第 3 / 5 項、12.4 第 5 / 7 項。

### F3. Power Fit 設定 8 通道共用

**現象**：system_reg_map（`0xA009_8000`）的 sys0 ~ 3、sys15 同時接到 8 個通道，所以模式（CW / Pulse）、power_limit_margin、CW goal、Pulse 穩定拍數 M、CW 平均 k **8 通道都相同**。每個通道能各自設定的只有 mem26 `goal_ref_dbfs` 與 VIO 的 `pulse_avg_amp` / `pulse_papr`。

**影響**：無法讓部分通道用 CW、部分用 Pulse，也無法各自設定 margin / goal。目前的驗證情境不需要，功能正常。

**建議**：若之後需要各通道獨立操作，把這些設定搬到 channel reg map（mem），並同步修改 `regmap_def.py`、Excel、PS 程式（`register_map.c`、`reg_map_cfg.c`）與 `reg_rt.tcl`。

詳見 `Power_Fit.md` 2、12.1 第 4 項、12.4 第 10 項。

### F4. sys14 build_version 讀回 0

**現象**：build 01 的 sys14 `build_version` 讀回 0，reg_dump 檔案裡的 build 欄位無法分辨是哪一版 bitstream。

**原因**：`system_reg_map.v` 的 `BUILD_VERSION` 參數預設 0，要由 build 腳本設定。source 專案（Calibration_Gain_Control）的 `hardware/scripts/build_full_xsa.tcl` 第 7 行有設定；RFSoC_TX 使用的共用 build 腳本沒有這一行，所以 design_1.bd 裡的值一直是 0。

**建議**：下一版在 `RFSoC_TX/hardware/scripts/build_full_xsa.tcl` 開啟 BD 後加上（同 source）：

```
set_property CONFIG.BUILD_VERSION [scan $idx %d] [get_bd_cells /system_reg_map]
puts "BUILD_VERSION: [get_property CONFIG.BUILD_VERSION [get_bd_cells /system_reg_map]]"
```

詳見 `Register_Map.md`（sys14）。

### F5. FIR 係數尚未依本板量測

**現象**：

- RFSoC_TX 的 8 個通道 In-band FIR 目前都是 **impulse**（h[7] = 0x7FFF、其餘 0），等於只做 7 sample 純延遲，沒有頻響補償。
- `reg_runtime/fir_ch1.tcl` 是 source 板 ch1（2.8 GHz、tilt −2.7 dB）的係數，只能當格式範例，不適用於 RFSoC_TX。

**係數格式（已確認）**：RTL 輸出右移 15 bit（`SHIFT_BIT = 15`），係數為 **sfix16_15（S0.15）**，0x7FFF ≈ 1.0。

- `docs/02_RFSoC_TX/tools/regmap_def.py`、`Register_Map.md`、`Reg_map/Reg_map_tx_ch_v0.1.xlsx`（mem1~16 格式欄）原本寫 S1.14，已於 2026-10-16 修正為 S0.15（Excel 直接覆蓋 v0.1，只改這 16 格）。
- `reg_runtime/fir_ch1_example.tcl` 的中心 tap 範例值 16384 在 S0.15 下只有 0.5（−6 dB），換成實際係數時注意。
- source 專案的 `regmap_def.py` 也是 S1.14，尚未修改。

**建議**：上板後逐通道量測類比鏈路頻響，以 sfix16_15 產生 8 組係數，寫入時照「`in_band_fir_enable` = 0 → 寫 16 個 tap → `in_band_fir_enable` = 1」的順序。

詳見 `Calibration.md` 第 6 章、第 16 章。

## 3. TRM 上線後處理

本版只針對 IF 輸出端做驗證。以下功能的邏輯在 FPGA 內照常運作，但沒有實體效果，TRM 板上線後再處理。

| # | 項目 | 現象 | TRM 上線後要做的事 | 詳見 |
|---|---|---|---|---|
| T1 | Shift register 腳位未接出 | 8 通道 `Reg1~5_SER / SRCLK / RCLK` 沒有 net、頂層 port、XDC 腳位；類比換檔沒有實體效果，但數位仍補 R，輸出會隨 T 跨檔跳 4~5 dB | 確認 TRM 控制線腳位 / IO 標準（1.8 V），建 port、加 XDC、重新 build。IF 驗證時以 mem20 = 1、mem21 固定數位 gain 避開跳檔 | `Gain_Control.md` §1、§8.7、§14 第 1 / 2 / 18 項 |
| T2 | 開機在 RX mode | `reg_map_cfg.c` 開機 `agc_reg5` = 0x80（TXRX_SW = 1，RX mode） | 依 TRM 的 TX/RX 開關需求決定開機模式 | `Gain_Control.md` §4、§12、§14 第 3 項 |
| T3 | RX mode 的數位 gain 與 RXAGC flag clear | RX mode 下 RTL 仍套用 `pf − R`（與 source 設計筆記不一致）；RXAGC 會週期性清本板 ADC 的 over_range / over_voltage sticky flag | 確認 RX mode 數位 gain 的意圖；若其他邏輯或 PS 也使用這些 flag，需協調 clear 機制 | `Gain_Control.md` §6.5、§7.4、§14 第 4 / 9 項 |

## 4. 修訂歷程

| 版本 | 日期 | 說明 |
|---|---|---|
| v0.1 | 2026-10-16 | 第一版：F1 ~ F5、T1 ~ T3，對應 RFSoC_TX build 01 |
