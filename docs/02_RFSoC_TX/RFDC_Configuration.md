# RFSoC_TX — RFDC Configuration

- 專案：PJ22045_1R8T_release_Rex_rev0.1_20261015 / RFSoC_TX（z2，接收 Aurora 並由 8 個 DAC 輸出）
- 適用版本：`RFSoC_TX/hardware/RFSoC_TX.xpr`，build 01（2026-10-15）
- 參數來源：以 Vivado 2025.2 唯讀開啟專案讀出的 RFDC（`usp_rf_data_converter_1`，v2.6）完整設定（`docs/tools/rfdc_params_TX.txt`，本文件由 `docs/tools/mk_doc_rfdc.py` 產生）
- 文件版本：v0.1（2026-10-16）

## 1. 閱讀指引

| 想知道 | 看哪裡 |
|---|---|
| RFDC 在這塊板子上做什麼 | 第 2 節 |
| 各 tile 的時脈、取樣率、PLL | 第 3 節 |
| ADC / DAC 每個通道的 mixer、NCO、decimation / interpolation | 第 4、5 節 |
| AXIS 與輸出時脈接到哪裡 | 第 6 節 |
| 頻率規劃（NCO 與 RF 頻段） | 第 6 節 |
| 和同事版本的差異 | 第 7 節 |
| PS 端的設定流程 | 第 8 節 |

## 2. 功能概述

z2 的 RFDC 有兩個用途：

- **DAC（8 個，s00 ~ s32）**：輸出 8 個通道的 RF。每通道的資料來自 `cal_plus_gain_control_chN/m_axis_iq`（經 Signal Source Mux 選擇 Aurora 或本板 ADC，再經 calibration / gain control）。
- **ADC（8 個，m00 ~ m33）**：每個 ADC 的 I / Q 經 `rfdc_iq_combine_chN` 合併成 160-bit，接到 `cal_plus_gain_control_chN/s_axis_iq_in_1`（ADC loopback 來源）。ADC 的 over_range / over_voltage / over_threshold flag 給 RXAGC 使用。

```
ADC m{T}{0/2} (I) ─┐
ADC m{T}{1/3} (Q) ─┴─► rfdc_iq_combine_chN ─► cal_plus_gain_control_chN (in_1) ─┐
hier_rx_x0yN (Aurora) ─────────────────────────────► cal_plus_gain_control_chN (in_0) ─┴─► m_axis_iq ─► DAC s{T}{0/2}
RFDC clk_adcT (240 MHz) ─► cal_plus_gain_control_chN/adc_clk（AGC）
```

- 元件：`design_1/usp_rf_data_converter_1`（Zynq UltraScale+ RFSoC Data Converter v2.6），xczu47dr：4 個 ADC tile、4 個 DAC tile。
- AXI-Lite 控制介面 `s_axi` 在 0xA004_0000（256 KB），時脈 pl_clk0 100 MHz。
- 所有 ADC / DAC AXIS 都在 **FPGA_clk 256 MHz**（`util_ds_buf_0/IBUF_OUT`）。

## 3. Tile 與時脈

### 3.1 ADC tiles

| Tile | Enable | Sampling (GSPS) | Refclk (MHz) | PLL | Clock source | Clock distribution | Fabric (MHz) | Outclk (MHz) | MTS |
|---|---|---|---|---|---|---|---|---|---|
| ADC Tile 224（adc0） | 1 | 3.84 | 3840.000 | Off | Tile 225 | Off | 256.000 | 240.000 | true |
| ADC Tile 225（adc1） | 1 | 3.84 | 256.000 | On | Tile 225 | PLL output | 256.000 | 240.000 | true |
| ADC Tile 226（adc2） | 1 | 3.84 | 3840.000 | Off | Tile 225 | Off | 256.000 | 240.000 | true |
| ADC Tile 227（adc3） | 1 | 3.84 | 3840.000 | Off | Tile 225 | Off | 256.000 | 240.000 | true |

### 3.2 DAC tiles

| Tile | Enable | Sampling (GSPS) | Refclk (MHz) | PLL | Clock source | Clock distribution | Fabric (MHz) | Outclk (MHz) | MTS |
|---|---|---|---|---|---|---|---|---|---|
| DAC Tile 228（dac0） | 1 | 3.84 | 256.000 | On | Tile 228 | Input Refclk | 256.000 | 240.000 | true |
| DAC Tile 229（dac1） | 1 | 3.84 | 256.000 | On | Tile 228 | Off | 256.000 | 240.000 | true |
| DAC Tile 230（dac2） | 1 | 3.84 | 256.000 | On | Tile 228 | Off | 256.000 | 240.000 | true |
| DAC Tile 231（dac3） | 1 | 3.84 | 256.000 | On | Tile 228 | Off | 256.000 | 240.000 | true |

