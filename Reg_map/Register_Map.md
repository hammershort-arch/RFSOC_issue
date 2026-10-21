# RFSoC_TX — Register Map

- 專案：PJ22045_1R8T_release_Rex_rev0.1_20261015 / RFSoC_TX（z2）
- 適用版本：**Debug_008**（RFSoC_TX = v1.0.0 + Signal Source Mux all_zero），RegMap v8 + mem39（2 bit）
- 定義來源：`docs/02_RFSoC_TX/tools/regmap_def.py`（本文件的暫存器表由 `docs/02_RFSoC_TX/tools/mk_doc_register_map.py` 自動產生）
- Excel：`docs/02_RFSoC_TX/Reg_map/Reg_map_tx_ch_v0.1.xlsx`（channel）、`Reg_map_emu_sys_v0.1.xlsx`（system）
- 文件版本：v0.2（2026-10-19，Debug_008）

## 1. 閱讀指引

| 想知道 | 看哪裡 |
|---|---|
| 有哪些 reg map、位址在哪裡 | 第 2 節 |
| AXI 存取規則（reset 值、寫入方式、保留位址） | 第 3 節 |
| system 暫存器（8 通道共用） | 第 4 節 |
| channel 設定暫存器（每通道一份） | 第 5 節 |
| 狀態暫存器與 snapshot | 第 6 節 |
| 暫存器何時生效、跨時脈 | 第 7 節 |
| Gain 表 BRAM | 第 8 節 |
| 開機初值（PS） | 第 9 節 |
| 用 XSDB 在板上讀寫 | 第 10 節 |
| 改暫存器要動哪些檔案 | 第 11 節 |

各功能的細節（暫存器如何影響電路）另見同目錄的 `Calibration.md`、`Power_Fit.md`、`Gain_Control.md`。

## 2. 架構總覽

RFSoC_TX 共有三種 PS 可存取的 PL 位址空間，都掛在 `smartconnect_0`（S_AXI_ACLK = pl_clk0 100 MHz）：

```
PS (M_AXI_HPM0_FPD) ─► smartconnect_0 ─┬─ M22 ─► system_reg_map            0xA009_8000  (8 通道共用)
                                       ├─ M06/M07 ─► ch1 addressable_reg_map / gain BRAM
                                       ├─ ...
                                       └─ M20/M21 ─► ch8 addressable_reg_map / gain BRAM
system_reg_map sysN ──(net reg_<name>)──► 8 個 cal_plus_gain_control_chN 的 reg_<name> 輸入
```

| Reg map | 位置 | Base | 大小 | 內容 |
|---|---|---|---|---|
| system_reg_map | `design_1/system_reg_map` | 0xA0098000 | 4 KB（64 × 32-bit） | sys0~13、15、16 設定；sys14 build_version（唯讀） |
| addressable_reg_map | `cal_plus_gain_control_chN/addressable_reg_map` | 見下表 | 4 KB（128 × 32-bit） | mem0~39 設定；mem40~63 保留；mem64~70 狀態 |
| gain 表 BRAM | `cal_plus_gain_control_chN/calibration/axi_bram_ctrl_0` | 見下表 | 8 KB（2048 × 32-bit） | Gain_Compensation 用的增益表 |

| 通道 | BD cell | Reg map base | Gain BRAM base | 範圍 |
|---|---|---|---|---|
| ch1 | `cal_plus_gain_control_ch1` | 0xA0090000 | 0xA009A000 | reg 4 KB / BRAM 8 KB |
| ch2 | `cal_plus_gain_control_ch2` | 0xA0091000 | 0xA009C000 | reg 4 KB / BRAM 8 KB |
| ch3 | `cal_plus_gain_control_ch3` | 0xA0092000 | 0xA009E000 | reg 4 KB / BRAM 8 KB |
| ch4 | `cal_plus_gain_control_ch4` | 0xA0093000 | 0xA00A0000 | reg 4 KB / BRAM 8 KB |
| ch5 | `cal_plus_gain_control_ch5` | 0xA0094000 | 0xA00A2000 | reg 4 KB / BRAM 8 KB |
| ch6 | `cal_plus_gain_control_ch6` | 0xA0095000 | 0xA00A4000 | reg 4 KB / BRAM 8 KB |
| ch7 | `cal_plus_gain_control_ch7` | 0xA0096000 | 0xA00A6000 | reg 4 KB / BRAM 8 KB |
| ch8 | `cal_plus_gain_control_ch8` | 0xA0097000 | 0xA00A8000 | reg 4 KB / BRAM 8 KB |

