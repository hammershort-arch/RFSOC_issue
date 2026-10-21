# PJ22045_1R8T rev0.12_dev：8 通道 Calibration + Gain Control 整合紀錄

- 日期：2026-10-14 ~ 2026-10-15
- Target：`PJ22045_1R8T_release_rev0.12_20261014_dev/hardware/project_1.xpr`（Vivado 2025.2，xczu47dr-ffvg1517-2-i）
- Source：`Rex_Dev_Temporally/Calibration_Gain_Control`
- **目前版本：build 03** → `output_data/03/`：`pj22045_1r8t_cal8ch_03.bit` / `.ltx` / `.xsa`、`BOOT.bin`、`MANIFEST.txt`
- 報告：`hardware/scripts/log/`（`timing_impl.rpt`、`util.rpt`、`util_hier.rpt`、`cdc.rpt`、`clock_interaction.rpt`，目前為 build 03 的內容）

---

## 0. 版本歷程

| Build | 日期 | 內容 | 狀態 |
|---|---|---|---|
| 01 | 2026-10-14 | 8 通道整合，包成 `hier_8CH` | ❌ **不能使用**：Aurora 資料沒有接進各通道（見 3.4）；`output_data/01/INVALID_README.txt` |
| 02 | 2026-10-15 | 拆掉 `hier_8CH`，Aurora 直接接各通道；Vitis / BOOT.bin 第一版 | 可用，已被 build 03 取代 |
| **03** | 2026-10-15 | **RFDC NCO：ADC 0.84 → 1.04 GHz、DAC −0.84 → −1.04 GHz**（8 通道，輸出頻率 2.5~3.5 GHz → 2.3~3.3 GHz）；重新產生 BOOT.bin | ✅ **目前版本** |

| Build | WNS (ns) | WHS (ns) | 最差路徑 | LUT / FF / BRAM / DSP |
|---|---|---|---|---|
| 01 | +0.002 | +0.007 | Aurora `hier_rx_x0y3` 內的 system_ila（txoutclk） | 50.1% / 40.4% / 52.5% / 68.0% |
| 02 | +0.007 | +0.010 | FPGA_clk：Aurora `data_aligner` → ch4 Power Fit | 50.2% / 40.4% / 52.5% / 68.0% |
| 03 | **0.000** | +0.010 | FPGA_clk：`timer_1/timestamp` → `hier_rx_x0y1` 的 debug ILA（同事原有設計） | 50.2% / 40.4% / 52.5% / 68.0% |

---

## 1. Build 結果（build 03）

### 1.1 Timing

整體 **WNS 0.000 ns / WHS +0.010 ns**，「All user specified timing constraints are met」，0 個失敗的 endpoint；synth / impl 都沒有 CRITICAL WARNING。

| Clock | 用途 | build 02 WNS / WHS (ns) | **build 03 WNS / WHS (ns)** |
|---|---|---|---|
| FPGA_clk（256 MHz） | 資料路徑（8 通道、Aurora RX、RFDC AXIS） | +0.007 / +0.011 | **0.000 / +0.010** |
| RFADC0_CLK（240 MHz） | ch1 / ch2 AGC | +0.165 / +0.016 | +0.127 / +0.013 |
| RFADC1_CLK（240 MHz） | ch3 / ch4 AGC | +0.155 / +0.014 | +0.080 / +0.011 |
| RFADC2_CLK（240 MHz） | ch5 / ch6 AGC | +0.130 / +0.013 | +0.065 / +0.010 |
| RFADC3_CLK（240 MHz） | ch7 / ch8 AGC | +0.171 / +0.023 | +0.093 / +0.013 |
| clk_pl_0（100 MHz） | AXI-Lite（reg map） | +1.887 / +0.016 | +1.703 / +0.010 |

- build 03 最差路徑（FPGA_clk，0.000 ns）：`timer_1/timestamp_reg[39]` → `hier_rx_x0y1/system_ila_0_2`（debug ILA），1 級邏輯，延遲 95% 是繞線。這條路徑在同事原有設計裡，不在新增邏輯中；只改 NCO，placement 變動後就落在這條線上（見 3.7）。
- 整體餘裕幾乎為 0，之後再加邏輯或改設定，都可能出現 timing 問題。

