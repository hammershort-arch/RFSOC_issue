# RFSoC_TX — Top Architecture

- 專案：PJ22045_1R8T_release_Rex_rev0.1_20261015 / RFSoC_TX（z2）
- Vivado 專案：`RFSoC_TX/hardware/RFSoC_TX.xpr`（Vivado 2025.2，xczu47dr-ffvg1517-2-i，top `design_1_wrapper`）
- 適用版本：RFSoC_TX build 01（2026-10-15），輸出 `RFSoC_TX/output_data/01/`
- 來源：同事 PJ22045_1R8T rev0.12 的 47dr2（z2）+ Rex 的 Calibration_Gain_Control（8 通道 Calibration / Gain Control）
- 文件版本：v0.1（2026-10-16）

## 1. 閱讀指引

| 想知道 | 看哪裡 |
|---|---|
| z2 在整個 1R8T 系統中的角色 | 第 2 節 |
| design_1 頂層方塊圖與模組 | 第 3 節 |
| 8 個通道的資料路徑與對應 | 第 4 節 |
| 時脈與 reset | 第 5 節 |
| PS 位址表 | 第 6 節 |
| PS 程式與 BOOT.bin | 第 7 節 |
| Build 結果（timing / 用量） | 第 8 節 |
| 和同事 rev0.12 的差異、整合時遇到的問題 | 第 9、10 節 |
| 檔案位置與重新 build 的方法 | 第 11 節 |

各功能的細節見同目錄：`Register_Map.md`、`Calibration.md`、`Power_Fit.md`、`Gain_Control.md`、`RFDC_Configuration.md`。Aurora 傳輸與時間同步沿用同事設計，見 `docs/reference_rev0.12/SIGNAL_TRANSMISSION.md`、`TIMING_SYNC.md`。

## 2. 系統中的角色

PJ22045 1R8T 由三塊板子組成：

```
RFSoC_RX (z1)  ADC 00 ──Aurora──► VU13P (廣播 1 → 8) ──8 條 Aurora──► RFSoC_TX (z2) ──► 8 個 DAC
```

RFSoC_TX（z2）是**接收端 + 8 通道 RF 輸出**：

- 從 VU13P 收 8 路 Aurora（同一份 z1 ADC 資料），經同事的 `hier_rx_x0yN` 依 timestamp 對齊後送進 8 個通道。
- 每個通道（`cal_plus_gain_control_chN`）可在「Aurora 資料」與「本板 ADC 資料」之間切換（Signal Source Mux），再經 In-band FIR、Delay / Phase / Gain calibration 與 Gain Control 後送到 RFDC DAC。
- Gain Control 依 Power Fit 結果控制類比衰減器（74LVC595 shift register）與數位增益。

## 3. 頂層架構

![RFSoC_TX design_1 頂層架構](fig/tx_top.png)

### 3.1 頂層模組

| 類別 | 模組（design_1） | 說明 | 來源 |
|---|---|---|---|
| PS | `zynq_ultra_ps_e_0`、`rst_ps8_0_96M`、`smartconnect_0`（23 MI）、`axi_intc_0` | PS、AXI 互連 | 同事（smartconnect MI 6 → 23） |
| RFDC | `usp_rf_data_converter_1` | 8 ADC + 8 DAC，3.84 GSPS | 同事（Outclk、NCO 有修改，見 `RFDC_Configuration.md`） |
| Aurora | `aurora_gty_47drto13p_0`（BD container） | 4 quad × 2 core，header_extraction | 同事（未修改） |
| Aurora 接收鏈 | `hier_rx_x0y1` ~ `hier_rx_x0y4` | data_delay → FIFO → data_aligner（依 timestamp 釋放），含 ILA | 同事（未修改） |
| 時間 / 同步 | `hier_mts`、`timer_1`、`pl_sysref_int_0`、`regs_4_sysref_0`、`sync_pulse_to_level_1`、`xpm_cdc_gen_0/1` | SYSREF、MTS、系統時間 | 同事（未修改） |
| 控制 | `axi_gpio_arstn`（0xA001_0000）、`axi_gpio_pma_rst`（0xA002_0000）、`axi_delay`（0xA008_0000）、`DMA_Ctrl` | Aurora reset、延遲設定 | 同事（未修改） |
| 時脈 / reset | `util_ds_buf_0~3`、`dac_rst1` | FPGA_clk 256 MHz 等 | 同事（未修改） |
| 除錯 | `system_ila_0` | 監看 ch1 in_0（hier_rx_x0y2 / M_AXIS_C0） | 同事（未修改） |
| **通道** | **`cal_plus_gain_control_ch1` ~ `ch8`**（BD container） | Signal Source Mux、FIR、calibration、Power Fit、Gain Control、reg map、gain BRAM | **新增** |
| **ADC 合併** | **`rfdc_iq_combine_ch1` ~ `ch8`** | ADC I + Q（2 × 80-bit）→ 160-bit | **新增** |
| **系統暫存器** | **`system_reg_map`** | 8 通道共用的 Power Fit / AGC 參數 | **新增** |
| **外部輸入** | **`vio_ext_inputs`**（32 probe） | 每通道 rx_att_index、algo_analog_att_db、pulse_avg_amp、pulse_papr | **新增（暫時）** |

