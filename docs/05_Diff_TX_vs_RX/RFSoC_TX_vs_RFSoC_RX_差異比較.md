# RFSoC_TX vs RFSoC_RX — Release 差異比較

- 比較對象：`PJ22045_1R8T_release_Rex_v0.1.zip` 內的 `RFSoC_TX/` 與 `RFSoC_RX/`（20261015_v003_Rex_PL_PS）
- 比較方式：解壓後逐檔 diff；專案名稱 `RFSoC_TX` / `RFSoC_RX` 統一替換成 `PRJ`、移除 xci `checksum` 行，避免只因專案名稱不同而產生的雜訊
- 附件：
  - `RFSoC_TX_vs_RFSoC_RX_key.diff`：重點檔案的 unified diff（約 300 行，建議先看）
  - `RFSoC_TX_vs_RFSoC_RX_full.diff`：PL_source + PS_source 完整 unified diff（`diff -ruN`，約 12 萬行；`-` = TX、`+` = RX）
  - `RFSoC_TX_vs_RFSoC_RX_filelist.txt`：逐檔狀態清單（ONLY_TX / ONLY_RX / MODIFIED + 差異行數）

## 1. 總覽

| 項目 | RFSoC_TX（z2，接收 Aurora → DAC） | RFSoC_RX（z1，ADC → Aurora） |
|---|---|---|
| 系統角色 | 從 VU13P 收 8 條 Aurora，每條經 `cal_plus_gain_control_chN` 驅動一個 DAC | ADC 00 經 packetizer 走 X0Y1 core1 Aurora 送 VU13P；其餘 7 個 ADC 直接回送同編號 DAC |
| Part / Vivado / top | xczu47dr-ffvg1517-2-i / 2025.2 / design_1_wrapper | 相同 |
| 頂層 port | 49 個 | **完全相同** |
| BD cell 數（design_1） | 87 | 44 |
| Rex 修改幅度 | 大（8 通道 Calibration / Gain Control、reg map、PS app） | 小（只改 NCO、補 onebit_cdc_fifo、重建 wrapper） |
| PS_source | `main.c` + `sources/`（7 檔） | **空** |
| XSA | `RFSoC_TX_01.xsa`（11.6 MB） | `RFSoC_RX.xsa`（3.9 MB） |
| Bitstream | 2026/10/15 12:09，md5 `38374e8b…` | 2026/10/15 09:23，md5 `34da87be…` |
| LTX debug core | 32 個（ILA / VIO） | 16 個 |
| ip_repo | 509 檔 | **與 TX 完全相同** |

檔案層級統計（PL_source + PS_source，不含 ip_repo）：相同 155 檔、只在 TX 135 檔、只在 RX 19 檔、內容不同 20 檔。

## 2. Block Design（design_1.bd）差異

### 2.1 共用 cell（21 個）

`DMA_Ctrl`、`aurora_gty_47drto13p_0`（container，子 BD 內容相同）、`axi_gpio_arstn`、`axi_gpio_pma_rst`、`axi_intc_0`、`dac_rst1`、`hier_mts`、`pl_sysref_int_0`、`regs_4_sysref_0`、`rst_ps8_0_96M`、`smartconnect_0`、`sync_pulse_to_level_1`、`timer_1`、`usp_rf_data_converter_1`、`util_ds_buf_0~3`、`xpm_cdc_gen_0/1`、`zynq_ultra_ps_e_0`

共用 cell 中參數不同的只有：

| Cell | 參數 | TX | RX |
|---|---|---|---|
| smartconnect_0 | NUM_MI | **23** | 5 |
| usp_rf_data_converter_1 | ADC0~3_Outclk_Freq | **240 MHz** | 30 MHz |
| usp_rf_data_converter_1 | DAC_Mode30/32、DAC_Decoder_Mode30/32 | 0（user 設定） | 0（default）— 值相同，只差 value_src |