### 1.2 Utilization

| 資源 | 用量 | 比例 | rev0.11 z2（47dr2）原本 |
|---|---|---|---|
| LUT | 213,477 | 50.2% | 21.3% |
| FF | 343,806 | 40.4% | 16.1% |
| BRAM tile | 566.5 | 52.5% | 46.9% |
| DSP | 2,904 | 68.0% | — |

| 區塊 | LUT | FF | BRAM36 / 18 | DSP |
|---|---|---|---|---|
| 8 個 cal_plus_gain_control 合計 | 119,899 | 201,808 | 56 / 8 | 2,904 |
| 每個 cal_plus_gain_control_chN | 約 14,950 ~ 15,050 | 約 25,230 | 7 / 1 | 363 |
| 每個 rfdc_iq_combine_chN | 40 | 161 | 0 | 0 |
| system_reg_map | 320 | 590 | 0 | 0 |
| vio_ext_inputs | 228 | 875 | 0 | 0 |
| smartconnect_0（23 MI） | 2,550 | 3,392 | 0 | 0 |
| aurora_gty_47drto13p_0（原有） | 48,335 | 71,299 | 201 / 25 | 0 |

---

## 2. 修改內容（Source → Target）

### 2.1 Source 專案（Calibration_Gain_Control）新增的功能

| 項目 | 內容 |
|---|---|
| Signal Source Mux | 新增 `axis_iq_source_mux.v`：純組合邏輯 mux（latency 0），放在 `axis_iq_bypass_0` 前面；沒被選到的那一路 tready 固定為 1，資料直接丟掉 |
| BD 輸入 | `cal_plus_gain_control.bd` 的輸入改成兩路：`s_axis_iq_in_0`、`s_axis_iq_in_1`（160-bit，256 MHz） |
| Reg map | channel 新增 **mem39 `signal_source_select`**（0x09C，0 = in_0，1 = in_1，reset 0），經 `cal_cdc_0` 同步；reserved 改成 mem40~63 |
| 文件 / 腳本 | `regmap_def.py` 與產生的 `addressable_reg_map.v`、Excel `Reg_map_tx_ch_v0.2.xlsx`、`reg_rt.tcl` / `reg_template.tcl` / `README.md` |
| 驗證 | 新增 `tb_axis_iq_source_mux`，回歸 11 個 TB 全部 PASS |

### 2.2 Target 專案新增的檔案

| 檔案 | 說明 |
|---|---|
| `hardware/project_1.srcs/sources_1/new/cal_plus_gain_control/`（40 個 RTL） | container 用到的 module_ref（含 `agc_emu/`、`squareroot/`），由 source 複製 |
| `hardware/project_1.srcs/sources_1/bd/cal_plus_gain_control/` | 由 source `write_bd_tcl` 匯出後重建；cell、net、port、參數和 source 完全相同 |
| `hardware/project_1.srcs/constrs_1/new/cal_plus_gain_control.xdc` | reg map `cfg_r*` → 資料時脈的 false path（以 `cal_cdc_0` 目的端時脈指定，不依賴 clock 名稱） |
| `hardware/project_1.srcs/sources_1/ip/onebit_cdc_fifo/` | 補回原有設計缺少的 IP（見 3.2） |
| `software/`（`platform/` + `app_component/`） | Vitis workspace（見第 4 節） |
| `docs/Reg_map/Reg_map_tx_ch_v0.1.xlsx`、`Reg_map_emu_sys_v0.1.xlsx` | target 的 Register map：暫存器定義同 source tx_ch v0.2 / emu_sys v0.1，base address 改成 target 的；含 `Channel_Map` 工作表；由 `docs/tools/` 產生 |
| `reg_runtime/` | XSDB runtime 腳本：支援 ch1~ch8，位址改成 target 的，移除 RX ch7 |
| `hardware/scripts/`、`software/*.py` | 整合、build 與 Vitis 腳本（見第 6 節） |

### 2.3 design_1.bd 的修改