- 8 個通道**直接放在 design_1 頂層**，沒有包成 hierarchy（原因見 10.4）。
- 每個通道的內部架構（container `cal_plus_gain_control.bd`）：

```
s_axis_iq_in_0 ─┐
s_axis_iq_in_1 ─┴─► Signal Source Mux ─► axis_iq_bypass ─► IQ 拆分 ─┬─► in_band_flatness (FIR) ─► calibration (delay / phase / gain) ─► IQ 合併 ─► axis_iq_bypass ─► m_axis_iq
                                                                    └─► power_fit_top ─► agc_emu (TXAGC / RXAGC / SR) ─► gain index
addressable_reg_map ─► cal_cdc / agc_cdc ─► 各模組；status_snapshot ─► addressable_reg_map
```

## 4. 通道資料路徑

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

- 資料格式：160-bit AXIS，每拍 5 個複數 sample，每 sample 32-bit = {Q[15:0], I[15:0]}，256 MHz（= 1.28 GSPS）。
- 輸出到 DAC 的對應（s00 ~ s32）與同事原設計（`hier_rx` 直接送 DAC）相同。
- 開機預設 mem39 = 0（Aurora），mem38 = 0（完整處理）。用 XSDB 寫 `signal_source_select = 1` 即為本板 ADC loopback。
- Aurora 這一路的時間對齊（timestamp、`axi_delay`）與同事設計相同，見 `docs/reference_rev0.12/TIMING_SYNC.md`。

## 5. 時脈與 reset

| 時脈 | 頻率 | 來源 | 使用者 |
|---|---|---|---|
| FPGA_clk | 256 MHz | `FPGA_clk_p/n_0` → `util_ds_buf_0/IBUF_OUT` | RFDC 全部 AXIS、`hier_rx`、8 個通道的 clk（資料路徑）、combiner、VIO |
| clk_adc0 ~ 3 | **240 MHz** | RFDC ADC tile 0~3 outclk | 通道的 adc_clk（Gain Control / AGC）：ch1/2 ← adc0、ch3/4 ← adc1、ch5/6 ← adc2、ch7/8 ← adc3；clk_adc0 另驅動 `hier_mts` |
| clk_dac0 | 240 MHz | RFDC DAC tile 0 outclk | `hier_mts` |
| pl_clk0 | 100 MHz | PS | AXI-Lite（smartconnect、reg map、RFDC s_axi） |
| Aurora user_clk / txoutclk | — | GT | Aurora container 內部（同事設計） |

| Reset | 來源 | 使用者 |
|---|---|---|
| 通道 rst_n | `dac_rst1/peripheral_aresetn`（FPGA_clk domain） | 8 個通道的資料路徑 |
| 通道 S_AXI_resetn | `rst_ps8_0_96M/peripheral_aresetn` | reg map AXI |
| Aurora arstn / pma_rst | `axi_gpio_arstn` / `axi_gpio_pma_rst` | 同事設計，PS 不處理（人工操作，見同事 DESIGN.md §15） |

跨時脈：reg map（100 MHz）→ 資料路徑（256 MHz）由 `cal_cdc` 處理，→ AGC（240 MHz）由 `agc_cdc` 處理；FIR 係數以 XDC false path 處理（`constrs_1/new/cal_plus_gain_control.xdc`）。細節見 `Register_Map.md` 第 7 節。

## 6. PS 位址表

| 位址 | 大小 | 模組 | 來源 |
|---|---|---|---|
| 0xA000_0000 | 64 KB | `DMA_Ctrl/axi_lite_interface_0` | 同事 |
| 0xA001_0000 | 64 KB | `axi_gpio_arstn` | 同事 |
| 0xA002_0000 | 64 KB | `axi_gpio_pma_rst` | 同事 |
| 0xA003_0000 | 64 KB | `axi_intc_0` | 同事 |
| 0xA004_0000 | 256 KB | `usp_rf_data_converter_1`（RFDC） | 同事 |
| 0xA008_0000 | 64 KB | `axi_delay` | 同事 |
| 0xA009_0000 ~ 0xA009_7FFF | 8 × 4 KB | `cal_plus_gain_control_ch1~8/addressable_reg_map` | 新增 |
| 0xA009_8000 | 4 KB | `system_reg_map` | 新增 |
| 0xA009_A000 ~ 0xA00A_9FFF | 8 × 8 KB | `cal_plus_gain_control_ch1~8/calibration/axi_bram_ctrl_0`（gain 表） | 新增 |