- 位址是 Vivado Address Editor 分配的結果（2026-10-14）。同事原有的位址（0xA000_0000 ~ 0xA008_FFFF）沒有變動。
- 8 個通道的暫存器表完全相同，只差 base address。
- system 暫存器只有一份，8 個通道讀到的值相同。

## 3. AXI 存取規則

- 介面：AXI4-Lite，32-bit，`addressable_reg_map` 9-bit 位址、`system_reg_map` 8-bit 位址（RTL 由 `gen_reg_maps.py` 產生）。
- **沒有 reset**：設定暫存器的初值是 FPGA 上電時的值（= 表中 Reset 欄），不受 `S_AXI_resetn` 影響。PS 重新開機不會把值恢復，要恢復需要重新寫入或重新載入 bitstream。
- 寫入：支援 WSTRB 位元組寫入；AW / W 可以同拍或分開到達。
- 設定暫存器整個 32-bit 都可讀寫；超出「位元」欄的高位元會被保留並讀回，但硬體不使用。
- 有號欄位使用二補數；`S6.4` 表示 11-bit、1/16 dB 步階（例：−6.0 dB = −96 = 0x7A0）。
- 保留位址（mem40~63、mem71~127、sys17~63）讀回 0，寫入無效。
- 唯讀暫存器（狀態、sys14）寫入無效。
- dBFS 基準：16384 = 0 dBFS。

## 4. System 暫存器（`system_reg_map`，base 0xA0098000）

| 暫存器 | Offset | 名稱 | 位元 | 存取 | Reset | 格式 / 單位 | 範圍 / 說明 | 生效 |
|---|---|---|---|---|---|---|---|---|
| sys0 | 0x000 | signal_mode_select | [0] | R/W | 0x0 | bit | 0: CW, 1: Pulse；Power Fit input / goal: CW = cw_power_calc + cw_mode_goal_dbfs; Pulse = pulse_avg_amp + goal -(margin + PAPR), auto update | Real-time (CDC) |
| sys1 | 0x004 | power_limit_margin | [2:0] | R/W | 0x3 | U3.0 dB | 0 ~ 7 dB；Power limit = -margin dBFS. CW goal = min(cw_mode_goal_dbfs, -margin); Pulse goal = -(margin + PAPR) | Real-time (CDC) |
| sys2 | 0x008 | cw_mode_goal_dbfs | [10:0] | R/W | 0x7A0 (-6) | S6.4 dBFS (16384 = 0 dBFS) | -64 ~ 0 dB (HW: <= -margin)；CW mode Power Fit goal (e.g. 0x7A0 = -6.0 dBFS ~ amplitude 8211) | Real-time (CDC) |
| sys3 | 0x00C | pulse_update_stable_cycle | [3:0] | R/W | 0x4 | unsigned, clk (3.906 ns) | 0 ~ 15；Pulse auto update: pulse_avg_amp / pulse_papr must stay unchanged M clk after a change before they are latched together and one Power Fit result (pf + goal_rel) is sent | Real-time (CDC) |
| sys4 | 0x010 | agc_tx_power_mode | [0] | R/W | 0x0 | bit | 0: Linear, 1: Manual；TXAGC target T. Linear: 96.5625 + linear_mode_offset - rx_att_index x 10 + pf - offsets + algo; Manual: dac_output_ref_dbm + goal_rel_db + 50 - target_power + manual_mode_offset - offsets + algo (dB) | Real-time |
| sys5 | 0x014 | digital_apply_delay | [7:0] | R/W | 0x23 | unsigned, adc_clk (4.167 ns) | 0 ~ 255 (< agc_sr_update_period)；Digital gain index applied N clk after the Reg1~4 SR start (35 = RCLK) | Next analog step |
| sys6 | 0x018 | agc_sr_update_period | [7:0] | R/W | 0x32 | unsigned, adc_clk | HW min 50, max 255 (208 ns ~ 1.06 us)；Shift register update round (SER transfer ~37 clk + hardware settling); shared by Reg1~4 and Reg5 | Next round |
| sys7 | 0x01C | agc_mode_settle_cycle | [15:0] | R/W | 0x40 | unsigned, adc_clk | HW min 1；Wait after Reg5 transfer before AGC switches RX/TX | Real-time |
| sys8 | 0x020 | agc_rx_watch_cycle | [31:0] | R/W | 0x3E8 | unsigned, adc_clk | HW min 1；RXAGC S_WATCHING time (no signal -> back to 0 dB); set by PRI | Real-time |
| sys9 | 0x024 | agc_rx_wait_dsa_cycle | [7:0] | R/W | 0x6 | unsigned, adc_clk | HW min 1；RXAGC S_WAIT_DSA | Real-time |
| sys10 | 0x028 | agc_rx_set_dsa_cycle | [7:0] | R/W | 0x6 | unsigned, adc_clk | HW min 1；RXAGC S_SET_DSA | Real-time |
| sys11 | 0x02C | agc_rx_wait_cycle | [7:0] | R/W | 0x32 | unsigned, adc_clk | HW min 1；RXAGC S_WAIT (RF settling before flag clear) | Real-time |
| sys12 | 0x030 | agc_rx_set_clear_cycle | [7:0] | R/W | 0x6 | unsigned, adc_clk | HW min 6；RXAGC clear_or / clear_ov pulse width | Real-time |
| sys13 | 0x034 | agc_rx_wait_clear_cycle | [7:0] | R/W | 0x10 | unsigned, adc_clk | HW min 1；RXAGC S_WAIT_CLEAR | Real-time |
| sys15 | 0x03C | cw_power_avg_log2 | [3:0] | R/W | 0x8 | log2(N), CW samples (clk) | 0 ~ 12 (N = 1 ~ 4096, >12 -> 12)；CW power block average: cw_amp averaged over N = 2^k samples, Power Fit (CW) updated once every N clk (2026-10-10, build 13) | Next block |
| sys16 | 0x040 | agc_tx_att_hysteresis | [7:0] | R/W | 0x10 | U4.4 dB (1/16 dB) | 0 ~ 15.9375 dB (0 = no hysteresis)；TXAGC analog step hysteresis H: keep the current analog step while T stays within [A - H, A_next + H); R range -H ~ 4.9375 + H dB (build 13) | Real-time |
| sys14 | 0x038 | build_version | [31:0] | R | - | unsigned | -；Build number (XSA / output_data index, e.g. 12), set by build_full_xsa.tcl | - |