| 項目 | 內容 |
|---|---|
| `cal_plus_gain_control_ch1~8` | 8 個 BD container，**直接放在 design_1 頂層**（不包 hierarchy，原因見 3.4） |
| `rfdc_iq_combine_ch1~8` | ADC I / Q（mXY0 / mXY1）合併成 160-bit 送 in_1，放在 design_1 頂層 |
| `system_reg_map` | 新增（BUILD_VERSION = 0）；sys0~13、15、16 接到 8 個 channel 的 `reg_*` |
| `vio_ext_inputs` | 新增，32 個 probe_out（每通道 4 個：`rx_att_index[2:0]`、`algo_analog_att_db[8:0]`、`pulse_avg_amp[15:0]`、`pulse_papr[8:0]`），clk = FPGA_clk |
| `smartconnect_0` | NUM_MI 6 → 23（M06~M21 = ch1~8 Register / BRAM，M22 = system_reg_map） |
| RFDC flag | `adcT_01/23` 的 `over_range` / `over_voltage` / `over_threshold1` / `over_threshold2` 接到對應 channel；`clear_or` / `clear_ov` 也接上（接法同 source） |
| RFDC ADC0~3 Outclk | 30 MHz → **240 MHz**（`clk_adc0~3` = AGC 的 adc_clk，對齊 source） |
| **RFDC NCO（build 03）** | **ADC `ADC_NCO_Freq00/02/10/12/20/22/30/32`：0.84 → 1.04 GHz；DAC `DAC_NCO_Freq00/02/10/12/20/22/30/32`：−0.84 → −1.04 GHz**（Rex 修改；輸出頻率範圍 2.5~3.5 GHz → 2.3~3.3 GHz；和 source 一致；RFDC 其他參數沒有變動） |
| 舊的 BDC variant | 刪除沒在用的 `cal_plus_gain_control_inst_0~7`（fileset 與 gen 目錄），保留使用中的 `inst_8~15` |
| 同事的設計 | `hier_rx_*`、`hier_mts`、Aurora 等**都沒有修改** |

### 2.4 各通道接線

| Ch | in_0（Aurora） | in_1（ADC → combiner） | 輸出 DAC | adc_clk | RFDC flag | Reg map | Gain BRAM | VIO probe |
|---|---|---|---|---|---|---|---|---|
| 1 | hier_rx_x0y2 / M_AXIS_C0 | m00 / m01 | s00 | clk_adc0 | adc0_01 | 0xA009_0000 | 0xA009_A000 | 0~3 |
| 2 | hier_rx_x0y2 / M_AXIS_C1 | m02 / m03 | s02 | clk_adc0 | adc0_23 | 0xA009_1000 | 0xA009_C000 | 4~7 |
| 3 | hier_rx_x0y1 / M_AXIS_C0 | m10 / m11 | s10 | clk_adc1 | adc1_01 | 0xA009_2000 | 0xA009_E000 | 8~11 |
| 4 | hier_rx_x0y1 / M_AXIS_C1 | m12 / m13 | s12 | clk_adc1 | adc1_23 | 0xA009_3000 | 0xA00A_0000 | 12~15 |
| 5 | hier_rx_x0y3 / M_AXIS_C0 | m20 / m21 | s20 | clk_adc2 | adc2_01 | 0xA009_4000 | 0xA00A_2000 | 16~19 |
| 6 | hier_rx_x0y3 / M_AXIS_C1 | m22 / m23 | s22 | clk_adc2 | adc2_23 | 0xA009_5000 | 0xA00A_4000 | 20~23 |
| 7 | hier_rx_x0y4 / M_AXIS_C0 | m30 / m31 | s30 | clk_adc3 | adc3_01 | 0xA009_6000 | 0xA00A_6000 | 24~27 |
| 8 | hier_rx_x0y4 / M_AXIS_C1 | m32 / m33 | s32 | clk_adc3 | adc3_23 | 0xA009_7000 | 0xA00A_8000 | 28~31 |