## 7. PS 程式與 BOOT.bin

- Vitis workspace：`RFSoC_TX/software/`（`platform/` = build 01 XSA，zynqmp_fsbl + standalone A53-0；`app_component/` = PS 程式）。原始碼由 Calibration_Gain_Control 改成 8 通道，種子檔在 `software/app_src/`。
- 開機流程（`main.c`）：RFDC 初始化 → GPIO（EMIO）→ gain 表 BRAM（8 通道，寫入後讀回比對）→ reg map 初值（system + ch1~8）→ ADC threshold（8 ADC）→ RFDC reset → BMC handshake → MTS → handshake → MBS → handshake。
- 開機會停在第一次 BMC handshake（BMC 沒回 CMD 時會一直等）；BRAM / reg map / threshold 在 handshake 之前就已完成。
- 不處理同事的 `axi_gpio_arstn` / `axi_delay`。
- BOOT.bin：`output_data/01/BOOT.bin` 與 `software/app_component/BOOT.bin`（FSBL + bit + app，**沒有 PMUFW**，與 Calibration_Gain_Control 相同）。
- 執行期調整：`RFSoC_TX/reg_runtime/reg_rt.tcl`（XSDB），見 `Register_Map.md` 第 10 節。

## 8. Build 結果（build 01）

| 項目 | 結果 |
|---|---|
| Timing | WNS **0.000 ns** / WHS +0.010 ns，All user specified timing constraints are met，0 failing endpoint |
| Critical warning | synth 0 / impl 0 |
| LUT / FF | 213,477（50.2%）/ 343,806（40.4%） |
| BRAM / DSP | 566.5 tile（52.5%）/ 2,904（68.0%） |
| 8 個通道合計 | 約 120K LUT、202K FF、BRAM36 56 + BRAM18 8、DSP 2,904 |

| Clock | WNS (ns) | WHS (ns) |
|---|---|---|
| FPGA_clk（256 MHz） | 0.000 | +0.010 |
| RFADC0 / 1 / 2 / 3_CLK（240 MHz） | +0.127 / +0.080 / +0.065 / +0.093 | +0.013 / +0.011 / +0.010 / +0.013 |
| clk_pl_0（100 MHz） | +1.703 | +0.010 |

- 最差路徑：`timer_1/timestamp_reg[39]` → `hier_rx_x0y1/system_ila_0_2`（同事的 debug ILA），1 級邏輯、95% 是繞線。不在新增的邏輯中。
- 餘裕為 0：之後再加邏輯可能出現 timing 問題。可考慮在 ILA 的 timestamp probe 前加一級暫存器，或移除不需要的 debug ILA（會動到同事設計，需先討論）。
- **建議下一版修正**，一併處理其他餘裕很小的路徑：Power Fit 的 `data_aligner` → Signal Source Mux → `cw_power_calc_IQ` 平方 DSP（+0.003 ns，見 `Power_Fit.md` 12.1），以及 adc_clk 的 `txagc_calc` stage 2（+0.065 ns，見 `Gain_Control.md` §14 第 5 項）。
- 結果與 rev0.12_dev 的 build 03 完全相同（同一份設計，Save Project As 搬到本專案後重新 build）。

## 9. 與同事 rev0.12（47dr2）的差異

| 項目 | rev0.12 47dr2 | RFSoC_TX |
|---|---|---|
| DAC 資料來源 | `hier_rx_x0yN/M_AXIS_Cx` 直接接 DAC | 經 `cal_plus_gain_control_chN`（Aurora / ADC 選擇 + calibration + gain control） |
| ADC 用途 | 只有 m00~m03 經 combiner，輸出未使用 | 8 個 ADC 都經 `rfdc_iq_combine_chN` 接到各通道 in_1；4 個 flag + clear 接到各通道 |
| RFDC ADC Outclk | 30 MHz | 240 MHz（AGC adc_clk） |
| RFDC NCO | ADC 0.84 / DAC −0.84 GHz | ADC 1.04 / DAC −1.04 GHz（2.3 ~ 3.3 GHz） |
| smartconnect_0 | 6 MI | 23 MI |
| 新增模組 | — | 8 × cal_plus_gain_control、8 × rfdc_iq_combine、system_reg_map、vio_ext_inputs |
| 新增 IP / 檔案 | — | `onebit_cdc_fifo`（補回，見 10.2）、`cal_plus_gain_control.xdc`、40 個 RTL |
| PS 程式 | 無 | 8 通道版 app、BOOT.bin |
| 同事的 Aurora、hier_rx、hier_mts、timer、GPIO | — | 未修改 |

## 10. 整合時遇到的問題