- Clock source / distribution：ADC tile 225（adc1）使用 PLL（refclk 256 MHz），並把 PLL 輸出分配給其他 ADC tile（其他 ADC tile 的 refclk = 3840 MHz、PLL 關閉）；DAC tile 228（dac0）以 256 MHz refclk 啟用 PLL 並分配 input refclk。
- Fabric（AXIS）時脈 256 MHz；Outclk 是 RFDC 輸出給 PL 的 `clk_adcN` / `clk_dacN`（見第 6 節）。
- 全部 tile 開啟 Multi-Tile Sync（MTS），SYSREF 來源 = 1。
- DAC VOP mode = 1，各 DAC tile VOP = 32 mA。

## 4. ADC 設定

| ADC | Data type | Mixer | Mixer mode | NCO (GHz) | Nyquist | Decimation | Data width（sample / clk） | AXIS |
|---|---|---|---|---|---|---|---|---|
| ADC 00 | I/Q | Fine | Real → I/Q | 1.04 | Zone 2 | 3x | 5 | m00 (I) / m01 (Q) |
| ADC 02 | I/Q | Fine | Real → I/Q | 1.04 | Zone 2 | 3x | 5 | m02 (I) / m03 (Q) |
| ADC 10 | I/Q | Fine | Real → I/Q | 1.04 | Zone 2 | 3x | 5 | m10 (I) / m11 (Q) |
| ADC 12 | I/Q | Fine | Real → I/Q | 1.04 | Zone 2 | 3x | 5 | m12 (I) / m13 (Q) |
| ADC 20 | I/Q | Fine | Real → I/Q | 1.04 | Zone 2 | 3x | 5 | m20 (I) / m21 (Q) |
| ADC 22 | I/Q | Fine | Real → I/Q | 1.04 | Zone 2 | 3x | 5 | m22 (I) / m23 (Q) |
| ADC 30 | I/Q | Fine | Real → I/Q | 1.04 | Zone 2 | 3x | 5 | m30 (I) / m31 (Q) |
| ADC 32 | I/Q | Fine | Real → I/Q | 1.04 | Zone 2 | 3x | 5 | m32 (I) / m33 (Q) |

- 每個 tile 啟用 4 個 ADC slice（I/Q 模式下每個 ADC 佔兩個 slice，輸出 I、Q 兩條 AXIS）。
- Data width 5：每個 256 MHz 時脈輸出 5 個 16-bit sample（每條 AXIS 80-bit）；3.84 GSPS ÷ 3（decimation）= 1.28 GSPS = 256 MHz × 5。
- ADC Real-time signal（RTS）：true（over_range / over_voltage / over_threshold 等 flag 由 PL 腳位輸出）。
- 目前全部 ADC 的 NCO：1.04 GHz。

## 5. DAC 設定

| DAC | Mixer | Mixer mode | NCO (GHz) | Nyquist | Interpolation | Data width（16-bit word / clk） | Inverse sinc | Mode | Decoder |
|---|---|---|---|---|---|---|---|---|---|
| DAC 00（s00） | Fine | I/Q → Real | -1.04 | Zone 2 | 3x | 10 | On | - | - |
| DAC 02（s02） | Fine | I/Q → Real | -1.04 | Zone 2 | 3x | 10 | On | - | - |
| DAC 10（s10） | Fine | I/Q → Real | -1.04 | Zone 2 | 3x | 10 | On | - | - |
| DAC 12（s12） | Fine | I/Q → Real | -1.04 | Zone 2 | 3x | 10 | On | - | - |
| DAC 20（s20） | Fine | I/Q → Real | -1.04 | Zone 2 | 3x | 10 | On | - | - |
| DAC 22（s22） | Fine | I/Q → Real | -1.04 | Zone 2 | 3x | 10 | On | - | - |
| DAC 30（s30） | Fine | I/Q → Real | -1.04 | Zone 2 | 3x | 10 | On | - | - |
| DAC 32（s32） | Fine | I/Q → Real | -1.04 | Zone 2 | 3x | 10 | On | - | - |

- 每個 tile 啟用 slice 0、2（共 8 個 DAC）；slice 1、3 關閉。
- Data width 10：每個 256 MHz 時脈輸入 10 個 16-bit word = 5 個複數 sample（160-bit AXIS，每 sample 32-bit = {Q[15:0], I[15:0]}）。
- 目前全部 DAC 的 NCO：-1.04 GHz。