- system_reg_map：`0xA009_8000`。原有的位址（0xA000_0000 ~ 0xA008_xxxx）都沒動。
- 共用訊號：clk = FPGA_clk 256 MHz（`util_ds_buf_0/IBUF_OUT`）；rst_n = `dac_rst1/peripheral_aresetn`；S_AXI_ACLK = `pl_clk0`；S_AXI_resetn = `rst_ps8_0_96M/peripheral_aresetn`。
- 輸出到 DAC 的對應（s00 ~ s32）和原本 Aurora 直接送 DAC 時一樣。
- 原有的 `system_ila_0/SLOT_0_AXIS` 仍然監看 ch1 in_0（hier_rx_x0y2 / M_AXIS_C0）。
- 已確認產生的 HDL：8 個通道的 `s_axis_iq_in_0_tdata` 都是 `[159:0]`，由對應的 `hier_rx_x0yN/M_AXIS_Cx_tdata` 驅動。

---

## 3. 遇到的問題與額外修改（需和同事確認）

| # | Build | 問題 | 處理方式 | 有沒有改到設計 |
|---|---|---|---|---|
| 1 | 01 | Target 的 `clk_adc0~3` 是 30 MHz，source 是 240 MHz | RFDC ADC0~3 Outclk 改成 240 MHz（見 3.1） | **有**（RFDC 設定） |
| 2 | 01 | **rev0.11 release 少了 `onebit_cdc_fifo.xci`**，impl 在 DRC INBB-3（black box）失敗 | 從 Calibration_Gain_Control 補回（見 3.2） | 只是補回原有 IP |
| 3 | 01 | 8 個 BDC variant 裡有 6 種 module_ref 沒產生 synth wrapper，OOC 報 `Synth 8-439 module not found` | build 腳本對缺 wrapper 的 variant 執行 `reset_target` + `generate_target`（見 3.3） | 沒有（build 流程） |
| 4 | 01 → 02 | **包成 `hier_8CH` 後，Aurora 資料沒有接進各通道（build 01 無效）** | 拆掉 `hier_8CH`（見 3.4） | 只改我們新增的部分 |
| 5 | 01~03 | OOC run 隨機出現 Bus error / `Failed to create directory ~/.Xilinx/Vivado/tclapp` | 自動 reset 失敗的 run 後重跑（見 3.5） | 沒有 |
| 6 | 01 | 沒在用的 `cal_plus_gain_control_inst_0~7` | 刪除 fileset 與 gen 目錄 | 沒有 |
| 7 | 03 | **WNS 剛好 0.000 ns**，最差路徑在同事的 debug ILA | 目前收斂，沒有處理（見 3.6） | 沒有 |
| 8 | 02 | 開 GUI 時偶發 `BD 41-1726`（ch6 `axis_iq_split_0` 找不到 module） | 一次性訊息，batch 重開不會出現（見 3.7） | 沒有 |

### 3.1 RFDC ADC Outclk 30 → 240 MHz

- 改了什麼：`usp_rf_data_converter_1` 的 `ADC0~3_Outclk_Freq` 從 30.000 改成 240.000。
- 影響範圍：`clk_adc0~3`。用到的地方有 8 個 channel 的 AGC（adc_clk），以及原有的 `hier_mts/sync_out_latch_1`（clk_adc0；只是 latch，和頻率無關）。
- 請同事確認：原本設成 30 MHz 有沒有特別原因，以及 `clk_adc0` 改成 240 MHz 後，`hier_mts` 的 MTS / SYSREF 流程是否還正確。

### 3.2 `onebit_cdc_fifo` IP 遺失

- 位置：`hier_mts/daq_timing_ctrl_0`（`daq_timing_ctrl.vhd`）裡的 `u_onebit_cdc_fifo_eth_valid`，用途是把 `eth_info_valid` 脈衝從 `clk_eth` 跨到 `clk_adc`。
- 原因：rev0.11 的 release 清理清單 `source/scripts/cleanup/remove_47dr2.txt` 把 `47dr2.srcs/sources_1/ip/onebit_cdc_fifo/onebit_cdc_fifo.xci` 刪掉了，`47dr2.xpr` 也不再登錄這顆 IP。
- 同事當時的 build 是正常的：`build_47dr2_b5.log` 顯示 build 時這顆 IP 還在。所以 rev0.11 的 bit / xsa 沒有問題，只是 release 裡的原始碼不完整。
- **47dr1 也一樣**：`remove_47dr1.txt` 也刪了這顆 IP。直接拿 rev0.11 release 的 source 重 build，兩個專案都會失敗。
- 處理方式：從 Calibration_Gain_Control 複製同一份 xci（和同事 baseline「Baseline: restore 47DR_integrated_3 (EnableI2c)」相同）：fifo_generator 13.2、1 bit × 16、Independent Clocks Distributed RAM、Standard FIFO。兩邊的 `daq_timing_ctrl.vhd` 也相同。
- 請同事確認：補回的 IP 設定是否和他原本用的一致，並更新 release，補回 47dr1 / 47dr2 的這顆 IP。