> RFDC 其餘設定（取樣率 3.84 GSPS、Fabric 256 MHz、NCO ADC 1.04 / DAC −1.04 GHz、MTS 等）兩邊一致，`docs/tools/rfdc_params_TX/RX.txt` 比對結果也只差 ADC Outclk。

### 2.2 只在 RFSoC_TX 的 cell

| 群組 | Cell | 說明 |
|---|---|---|
| 8 通道處理 | `cal_plus_gain_control_ch1~8` | BD container（`cal_plus_gain_control.bd`），Calibration / Gain Control / Signal Source Mux |
| ADC 合併 | `rfdc_iq_combine_ch1~8` | RTL `axi_stream_combininput`，ADC m_xx → 通道 in_1 |
| Aurora 接收鏈 | `hier_rx_x0y1~4`（各含 data_delay ×2、axis_data_fifo ×2、data_aligner ×2、system_ila ×2） | Aurora → 通道 in_0 |
| 暫存器 | `system_reg_map`、`axi_delay`（axi_gpio） | |
| Debug | `system_ila_0`、`vio_ext_inputs`（32 probe，暫時的外部輸入） | |

### 2.3 只在 RFSoC_RX 的 cell

| Cell | 說明 |
|---|---|
| `axi_stream_combininp_adc00/02/10/12/20/22/30/32` | RTL `axi_stream_combininput`，ADC → DAC 回送（adc00 → Aurora） |
| `axis_packetizer_0` | ADC 00 打包後送 Aurora X0Y1 core1 |
| `system_ila_1`、`vio_data_delay` | Debug |
| `xlconstant_0`、`ilconcat_1` | 常數 / concat |

### 2.4 RFDC AXIS 連接

| RFDC port | TX 接到 | RX 接到 |
|---|---|---|
| m00/m01 | rfdc_iq_combine_ch1 | axi_stream_combininp_adc00 → packetizer → Aurora |
| m02/03 … m32/33 | rfdc_iq_combine_ch2~8 | axi_stream_combininp_adc02~32 |
| s00 | cal_plus_gain_control_ch1 | **未接** |
| s02 … s32 | cal_plus_gain_control_ch2~8 | axi_stream_combininp_adc02~32（ADC 直接回送） |
| clk_adc0~3（Outclk） | 240 MHz → hier_mts + 各通道 adc_clk | 30 MHz → 只有 clk_adc0 接 hier_mts |

## 3. Address Map

前 5 段兩邊相同（DMA_Ctrl 0xA000_0000、axi_gpio_arstn 0xA001_0000、axi_gpio_pma_rst 0xA002_0000、axi_intc_0 0xA003_0000、RFDC 0xA004_0000 / 256K）。TX 另外多出：

| 位址 | 大小 | 目標 |
|---|---|---|
| 0xA008_0000 | 64K | axi_delay |
| 0xA009_0000 + 0x1000 × (N−1) | 4K × 8 | cal_plus_gain_control_chN / addressable_reg_map |
| 0xA009_8000 | 4K | system_reg_map |
| 0xA009_A000 + 0x2000 × (N−1) | 8K × 8 | cal_plus_gain_control_chN / gain BRAM |

## 4. 原始檔 / 約束

| 類別 | 只在 TX | 只在 RX |
|---|---|---|
| RTL | `new/cal_plus_gain_control/` 44 檔（含 `agc_emu/` 15 檔、`squareroot/` 3 檔）；`imports/new/data_aligner.v`、`data_delay.v` | `imports/new/axis_packetizer.v`、`new/axi_stream_combininput.v` |
| BD | `cal_plus_gain_control.bd` + 其 IP | `aurora_gty_47drto13p.bda` |
| XDC | `constrs_1/new/cal_plus_gain_control.xdc`（reg map → 資料時脈 false path） | — |
| xpr | File 項目 74、Run 752 | File 項目 24、Run 254 |

內容不同但同名的檔案（20 個），實際有意義的只有：

