# RFSoC_RX — RFDC Configuration

- 專案：PJ22045_1R8T_release_Rex_rev0.1_20261015 / RFSoC_RX（z1，ADC 訊號源，經 Aurora 送往 VU13P）
- 適用版本：`RFSoC_RX/hardware/RFSoC_RX.xpr`，build 01（2026-10-15）
- 參數來源：以 Vivado 2025.2 唯讀開啟專案讀出的 RFDC（`usp_rf_data_converter_1`，v2.6）完整設定（`docs/tools/rfdc_params_RX.txt`，本文件由 `docs/tools/mk_doc_rfdc.py` 產生）
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

z1 的 RFDC：

- **ADC 00（m00 / m01）**：系統的訊號源。經 `axi_stream_combininp_adc00` 合併成 160-bit → `axis_packetizer_0` → Aurora（X0Y1 core1）→ VU13P → 廣播到 z2 的 8 個通道。
- **其他 7 個 ADC（02 ~ 32）**：各自經 `axi_stream_combininp_adcXX` 回送到同編號的 DAC（本板 loopback）。
- **DAC 00（s00）沒有使用**（ADC 00 送到 Aurora）。

```
ADC m00/m01 ─► axi_stream_combininp_adc00 ─► axis_packetizer_0 ─► Aurora X0Y1 core1 ─► VU13P
ADC mXY / mX(Y+1) ─► axi_stream_combininp_adcXY ─► DAC sXY   (XY = 02, 10, 12, 20, 22, 30, 32)
```

- 元件：`design_1/usp_rf_data_converter_1`（Zynq UltraScale+ RFSoC Data Converter v2.6），xczu47dr：4 個 ADC tile、4 個 DAC tile。
- AXI-Lite 控制介面 `s_axi` 在 0xA004_0000（256 KB），時脈 pl_clk0 100 MHz。
- 所有 ADC / DAC AXIS 都在 **FPGA_clk 256 MHz**（`util_ds_buf_0/IBUF_OUT`）。

## 3. Tile 與時脈

### 3.1 ADC tiles

| Tile | Enable | Sampling (GSPS) | Refclk (MHz) | PLL | Clock source | Clock distribution | Fabric (MHz) | Outclk (MHz) | MTS |
|---|---|---|---|---|---|---|---|---|---|
| ADC Tile 224（adc0） | 1 | 3.84 | 3840.000 | Off | Tile 225 | Off | 256.000 | 30.000 | true |
| ADC Tile 225（adc1） | 1 | 3.84 | 256.000 | On | Tile 225 | PLL output | 256.000 | 30.000 | true |
| ADC Tile 226（adc2） | 1 | 3.84 | 3840.000 | Off | Tile 225 | Off | 256.000 | 30.000 | true |
| ADC Tile 227（adc3） | 1 | 3.84 | 3840.000 | Off | Tile 225 | Off | 256.000 | 30.000 | true |

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
| m00_axis | `/axi_stream_combininp_adc00/s0` |
| m01_axis | `/axi_stream_combininp_adc00/s1` |
| m02_axis | `/axi_stream_combininp_adc02/s0` |
| m03_axis | `/axi_stream_combininp_adc02/s1` |
| m10_axis | `/axi_stream_combininp_adc10/s0` |
| m11_axis | `/axi_stream_combininp_adc10/s1` |
| m12_axis | `/axi_stream_combininp_adc12/s0` |
| m13_axis | `/axi_stream_combininp_adc12/s1` |
| m20_axis | `/axi_stream_combininp_adc20/s0` |
| m21_axis | `/axi_stream_combininp_adc20/s1` |
| m22_axis | `/axi_stream_combininp_adc22/s0` |
| m23_axis | `/axi_stream_combininp_adc22/s1` |
| m30_axis | `/axi_stream_combininp_adc30/s0` |
| m31_axis | `/axi_stream_combininp_adc30/s1` |
| m32_axis | `/axi_stream_combininp_adc32/s0` |
| m33_axis | `/axi_stream_combininp_adc32/s1` |
| s00_axis | （未接） |
| s02_axis | `/axi_stream_combininp_adc02/m` |
| s10_axis | `/axi_stream_combininp_adc10/m` |
| s12_axis | `/axi_stream_combininp_adc12/m` |
| s20_axis | `/axi_stream_combininp_adc20/m` |
| s22_axis | `/axi_stream_combininp_adc22/m` |
| s30_axis | `/axi_stream_combininp_adc30/m` |
| s32_axis | `/axi_stream_combininp_adc32/m` |

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
| clk_adc0 | 30 MHz | hier_mtsclk |
| clk_adc1 | 30 MHz | （未使用） |
| clk_adc2 | 30 MHz | （未使用） |
| clk_adc3 | 30 MHz | （未使用） |
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

| 項目 | rev0.12 47dr1（同事） | RFSoC_RX | 原因 |
|---|---|---|---|
| ADC NCO（8 組） | 0.84 GHz | **1.04 GHz** | 與 RFSoC_TX 對齊，使用頻段改成 2.3 ~ 3.3 GHz（2026-10-15） |
| DAC NCO（8 組） | −0.84 GHz | **−1.04 GHz** | 同上 |
| 其他 RFDC 參數 | — | 相同 | 只改 NCO |

ADC Outclk 維持同事的 30 MHz（RFSoC_RX 沒有 Gain Control，不需要 240 MHz 的 adc_clk）。

## 8. PS 端設定流程

RFSoC_RX 這一版只有 PL（bitstream / XSA），**沒有 PS 程式**。RFDC 的初始化、MTS 與 NCO 相關的 PS 流程，依同事原本的方式（`docs/reference_rev0.12/DESIGN.md` §15 bring-up procedure）處理。

## 9. 待確認

1. 頻段（2.3 ~ 3.3 GHz）尚未在板上量測確認。
2. RFSoC_RX 與 RFSoC_TX 的 NCO 必須一致；請勿與舊版 z1（rev0.11 / rev0.12 release，0.84 GHz）混用。
3. RFSoC_RX 尚無 PS 程式，RFDC / MTS 的開機流程需另行確認。

## 10. 修訂歷程

| 版本 | 日期 | 說明 |
|---|---|---|
| v0.1 | 2026-10-16 | 第一版，對應 RFSoC_RX build 01（NCO 1.04 / −1.04 GHz） |