### 3.3 BDC variant 的 module_ref wrapper 沒產生

- 現象：每個 `cal_plus_gain_control_inst_N` 裡，`agc_att_mux`、`agc_reg_pack`、`rxagc_dummy`、`sr_att_pins`、`sr_src_mux`、`txagc_dummy` 這 6 種 module_ref 只有 `.xci` / `.xml`，沒有 `synth/<ip>.v`。8 個通道全部失敗，不是隨機發生。
- 原因：這些 variant BD 被標記為「已產生」，但輸出不完整，所以對 `design_1` 執行 `generate_target` 時直接跳過了它們。
- 處理方式：對 variant BD 執行 `reset_target all` + `generate_target all` 後，wrapper 就齊了。`build_full_xsa.tcl` 會先檢查，有缺才重新產生，並確認全部齊全才開始 build。

### 3.4 `hier_8CH` 造成 Aurora 資料沒有接進通道（build 01 無效）

- 背景：同事的 `hier_rx_x0yN/M_AXIS_C0/C1` 這 8 個 hier pin，BD 裡的 mode 是 **Monitor**，不是 Master。實際驅動資料的是內部 `data_aligner/m_axis`，同時有 system_ila 監看。
- rev0.11 原本直接接 RFDC DAC（Slave）時沒問題，因為 RFDC 的 port 本身固定 160 bit，HDL 會正確接上 tdata / tvalid（已確認 rev0.11 的 HDL）。
- 包成 `hier_8CH` 後，`group_bd_cells` 也把新建的 hier pin 推斷成 Monitor。結果變成 Monitor 接 Monitor，產生的 HDL 中這 8 組 port 成為 hier 的 output，頂層也沒有接上。**build 01 的 8 個通道 in_0 都沒有 Aurora 資料**，validate 也沒有報錯。
- 嘗試過把 hier pin 改成 Slave：線接上了，但 hier pin 拿不到 AXIS 參數（Monitor 端不提供，hier pin 參數唯讀），tdata 只有 1 bit。
- 最後的做法（Rex 決定）：**拆掉 `hier_8CH`**，各通道直接放在頂層：`hier_rx`（Monitor）→ `cal_plus_gain_control_chN/s_axis_iq_in_0`（Slave，160 bit），和 rev0.11「`hier_rx` → RFDC DAC」是同一種接法，同事的設計完全不動。
- 給同事的建議（非必要）：`hier_rx_*` 的 `M_AXIS_C0/C1` 應該是 Master。改成 Master 後，下游就可以再包 hierarchy。

### 3.5 工作站 `~/.Xilinx` 共用造成的隨機錯誤

- 平行跑 OOC run 時，偶爾會有 run 在啟動時出現 Bus error（Abnormal program termination），或 `Failed to create directory ~/.Xilinx/Vivado/tclapp`（資料夾其實存在）。
- build 腳本會自動 reset 失敗的 run 後重跑。出現 `tclapp` 錯誤的 run 實際上都有完成（COMPLETE、dcp 都有產生）。
- 重新打開專案時，Messages 視窗會從 run 的記錄載入這些舊的 error，可以忽略。不要為了讓訊息消失去 reset run，否則 OOC 會全部重跑。

### 3.6 build 03 的 timing 餘裕為 0

- 最差路徑：`timer_1/timestamp_reg[39]` → `hier_rx_x0y1/system_ila_0_2`（debug ILA 的 probe），requirement 3.906 ns，data path 3.485 ns，95% 是繞線，clock skew −0.411 ns。
- 這條路徑在同事原有設計裡。build 03 只改了 NCO，但 placement 變動後最差路徑就落到這裡；build 02 時同一條路徑還有餘裕。
- 目前收斂，沒有處理。之後如果沒收斂，可以考慮：
  - 在 ILA 的 `timestamp` probe 前加一級暫存器。
  - 或者拿掉不需要的 debug ILA。

  兩者都會動到同事的設計，需要先討論。