- sys14 `build_version` 由 Vivado 參數 `BUILD_VERSION` 決定；RFSoC_TX build 01 目前是 **0**（沒有設定）。
- sys6~13 的 AGC 週期暫存器若寫入小於硬體最小值，硬體會以最小值運作（讀回仍是寫入的值）。

### 4.1 System 暫存器的使用者

| 暫存器 | 名稱 | 使用者（BD） | 群組 |
|---|---|---|---|
| sys0 | signal_mode_select | `chN/cal_cdc_0 -> power_fit_top/power_fit_db_0` | Power Fit |
| sys1 | power_limit_margin | `chN/cal_cdc_0 -> power_fit_top/power_fit_db_0` | Power Fit |
| sys2 | cw_mode_goal_dbfs | `chN/cal_cdc_0 -> power_fit_top/power_fit_db_0` | Power Fit |
| sys3 | pulse_update_stable_cycle | `chN/cal_cdc_0 -> power_fit_top/power_fit_db_0` | Power Fit |
| sys4 | agc_tx_power_mode | `chN/agc_emu/agc_cdc_0 -> txagc_0` | AGC_EMU |
| sys5 | digital_apply_delay | `chN/agc_emu/agc_cdc_0 -> gain_apply_sync_0` | AGC_EMU |
| sys6 | agc_sr_update_period | `chN/agc_emu/agc_cdc_0 -> sr_att_group / sr_reg5_group` | AGC_EMU |
| sys7 | agc_mode_settle_cycle | `chN/agc_emu/agc_cdc_0 -> agc_mode_ctrl_0` | AGC_EMU |
| sys8 | agc_rx_watch_cycle | `chN/agc_emu/agc_cdc_0 -> rxagc_0` | AGC_EMU |
| sys9 | agc_rx_wait_dsa_cycle | `chN/agc_emu/agc_cdc_0 -> rxagc_0` | AGC_EMU |
| sys10 | agc_rx_set_dsa_cycle | `chN/agc_emu/agc_cdc_0 -> rxagc_0` | AGC_EMU |
| sys11 | agc_rx_wait_cycle | `chN/agc_emu/agc_cdc_0 -> rxagc_0` | AGC_EMU |
| sys12 | agc_rx_set_clear_cycle | `chN/agc_emu/agc_cdc_0 -> rxagc_0` | AGC_EMU |
| sys13 | agc_rx_wait_clear_cycle | `chN/agc_emu/agc_cdc_0 -> rxagc_0` | AGC_EMU |
| sys15 | cw_power_avg_log2 | `chN/cal_cdc_0 -> power_fit_top/power_fit_db_0` | Power Fit |
| sys16 | agc_tx_att_hysteresis | `chN/agc_emu/agc_cdc_0 -> txagc_0` | AGC_EMU |
| sys14 | build_version | `system_reg_map parameter BUILD_VERSION` | System |