### 10.1 RFDC ADC Outclk
同事設定 30 MHz，Calibration_Gain_Control 的 AGC 設計在 240 MHz；依 Rex 決定改成 240 MHz。`clk_adc0` 也驅動 `hier_mts/sync_out_latch_1`（latch，與頻率無關），**請同事確認 MTS 流程不受影響**。

### 10.2 `onebit_cdc_fifo` 遺失
`hier_mts/daq_timing_ctrl_0` 使用的 `onebit_cdc_fifo`，在 rev0.11 / rev0.12 release 的清理（`source/scripts/cleanup/remove_47dr*.txt`）中被刪掉，impl 會因 DRC INBB-3（black box）失敗。已從 Calibration_Gain_Control 補回同一份 xci（fifo_generator 13.2，1 bit × 16，independent clocks distributed RAM），47dr1 也有同樣問題。**請同事確認並更新 release。**

### 10.3 BDC variant 的 module_ref wrapper 沒產生
8 個 `cal_plus_gain_control_inst_N` 中有 6 種 module_ref 沒有 synth wrapper，OOC 報 `Synth 8-439`。`hardware/scripts/build_full_xsa.tcl` 會先檢查，缺 wrapper 才 `reset_target` + `generate_target`。

### 10.4 不包 hierarchy 的原因
同事的 `hier_rx_x0yN/M_AXIS_C0/C1` 在 BD 中是 **Monitor** mode（內部由 data_aligner 驅動）。直接接 IP 的 Slave port（RFDC DAC、container）沒問題；但若把 8 個通道包成 hierarchy，Vivado 會把新的 hier pin 也推成 Monitor，產生的 HDL 中 Aurora 資料不會接進通道（validate 不會報錯）。因此 8 個通道直接放在頂層。建議同事把這 8 個 pin 改成 Master，下游才能再包 hierarchy。

### 10.5 Build 時的隨機當機
工作站的 `~/.Xilinx` 共用造成 OOC run 啟動時偶發 Bus error；build 腳本會 reset 失敗的 run 後重跑。RFSoC_TX build 01 曾有一次 RFDC OOC run 的輔助程序當掉、主程序一直等待，處理方式是停掉 build 後重新執行（已完成的 run 保留）。

## 11. 檔案與重新 build

```
RFSoC_TX/
├ hardware/RFSoC_TX.xpr            Vivado 專案（ip_repo 在 hardware/ip_repo，與 release 資料夾無關）
├ hardware/scripts/
│   build_and_boot.sh <idx>        一次完成：Vivado build → Vitis 更新 → 重編 app → bootgen → MANIFEST（timing 不收斂就停止）
│   build_full_xsa.tcl <idx>       只做 Vivado build（wrapper / variant 檢查、失敗自動重跑）
├ software/                        Vitis workspace（platform / app_component / app_src）
├ reg_runtime/                     XSDB 腳本
└ output_data/<idx>/               RFSoC_TX_<idx>.bit / .ltx / .xsa、BOOT.bin、MANIFEST.txt
（文件已移到 release 根目錄 docs/02_RFSoC_TX/：本文件與各功能文件、Reg_map Excel、tools）
```

重新 build：`RFSoC_TX/hardware/scripts/build_and_boot.sh 02`（輸出到 `output_data/02/`）。

## 12. 待確認

已知現象與後續版本的優化建議集中在 `Follow_Up.md`（F1 ~ F5 後續版本優化、T1 ~ T3 TRM 上線後處理）。

1. RFDC ADC Outclk 改成 240 MHz 對 `hier_mts` 的影響（10.1）。
2. `onebit_cdc_fifo` 的設定與 release 更新（10.2）。
3. 同事 `hier_rx_*` 的 `M_AXIS_C0/C1` 是否改成 Master（10.4）。
4. Timing 餘裕為 0（第 8 節），建議下一版修正。
5. Gain Control 的 SR 腳位（Reg1~5 SER / SRCLK / RCLK）沒有拉到頂層、沒有腳位約束：本版只驗證 **IF 輸出端**，TRM 相關功能（SR、TX / RX 模式、RXAGC）是 TRM 板上線後才需要的功能，屆時再處理（見 `Gain_Control.md` §1）。VIO 是暫時的輸入來源。
6. 開機預設 mem39 = 0（Aurora）且走完整處理，與同事原本「Aurora 直接送 DAC」不同；要恢復原行為需 mem38 = 1。
7. sys14 build_version 目前為 0（build 腳本漏設，`Follow_Up.md` F4）。
8. 尚未上板驗證。

## 13. 修訂歷程

| 版本 | 日期 | 說明 |
|---|---|---|
| v0.1 | 2026-10-16 | 第一版，對應 RFSoC_TX build 01；標明本版驗證範圍（IF 輸出端）與 timing 建議下一版修正 |