## 6. AXIS 與輸出時脈

| RFDC AXIS | 接到 |
|---|---|
| m00_axis | `/rfdc_iq_combine_ch1/s0` |
| m01_axis | `/rfdc_iq_combine_ch1/s1` |
| m02_axis | `/rfdc_iq_combine_ch2/s0` |
| m03_axis | `/rfdc_iq_combine_ch2/s1` |
| m10_axis | `/rfdc_iq_combine_ch3/s0` |
| m11_axis | `/rfdc_iq_combine_ch3/s1` |
| m12_axis | `/rfdc_iq_combine_ch4/s0` |
| m13_axis | `/rfdc_iq_combine_ch4/s1` |
| m20_axis | `/rfdc_iq_combine_ch5/s0` |
| m21_axis | `/rfdc_iq_combine_ch5/s1` |
| m22_axis | `/rfdc_iq_combine_ch6/s0` |
| m23_axis | `/rfdc_iq_combine_ch6/s1` |
| m30_axis | `/rfdc_iq_combine_ch7/s0` |
| m31_axis | `/rfdc_iq_combine_ch7/s1` |
| m32_axis | `/rfdc_iq_combine_ch8/s0` |
| m33_axis | `/rfdc_iq_combine_ch8/s1` |
| s00_axis | `/cal_plus_gain_control_ch1/m_axis_iq` |
| s02_axis | `/cal_plus_gain_control_ch2/m_axis_iq` |
| s10_axis | `/cal_plus_gain_control_ch3/m_axis_iq` |
| s12_axis | `/cal_plus_gain_control_ch4/m_axis_iq` |
| s20_axis | `/cal_plus_gain_control_ch5/m_axis_iq` |
| s22_axis | `/cal_plus_gain_control_ch6/m_axis_iq` |
| s30_axis | `/cal_plus_gain_control_ch7/m_axis_iq` |
| s32_axis | `/cal_plus_gain_control_ch8/m_axis_iq` |

| RFDC 時脈輸入 | 來源 | 頻率 |
|---|---|---|
| m0_axis_aclk | `util_ds_buf_0_IBUF_OUT` | 256.000 MHz |
| m1_axis_aclk | `util_ds_buf_0_IBUF_OUT` | 256.000 MHz |
| m2_axis_aclk | `util_ds_buf_0_IBUF_OUT` | 256.000 MHz |
| m3_axis_aclk | `util_ds_buf_0_IBUF_OUT` | 256.000 MHz |
| s0_axis_aclk | `util_ds_buf_0_IBUF_OUT` | 256.000 MHz |
| s1_axis_aclk | `util_ds_buf_0_IBUF_OUT` | 256.000 MHz |
| s2_axis_aclk | `util_ds_buf_0_IBUF_OUT` | 256.000 MHz |
| s3_axis_aclk | `util_ds_buf_0_IBUF_OUT` | 256.000 MHz |
| s_axi_aclk | `zynq_ultra_ps_e_0_pl_clk0` | 100.000 MHz |

| RFDC 輸出時脈 | 頻率 | 使用者 |
|---|---|---|
| clk_adc0 | 240 MHz | hier_mtsclk、cal_plus_gain_control_ch2adc_clk、cal_plus_gain_control_ch1adc_clk |
| clk_adc1 | 240 MHz | cal_plus_gain_control_ch4adc_clk、cal_plus_gain_control_ch3adc_clk |
| clk_adc2 | 240 MHz | cal_plus_gain_control_ch6adc_clk、cal_plus_gain_control_ch5adc_clk |
| clk_adc3 | 240 MHz | cal_plus_gain_control_ch8adc_clk、cal_plus_gain_control_ch7adc_clk |
| clk_dac0 | 240 MHz | hier_mtsclk3 |
| clk_dac1 | 240 MHz | （未使用） |
| clk_dac2 | 240 MHz | （未使用） |
| clk_dac3 | 240 MHz | （未使用） |

### 6.1 RF 頻段與 NCO

ADC / DAC 取樣率都是 **3.84 GSPS**，Nyquist zone 都設在 **Zone 2**（1.92 ~ 3.84 GHz）。在 Zone 2 中，RF 頻率 f 會折到 3.84 − f：