| 檔案 | 差異 |
|---|---|
| `design.xdc` | 只差一行註解（`ibert_47dr2To13p` vs `ibert_47dr1To13p`），**腳位相同** |
| `axi_stream_combininput.v`（TX 在 cal_plus_gain_control/、RX 在 new/） | RX 版多了 `assign m1_tdata = m_tdata; assign m1_tvalid = m_tvalid;`（第二組輸出） |
| `design_1_sync_out_latch_0_1.xci` | 時脈 FREQ_HZ 240 MHz vs 30 MHz（跟著 ADC Outclk） |
| `design_1_axi_stream_combininp_0_0.xci` | cell_name `rfdc_iq_combine_ch1` vs `axi_stream_combininp_adc00`（同一個 IP 實例被改名） |
| `design_1_smartconnect_0_1.xci` | NUM_MI 23 vs 5（其餘 ~1700 行是 M06~M22 介面參數） |
| `design_1_usp_rf_data_converter_1_1.xci` | ADC Outclk 240 vs 30 MHz |
| `design_1.bd` / `.bda` / `ui/*.ui` | 上述 BD 結構差異的展開 |
| aurora container 下 ILA xci、`ui/*.ui` | 只有 `value_permission` 等 metadata 與 GUI 座標，**功能相同** |
| `onebit_cdc_fifo.xci` | 只差 gen_directory 路徑（見 §6） |

## 5. 資源使用（由 XSA `availableResources` 推算，ZU47DR 總量 LUT 425,280 / FF 850,560 / BRAM 1,080 / DSP 4,272）

| | RFSoC_TX | RFSoC_RX |
|---|---|---|
| LUT | ≈ 213,477（50.2%） | ≈ 62,320（14.7%） |
| FF | ≈ 343,806（40.4%） | ≈ 85,553（10.1%） |
| BRAM | ≈ 566（52.4%） | ≈ 224（20.7%） |
| DSP | ≈ 2,904（68.0%） | 0 |
| Timing（Design Notes） | WNS 0.000 / WHS +0.010 ns | WNS +0.063 / WHS +0.010 ns |

> 這是由 XSA 剩餘資源反推的數字，正式數字請以 impl utilization report 為準。PS 設定（`psu_init.c/tcl`）兩邊完全相同。

## 6. 需要注意的地方

1. **TX PS_source 不完整**：`main.c` include 了 `rfdc.h`、`gpio.h`，並呼叫 `rfdc_dev_init`、`gpio_emio_init`、`rfdc_mts_exec`、`rfdc_reset_dc`、`gpio_handshake`，但 release 中沒有 `rfdc.c/h`、`gpio.c/h`，只靠 release 內容無法重新編譯 PS app。建議補進 `PS_source/sources/`。
2. **RX `onebit_cdc_fifo.xci` 的 gen_directory 指向 `../../../../RFSoC_TX.gen/...`**（從 TX 直接複製過來，沒改路徑）。Vivado 通常會重新產生，但在乾淨環境開 RX 專案時可能出現 IP 需要 regenerate / 找不到 output product 的警告，建議在 RX 專案內 reset + regenerate 後重新存檔。
3. **ADC Outclk 不一致**：TX 240 MHz、RX 30 MHz（RX 維持同事原設定）。兩邊 `hier_mts/clk` 都吃 clk_adc0，Design Notes 已列「ADC Outclk 改 240 MHz 對 hier_mts 的影響」待確認。
4. **RX 沒有 PS 程式**，RFDC / MTS 開機依同事原流程；NCO 已改成 1.04 / −1.04 GHz，不可與舊版 z1（0.84 GHz）混用。
5. **TX timing 餘裕 0**（WNS 0.000 ns），RX 有 +0.063 ns。
6. 兩邊 bitstream 檔名與 XSA 內的 bit 名稱不同（`RFSoC_TX.bit` vs XSA 內 `RFSoC_TX_01.bit`；RX 同樣），但 md5 一致，是同一份 bitstream。