### 3.7 GUI 開啟時偶發的 `BD 41-1726`

- 2026-10-15 開 GUI 時，只有 ch6 的 `axis_iq_split_0` 報一次「Unable to resolve module-source」。其他 7 個通道、以及 ch6 其他 module_ref 都正常。
- batch 重開沒有出現，`report_ip_status` 顯示為 Up-to-date，GUI 的 `validate_bd_design` 也正常。推測是 GUI 還在背景解析 RTL 時就先開了 BD。

---

## 4. 軟體（Vitis / BOOT.bin）

| 項目 | 內容 |
|---|---|
| Workspace | `software/`：`platform/`（build 03 XSA；zynqmp_fsbl + standalone_psu_cortexa53_0，libmetal，stdout psu_uart_0）+ `app_component/`（empty application） |
| 原始碼 | 由 Calibration_Gain_Control `software/app_component/src`（build 14）複製後改成 8 通道 |
| `register_map.h/.c` | ch1~ch8 base（`0xA009_0000` + 0x1000×(N−1)）、system `0xA009_8000`；新增 mem39；移除 RX ch7；初始化依序寫 system + ch1~ch8，每個暫存器寫完讀回比對 |
| `reg_map_cfg.c` | SYSTEM 初值同 source；ch1~ch8 各自完整欄位（`REG_MAP_CFG_CH[8]`） |
| 開機初值（Rex 指定） | FIR = impulse response（tap7 I = `0x7FFF`，其餘 0，enable = 1，和 FIR disable 時硬體用的係數相同）；mem39 = 0（Aurora）；mem38 = 0（完整處理路徑）；其他沿用 source ch1 |
| `bram.h/.c` | 8 通道 gain 表（`0xA009_A000` + 0x2000×(N−1)）；每通道寫入後讀回比對，UART 印出 OK / FAIL |
| `adcThresholds.c` | 8 個 ADC 都設定 threshold：chN = tile (N−1)/2、block (N−1)%2 |
| `main.c` 流程 | 和 source 相同：RFDC init → GPIO → BRAM → reg map → ADC threshold → RFDC reset → MTS → MBS（中間有 BMC GPIO handshake） |
| 沒有處理 | 同事的 `axi_gpio_arstn`（0xA001_0000）/ `axi_delay`（0xA008_0000），維持同事 §15 的人工操作流程 |
| BOOT.bin | `software/app_component/boot.bif`：FSBL + bit + app elf（格式同 source 的 `test.bif`，**沒有 PMUFW**）；輸出到 `output_data/<build>/BOOT.bin` 與 `software/app_component/BOOT.bin` |

- 驗證方式（Rex）：上板後看 UART 的 BRAM 讀回結果，並用 `reg_runtime/` 的 XSDB 腳本讀寫 reg map；用 `reg_wr signal_source_select 1` 切到 ADC loopback。
- 目前只確認了編譯成功（沒有 warning / error），以及 ELF 中 8 通道的 reg map / BRAM base、FIR tap、mem39 / mem38 的值正確，**尚未上板**。
- 開機會停在第一次 BMC handshake（BRAM / reg map / ADC threshold 在 handshake 之前就已經完成）。PS / BMC 由另一位同事負責。

---

## 5. 待確認事項