| 項目 | rev0.12（同事原設定） | **Rex rev0.1（目前）** |
|---|---|---|
| ADC NCO | 0.84 GHz | **1.04 GHz** |
| DAC NCO | −0.84 GHz | **−1.04 GHz** |
| 對應 RF 中心頻率（3.84 GHz − NCO 絕對值） | 3.0 GHz | **2.8 GHz** |
| 使用頻段（中心 ± 0.5 GHz） | 2.5 ~ 3.5 GHz | **2.3 ~ 3.3 GHz** |

- ADC：Fine mixer，Real → I/Q，把 RF 降到基頻後 3x decimation，輸出 1.28 GSPS 的複數 I/Q（每 256 MHz 時脈 5 個 sample，I、Q 各一條 AXIS）。
- DAC：輸入 1.28 GSPS 複數 I/Q（每時脈 5 個 sample），3x interpolation 後 Fine mixer I/Q → Real 升頻，輸出到 Zone 2。
- NCO 的正負號（ADC +1.04、DAC −1.04）與 Zone 2 的頻譜反轉一起決定實際的 RF 位置與頻譜方向；目前設定與 Calibration_Gain_Control（source 板）相同。
- 本表的頻率換算是依 RFDC 設定推算，**尚未在板上量測確認**。

## 7. 與同事版本（rev0.12）的差異

| 項目 | rev0.12 47dr2（同事） | RFSoC_TX | 原因 |
|---|---|---|---|
| ADC0~3 Outclk（clk_adc0~3） | 30 MHz | **240 MHz** | clk_adcN 是 Gain Control（AGC）的 adc_clk，對齊 Calibration_Gain_Control 的設計（2026-10-14） |
| ADC NCO（8 組） | 0.84 GHz | **1.04 GHz** | 使用頻段改成 2.3 ~ 3.3 GHz（2026-10-15） |
| DAC NCO（8 組） | −0.84 GHz | **−1.04 GHz** | 同上 |
| ADC AXIS 用途 | m00/m01、m02/m03 經 combiner 後沒有使用 | 8 個 ADC 都經 `rfdc_iq_combine_chN` 接到各通道 in_1 | ADC loopback 路徑 |
| DAC AXIS 來源 | `hier_rx_x0yN` 直接接 DAC | `cal_plus_gain_control_chN/m_axis_iq` | 8 通道 calibration / gain control |
| ADC flag / clear | 未使用 | `adcT_01/23` 的 4 個 flag 與 clear_or / clear_ov 接到 chN | RXAGC |

`clk_adc0` 也驅動同事原有的 `hier_mts/sync_out_latch_1`（只是 latch，與頻率無關；請同事確認 MTS 流程不受影響）。

## 8. PS 端設定流程

PS 程式（`RFSoC_TX/software/app_component/src/sources/rfdc.c`、`main.c`，沿用 Calibration_Gain_Control）：

1. `rfdc_dev_init()`：XRFdc 初始化。
2. `adcInitThresh()`（`adcThresholds.c`）：8 個 ADC 都設定 threshold 0 / 1（chN = tile (N−1)/2、block (N−1)%2）：
   - threshold 0：hysteresis mode，avg 10，under 10950（−3.5 dBFS）/ over 11599（−3.0 dBFS）→ `over_threshold1`
   - threshold 1：hysteresis mode，avg 10，under 2750（−15.5 dBFS）/ over 2913（−15.0 dBFS）→ `over_threshold2`
3. `rfdc_reset_dc()`：依序 shutdown / startup 所有啟用的 ADC（順序 1, 0, 2, 3）與 DAC tile。
4. GPIO handshake（BMC）→ `rfdc_mts_exec()`：DAC / ADC 各做 multi-tile sync（tiles 0x0F）→ handshake。
5. `rfdc_mbs_prep()`：關閉 MTS sysref；DAC / ADC mixer、DAC QMC、DAC coarse delay 的 event source 改成 SYSREF，reset DAC NCO phase → handshake。

NCO 頻率使用 IP 中的設定，PS 不會改寫（只改 event source）。

## 9. 待確認

1. 頻段與頻譜方向（2.3 ~ 3.3 GHz）尚未在板上量測確認。
2. ADC Outclk 30 → 240 MHz 對同事 `hier_mts`（MTS / SYSREF）流程的影響，需和同事確認。
3. RFSoC_RX（z1）的 ADC NCO 已同步改成 1.04 GHz（Rex rev0.1）；舊版 z1（rev0.11 / rev0.12 release）仍是 0.84 GHz，兩者不能混用。

## 10. 修訂歷程

| 版本 | 日期 | 說明 |
|---|---|---|
| v0.1 | 2026-10-16 | 第一版，對應 RFSoC_TX build 01（NCO 1.04 / −1.04 GHz） |