## 5. Channel 設定暫存器（`addressable_reg_map`，每通道一份）

Base address 見第 2 節（ch1 = 0xA0090000，chN = 0xA0090000 + 0x1000 × (N−1)）。

| 暫存器 | Offset | 名稱 | 位元 | 存取 | Reset | 格式 / 單位 | 範圍 / 說明 | 生效 |
|---|---|---|---|---|---|---|---|---|
| mem0 | 0x000 | fir_enable | [0] | R/W | 0x0 | bit | 0 / 1；Complex FIR enable | - |
| mem1~16 | 0x004~0x040 | fir_tap00 ~ fir_tap15 | [31:0] | R/W | 0x0 | [15:0] I, [31:16] Q (S0.15 each, 0x7FFF ≈ 1.0) | Complex FIR tap 0~15 係數（XSDB：`reg_fir_tap <t> <I> <Q>`） | - |
| mem17 | 0x044 | coarse_delay_offset | [3:0] | R/W | 0x0 | unsigned, cycles | 0 ~ 15；Delay_Cal coarse delay | Real-time (CDC) |
| mem18 | 0x048 | fractional_delay_offset | [2:0] | R/W | 0x0 | unsigned, samples | 0 ~ 4；Delay_Cal fractional delay | Real-time (CDC) |
| mem19 | 0x04C | phase_offset | [15:0] | R/W | 0x0 | CORDIC phase | -；Phase_Cal phase offset (cordic_0~4) | Real-time (CDC) |
| mem20 | 0x050 | gain_index_mode_sel | [0] | R/W | 0x0 | bit | 0: TXAGC, 1: manual；Gain_Compensation index source: 0 = gain_index_tx (TXAGC digital), 1 = gain_index_manual | Real-time (CDC) |
| mem21 | 0x054 | gain_index_manual | [10:0] | R/W | 0x0 | S6.4, 1/16 dB | -64 ~ +63.9375 dB；Manual gain index (mode_sel = 1), offsets not added | Real-time (CDC) |
| mem22 | 0x058 | gain_index_ch_offset | [8:0] | R/W | 0x0 | S4.4, 1/16 dB | -16 ~ +15.9375 dB；Channel magnitude trim (+ = gain), in the TXAGC target (analog first, residual digital) | Real-time |
| mem23 | 0x05C | gain_index_rf_freq_offset | [7:0] | R/W | 0x0 | S3.4, 1/16 dB | -8 ~ +7.9375 dB；RF-frequency magnitude trim (+ = gain), in the TXAGC target | Real-time |
| mem24 | 0x060 | gain_index_temperature_offset | [7:0] | R/W | 0x0 | S3.4, 1/16 dB | -8 ~ +7.9375 dB；Temperature magnitude trim (+ = gain), in the TXAGC target | Real-time |
| mem25 | 0x064 | dac_output_ref_dbm | [10:0] | R/W | 0x670 (-25) | S6.4 dBm | HW limit +10 ~ -40 dBm；DAC output measured with goal = goal_ref_dbfs (TXAGC Manual mode reference) | Real-time |
| mem26 | 0x068 | goal_ref_dbfs | [10:0] | R/W | 0x7A0 (-6) | S6.4 dBFS (16384 = 0 dBFS) | -64 ~ +63.9375 dB；Goal (dBFS) used when dac_output_ref_dbm was measured; goal_rel_db = goal_dBFS - goal_ref_dbfs | Real-time (CDC) |
| mem27 | 0x06C | agc_reg5 | [7:0] | R/W | 0x80 | bits | [7] TXRX_SW: 0 TX, 1 RX; [6:2] filter; [1:0] PA on = 11；Reg5 byte (595 QA~QH). [7] TXRX_SW = AGC mode source; [6:2] Filter {Vc2, Vc1, Vc0, Vc3, Vc4}; [1] PA_VC_D, [0] PA_VC_G | Real-time (bypass: agc_bypass_sr_update[1]) |
| mem28 | 0x070 | agc_bypass_agc | [0] | R/W | 0x0 | bit | 0: AGC, 1: bypass；1: AGC paused; TX attenuator = agc_bypass_tx_att_state, RX = dummy 0 dB, digital comp = 0; SR sent only by agc_bypass_sr_update | Real-time |
| mem29 | 0x074 | agc_bypass_tx_att_state | [4:0] | R/W | 0x0 | unsigned state | 0 ~ 27 (0 = 130 dB ... 27 = 5 dB)；TX analog attenuator state in bypass | Bypass trigger |
| mem30 | 0x078 | agc_bypass_sr_update | [1:0] | R/W | 0x0 | bits, rising edge | write 1 then 0 (0x3 = all 5 registers)；Bypass only. [0] send Reg1~4, [1] send Reg5 | - |
| mem31 | 0x07C | agc_manual_tx_att_en | [0] | R/W | 0x0 | bit | 0: formula, 1: manual；TX target attenuation = agc_manual_tx_att_db (other TX inputs ignored) | Real-time |
| mem32 | 0x080 | agc_manual_tx_att_db | [7:0] | R/W | 0x0 | unsigned, 1 dB | 5 ~ 130；Manual TX target attenuation | Real-time |
| mem33 | 0x084 | agc_target_power | [7:0] | R/W | 0x0 | signed, 1 dBm | -128 ~ +127 dBm；Manual mode target output power (e.g. 0xD8 = -40 dBm) | Real-time |
| mem34 | 0x088 | agc_linear_mode_offset | [11:0] | R/W | 0x0 | signed, 1/16 dB | -128 ~ +127.9375 dB；Linear mode offset | Real-time |
| mem35 | 0x08C | agc_manual_mode_offset | [11:0] | R/W | 0x0 | signed, 1/16 dB | -128 ~ +127.9375 dB；Manual mode offset | Real-time |
| mem36 | 0x090 | agc_manual_rx_att_en | [0] | R/W | 0x0 | bit | 0: RXAGC, 1: manual；Use agc_manual_rx_att_state instead of the RXAGC result (RX mode) | Real-time |
| mem37 | 0x094 | agc_manual_rx_att_state | [2:0] | R/W | 0x0 | unsigned state | 0 ~ 6 (0 ~ 60 dB)；Manual RX attenuation state | Real-time |
| mem38 | 0x098 | bypass_axis_iq | [0] | R/W | 0x0 | bit | 0: normal, 1: bypass；Debug: 1 = m_axis_iq = Signal Source Mux output (mem39 selected input; FIR / calibration / gain control bypassed, input sent directly to the DAC); the normal path keeps running (AGC / Power Fit still computed) | Real-time (CDC) |
| mem39 | 0x09C | signal_source_select | [1:0] | R/W | 0x0 | unsigned | 0: s_axis_iq_in_0, 1: s_axis_iq_in_1, 2 / 3: all_zero；Signal Source Mux: input stream sent to Power Fit / Calibration (and to the mem38 bypass path); the unselected inputs are dropped (tready = 1). Debug_008: 2 / 3 = all_zero (160'd0, tvalid = 1) | Real-time (CDC) |

- mem40~63 保留給之後擴充，讀回 0。
- **mem39 `signal_source_select`** 是 RFSoC_TX 新增的 Signal Source Mux 選擇：0 = `s_axis_iq_in_0`（Aurora，`hier_rx_x0yN`），1 = `s_axis_iq_in_1`（本板 ADC，`rfdc_iq_combine_chN`），**2 / 3 = all_zero**（Debug_008 新增：160'd0、tvalid = 1，用來看 DAC 收到全 0 時的輸出）。mem39 在 Debug_008 是 2 bit（`cal_cdc` 同步寬度 1 → 2）。
- **mem38 `bypass_axis_iq`** = 1 時，Mux 選到的輸入直接送 DAC，不經 FIR / calibration / gain（AGC 與 Power Fit 仍照常計算）。

### 5.1 Channel 暫存器的使用者

| 暫存器 | 名稱 | 使用者（BD） | 群組 |
|---|---|---|---|
| mem0 | fir_enable | `in_band_flatness/sl_fir_enable` | Calibration |
| mem1~16 | fir_tap00 ~ 15 | `in_band_flatness/FIR_coef_unpack_0` | Calibration |
| mem17 | coarse_delay_offset | `cal_cdc_0 -> calibration/Delay_Cal_0` | Calibration |
| mem18 | fractional_delay_offset | `cal_cdc_0 -> calibration/Delay_Cal_0` | Calibration |
| mem19 | phase_offset | `cal_cdc_0 -> calibration/cordic_0~4` | Calibration |
| mem20 | gain_index_mode_sel | `cal_cdc_0 -> gain_index_mux_0` | Gain Index |
| mem21 | gain_index_manual | `cal_cdc_0 -> gain_index_mux_0` | Gain Index |
| mem22 | gain_index_ch_offset | `agc_emu/agc_cdc_0 -> txagc_0` | Gain Index |
| mem23 | gain_index_rf_freq_offset | `agc_emu/agc_cdc_0 -> txagc_0` | Gain Index |
| mem24 | gain_index_temperature_offset | `agc_emu/agc_cdc_0 -> txagc_0` | Gain Index |
| mem25 | dac_output_ref_dbm | `agc_emu/agc_cdc_0 -> txagc_0` | Gain Index |
| mem26 | goal_ref_dbfs | `cal_cdc_0 -> power_fit_top/power_fit_db_0` | Gain Index |
| mem27 | agc_reg5 | `agc_emu/agc_cdc_0 -> agc_mode_ctrl_0 / sr_src_mux_0` | AGC_EMU |
| mem28 | agc_bypass_agc | `agc_emu/agc_cdc_0` | AGC_EMU |
| mem29 | agc_bypass_tx_att_state | `agc_emu/agc_cdc_0 -> txagc_0` | AGC_EMU |
| mem30 | agc_bypass_sr_update | `agc_emu/agc_cdc_0 -> sr_src_mux_0` | AGC_EMU |
| mem31 | agc_manual_tx_att_en | `agc_emu/agc_cdc_0 -> txagc_0` | AGC_EMU |
| mem32 | agc_manual_tx_att_db | `agc_emu/agc_cdc_0 -> txagc_0` | AGC_EMU |
| mem33 | agc_target_power | `agc_emu/agc_cdc_0 -> txagc_0` | AGC_EMU |
| mem34 | agc_linear_mode_offset | `agc_emu/agc_cdc_0 -> txagc_0` | AGC_EMU |
| mem35 | agc_manual_mode_offset | `agc_emu/agc_cdc_0 -> txagc_0` | AGC_EMU |
| mem36 | agc_manual_rx_att_en | `agc_emu/agc_cdc_0 -> rxagc_0` | AGC_EMU |
| mem37 | agc_manual_rx_att_state | `agc_emu/agc_cdc_0 -> rxagc_0` | AGC_EMU |
| mem38 | bypass_axis_iq | `cal_cdc_0 -> axis_iq_bypass_0` | Calibration |
| mem39 | signal_source_select | `cal_cdc_0 -> axis_iq_source_mux_0` | Calibration |

## 6. 狀態暫存器（mem64~70）與 snapshot

| 暫存器 | Offset | 名稱 | 位元 | 存取 | Reset | 格式 / 單位 | 範圍 / 說明 | 生效 |
|---|---|---|---|---|---|---|---|---|
| mem64 | 0x100 | status_snapshot | [15:0] | W1 / R | - | W: bit0 = 1 trigger; R: [15:0] completed snapshot count | -；Write 1: latch all st_* registers of this channel on the same clock (clk and adc_clk domains); read back the number of completed snapshots (increments when both domains are latched) | - |
| mem65 | 0x104 | st_power_amp | [15:0] | R | - | unsigned amplitude | 0 ~ 65535；power_fit_top/power_amp (cw_power_calc output) | - |
| mem66 | 0x108 | st_gain_index_power_fit | [9:0] | R | - | S5.4, 1/16 dB (sign-extended) | -31.9375 ~ +31.9375 dB；Power Fit result pf = goal_dBFS - input_dBFS | - |
| mem67 | 0x10C | st_goal_db | [11:0] | R | - | S7.4 dBFS (sign-extended) | -128 ~ 0 dB；Power Fit goal in dBFS (16384 = 0 dBFS). CW: min(cw_mode_goal_dbfs, -margin); Pulse: -(margin + PAPR) | - |
| mem68 | 0x110 | st_goal_rel_db | [9:0] | R | - | S5.4, 1/16 dB (sign-extended) | -31.9375 ~ +31.9375 dB；goal_dBFS - goal_ref_dbfs (TXAGC Manual mode) | - |
| mem69 | 0x114 | st_gain_index_tx | [11:0] | R | - | S7.4, 1/16 dB (sign-extended) | -128 ~ +127.9375 dB；TXAGC digital gain index (pf - R) applied to Gain_Compensation (clk domain) | - |
| mem70 | 0x118 | st_adc_flags | [3:0] | R | - | bits | [0] over_threshold1, [1] over_threshold2, [2] over_range, [3] over_voltage；RFDC flags at the snapshot (adc_clk domain, current value only) | - |

讀取流程（同一次 snapshot 的值彼此一致）：

1. 讀 mem64，記下目前的 snapshot 次數 `cnt0`。
2. 寫 mem64 = 1（bit0），觸發 `status_snapshot_0` 在 clk（256 MHz）與 adc_clk（240 MHz）兩個 domain 同時鎖存所有 `st_*`。
3. 輪詢 mem64，直到讀回的次數 ≠ `cnt0`（兩個 domain 都鎖存完成，約 < 0.2 µs）。
4. 讀 mem65~70。有號欄位已符號擴展到 32-bit，S?.4 欄位除以 16 即為 dB。

PS 端的實作是 `register_map_status()`（`software/app_component/src/sources/register_map.c`）；XSDB 是 `reg_dump`（第 10 節）。

## 7. 生效時機與跨時脈

暫存器在 S_AXI_ACLK（100 MHz）寫入，使用端在其他時脈 domain，依「生效」欄分成三類：

| 類別 | 暫存器 | 跨時脈方式 |
|---|---|---|
| 直接使用（準靜態） | mem0~16（FIR enable / 係數） | 直接接到 256 MHz FIR，XDC 設 false path（`constrs_1/new/cal_plus_gain_control.xdc`）；改係數時先把 mem0 寫 0，寫完係數再寫 1 |
| Real-time (CDC)，到 clk 256 MHz | mem17~21、26、38、39；sys0~3、15 | `cal_cdc_0`：`xpm_cdc_array_single` + 連續 4 拍不變才採用（避免多 bit 欄位在變化那一拍讀到新舊混合值） |
| 到 adc_clk 240 MHz（AGC） | mem22~25、27~37；sys4~13、16 | `agc_emu/agc_cdc_0`（細節見 `Gain_Control.md`） |

- 「Bypass trigger」/ 正緣觸發的暫存器（mem30 `agc_bypass_sr_update`）要寫 1 再寫 0（XSDB：`reg_pulse`）。
- 多個暫存器需要同時生效時（例如 FIR 係數），請依第 9 節的寫入順序。

## 8. Gain 表 BRAM

- 每通道一顆 `blk_mem_gen`，經 `axi_bram_ctrl_0` 掛在 AXI 上，8 KB = 2048 筆 × 32-bit。
- 位址 chN = 0xA009A000 + 0x2000 × (N−1)；第 i 筆在 base + 4 × i。
- 內容是 Gain_Compensation 的增益係數（線性值），索引為 gain index（0.0625 dB 步階，有號，2048 筆）。格式與索引方式見 `Calibration.md`。
- PS 開機時由 `gain_offset_tabel_initialize()`（`bram.c`）寫入 8 個通道，每通道寫完讀回比對並在 UART 印出 OK / FAIL。
- `reg_rt.tcl` 不存取 BRAM；要在板上檢查可用 XSDB 的 `mrd`。

## 9. 開機初值（PS `reg_map_cfg.c`）

開機時 `register_map_init()` 依序寫入 system 與 ch1~ch8，每個暫存器寫入後讀回比對，不一致或超出範圍會在 UART 印出。初值以物理單位寫在 `software/app_component/src/sources/reg_map_cfg.c`（只需要改這個檔）。

寫入順序（每通道）：FIR 先寫 0 → 16 個係數 → delay / phase → gain index 與參考值 → AGC 參數 → 模式 / enable（mem39、mem38、mem0 最後）。

| 項目 | 初值 | 說明 |
|---|---|---|
| FIR（mem0~16） | enable = 1，tap7 = `FIR_IQ(0x7FFF, 0)`，其餘 0 | impulse response，等同 FIR 關閉時硬體使用的係數；量測後再換成各通道係數 |
| mem39 signal_source_select | 0（**Debug_008：ch1 = 2**） | Aurora（in_0）；1 = ADC loopback；2 = all_zero |
| mem38 bypass_axis_iq | 0（**Debug_008：ch1 = 1**） | 走完整處理路徑；ch1 預設 bypass（all_zero 直接送 DAC） |
| dac_output_ref_dbm / goal_ref_dbfs | −25 dBm / −6 dBFS | 與 Calibration_Gain_Control 相同 |
| agc_reg5 | 0x80 | TXRX_SW = 1（RX mode） |
| 其他 channel 暫存器 | 0 | 同 reset 值 |
| system | signal_mode_select 0、power_limit_margin 3、cw_mode_goal_dbfs −6、pulse_update_stable_cycle 4、cw_power_avg_log2 8、agc_tx_power_mode 0、digital_apply_delay 35、agc_sr_update_period 50、agc_mode_settle_cycle 64、agc_rx_watch / wait_dsa / set_dsa / wait / set_clear / wait_clear = 1000 / 6 / 6 / 50 / 6 / 16、agc_tx_att_hysteresis 1 dB | 與 Calibration_Gain_Control 相同 |

## 10. 在板上讀寫（XSDB）

腳本：`RFSoC_TX/reg_runtime/reg_rt.tcl`（使用說明 `reg_runtime/README.md`）。

| 指令 | 用途 |
|---|---|
| `reg_ch <1~8>` | 切換通道（system 暫存器不受影響） |
| `reg_set <name> <value>` / `reg_get <name>` | 以物理單位寫入 / 讀回（自動換算、範圍檢查、讀回確認） |
| `reg_wr <name> <raw>` / `reg_rd <name>` | 直接寫 / 讀 raw 值 |
| `reg_pulse <name> <raw>` | 寫入後再寫 0（正緣觸發） |
| `reg_fir_tap <t> <I> <Q>` | 寫 FIR tap（I / Q 各為 signed 16-bit） |
| `reg_dump <1~8 / all>` | 執行 snapshot 並印出狀態，同時存成 CSV / txt |
| `reg_list` / `reg_info <name>` | 列出暫存器 / 查詢位址與格式 |
| `reg_template <file>` / `reg_run <file>` | 產生設定檔範本 / 執行設定檔 |

名稱與本文件相同，只有 mem0 在 XSDB 中叫 `in_band_fir_enable`。

範例：把 ch3 切到 ADC loopback 並讀狀態

```
xsdb% reg_ch 3
xsdb% reg_wr signal_source_select 1
xsdb% reg_dump 3
```

## 11. 修改暫存器時要更新的檔案

暫存器以 `regmap_def.py` 為唯一定義來源：

| 檔案 | 說明 |
|---|---|
| `docs/02_RFSoC_TX/tools/regmap_def.py` | 定義（本專案的副本；原始版本在 Calibration_Gain_Control `doc/tools/`） |
| RTL `addressable_reg_map.v`、`system_reg_map.v` | 由 Calibration_Gain_Control `hardware/scripts/gen_reg_maps.py` 產生後複製到 `RFSoC_TX.srcs/sources_1/new/cal_plus_gain_control/` |
| `docs/02_RFSoC_TX/Reg_map/*.xlsx` | `docs/02_RFSoC_TX/tools/mk_regmap_v8.py` |
| 本文件 | `docs/02_RFSoC_TX/tools/mk_doc_register_map.py` |
| PS：`register_map.h/.c`、`reg_map_cfg.c` | 手動更新 |
| XSDB：`reg_runtime/reg_rt.tcl`（`::reg::def` 表）、`reg_template.tcl` | 手動更新 |
| 位址（Address Editor 重新分配時） | `register_map.h`、`bram.h`（XPAR 巨集會自動跟著 XSA）、`reg_rt.tcl` 的 `CH_BASE` / `SYS_BASE`、Excel Summary |

## 12. 待確認

1. sys14 `build_version` 目前是 0，之後 build 時可在 build 腳本設定 `BUILD_VERSION`。
2. 設定暫存器沒有 reset，PS 重開機前的值會保留；若需要「重開機即回到初值」，需在 PS 開機流程重寫（目前 `register_map_init()` 會重寫全部設定暫存器）。

## 13. 修訂歷程

| 版本 | 日期 | 說明 |
|---|---|---|
| v0.1 | 2026-10-16 | 第一版，對應 RFSoC_TX build 01（RegMap v8 + mem39，8 通道） |
| v0.2 | 2026-10-19 | Debug_008：mem39 改成 2 bit，2 / 3 = all_zero；PS 預設 ch1 = all_zero + bypass |