1. **z1（47dr1）的 NCO 需要一起改（Rex 已確認 z1 尚未修改）**：build 03 的 z2 改成 ADC 1.04 / DAC −1.04 GHz，但 z1 的 ADC NCO 仍是 rev0.11 的 0.84 GHz。z2 本板的 ADC loopback（in_1）兩邊一致，不受影響；Aurora 這一路（in_0）則是 z1 用 0.84 降頻、z2 用 −1.04 升頻，兩邊不一致，輸出頻率理論上會偏移 0.2 GHz（未驗證）。要讓整個系統變成 2.3~3.3 GHz，z1 的 ADC NCO 也要改成 1.04 GHz 並重新 build。
2. **預設行為改變**：mem39 預設 0（Aurora），這一路現在會經過 FIR（目前是 impulse）/ calibration / gain 處理，不再是原本「Aurora 直接送 DAC」。要恢復原本的行為，需要把 mem38 `bypass_axis_iq` 設成 1。
3. **Timing 餘裕為 0**（見 3.6）：最差路徑在同事的 debug ILA，是否要調整。
4. RFDC ADC Outclk 改成 240 MHz 對原有 MTS 流程的影響（見 3.1）。
5. `onebit_cdc_fifo` 設定是否正確，以及 rev0.11 release 的修正（見 3.2）。
6. 同事 `hier_rx_*` 的 `M_AXIS_C0/C1` 是 Monitor mode，是否改成 Master（見 3.4）。
7. **SR 腳位沒有接**：每個 channel 的 `Reg1~5_SER / SRCLK / RCLK`（74LVC595）目前沒有拉到頂層，也沒有腳位約束。
8. **VIO 是暫時的輸入**：`rx_att_index` / `algo_analog_att_db` / `pulse_avg_amp` / `pulse_papr` 目前由 VIO 提供，之後要改接正式的來源。
9. **build_version**：`system_reg_map` 的 BUILD_VERSION 目前是 0（sys14 讀回 0）。
10. **BOOT.bin 沒有 PMUFW**（同 source）；PS 程式不處理 `arstn` / `axi_delay`；開機會等 BMC handshake。

---

## 6. 腳本與備份

| 腳本 | 用途 |
|---|---|
| `hardware/scripts/build_and_boot.sh <idx>` | **一次完成**：Vivado build → Vitis 更新 platform → 重編 app → bootgen → MANIFEST；timing 沒收斂就停止 |
| `hardware/scripts/build_full_xsa.tcl` | wrapper 檢查 + synth / impl / bitstream / 報告 / XSA（`-jobs 4`，失敗自動重跑） |
| `hardware/scripts/cal_plus_gain_control_bd.tcl` | source 匯出的 BD Tcl |
| `hardware/scripts/integrate_cal_plus_gain_control.tcl` | 加入 RTL / XDC、建立 BD、8 個 container、system_reg_map、smartconnect、位址分配 |
| `hardware/scripts/hier_8ch_vio_flags.tcl` | RFDC Outclk 240 MHz、VIO、RFDC flag / clear、包成 hier_8CH（hier_8CH 之後已拆掉） |
| `hardware/scripts/cleanup_stale_bdc_inst.tcl` | 刪除沒在用的 BDC variant |
| `hardware/scripts/add_onebit_cdc_fifo.tcl` | 補回 `onebit_cdc_fifo` IP |
| `hardware/scripts/fix_hier8ch_in0_slave.tcl` / `fix_hier8ch_in0_width.tcl` | 嘗試把 hier_8CH 的 in_0 改成 Slave（沒有成功，已被 `ungroup_hier8ch.tcl` 取代） |
| `hardware/scripts/ungroup_hier8ch.tcl` | 拆掉 hier_8CH |
| `software/create_platform.py` / `create_app.py` | 建立 Vitis platform / app（只在第一次） |
| `software/update_platform.py`（`BUILD_IDX=<idx>`）/ `rebuild_app.py` | XSA 更新後重建 platform / app |
| `docs/tools/regmap_def.py` / `mk_regmap_v8.py` | 產生 target 的 Register map Excel |

| 備份（`backup/`） | 內容 |
|---|---|
| `backup_before_cal_gain_integration_20261014.tar.gz` | target 整合前（xpr + srcs） |
| `backup_before_hier_8ch_20261014.tar.gz` | 包 hier_8CH 前（xpr + BD） |
| `backup_before_in0_slave_fix_20261014.tar.gz` | in_0 改 Slave 前 |
| `backup_before_ungroup_hier8ch_20261015.tar.gz` | 拆 hier_8CH 前 |
| `backup_before_nco_104_build03_20261015.tar.gz` | build 03 前（已含 Rex 的 NCO 修改） |
| `Calibration_Gain_Control/backup/backup_before_signal_source_mux_20261014.tar.gz` | source 加 Signal Source Mux 前 |

> rev0.11 release 資料夾全程只有讀取、沒有修改。
