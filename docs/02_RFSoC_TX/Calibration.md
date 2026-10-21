# RFSoC_TX Calibration 資料路徑設計說明

| | |
|---|---|
| 專案 | PJ22045_1R8T release Rex rev0.1 — `RFSoC_TX`（z2，xczu47dr-ffvg1517-2-i，Vivado 2025.2，top `design_1_wrapper`）。專案檔 `RFSoC_TX/hardware/RFSoC_TX.xpr` |
| 範圍 | 每個通道 `cal_plus_gain_control_ch1` ~ `ch8` 的**資料路徑**：Signal Source Mux、bypass、IQ 拆分 / 分流、In-band FIR、IQ 合併、Delay / Phase / Gain 校正、gain 表 BRAM，到 RFDC DAC 為止；以及相關的 channel 暫存器、跨時脈、XDC、PS 開機流程。`power_fit_top` 與 `agc_emu` 只描述和資料路徑相接的介面 |
| 資料來源 | RTL：`RFSoC_TX/hardware/RFSoC_TX.srcs/sources_1/new/cal_plus_gain_control/`；BD：`sources_1/bd/cal_plus_gain_control/cal_plus_gain_control.bd`（JSON）與 IP `.xci`；頂層 `sources_1/bd/design_1/design_1.bd`；XDC：`constrs_1/new/cal_plus_gain_control.xdc`；Reg map：`docs/02_RFSoC_TX/tools/regmap_def.py`；PS：`RFSoC_TX/software/app_component/src/`；資源：`hardware/scripts/log/util_hier.rpt`（build 01，routed）。參考素材：Calibration_Gain_Control 的設計解析 v0.2 §2 / §4 / §6、`AGC_EMU_Design_Note.md` §5d、`HANDOFF.md` P6（source 專案，已依 target 修正） |
| 版本 | **v0.1**（2026-10-16） |
| 適用 build | **RFSoC_TX build 01**（2026-10-15，`RFSoC_TX/output_data/01/`）：WNS 0.000 ns / WHS +0.010 ns，0 critical warning |
| 狀態 | 已 build、timing 收斂；**RFSoC_TX 尚未上板驗證**。模擬是在 source 專案（Calibration_Gain_Control）用相同 RTL 跑的（見第 15 章） |

> **歷程規則：** 本文件描述目前的設計。設計改變時直接更新內文，並在第 17 章「修訂歷程」加一列。RTL 與參考素材不一致時，以 RTL / BD 為準，差異列在第 16 章。

---

## 1. 閱讀指引

### 1.1 章節安排

- 第 2 章用一張圖和一張表列出整條路徑；第 3 章說明資料格式。
- 第 4 ~ 11 章依資料流動的順序逐一說明每個模組：Signal Source Mux / bypass（4）→ IQ 拆分 / 分流（5）→ In-band FIR（6）→ IQ 合併（7）→ Delay（8）→ Phase（9）→ Gain 與 gain 表 BRAM（10）→ 輸出到 DAC（11）。
- 第 12 章整理暫存器、跨時脈與 XDC；第 13 章整理 latency；第 14 章是開機預設值與 PS 流程；第 15 章是驗證狀態；第 16 章是已知限制與待確認事項。
- 只想知道「怎麼設定」：看第 12 章的暫存器表與第 14 章的開機值。只想知道「有什麼風險」：看第 16 章。

> 注意：IQ 合併（`axi_stream_combininput`）在 BD 中位於 **FIR 之後、calibration 之前**（不是在 calibration 之後），所以本文件把它放在第 7 章，第 11 章才是 calibration → DAC 的輸出段。

### 1.2 符號與慣例

| 用語 | 意義 |
|---|---|
| `clk` | 資料路徑時脈 = `FPGA_clk` 256 MHz（design_1 `util_ds_buf_0/IBUF_OUT`），1 clk = 3.90625 ns |
| beat | 一拍 160-bit 的資料 = 5 個複數 sample |
| sample | 一個複數 sample {Q[15:0], I[15:0]}，取樣率 256 MHz × 5 = **1.28 GSPS**，1 sample = 0.78125 ns |
| lane k | 一拍裡的第 k 個 sample（k = 0 ~ 4），**lane 0 在 LSB、時間上最早** |
| `memN` | channel reg map（`addressable_reg_map`）的第 N 個 32-bit 暫存器，offset = 4 × N |
| S*m*.*n* / U*m*.*n* | 有號 / 無號定點數，*n* 位小數（例：S6.4 = 11 bit，1 LSB = 1/16 dB） |
| sfix16_15 | 16-bit 有號、15 位小數（−1.0 ~ +0.99997） |
| 「推測」 | 程式碼沒有明寫、由結構推斷的設計意圖，或無法從檔案確認的數值（例如 IP 加密的內部 latency） |
| 「尚未上板驗證」 | 只有 RTL 模擬或推導，RFSoC_TX 板子上還沒有量過 |

### 1.3 來源檔案

| 模組 | 檔案（`sources_1/new/cal_plus_gain_control/`） | 章 |
|---|---|---|
| `axis_iq_source_mux` | `axis_iq_source_mux.v`（2026-10-14 新增） | 4 |
| `axis_iq_bypass` | `axis_iq_bypass.v` | 4 |
| `axis_iq_split` / `axis_spliter_iq` | `axis_iq_split.v`、`axis_spliter_iq.v` | 5 |
| `FIR_coef_unpack` / `TOP_complex_FIR_module_parallel` / `complex_FIR_module_parallel` | 同名 `.v` | 6 |
| `axi_stream_combininput` | `axi_stream_combininput.v`（容器內 `axi_stream_combininp_0`，頂層 `rfdc_iq_combine_chN` 也是同一個 module） | 7 |
| `Delay_Cal` | `Delay_Cal.v` | 8 |
| `axis_demux_1to5` / `axis_mux_5to1` / `cordic_0~4` | `axis_demux_1to5.v`、`axis_mux_5to1.v`、Xilinx CORDIC 6.0 | 9 |
| `Gain_Compensation` / `blk_mem_gen_0` / `axi_bram_ctrl_0` / `gain_index_mux` | `Gain_Compensation.v`、Xilinx BMG 8.4 / AXI BRAM Controller 4.1、`gain_index_mux.v` | 10 |
| `cal_cdc` | `cal_cdc.v` | 12 |

這些 RTL 與 source 專案（`Calibration_Gain_Control/hardware/project_1.srcs/sources_1/new/`）的同名檔案逐位元組相同（2026-10-16 以 `cmp` 確認）。

---

## 2. 資料路徑總覽

### 2.1 方塊圖（一個通道，`cal_plus_gain_control_chN`）

```
 design_1 頂層                              │ cal_plus_gain_control_chN（BD container）
                                            │
 hier_rx_x0yN/M_AXIS_Cx ───────────────────────▶ s_axis_iq_in_0 ─┐
 (Aurora，同事的資料：data_delay → FIFO      │                   │  axis_iq_source_mux_0
  → data_aligner 依 timestamp 釋放)           │                   ├─▶ (sel = mem39，組合 mux，0 clk)
                                            │                   │
 RFDC ADC mXY0 (I) ─┐                       │                   │
                    ├─▶ rfdc_iq_combine_chN ───▶ s_axis_iq_in_1 ─┘
 RFDC ADC mXY1 (Q) ─┘   (I/Q 合併, 1 clk)    │                   │
                                            │                   ▼
                                            │   axis_iq_bypass_0.s_axis_iq ──┬──────────────────────────────┐
                                            │                                │ m_axis_cal（直通）            │ (bypass 路徑)
                                            │                                ▼                              │
                                            │   axis_iq_split_0      160b → I 80b / Q 80b（0 clk）          │
                                            │   axis_spliter_iq_0    I/Q 各複製兩份（0 clk）                │
                                            │        │ m0                          │ m1                     │
                                            │        ▼                             ▼                        │
                                            │   in_band_flatness               power_fit_top               │
                                            │   (16-tap complex FIR, 9 clk)    (量 FIR 前的振幅 → pf)        │
                                            │        │ I 80b / Q 80b               │ pf → agc_emu           │
                                            │        ▼                             ▼                        │
                                            │   axi_stream_combininp_0       gain_index_tx (TXAGC)          │
                                            │   (I/Q 合併回 160b, 1 clk)          │                        │
                                            │        ▼                             ▼                        │
                                            │   calibration                  gain_index_mux_0 (mem20/21)    │
                                            │     Delay_Cal_0     (1 + coarse clk, + fractional sample)     │
                                            │     axis_demux_1to5_0 (1 clk)                                  │
                                            │     cordic_0 ~ 4    (Rotate, phase = mem19, L_c clk)          │
                                            │     axis_mux_5to1_0 (1 clk)          │ gain_offset_index      │
                                            │     Gain_Compensation_0 (4 clk) ◀────┘                        │
                                            │        ▲ blk_mem_gen_0（gain 表 2048 × 32b）                   │
                                            │        │ axi_bram_ctrl_0 ◀── PS（S_AXI_BRAM）                  │
                                            │        ▼ calibration/m_axis_iq                                 │
                                            │   axis_iq_bypass_0.s_axis_cal                                 │
                                            │        ▼                                                      ▼
                                            │   m_axis_iq = (mem38 ? Mux 輸出 : calibration 輸出)（組合 mux）
                                            │        │
 RFDC DAC sXY ◀───────────────────────────────── m_axis_iq
```

### 2.2 各級一覽

| # | 區塊（BD 路徑，container 內） | 時脈 | 寬度 入 → 出 | Latency | 功能 | 章 |
|---|---|---|---|---|---|---|
| 0 | 頂層 `rfdc_iq_combine_chN`（只有 in_1） | clk | 2 × 80 → 160 b | 1 clk | RFDC ADC 的 I / Q 合併成 160-bit | 4.2 |
| 1 | `axis_iq_source_mux_0` | clk | 2 × 160 → 160 b | 0（組合） | 選 in_0（Aurora）或 in_1（ADC），mem39 | 4.1 |
| 2 | `axis_iq_bypass_0`（前半） | clk | 160 b | 0（組合） | 直通到正常處理路徑 | 4.3 |
| 3 | `axis_iq_split_0` | clk | 160 → 2 × 80 b | 0 | {Q, I} 拆成 I bus / Q bus | 5.1 |
| 4 | `axis_spliter_iq_0` | clk | 2 × 80 → 2 × (2 × 80) b | 0 | m0 → FIR，m1 → power_fit_top | 5.2 |
| 5 | `in_band_flatness/TOP_complex_FIR_modu_1` | clk | 2 × 80 b | 9 clk + group delay | 16-tap complex FIR | 6 |
| 6 | `axi_stream_combininp_0` | clk | 2 × 80 → 160 b | 1 clk | I / Q 合併回 160-bit | 7 |
| 7 | `calibration/Delay_Cal_0` | clk | 160 b | 1 + coarse clk（+ fractional sample） | 整數 clk + 1/5 clk 延遲 | 8 |
| 8 | `calibration/axis_demux_1to5_0` | clk | 160 → 5 × 32 b | 1 clk | 拆成 5 個 sample 給 CORDIC | 9.1 |
| 9 | `calibration/cordic_0 ~ cordic_4` | clk | 5 × 32 b | L_c（未確認，推測約 20 clk） | 每個 sample 旋轉 phase_offset | 9.2 |
| 10 | `calibration/axis_mux_5to1_0` | clk | 5 × 32 → 160 b | 1 clk | 合回 160-bit | 9.3 |
| 11 | `calibration/Gain_Compensation_0` | clk | 160 b | 4 clk | 查表 gain、乘法、round-half-even、飽和 ±16384 | 10 |
| 12 | `axis_iq_bypass_0`（後半） | clk | 2 × 160 → 160 b | 0（組合） | mem38 = 1 時改送 Mux 輸出 | 4.3、11 |
| 13 | 頂層 `usp_rf_data_converter_1` DAC sXY | clk | 160 b → RF | — | ×3 interpolation、NCO −1.04 GHz、3.84 GSPS | 11 |

### 2.3 時脈與 reset

| 訊號（container port） | 頂層來源 | 頻率 | 本文件範圍內的使用者 |
|---|---|---|---|
| `clk` | `util_ds_buf_0/IBUF_OUT`（FPGA_clk） | 256 MHz | 所有資料路徑模組、`gain_index_mux_0`、`cal_cdc_0` 目的端、`blk_mem_gen_0` port B |
| `rst_n` | `dac_rst1/peripheral_aresetn` | — | `in_band_flatness`（FIR）、`calibration`（Delay_Cal / demux / mux / Gain_Compensation）、`cal_cdc_0`。Source Mux、bypass、split、spliter、combininput 沒有 reset |
| `S_AXI_ACLK` | PS `pl_clk0` | 100 MHz | `addressable_reg_map`、`cal_cdc_0` 來源端、`axi_bram_ctrl_0`、`blk_mem_gen_0` port A |
| `S_AXI_resetn` | `rst_ps8_0_96M/peripheral_aresetn` | — | 只接 `axi_bram_ctrl_0` |
| `adc_clk` | RFDC `clk_adc0~3` | 240 MHz | `agc_emu`（不在本文件範圍） |

- 兩路輸入 `s_axis_iq_in_0` / `s_axis_iq_in_1` 都在 `clk` domain（BD `ASSOCIATED_BUSIF = s_axis_iq_in_0:s_axis_iq_in_1:m_axis_iq`），所以 Source Mux 不需要跨時脈。
- reset 風格不一致：`Delay_Cal`、`axis_demux_1to5`、`axis_mux_5to1` 是**非同步** reset（`negedge rst_n`）；FIR 與 `Gain_Compensation` 是**同步** reset；CORDIC 沒有 reset（xci `ARESETN false`）。只影響 reset 釋放時的暫態。

### 2.4 8 通道對應

| Ch | in_0（Aurora） | in_1（ADC → `rfdc_iq_combine_chN`） | DAC | Reg map | Gain BRAM（8 KB） |
|---|---|---|---|---|---|
| 1 | `hier_rx_x0y2/M_AXIS_C0` | m00 / m01 | s00 | 0xA009_0000 | 0xA009_A000 |
| 2 | `hier_rx_x0y2/M_AXIS_C1` | m02 / m03 | s02 | 0xA009_1000 | 0xA009_C000 |
| 3 | `hier_rx_x0y1/M_AXIS_C0` | m10 / m11 | s10 | 0xA009_2000 | 0xA009_E000 |
| 4 | `hier_rx_x0y1/M_AXIS_C1` | m12 / m13 | s12 | 0xA009_3000 | 0xA00A_0000 |
| 5 | `hier_rx_x0y3/M_AXIS_C0` | m20 / m21 | s20 | 0xA009_4000 | 0xA00A_2000 |
| 6 | `hier_rx_x0y3/M_AXIS_C1` | m22 / m23 | s22 | 0xA009_5000 | 0xA00A_4000 |
| 7 | `hier_rx_x0y4/M_AXIS_C0` | m30 / m31 | s30 | 0xA009_6000 | 0xA00A_6000 |
| 8 | `hier_rx_x0y4/M_AXIS_C1` | m32 / m33 | s32 | 0xA009_7000 | 0xA00A_8000 |

- 8 個 container 都直接放在 design_1 頂層（沒有 hierarchy），BDC variant 檔為 `cal_plus_gain_control_inst_8` ~ `_15`（ch1 = inst_8 … ch8 = inst_15）。
- 規則：Reg map = 0xA009_0000 + 0x1000 × (N − 1)；Gain BRAM = 0xA009_A000 + 0x2000 × (N − 1)。system_reg_map 在 0xA009_8000（本文件只用到它的 `reg_*` 輸出經 `cal_cdc_0` 給 power_fit，與資料路徑無直接關係）。
- ch1 的 in_0 同時被頂層原有的 `system_ila_0/SLOT_0_AXIS` 監看。

### 2.5 資源用量（build 01，ch1，routed，`util_hier.rpt`）

| Hierarchy | LUT | FF | RAMB36 | DSP |
|---|---|---|---|---|
| **`cal_plus_gain_control_ch1` 合計**（含 power_fit / agc_emu / reg map / ILA） | 14,973 | 25,226 | 7（另 RAMB18 × 1） | 363 |
| `in_band_flatness`（= `TOP_complex_FIR_modu_1`） | 4,917 | 10,130 | 0 | **320** |
| `calibration` 合計 | 6,892 | 9,144 | 2 | 40 |
| ├ `Delay_Cal_0` | 965 | 2,705 | 0 | 0 |
| ├ `axis_demux_1to5_0` / `axis_mux_5to1_0` | 0 / 1 | 161 / 160 | 0 | 0 |
| ├ `cordic_0` ~ `cordic_4`（每顆） | 約 1,072 | 1,117 | 0 | 4 |
| ├ `Gain_Compensation_0` | 430 | 362 | 0 | 20 |
| └ `axi_bram_ctrl_0`（+ `blk_mem_gen_0` 的 2 個 RAMB36） | 126 | 163 | 2 | 0 |
| `axi_stream_combininp_0` | 40 | 161 | 0 | 0 |
| `axis_iq_source_mux_0` / `axis_iq_bypass_0` | 96 / 90 | 0 / 0 | 0 | 0 |
| `cal_cdc_0` | 28 | 428 | 0 | 0 |

- 8 個通道的合計：119.9K LUT、2,904 DSP（整個設計 DSP 68.0%）。資料路徑佔每通道 DSP 的 360 / 363，其中 FIR 佔 88%。
- `axis_iq_source_mux_0` / `axis_iq_bypass_0` 的 LUT 數在各通道略有不同（例如 ch2 為 128 / 127），是合成最佳化的差異，邏輯相同。

---

## 3. 資料格式

### 3.1 160-bit 合併格式（container 的輸入 / 輸出、calibration 內部）

每拍 160 bit = 5 個 sample，每個 sample 32 bit = {Q[15:0], I[15:0]}：

```
 bit  159      144 143      128 127  ...   64 63       48 47       32 31       16 15        0
     ┌───────────┬───────────┬──────────────┬───────────┬───────────┬───────────┬───────────┐
     │    Q4     │    I4     │  Q3 I3 Q2 I2 │    Q1     │    I1     │    Q0     │    I0     │
     └───────────┴───────────┴──────────────┴───────────┴───────────┴───────────┴───────────┘
      lane 4（最晚）                                                      lane 0（最早）
```

- sample k 佔 `[32k+31 : 32k]`，其中 `[32k+15 : 32k]` = I_k、`[32k+31 : 32k+16]` = Q_k。
- 這個格式由 `axi_stream_combininput` 產生（`axi_stream_combininput.v:47`：`{s1[79:64], s0[79:64], …, s1[15:0], s0[15:0]}`，s0 = I、s1 = Q），也就是 RFDC DAC IQ 輸入使用的格式。頂層的 `rfdc_iq_combine_chN` 就是同一個 module（s0 = ADC mXY0 = I，s1 = mXY1 = Q）。
- Aurora 這一路（in_0）的資料在 z1 端由同一種 combiner 產生，格式相同。
- 同一格式也是 CORDIC `S_AXIS_CARTESIAN` 的 {Y, X}（X 在低位）與 `Gain_Compensation` 的 {Q16, I16}，所以 demux / mux 不需要重排 I / Q。

### 3.2 I / Q 分開格式（FIR 與 power_fit 內部）

| Bus | 寬度 | 內容 |
|---|---|---|
| `*_axis_i_tdata` | 80 b | lane k = `[16k+15 : 16k]` = I_k |
| `*_axis_q_tdata` | 80 b | lane k = `[16k+15 : 16k]` = Q_k |

### 3.3 數值慣例

| 用途 | 格式 | 說明 |
|---|---|---|
| IQ sample | 16-bit 有號 | 系統約定 **16384 = 0 dBFS**（Gain_Compensation 輸出飽和在 ±16384；CORDIC fix16_14 的 1.0） |
| FIR 係數 | sfix16_15（RTL 輸出右移 15 bit） | 1.0 ≈ 0x7FFF（32767 / 32768）。`regmap_def.py` / Excel 原本寫 S1.14，已於 2026-10-16 修正為 S0.15（見 6.3） |
| phase_offset | fix16_13 弧度（二補數） | 8192 = 1 rad，±π = ±25736；約 143 × 角度（°） |
| gain index | S7.4 / S6.4（1/16 dB） | BRAM 只用低 11 bit |
| gain 表內容 | unsigned fixed_32_21 | 1.0 = 0x0020_0000 |

### 3.4 tvalid / tready 的實際行為

- **tvalid**：沿路傳遞。`axi_stream_combininput` 在任一路 tvalid = 0 時輸出 **tdata = 0、tvalid = 0**；CORDIC 為 NonBlocking，tvalid 跟著資料走；mux 只在 5 個 lane 都 valid 時輸出 valid。
- **tready**：在正常處理路徑上**邏輯上恆為 1**。原因（BD 產生的 HDL `cal_plus_gain_control_inst_8.v`）：
  - `axis_demux_1to5_0` 的 `m0~m4_axis_tready` 綁成 `1'b1`（CORDIC 沒有 TREADY），所以 demux 的 `s_axis_tready` = 1；
  - `Delay_Cal` 的 `s_axis_tready = m_axis_tready`（= demux 的 tready = 1）→ `calibration/s_axis` 的 tready = 1；
  - `axi_stream_combininput` 的 `s0/s1_tready = m_tready` = 1 → FIR 的 `m_axis_*_tready` = 1 → FIR 內部 `aclken` = 1；
  - `power_fit_top`（`cw_power_calc_IQ.v:42-43`）的 tready 固定 1；所以 `axis_spliter_iq` / `axis_iq_split` / `axis_iq_bypass` 的上游 tready 都是 1。
- 唯一會看 DAC tready 的是 `axis_mux_5to1_0`（經 `Gain_Compensation` 延遲 4 拍回傳），以及 bypass 時的 `s_axis_iq_tready`。整條路徑實際上**不支援 backpressure**，設計隱含假設 RFDC DAC 的 tready 恆為 1（見 16 章）。

---

## 4. Signal Source Mux 與 bypass

### 4.1 `axis_iq_source_mux_0`（2026-10-14 新增）

**功能**：從兩路 160-bit 輸入選一路，送往 `axis_iq_bypass_0`（也就是送往 Power Fit / FIR / calibration，以及 mem38 的 bypass 路徑）。

| Port | 方向 | 寬度 | 說明 |
|---|---|---|---|
| `aclk` | in | 1 | `clk`（256 MHz）；只用於 BD 介面關聯，模組內沒有暫存器 |
| `sel` | in | 1 | `cal_cdc_0/signal_source_select`（mem39 同步後） |
| `s_axis_iq0_*` | slave | 160 / 1 / 1 | container `s_axis_iq_in_0`（Aurora） |
| `s_axis_iq1_*` | slave | 160 / 1 / 1 | container `s_axis_iq_in_1`（ADC） |
| `m_axis_iq_*` | master | 160 / 1 / 1 | → `axis_iq_bypass_0/s_axis_iq` |

參數 `WIDTH = 160`。邏輯（`axis_iq_source_mux.v:35-38`）：

```verilog
assign m_axis_iq_tdata   = sel ? s_axis_iq1_tdata  : s_axis_iq0_tdata;
assign m_axis_iq_tvalid  = sel ? s_axis_iq1_tvalid : s_axis_iq0_tvalid;
assign s_axis_iq0_tready = sel ? 1'b1 : m_axis_iq_tready;
assign s_axis_iq1_tready = sel ? m_axis_iq_tready : 1'b1;
```

| `sel`（mem39） | 輸出 | in_0 tready | in_1 tready |
|---|---|---|---|
| 0（reset 值、PS 開機值） | in_0（Aurora） | = 下游 tready | 1（資料丟掉） |
| 1 | in_1（ADC） | 1（資料丟掉） | = 下游 tready |

- **純組合邏輯，latency 0**，不增加任何暫存器（build 01：每通道約 90 ~ 130 LUT、0 FF）。
- **沒被選到的那一路 tready 固定 1**：上游不會被卡住，資料直接丟棄。對 Aurora 這一路來說，`data_aligner` 仍依 timestamp 釋放資料，只是釋放後沒人用。
- 兩路都必須是 `clk` domain，資料格式不變（第 3 章）。

### 4.2 兩路輸入的來源

| 輸入 | 頂層來源 | 說明 |
|---|---|---|
| `s_axis_iq_in_0` | `hier_rx_x0yN/M_AXIS_Cx`（同事的 Aurora 接收端） | `header_extraction` → `cdc_fifo` → `data_delay` → `axis_data_fifo` → `data_aligner`，依 timestamp 釋放（詳見同事的 `SIGNAL_TRANSMISSION.md` / `TIMING_SYNC.md`）。`M_AXIS_C0/C1` 在同事的 BD 是 Monitor mode，實際驅動者是內部的 `data_aligner/m_axis`；已確認產生的 HDL 中 8 個通道的 `s_axis_iq_in_0_tdata` 都是 `[159:0]` |
| `s_axis_iq_in_1` | `rfdc_iq_combine_chN/m` | 頂層的 `axi_stream_combininput`：RFDC ADC mXY0（I）/ mXY1（Q）各 80 bit → 160 bit，1 clk 暫存；ADC NCO +1.04 GHz、×3 decimation、1.28 GSPS。用途：本板 ADC → DAC 的 loopback 量測 |

### 4.3 `axis_iq_bypass_0`（mem38，除錯用）

```
 Source Mux 輸出 ─▶ s_axis_iq ──┬─▶ m_axis_cal ─▶ axis_iq_split_0 ─▶ …（FIR / power_fit / calibration，永遠在跑）
                                │
 calibration/m_axis_iq ─▶ s_axis_cal ─┐
                                │     ▼
                                └──▶ m_axis_iq = bypass ? s_axis_iq : s_axis_cal ─▶ container m_axis_iq ─▶ DAC
```

| Port | 方向 | 說明 |
|---|---|---|
| `bypass` | in | `cal_cdc_0/bypass_axis_iq`（mem38 同步後） |
| `s_axis_iq` | slave | Source Mux 輸出 |
| `m_axis_cal` | master | 直通到 `axis_iq_split_0`（`m_axis_cal = s_axis_iq`，tdata / tvalid） |
| `s_axis_cal` | slave | `calibration/m_axis_iq` |
| `m_axis_iq` | master | container 輸出 → RFDC DAC |

邏輯（`axis_iq_bypass.v:80-87`）：

| 項目 | bypass = 0 | bypass = 1 |
|---|---|---|
| `m_axis_iq_tdata / tvalid` | `s_axis_cal`（處理後） | `s_axis_iq`（Mux 輸出，原樣） |
| `s_axis_iq_tready` | `m_axis_cal_tready` | `m_axis_cal_tready & m_axis_iq_tready` |
| `s_axis_cal_tready` | `m_axis_iq_tready` | `m_axis_iq_tready` |

- 純組合 mux：正常路徑 latency 不變；bypass 路徑從 container 輸入到輸出 **0 clk**（in_1 另有頂層 combiner 的 1 clk）。
- bypass 時正常路徑**照常運作**（`m_axis_cal` 一直有資料），power_fit / AGC / status snapshot 仍有效，可在 bypass 下觀察 pf 與 TXAGC 的行為；類比衰減器也照 AGC 運作（要固定類比請另外用 `agc_bypass_agc`）。
- 切換那一拍輸出會從處理後的資料直接跳到輸入資料（兩者相差整個處理 latency 與增益），會有一次不連續，屬預期。

### 4.4 mem39 × mem38 的組合

| mem39 `signal_source_select` | mem38 `bypass_axis_iq` | DAC 輸出 | 用途 |
|---|---|---|---|
| 0 | 0 | Aurora → FIR → Delay → Phase → Gain | **開機預設**；正常運作 |
| 0 | 1 | Aurora 原樣 | 等同 rev0.11「Aurora 直接送 DAC」的行為 |
| 1 | 0 | 本板 ADC → FIR → Delay → Phase → Gain | 本板 loopback 量測 / 校正 |
| 1 | 1 | 本板 ADC 原樣 | 量 RFDC ADC → DAC 的原始通道 |

> 預設行為的改變：rev0.11 的 Aurora 資料是直接送 DAC；本設計開機後（mem39 = 0、mem38 = 0）Aurora 資料會經過 FIR（開機為 impulse）/ calibration / gain 處理。要恢復原本的直通行為，把 mem38 設成 1。

### 4.5 切換時的注意事項

- mem39 / mem38 都經 `cal_cdc_0`（3 級同步 + 連續 4 拍不變才放行），切換在 PS 寫入後約數十 ns 內生效，沒有 bit 混合的問題。
- 切換 mem39 時，FIR 的 delay line 裡還有前一個來源的 15 個 sample，Delay_Cal / CORDIC / Gain 的 pipeline 也還有舊資料，所以切換後約一個處理 latency（第 13 章）的期間輸出是兩個來源混合的暫態。沒有 flush / mute 機制。
- 沒被選到的那一路一直被丟棄；切回來時拿到的是「當下」的資料，不是切走前留下的資料。

---

## 5. IQ 拆分 / 分流

### 5.1 `axis_iq_split_0`

把 160-bit 合併格式拆成 I bus / Q bus（`axis_iq_split.v:35-43`）：

```verilog
m_axis_i_tdata[16k +: 16] = s_axis_iq_tdata[32k      +: 16];   // I_k
m_axis_q_tdata[16k +: 16] = s_axis_iq_tdata[32k + 16 +: 16];   // Q_k
m_axis_i_tvalid = m_axis_q_tvalid = s_axis_iq_tvalid;
s_axis_iq_tready = m_axis_i_tready & m_axis_q_tready;
```

參數 `DATA_WIDTH = 16`、`NUM_PARALLEL = 5`。純組合，latency 0，不吃 FF。

### 5.2 `axis_spliter_iq_0`

把 I bus、Q bus 各複製成兩份：

| 輸出 | 去向 | 用途 |
|---|---|---|
| `m0_axis_i / m0_axis_q` | `in_band_flatness/s_axis_i / s_axis_q` | 主資料路徑 |
| `m1_axis_i / m1_axis_q` | `power_fit_top/s_axis_i / s_axis_q` | 量測旁路（`cw_power_calc_IQ`） |

- tdata / tvalid 純接線複製；`s_axis_i_tready = m0_axis_i_tready && m1_axis_i_tready`（Q 相同）。power_fit 端 tready 固定 1，FIR 端 tready 邏輯上也是 1（3.4），所以上游 tready = 1。
- 純組合，latency 0。

### 5.3 為什麼在 FIR 之前分流

- **Power Fit 量的是 FIR 之前的訊號**（m1 在 FIR 前分出），所以 pf 修正的是「輸入振幅」，FIR 刻意做出的 inverse response 不會被 AGC 拉平。若在 FIR 之後量，AGC 會把 FIR 的補償抵消掉，類比端就補不到通帶斜率。
- 因為數位 gain（pf − R）要到最後的 `Gain_Compensation` 才套用，FIR 與 CORDIC 看到的是**未經 AGC 衰減的原始振幅**（HANDOFF P6）。這是 FIR 沒飽和、CORDIC 輸入超範圍風險的來源（第 16 章）。

---

## 6. In-band FIR（`in_band_flatness`）

### 6.1 功能

baseband 頻寬約 ±500 MHz（Fs = 1.28 GSPS）。訊號上變頻到 RF 後，類比鏈路的 loss 隨頻率變化，in-band response 呈斜線。`in_band_flatness` 用一個 **16-tap 複數 FIR** 在數位端預先補上反向響應（pre-equalization），讓 RF 輸出的 in-band 振幅變平。

- 用複數係數（I / Q 各 16 bit）而不是實數 FIR，是為了將來也能補相位。目前 PC 端腳本（`inband_flatness_cal.py`）產生的係數只補振幅、conjugate-symmetric（線性相位），並把峰值增益正規化成 0 dB。
- **RFSoC_TX 的 8 個通道目前都是 impulse（不補償）**：每塊板子、每個通道的類比鏈路不同，要在 RFSoC_TX 上量測後才能產生係數。`reg_runtime/fir_ch1.tcl` 是 source 板 ch1（2.8 GHz、tilt −2.7 dB）的係數，只能當格式範例，不適用於 RFSoC_TX。

### 6.2 BD 接線（hierarchy `in_band_flatness`）

| hierarchy pin | 外部 | 內部 |
|---|---|---|
| `reg_fir_enable[31:0]` | `addressable_reg_map/mem0` | `sl_fir_enable`（ilslice，`DIN_WIDTH 32, DIN_FROM 0, DIN_TO 0`，只取 bit 0）→ `TOP_complex_FIR_modu_1/enable` |
| `reg_fir_tap00..15[31:0]` | `addressable_reg_map/mem1..mem16` | `FIR_coef_unpack_0/in_tap00..15` → `tapNN_i / tapNN_q`（32 條 16-bit）→ `TOP_complex_FIR_modu_1` |
| `s_axis_i / s_axis_q` | `axis_spliter_iq_0/m0_axis_i / m0_axis_q` | `TOP_complex_FIR_modu_1/s_axis_i / s_axis_q` |
| `m_axis_i / m_axis_q` | `axi_stream_combininp_0/s0 / s1` | `TOP_complex_FIR_modu_1/m_axis_i / m_axis_q` |
| `clk` / `rst_n` | container `clk` / `rst_n` | `rst_n` 只接 `TOP_complex_FIR_modu_1` |

mem0 ~ mem16 → FIR **沒有經過 `cal_cdc_0`**，直接從 100 MHz 的 `cfg_r*` 進到 256 MHz domain，靠 XDC false path（12.3）與 FIR 內部的 `tap_*_reg` 落地。build 01 的 `report_cdc` 中 100 個 CDC-14（Critical，"Multi-bit CDC path on a non-FD primitive"）全部是這組 `cfg_r* → DSP B port` 的路徑，屬預期。

### 6.3 `FIR_coef_unpack_0` 與係數格式

純組合接線，把 16 個 32-bit 暫存器拆成 32 條 16-bit 係數線：`tapNN_i = in_tapNN[15:0]`、`tapNN_q = in_tapNN[31:16]`。`clk` port 沒有使用（只是讓 BD 把它掛在 `clk` domain）。

| 項目 | 內容 |
|---|---|
| 暫存器打包 | mem(1 + t) = {Q[15:0], I[15:0]}，t = 0 ~ 15；PS 用 `FIR_IQ(I, Q)` 巨集，XSDB 用 `reg_fir_tap <t> <I> <Q>`（自動打包並 write-verify） |
| 數值格式（以 RTL 為準） | **sfix16_15**：輸出 = Σ h·x 右移 15 bit（`SHIFT_BIT = FIR_COE_WIDTH − 1 = 15`），所以 0x7FFF ≈ +0.99997、0x4000 = 0.5、0x8000 = −1.0。PC 腳本 `fir_ch1.tcl` 標頭也寫 `sfix16_15` |
| 與 reg map 文件的差異 | 原本 `regmap_def.py` 與 `Reg_map_tx_ch_v0.1.xlsx` 寫「S1.14 each」（照 S1.14 解讀，0x7FFF 會是 ≈ 2.0，與 RTL 不符）。`regmap_def.py`、`Register_Map.md`、Excel 已於 2026-10-16 修正為 S0.15（`Follow_Up.md` F5）。**請以 sfix16_15 計算係數** |
| tap 編號 | tap t 對應卷積的 h[t]：`y[n] = Σ h[t]·x[n − t]`，tap00 作用在最新的 sample |

### 6.4 `TOP_complex_FIR_module_parallel`

參數：`DATA_WIDTH 16`、`FIR_COE_WIDTH 16`、`TAPS 16`、`NUM_PARALLEL 5`（BD 用預設值）。

```
                  enable (mem0 bit0, 非同步) ─┐
 tapNN_i/q (非同步) ──▶ tap_i_reg / tap_q_reg[0:15]   (每拍取樣：enable ? tapNN : impulse)
                                             │  → 實作時吸收為 DSP B2 register
                                             ▼
 s_axis_i/q_tdata ─▶ s_axis_*_tdata_r ─▶ register_array_i/q[0:19] ─▶ 5 × complex_FIR_module_parallel
 s_axis_*_tvalid ──▶ s_axis_tvalid_r  ─▶ FIR_input_valid ─────────────▶   (in_valid)       │ 37 b × 5 × I/Q
                                                                                           ▼
                                               round (+2^14) 後取 [30:15]（不飽和）─▶ m_axis_*_tdata
                                               sub_fir_valid[0] ──────────────────────▶ m_axis_*_tvalid
 aclken = m_axis_i_tready & m_axis_q_tready ─▶ s_axis_*_tready 與所有暫存器的 CE
```

**握手與輸入暫存**（`:74-98`）

- `aclken = m_axis_i_tready && m_axis_q_tready`；`s_axis_*_tready = aclken`。全部暫存器以 `aclken` 為 CE（global stall）。在本 BD 中 `aclken` 邏輯上恆為 1（3.4）。
- 輸入先暫存一拍（`s_axis_*_tdata_r`、`s_axis_tvalid_r`）：拆開 ADC / Aurora 端到 FIR DSP column 的長繞線；`s_axis_tvalid_r` 加 `max_fanout = 32` 讓 Vivado 複製去推 shift register 的 CE。

**係數暫存與 impulse**（`:103-158`）

- `tap_*_reg` 沒有 CE，**每拍**重新取樣：`enable = 1` 取 `tapNN_*`；`enable = 0` 取 impulse（只有 `tap_i_reg[7] = 16'h7FFF`，其餘 0）。reset 時全為 0（輸出 0）。
- 這組暫存器是非同步 `cfg_r*` 落到 256 MHz domain 的第一級，實作時被吸收成 DSP48E2 的 B2 register，所以 false path 的終點在 DSP B port。
- **impulse 的意義**：h[7] = 0x7FFF、其餘 0 時，`y[n] = (x[n−7]·32767 + 2^14) >> 15`。以 python 窮舉確認：**x 在 −16383 ~ +16384 時輸出 = x（bit-exact 的 7-sample = 5.47 ns 純延遲）**；x = −16384 輸出 −16383，|x| > 16384 時輸出往 0 偏 1 LSB。中心放在 tap7（推測）是為了讓 impulse 的延遲接近 16-tap 線性相位濾波器的 group delay（7.5 sample），切換時時間對齊只差半個 sample。

**Shift register 與 5-parallel 映射**（`:173-225`）

- delay line 長度 `TAPS + NUM_PARALLEL − 1 = 20`：每個有效拍把本拍 5 個 sample 反序載入 `register_array[0..4]`，其餘位置整塊往後移 5 格。CE = `aclken && s_axis_tvalid_r`，所以 **tvalid = 0 的拍不會推進 delay line**（資料不會被無效拍污染）。
- 令第 m 個有效拍的 lane k 為 x[5m + k]，則 `register_array[r] = x[5m + 4 − r]`。engine i 的 tap j 取 `register_array[j + 4 − i] = x[5m + i − j]`，所以 **engine i 輸出 y[5m + i] = Σ_{j=0}^{15} h[j]·x[5m + i − j]**，放在輸出 lane i。
- 這是 direct-form FIR 的 block（parallel）展開：5 個 engine 共用一條 delay line，每個 engine 各算完整的 16-tap 卷積，沒有運算共用。

**輸出 rounding 與截位**（`:256-279`）

```verilog
round_tmp = parallel_out + (1 << 14);                 // 37-bit 累加結果 + 0.5 LSB
m_axis_tdata[16k +: 16] <= round_tmp[15 +: 16];       // 取 [30:15]
```

- round-half-up（tie 朝 +∞），不是 convergent。
- bit [36:31] 直接丟掉，**沒有飽和**：結果超過 ±32767 會繞回、翻號（第 16 章 L1）。
- 輸出 signed 16-bit，與輸入同刻度。

### 6.5 `complex_FIR_module_parallel`（單一 engine，TOP 內 5 份）

| Stage | 暫存器 | 內容 | 實作 |
|---|---|---|---|
| 1 | `mult_ii / mult_qq / mult_iq / mult_qi[16]` | 16 × 16 → 32 bit | DSP MREG |
| 2 | `cmult_i / cmult_q[16]` | Re = xI·hI − xQ·hQ，Im = xI·hQ + xQ·hI（33 bit） | DSP post-adder / PREG（cascade pair） |
| 3 | `fir_mult_sum[0][16]` | 純 copy | fabric FF |
| 4 ~ 7 | `fir_mult_sum[1..4]` | 16 → 8 → 4 → 2 → 1 的 binary adder tree，最後 37 bit | fabric |

- 每個 tap 4 個實數乘法（沒有用 Gauss 3-mult），16 tap × 5 engine × 4 = **320 DSP48E2 / 通道**，與 build 01 `util_hier.rpt` 一致。
- 累加器寬度 `16 + 16 + 1 + log2(16) = 37` bit，小數點在 bit 15。
- **valid 鏈少一級**：`valid_temp` 只有 `STAGES + 2 = 6` 級，資料是 7 級（漏算 `fir_mult_sum[0]` 的 copy），所以 `m_axis_tvalid` 比資料**早 1 拍**：第 k 個 valid beat 帶的是第 k − 1 個輸入 beat 的結果（source 專案的檢查用 TB `tb_fir_chk` 已確認，第 15 章）。

### 6.6 Latency

| 時脈邊緣 | 資料 | valid |
|---|---|---|
| E0 | `s_axis_*_tdata_r`（輸入 beat 被接收） | `s_axis_tvalid_r` |
| E1 | `register_array[0..4]` | `FIR_input_valid` |
| E2 / E3 | `mult_*` / `cmult_*` | `valid_temp[0]` / `[1]` |
| E4 ~ E8 | `fir_mult_sum[0]` ~ `[4]` | `valid_temp[2..5]`，E8 時 `m_axis_tvalid` ← 1 |
| E9 | `m_axis_tdata`（round + slice） | — |

- **資料 latency 9 clk（35.16 ns）**，另加濾波器本身的 group delay：impulse 7 sample（5.47 ns）；16-tap 線性相位係數 7.5 sample（5.86 ns）。
- 之後 `axi_stream_combininp_0` 再暫存 1 拍（第 7 章）。

### 6.7 係數寫入注意事項

1. **先關 FIR 再寫係數**：`tap_*_reg` 每拍直接取樣非同步的 `cfg_r*`，PS 一次只寫一個 32-bit tap，FIR 開著改係數會有一段時間新舊 tap 混用（同一個 tap 的 16 bit 在跨時域那一拍也可能部分新、部分舊）。標準流程（`register_map.c` 與 `fir_ch1.tcl` 都照這個順序）：`in_band_fir_enable = 0` → 寫 16 個 tap → `in_band_fir_enable = 1`。關 FIR 期間輸出走 impulse（純延遲 7 sample），不會斷訊。
2. **enable 本身也是非同步**：切換那一拍各 tap 可能分別看到新舊值，約有 16 個 sample 的暫態。硬體沒有 double buffer。
3. **group delay 隨 FIR 狀態改變**：impulse 7 sample、線性相位係數 7.5 sample（差 0.39 ns）。Delay calibration（第 8 章）要在實際使用的 FIR 狀態下量測。
4. **係數總和限制**：最壞輸出 = 16384 × Σ(|hI| + |hQ|) / 32768。Σ(|hI| + |hQ|) 超過約 2.0（以 32768 = 1.0 計）時，輸入在 0 dBFS 附近就可能翻號（source 板 ch1 係數 Σ = 1.956，最壞 32049，只剩約 0.2 dB 餘裕）。
5. PS 開機值是 impulse 係數 + enable = 1（第 14 章），效果和 enable = 0 相同。

---

## 7. IQ 合併（`axi_stream_combininp_0`）

位置：`in_band_flatness/m_axis_i, m_axis_q` → **`axi_stream_combininp_0`** → `calibration/s_axis`。

```verilog
// axi_stream_combininput.v:42-54
assign s0_tready = m_tready;  assign s1_tready = m_tready;
always @(posedge clk)
    if (s0_tvalid && s1_tvalid) begin
        m_tdata  <= {s1[79:64], s0[79:64], s1[63:48], s0[63:48], …, s1[15:0], s0[15:0]};
        m_tvalid <= 1'b1;
    end else begin
        m_tdata  <= 0;   m_tvalid <= 0;
    end
```

| 項目 | 內容 |
|---|---|
| 輸入 | s0 = FIR `m_axis_i`（I），s1 = FIR `m_axis_q`（Q），各 80 bit |
| 輸出 | 160 bit 合併格式（第 3.1 節），→ `calibration/s_axis` → `Delay_Cal_0` |
| Latency | 1 clk |
| tvalid = 0 時 | 輸出 tdata **清成 0**、tvalid = 0；下游看到的是乾淨的 0，DAC 輸出 0 |
| tready | 不看 `m_tready`（只往上游傳），沒有 skid buffer；目前 `m_tready` 恆為 1 |
| reset | 沒有 reset；上電後第一拍起就依 tvalid 更新 |
| 資源 | 40 LUT / 161 FF |

---

## 8. Delay calibration（`calibration/Delay_Cal_0`）

### 8.1 功能

以 160 bit（5 sample）為單位做整數 clk 延遲（coarse 0 ~ 15 clk），再用「跨兩拍重新拼 lane」做 1/5 clk 的 fractional 延遲（0 ~ 4 sample）。可調延遲 = 5 × coarse + fractional sample = **0 ~ 79 sample**（步階 0.78125 ns，最大 61.7 ns），另加固定 1 clk 的輸出暫存器。用途：對齊各通道之間（以及通道與系統其他路徑）的時間差。

| Port | 方向 | 寬度 | 說明 |
|---|---|---|---|
| `delay_coarse` | in | 4 | `cal_cdc_0` ← mem17 `coarse_delay_offset`，0 ~ 15 clk |
| `delay_fractional` | in | 3 | `cal_cdc_0` ← mem18 `fractional_delay_offset`，0 ~ 4 sample（5 ~ 7 見 8.4） |
| `s_axis_*` | slave | 160 / 1 / 1 | 來自 `axi_stream_combininp_0`；`s_axis_tready = m_axis_tready` |
| `m_axis_*` | master | 160 / 1 / 1 | → `axis_demux_1to5_0`；`m_axis_tready` 當整條 pipeline 的 `shift_en`（實際恆為 1） |

參數：`DATA_WIDTH 160`、`MAX_DELAY_CYCLES 15`、`NUM_SAMPLES 5`（每 sample `SW = 32` bit）。

### 8.2 內部架構

```
s_axis_tdata ─┬──────────────────────────────────────┐
              └─▶ data_pipe[0] ─▶ [1] ─▶ … ─▶ [14]    (15 級 × 160 bit，非同步 reset)
                                                      │
   coarse MUX（組合，16 選 1）：coarse = 0 取 s_axis_tdata，否則取 data_pipe[coarse − 1]
                                                      │ coarse_data (C)
                      prev_coarse_data (P) ◀─(1 clk)──┤
                                                      │
   fine MUX（組合）：依 fractional 從 {C, P} 拼 5 個 lane
                                                      │ shifted_data
                                       m_axis_tdata（輸出暫存器，1 clk）
```

- 移位暫存器深度 15：coarse = 0 走組合路徑，1 ~ 15 取 `data_pipe[coarse − 1]`。`:95-98` 的 `else`（coarse > 15）在 4-bit 輸入下不會發生。
- valid 走同樣的 `valid_pipe`，與資料同步。
- 因為 pipe 帶非同步 reset，無法推成 SRL：build 01 為 965 LUT / 2,705 FF。

### 8.3 fractional delay（`Delay_Cal.v:135-155`）

C = 本拍 `coarse_data`、P = 上一拍；Cn / Pn = lane n。

| fractional | 輸出 {lane4, …, lane0} | 輸出 lane n 對應的樣本 | 等效延遲 |
|---|---|---|---|
| 0 | {C4, C3, C2, C1, C0} | 5k + n | 0 |
| 1 | {C3, C2, C1, C0, P4} | 5k + n − 1 | 1 sample（0.78 ns） |
| 2 | {C2, C1, C0, P4, P3} | 5k + n − 2 | 2 sample |
| 3 | {C1, C0, P4, P3, P2} | 5k + n − 3 | 3 sample |
| 4 | {C0, P4, P3, P2, P1} | 5k + n − 4 | 4 sample |
| 5 ~ 7 | `default`：= C | 5k + n | 0（但 valid 仍要求 P valid） |

- 整條 1.28 GSPS 序列整體往後移整數個 sample；不是插值，**解析度就是 1 sample（0.78125 ns）**。
- fractional > 0 時輸出用到上一拍，所以 valid = `coarse_valid & prev_coarse_valid`。

### 8.4 Latency 與注意事項

- 輸入 → `m_axis_tdata`：**1 + coarse clk，再加 fractional 個 sample**。
- runtime 改延遲會讓輸出 sample 瞬間跳動（重複或跳過最多 79 個 sample）。mem17、mem18 是兩次 AXI 寫入，`cal_cdc_0` 各自放行，中間會有「新 coarse + 舊 fractional」的狀態。
- `delay_fractional` = 5 ~ 7 沒有 clamp，資料等於 0 延遲；從 4 改到 5 延遲會反向跳 4 sample。PS 的 `register_map.c` 開機寫入時會檢查 0 ~ 4（`chk_u`），但 XSDB 直接寫 raw 值時沒有保護。

---

## 9. Phase calibration

把每個 sample 旋轉同一個角度 θ：`I' + jQ' = (I + jQ)·e^{jθ}`。用途：校正各通道之間的相位差。

### 9.1 `axis_demux_1to5_0`

- lane k → `mk_axis_tdata = s_axis_tdata[32k+31 : 32k]`（{Q, I}），分別送 `cordic_k/S_AXIS_CARTESIAN`。
- 1 級暫存器，**latency 1 clk**；`tvalid` 每拍更新，`tdata` 只在 `s_axis_tvalid = 1` 時更新。
- `m0~m4_axis_tready` 在 BD 產生的 HDL 中綁成 `1'b1`，所以 `s_axis_tready` 恆為 1。
- 非同步 reset；資源 0 LUT / 161 FF。

### 9.2 `cordic_0` ~ `cordic_4`（Xilinx CORDIC 6.0）

5 顆設定相同（xci `component_parameters`）：

| 參數 | 值 | 意義 |
|---|---|---|
| Functional_Selection | Rotate | 向量旋轉 (X, Y) by θ |
| Architectural_Configuration | Parallel | 每拍一筆輸入、一筆輸出 |
| Pipelining_Mode | Maximum | 最多 pipeline（256 MHz 時序） |
| Data_Format | SignedFraction | X / Y = fix16_14（16384 = 1.0） |
| Phase_Format | Radians | phase = fix16_13（8192 = 1 rad） |
| Input_Width / Output_Width | 16 / 16 | |
| Round_Mode | Nearest_Even | |
| Coarse_Rotation | true | 先做象限旋轉，phase 可涵蓋 −π ~ +π |
| Compensation_Scaling | Embedded_Multiplier | CORDIC 增益 K ≈ 1.6468 用 DSP 補償，輸出幅度 = 輸入幅度 |
| flow_control | NonBlocking（`C_THROTTLE_SCHEME 3`） | 沒有 TREADY |
| ACLKEN / ARESETN | false / false | 沒有 clock enable、沒有 reset |

BD 連線：

- `s_axis_cartesian_*` ← demux m0 ~ m4（{Q, I} = {Y_in, X_in}）
- `s_axis_phase_tdata` ← `phase_offset`（`cal_cdc_0` ← mem19，5 顆共用同一條 net）
- `s_axis_phase_tvalid` ← `const_phase_tvalid`（ilconstant，`CONST_VAL 1`）
- `m_axis_dout_*` → mux s0 ~ s4（{Y_out, X_out} = {Q', I'}）

數學：`X_out = X·cos θ − Y·sin θ`、`Y_out = X·sin θ + Y·cos θ`。

**phase_offset 的換算**

| 項目 | 值 |
|---|---|
| 格式 | 16-bit 二補數 fix16_13 弧度（1 sign + 2 integer + 13 fraction） |
| 1° | π / 180 × 8192 = 142.977 → 軟體用 **143 × 角度**（PS 巨集 `PHASE_DEG(d)` 四捨五入；比例誤差 0.016%） |
| 解析度 | 1 LSB = 1/8192 rad ≈ 0.007° |
| 合法範圍 | ±π = ±25735.9 → ±25735 |
| 注意 | 143 × 180 = 25740 > 25735.9，`PHASE_DEG(±180)` 會超出 CORDIC 規定的 −π ~ +π；`register_map.c` 寫入時沒有 clamp（第 16 章） |

**Latency**：xci 沒有 latency 欄位，sim netlist 是加密的，無法從檔案確認。依 PG105 慣例（Parallel + Maximum pipeline、16 bit、coarse rotation + embedded multiplier）推測約 20 clk；**需在 IP GUI 的 Implementation Details 或 behavioral 模擬確認**。5 顆設定相同，所以 5 個 lane 輸出對齊。

**資源**：每顆約 1,072 LUT / 1,117 FF / 4 DSP（build 01），5 顆共約 5.4K LUT / 5.6K FF / 20 DSP。

**為什麼 5 顆**：每拍 5 個 sample，CORDIC Parallel 每拍只處理一筆，所以每個 lane 一顆。目前 5 顆收的是同一個常數 θ，等於每拍重算 5 次相同的 cos θ / sin θ（可優化，見第 16 章）。

### 9.3 `axis_mux_5to1_0`

- `all_s_valid = &s*_axis_tvalid`；`m_axis_tready = 1` 時 `m_axis_tvalid <= all_s_valid`，`all_s_valid = 1` 時 `m_axis_tdata <= {s4, s3, s2, s1, s0}`（lane 順序同 demux）。**latency 1 clk**。
- `m_axis_tready` 來自 `Gain_Compensation_0/s_axis_tready`（= DAC tready 延遲 4 拍，reset 後前 4 拍為 0）。tready = 0 時 mux 暫存器保持，但上游 CORDIC（NonBlocking）照常輸出，資料會遺失；實務上 RFDC DAC tready 啟動後恆為 1，所以不影響（推測依賴此條件）。
- `s0~s4_axis_tready` 在 BD 中沒有接（CORDIC 沒有 TREADY）。
- 非同步 reset；資源 1 LUT / 160 FF。

---

## 10. Gain compensation 與 gain 表 BRAM

### 10.1 `Gain_Compensation_0`

把 gain index（1/16 dB）換成 BRAM 位址，讀出線性 gain（unsigned fixed_32_21），5 個 sample 的 I / Q 共 10 個值各乘同一個 gain，round-half-even 回 16 bit，再**飽和到 ±16384**（`SAT_LEVEL`，0 dBFS / DAC 系統上限）。

| Port | 方向 | 寬度 | 說明 |
|---|---|---|---|
| `clk` / `rst_n` | in | 1 | 同步 reset |
| `in_valid` | in | 1 | `const_gain_comp_in_valid`（ilconstant，預設 1）→ 每拍都重讀 BRAM |
| `gain_offset_index` | in | 12 | `gain_index_mux_0/gain_index_out`（S7.4 dB）；位址只用低 11 bit |
| `s_axis_tdata / tvalid` | in | 160 / 1 | 來自 `axis_mux_5to1_0` |
| `s_axis_tready` | out | 1 | = `m_axis_tready` 延遲 4 拍 |
| `bram_*` | | | 接 `blk_mem_gen_0` port B：`bram_clk = clk`、`en = 1`、`we = 0`、`wrdata = 0`、`rst = ~rst_n` |
| `m_axis_tdata / tvalid` | out | 160 / 1 | → `calibration/m_axis_iq` |
| `m_axis_tready` | in | 1 | 來自 DAC；**資料路徑不使用**，只延遲後回傳 |

參數：`MEM_BASE = 0`、`SAT_LEVEL = 16384`。

**資料 pipeline（4 clk）**

| 拍 | 暫存器 | 內容 |
|---|---|---|
| 1 | `data_reg0` | 輸入 160 bit |
| 2 | `data_reg1` | 再延遲一拍，對齊 gain |
| 3 | `I49[i] / Q49[i]` | 16 × 33 signed 乘積（49 bit） |
| 4 | `m_axis_tdata` | `rnd_sat()` 捨入 + 飽和 |

valid：`s_axis_tvalid_reg0~2` + `m_axis_tvalid` = 4 拍，與資料對齊。`m_axis_tdata` 與乘積暫存器沒有 reset。

**gain 路徑**

| 拍 | 動作 |
|---|---|
| t | `gain_offset_index` 改變 |
| t + 1 | `bram_addr <= 4 × gain_offset_index` |
| t + 2 | BRAM `doutb`（read latency 1，無輸出暫存器） |
| t + 3 | `gain <= bram_rddata` |
| t + 4 | 乘積使用新 gain |
| t + 5 | 輸出 |

所以 **index → 輸出 5 clk、資料 → 輸出 4 clk**：新 gain 從「index 改變後下一拍進來的資料」開始生效。reset 時 `gain = 0x0020_0000`（1.0），2 ~ 3 拍後就換成 BRAM 讀出值。

**乘法、捨入與飽和**（`:112-138`）

```verilog
I49 = I16 * $signed({1'b0, gain});                 // gain 補 0 → 33 bit 正數（unsigned 語意）
r   = p + (2^20 − 1) + p[21];                      // bit 21 = 1.0 的位置
q   = r[48:21];                                    // floor(r / 2^21)
out = (q > 16384) ? 16384 : (q < −16384) ? −16384 : q[15:0];
```

- 捨入是 **round-half-even**（小數剛好 0.5 時只在整數部分為奇數時進位），對負數也成立，沒有直流偏差。
- 乘積最大約 2^47，49 bit 不會溢位。
- 飽和是 I、Q **各自**限制在 ±16384，複數幅度在飽和區最大可到 16384·√2，且相位會被扭曲（不是等比例壓縮）。
- 10 個 16 × 33 乘法，33 bit 超過 DSP48E2 的 27-bit port，每個乘法 2 個 DSP：**20 DSP**（build 01 確認）。

### 10.2 gain index → BRAM 位址與表格排列

```verilog
bram_addr <= MEM_BASE + 4 * gain_offset_index;    // byte address，0x0000 ~ 0x3FFC
```

`blk_mem_gen_0` 是 BRAM_Controller 模式、32-bit byte address、depth 2048，實際使用 `addrb[12:2]`，bit 13 被丟掉 → **只用 index 的低 11 bit**。表格因此是 11-bit 二補數排列：

| BRAM entry | index（S6.4） | gain | 表值（`bram.c`） |
|---|---|---|---|
| 0 | 0 | 0 dB | 0x0020_0000（1.0） |
| 1 | +1 | +0.0625 dB | 0x0020_3B2A |
| 16 | +16 | +1 dB | 0x0023_E792 |
| 964 | +964 | +60.25 dB | 0x80A6_6AB8（MSB = 1，以 unsigned 處理） |
| 1023 | +1023 | +63.9375 dB | 0xC4B0_F4F3（≈ 1573.5） |
| 1024 | −1024 | −64 dB | 0x0000_052B |
| 1952 | −96 | −6 dB | 0x0010_09B9（≈ 0.5012） |
| 2047 | −1 | −0.0625 dB | 0x001F_C543 |

- 表值 ≈ 10^(dB / 20) × 2^21；範圍 −64 ~ +63.9375 dB，步階 **0.0625 dB**，共 2048 筆。
- fixed_32_21：最大 (2^32 − 1) / 2^21 ≈ 2048 倍（+66.2 dB），最小 LSB 2^−21。entry 964 ~ 1023 的 MSB = 1，RTL 用 `{1'b0, gain}` 當 unsigned 處理，不會變負。
- index 超出 ±64 dB 時會 wrap（例如 +64 dB = 1024 → 讀到 −64 dB），沒有 clamp。目前兩個來源（manual 11-bit、TXAGC 的 pf − R 約 −37 ~ +32 dB）都不會超出。

### 10.3 `blk_mem_gen_0` / `axi_bram_ctrl_0`

| 項目 | 值（xci） |
|---|---|
| `blk_mem_gen_0` | Block Memory Generator 8.4，True_Dual_Port_RAM，2048 × 32 bit（8 KB），Primitive 8kx2 / Minimum_Area，build 01 為 2 個 RAMB36 |
| Port A | 32 bit，WRITE_FIRST，byte write enable（8 bit），接 `axi_bram_ctrl_0/BRAM_PORTA`（S_AXI_ACLK 100 MHz） |
| Port B | 32 bit，WRITE_FIRST，接 `Gain_Compensation_0`（clk 256 MHz），`web = 0` 只讀 |
| Read latency | A / B 皆 1（無 primitive / core 輸出暫存器） |
| Init file | 無（`Load_Init_File false`）→ **上電內容為 0** |
| Reset | RSTA / RSTB pin，SYNC |
| `Assume_Synchronous_Clk` | false（兩個 port 不同時脈） |
| `axi_bram_ctrl_0` | AXI BRAM Controller 4.1，AXI4、32 bit、`SINGLE_PORT_BRAM 1`、`MEM_DEPTH 2048`、`READ_LATENCY 1`、無 ECC |
| 位址 | container 內 `SEG_axi_bram_ctrl_0_Mem0` offset 0 / 8K；design_1 中 ch1 ~ ch8 = 0xA009_A000、0xA009_C000、0xA009_E000、0xA00A_0000、0xA00A_2000、0xA00A_4000、0xA00A_6000、0xA00A_8000（2.4 節） |

### 10.4 gain index 的來源（`gain_index_mux_0`，calibration hierarchy 外）

| Port | 寬度 | 來源 / 去向 |
|---|---|---|
| `gain_index_mode_sel` | 1 | `cal_cdc_0` ← mem20 |
| `gain_index_in` | 12 | `agc_emu/gain_index_tx`（TXAGC 數位 gain = pf − R，S7.4，已與類比衰減器同步） |
| `gain_index_manual` | 11 | `cal_cdc_0` ← mem21（S6.4），sign-extend 成 12 bit |
| `gain_index_out` | 12 | → `calibration/gain_offset_index`、`system_ila_ch0/probe0` |

- `mode_sel = 0` → TXAGC（**開機預設**）；`= 1` → manual（不加任何 offset）。
- **純組合邏輯**（`always @(*)`），`clk` 沒有使用，latency 0。
- 量測建議：量 FIR / 通帶 / S21 時，用 `gain_index_manual = 0`、`gain_index_mode_sel = 1` 把數位 gain 固定在 0 dB，避免 AGC 閉迴路影響量測（HANDOFF P7 的暫時對策）。量完設回 `mode_sel = 0`。

---

## 11. 輸出到 DAC

```
Gain_Compensation_0/m_axis ─▶ calibration/m_axis_iq ─▶ axis_iq_bypass_0/s_axis_cal
   ─▶ (mem38 = 0) axis_iq_bypass_0/m_axis_iq ─▶ container m_axis_iq ─▶ usp_rf_data_converter_1/sXY_axis
```

| 項目 | 內容 |
|---|---|
| 介面 | AXIS 160 bit，`HAS_TREADY 1`，`clk` domain |
| DAC 對應 | ch1 s00、ch2 s02、ch3 s10、ch4 s12、ch5 s20、ch6 s22、ch7 s30、ch8 s32（和原本 Aurora 直接送 DAC 時相同） |
| RFDC DAC | 1.28 GSPS 複數輸入、×3 interpolation、fine mixer NCO **−1.04 GHz**（2026-10-15 由同事的 −0.84 GHz 改來）、3.84 GSPS；RF 輸出頻率範圍 2.3 ~ 3.3 GHz |
| 輸出振幅 | 正常路徑經 Gain_Compensation 後保證 I、Q 絕對值 ≤ 16384（0 dBFS）；bypass 時是輸入原樣，沒有限制 |
| tready | DAC tready → `axis_iq_bypass_0` → `Gain_Compensation_0`（延遲 4 拍）→ `axis_mux_5to1_0`。其他級不看 tready（3.4） |

---

## 12. 相關暫存器與跨時脈

### 12.1 Channel 暫存器（`addressable_reg_map`，每通道一份）

Base：ch N = 0xA009_0000 + 0x1000 × (N − 1)。暫存器沒有 reset pin，以 FPGA 上電初值當 reset 值（`reg [31:0] cfg_rN = 32'h…`）。

| mem | Offset | 名稱（reg_rt 名稱） | 位元 / 格式 | HW reset | PS 開機值 | 跨時脈 | 去向 |
|---|---|---|---|---|---|---|---|
| mem0 | 0x00 | `fir_enable`（`in_band_fir_enable`） | [0]，0 = impulse，1 = 使用 tap | 0 | **1** | false path | `in_band_flatness/sl_fir_enable` |
| mem1 ~ mem16 | 0x04 ~ 0x40 | `fir_tap00` ~ `fir_tap15`（`in_band_fir_coef_tap_0~15`） | [15:0] I、[31:16] Q，各 sfix16_15（6.3） | 0 | tap7 = 0x0000_7FFF，其餘 0 | false path | `FIR_coef_unpack_0` |
| mem17 | 0x44 | `coarse_delay_offset` | [3:0]，0 ~ 15 clk | 0 | 0 | `cal_cdc_0` | `Delay_Cal_0/delay_coarse` |
| mem18 | 0x48 | `fractional_delay_offset` | [2:0]，0 ~ 4 sample | 0 | 0 | `cal_cdc_0` | `Delay_Cal_0/delay_fractional` |
| mem19 | 0x4C | `phase_offset` | [15:0] fix16_13 rad（143 × 角度） | 0 | 0 | `cal_cdc_0` | `cordic_0~4/s_axis_phase_tdata` |
| mem20 | 0x50 | `gain_index_mode_sel` | [0]，0 = TXAGC，1 = manual | 0 | 0 | `cal_cdc_0` | `gain_index_mux_0` |
| mem21 | 0x54 | `gain_index_manual` | [10:0] S6.4（1/16 dB），−64 ~ +63.9375 dB | 0 | 0（0 dB） | `cal_cdc_0` | `gain_index_mux_0` |
| mem38 | 0x98 | `bypass_axis_iq` | [0]，1 = DAC 直接收 Signal Source Mux 輸出 | 0 | 0 | `cal_cdc_0` | `axis_iq_bypass_0/bypass` |
| mem39 | 0x9C | `signal_source_select` | [0]，0 = in_0（Aurora），1 = in_1（ADC） | 0 | 0 | `cal_cdc_0` | `axis_iq_source_mux_0/sel` |

- mem22 ~ mem37（gain index offset、TXAGC / RXAGC 設定）屬於 agc_emu，經 `agc_cdc_0` 到 adc_clk，不在本文件範圍；它們透過 `gain_index_tx` 間接影響 Gain_Compensation 的 gain。mem26 `goal_ref_dbfs` 也經 `cal_cdc_0`，但給 power_fit_top 使用。
- mem40 ~ mem63 保留（讀 0）；mem64 ~ mem70 是唯讀狀態區（`status_snapshot_0`）。
- 定義來源：`docs/02_RFSoC_TX/tools/regmap_def.py`；Excel：`docs/02_RFSoC_TX/Reg_map/Reg_map_tx_ch_v0.1.xlsx`；PS：`register_map.h`；XSDB：`reg_runtime/reg_rt.tcl`（`reg_ch <1~8>` 切通道）。

### 12.2 `cal_cdc_0`（reg_clk 100 MHz → clk 256 MHz）

- 把 channel 的 mem17 ~ 21、mem26、mem38、mem39 與 system 的 sys0 ~ 3、sys15 打包成 71 bit，經 `xpm_cdc_array_single`（`DEST_SYNC_FF 3`、`SRC_INPUT_REG 1`）送到 clk。
- **穩定濾波**（`cal_cdc.v:86-105`）：同步後的整包值要**連續 `STABLE_CYCLES` = 4 拍不變**才更新輸出。原因：array_single 每個 bit 各自同步，多 bit 欄位在變化那一拍可能讀到一半新、一半舊。這些設定是 PS 偶爾寫一次的靜態值，多等幾拍沒有影響。
- 生效時間：PS 寫入後約 1 個 reg_clk（來源暫存）+ 3 個 clk（同步）+ 約 5 個 clk（濾波）≈ 數十 ns。
- reset（`rst_n`）時輸出全為 0；第一次穩定後才是暫存器的實際值。
- 限制：只適合很少變的設定；來源每拍都在變時濾波器會一直不放行。

### 12.3 XDC false path

`RFSoC_TX/hardware/RFSoC_TX.srcs/constrs_1/new/cal_plus_gain_control.xdc`：

```tcl
set_false_path -from [get_cells -hierarchical -filter {NAME =~ */addressable_reg_map/inst/cfg_r*_reg* && IS_SEQUENTIAL}] \
               -to   [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ */cal_cdc_0/inst/cfg_sync_d_reg*/C}]]
```

- 從 8 個通道的 reg map 設定暫存器（`cfg_r*`，S_AXI_ACLK）到資料時脈（以 `cal_cdc_0` 目的端暫存器的時脈指定，也就是 FPGA_clk）的路徑全部設成 false path。
- 主要對象是 mem0 ~ 16 → FIR 的 `tap_*_reg`（不經 CDC 模組）；經 `cal_cdc_0` 的設定本來就由 xpm 處理。
- source 專案寫法是 `-to [get_clocks FPGA_clk]`；target 改成由 `cal_cdc_0` 反查時脈，不依賴 container clk 之後接到哪個 clock 名稱。target 的 `overvoltage_sign.xdc` 沒有這條 false path。
- **改 reg map 的暫存器名稱（`cfg_r*`）或 `cal_cdc_0` 的實例名稱時，XDC 要一起改**，否則 FIR 係數路徑會被當成同步路徑分析而出現大量 timing violation。

---

## 13. 延遲（latency）整理

### 13.1 正常路徑（mem38 = 0）

以 container 輸入 beat 被取樣的那一拍為 0：

| 段 | Latency（clk @ 256 MHz） | 累計 | 備註 |
|---|---|---|---|
| Source Mux + bypass + split + spliter | 0 | 0 | 組合 |
| FIR（`TOP_complex_FIR_modu_1`） | 9 | 9 | 另加 group delay：impulse 7 sample；線性相位 7.5 sample |
| `axi_stream_combininp_0` | 1 | 10 | |
| `Delay_Cal_0` | 1 + coarse | 11 + coarse | 另加 fractional sample |
| `axis_demux_1to5_0` | 1 | 12 + coarse | |
| `cordic_0 ~ 4` | L_c | 12 + coarse + L_c | **L_c 未確認**（推測約 20） |
| `axis_mux_5to1_0` | 1 | 13 + coarse + L_c | |
| `Gain_Compensation_0` | 4 | **17 + coarse + L_c** | gain index → 輸出另為 5 clk |
| bypass mux → DAC | 0 | | 組合 |

- 總延遲 = **(17 + L_c + coarse) clk + (fractional + FIR group delay) sample**。
- 以 coarse = 0、fractional = 0、FIR = impulse、L_c ≈ 20（推測）估算：37 clk + 7 sample ≈ 144.5 + 5.5 = **約 150 ns**（待 CORDIC latency 確認，尚未上板驗證）。
- in_1（ADC）另有頂層 `rfdc_iq_combine_chN` 的 1 clk；RFDC ADC / DAC 內部的延遲不在此列。
- 8 個通道的 RTL 與 IP 設定相同，所以各通道的固定延遲相同；通道間差異只來自外部（Aurora / 類比鏈路），由 Delay calibration 補償。

### 13.2 bypass 路徑（mem38 = 1）

container 輸入 → 輸出 **0 clk**（純組合）。切換 mem38 時 DAC 看到的延遲會從上表的值瞬間變成 0。

### 13.3 控制延遲

| 設定 | 從 PS 寫入到生效 |
|---|---|
| mem17 ~ 21、mem38、mem39 | `cal_cdc_0`：約數十 ns（12.2） |
| mem0 ~ 16（FIR） | false path，下一個 clk 起 `tap_*_reg` 就取樣到新值（中間可能有混合值，6.7） |
| gain 表 BRAM | 寫入完成後，該 entry 下一次被讀到時生效（index → 輸出 5 clk） |
| gain index（TXAGC / manual） | `gain_index_mux` 0 clk + Gain_Compensation 5 clk |

---

## 14. 開機預設值與 PS 流程

### 14.1 `main.c` 流程

```
rfdc_dev_init → gpio_emio_init
  → gain_offset_tabel_initialize()   (bram.c：8 通道 gain 表寫入 + 讀回比對)
  → register_map_init()              (register_map.c：system + ch1 ~ ch8，初值在 reg_map_cfg.c)
  → adcInitThresh()                  (ADC threshold，給 RXAGC)
  → rfdc_reset_dc → gpio_handshake → MTS → gpio_handshake → MBS → gpio_handshake
```

gain 表與 reg map 都在第一次 BMC handshake 之前完成。

### 14.2 gain 表 BRAM（`bram.c`）

1. `GAIN_OFFSET_TBL[2048]` 以 10.2 節的排列填入（entry 0 = 0 dB … 1023 = +63.9375 dB、1024 = −64 dB … 2047 = −0.0625 dB）。
2. 對 ch1 ~ ch8（`GAIN_OFFSET_CHn_BRAM_BASE` = `XPAR_CAL_PLUS_GAIN_CONTROL_CHn_CALIBRATION_AXI_BRAM_CTRL_0_BASEADDR`，0xA009_A000 + 0x2000 × (n − 1)）：
   - `BramPsWrite_uint32()` 以 `XBram_WriteReg` 逐筆寫入 2048 個 32-bit word（byte offset = 4 × entry）；
   - 逐筆 `XBram_ReadReg` 讀回比對；
   - UART 印出 `chN gain table BRAM 0x…: 2048 entries, readback OK / FAIL (n mismatch)`。
3. 8 個通道用同一份表（目前沒有每通道不同的 gain 修正）。

> 寫表之前 BRAM 內容為 0，`Gain_Compensation` 讀到 gain = 0 → DAC 輸出全為 0。這是安全的（不會輸出未校正的大訊號），但 TX 前一定要先載入表。

### 14.3 Reg map 開機值（`reg_map_cfg.c`，8 通道相同）

| 項目 | 值 | 說明 |
|---|---|---|
| `in_band_fir_enable`（mem0） | 1 | |
| FIR tap（mem1 ~ 16） | tap7 = `FIR_IQ(0x7FFF, 0)`，其餘 0 | impulse response，與 FIR disable 時硬體使用的係數相同 → 純延遲 7 sample；量測後再換成各通道係數 |
| `coarse_delay_offset` / `fractional_delay_offset`（mem17 / 18） | 0 / 0 | |
| `phase_offset`（mem19） | 0 | 可寫 `PHASE_DEG(deg)` |
| `gain_index_mode_sel` / `gain_index_manual`（mem20 / 21） | 0 / 0.0 dB | 數位 gain 由 TXAGC 決定 |
| `signal_source_select`（mem39） | 0 | Aurora（in_0） |
| `bypass_axis_iq`（mem38） | 0 | 走完整處理路徑 |

**寫入順序**（`register_map.c` 的 `register_map_apply()`）：FIR enable = 0 → 16 個 tap → calibration（mem17 ~ 19）→ gain index / TXAGC 參考 → AGC 參數 → 模式 / enable（mem27、mem20、**mem39、mem38、最後 mem0 = 1**）。每個暫存器寫完讀回比對，數值以物理單位填寫、由 `register_map.c` 換算並檢查範圍（例如 fractional 限 0 ~ 4、coarse 限 0 ~ 15）；phase_offset 沒有範圍檢查。

### 14.4 Runtime 調整（XSDB，`reg_runtime/reg_rt.tcl`）

| 目的 | 指令範例 |
|---|---|
| 切通道 | `reg_ch 3` |
| 切到本板 ADC loopback | `reg_wr signal_source_select 1` |
| 直通（不處理） | `reg_wr bypass_axis_iq 1` |
| 數位 gain 固定 0 dB | `reg_set gain_index_manual 0`，`reg_wr gain_index_mode_sel 1` |
| 寫 FIR 係數 | `reg_wr in_band_fir_enable 0` → `reg_fir_tap <t> <I> <Q>` × 16 → `reg_wr in_band_fir_enable 1`（格式見 `fir_ch1.tcl`；其中的係數是 source 板 ch1 的，不適用於 RFSoC_TX） |

---

## 15. 驗證狀態

### 15.1 RTL 模擬

所有模擬都在 source 專案（`Calibration_Gain_Control/verification/`，Vivado 2025.2 xsim）執行；RFSoC_TX 的 RTL 與 source 逐位元組相同，所以結果適用，但**沒有在 RFSoC_TX 專案內重跑**。

| TB | 範圍 | 結果 |
|---|---|---|
| `tb_axis_iq_source_mux`（2026-10-14） | mem39 → `cal_cdc` → `axis_iq_source_mux` → `axis_iq_bypass`：reset = in_0（0 latency）、mem39 = 1 → in_1、tready（選到的 = 下游、沒選到的 = 1）、mem38 = 1 時輸出 = 被選到的那一路、切回 0 | PASS 12 checks |
| `tb_axis_iq_bypass`（2026-10-12） | mem38 → `cal_cdc` → `axis_iq_bypass`：reset = calibration 輸出、1 = 輸入直通（0 latency）且 `m_axis_cal` 照常、tready、切回 0 | PASS 10 checks |
| `tb_axis_iq_split` | combine → split round trip | PASS（1000 vectors） |
| `tb_gain_index` | reg map reset 值、`cal_cdc`、`gain_index_mux`（manual sign-extend）、`Gain_Compensation` + BRAM model（`gain_table.hex`）：0 dB 完全相同、−6 dB half-even、飽和 ±16384、+63.75 dB 不翻號、300 組隨機 bit-exact、latency 4 拍 | PASS 18 checks |
| `tb_fir_chk`（`verification/extra/`，**不在 regression 內**） | FIR：連續 / 隨機間隙 tvalid、隨機 tready、impulse（x = 16384）、大係數 wrap、latency | bit-exact（以「valid beat k ↔ 輸入 beat k − 1」比對；確認 valid 早 1 拍、沒有飽和、資料 latency 9 clk） |

### 15.2 沒有驗證的部分

- `Delay_Cal`、`axis_demux_1to5`、`axis_mux_5to1`、CORDIC：**沒有 TB**。CORDIC 的 latency、輸入 > 16384 的行為、±π 邊界都沒有確認。
- calibration 整條 hierarchy（Delay + CORDIC + Gain）串接的 bit-exact 模擬。
- FIR 開著時改係數 / 切 enable 的暫態；gain 表 BRAM 執行中更新的 collision。
- Signal Source Mux 切換時的暫態（只驗證了選擇邏輯）。

### 15.3 實作與上板

- **RFSoC_TX build 01**：timing 收斂（WNS 0.000 ns / WHS +0.010 ns）、0 critical warning；`report_cdc` 的 CDC-14 × 100 都是 FIR 係數的 false path 路徑（預期）。
- PS 程式編譯成功；ELF 中 8 通道的 reg map / BRAM base、FIR tap、mem38 / mem39 的值已確認。
- **RFSoC_TX 尚未上板驗證**：gain 表讀回、各模式的 DAC 輸出、Delay / Phase / Gain 的實際效果、latency 都還沒量。
- 參考：source 專案（不同的板子、2 通道）在 build 13 上板量過 ch1 FIR 補償後的 in-band response（2.3 / 2.8 / 3.3 GHz = −14.63 / −14.50 / −14.61 dB，起伏約 0.13 dB），Delay / Phase / Mag. 也曾在 source 板驗證；這些數據不代表 RFSoC_TX。

---

## 16. 已知限制 / 待確認

### 16.1 設計限制（RTL）

| # | 項目 | 影響 | 現況 / 建議 |
|---|---|---|---|
| L1 | **FIR 輸出沒有飽和**（取 `[30:15]`，超過 ±32767 翻號） | 輸入接近 full scale 或係數 Σ(abs(hI) + abs(hQ)) > 2.0 時，DAC 端出現極大的 glitch | HANDOFF P6：使用者決定硬體保護先不做。靠前級約定（訊號峰值 ≤ 16384，RXAGC threshold −3 dBFS）。候選修正：rounding 後飽和（每 lane 約 10 ~ 20 LUT） |
| L2 | **CORDIC 輸入超範圍**：Rotate + SignedFraction 規定 X / Y 在 ±1.0（±16384），FIR 輸出可能到 ±32767 | 超範圍時旋轉結果未定義，沒有用模擬確認 | HANDOFF P6：未模擬確認。候選：CORDIC 前限幅或先縮 6 dB 再由 Gain 補回、峰值超過 16384 的 sticky status flag |
| L3 | **FIR valid 比資料早 1 拍**（valid 鏈 6 級、資料 7 級） | 連續串流下無功能影響；reset 後第一個 valid beat 是 0（或殘值）。in_0 若有 tvalid 間隙（`data_aligner` 依 timestamp 釋放），每段資料的開頭 / 結尾會錯一個 beat（推測） | 修法：valid 鏈加 1 級，或移除 `fir_mult_sum[0]` copy stage |
| L4 | **phase ±180°**：143 × 180 = 25740 > π × 8192 ≈ 25736 | 超出 CORDIC 規定的 −π ~ +π（誤差約 0.03°） | `PHASE_DEG()` 與 `register_map.c` 都沒有 clamp；建議軟體限制在 ±25735 |
| L5 | FIR 係數 / enable 更新不是原子操作（非同步取樣，沒有 double buffer） | FIR 開著改係數時新舊 tap 混用 | SOP：先關 FIR 再寫（`register_map.c`、`fir_ch1.tcl` 都遵守）。候選：shadow + update strobe |
| L6 | Delay 執行中更改會跳 sample；mem17 / 18 分兩次寫入；fractional 5 ~ 7 = 0 延遲 | TX 波形 glitch、延遲非單調 | PS 開機寫入有範圍檢查；XSDB raw 寫入沒有 |
| L7 | gain 表 BRAM 兩個 port 不同時脈，執行中更新會有讀寫 collision；更新期間表新舊混合 | 至少 1 clk 錯誤 gain（受 ±16384 飽和限制） | 目前只在開機寫表。候選：雙 bank 切換 |
| L8 | BRAM 沒有 init file，PS 寫表前 gain = 0 | 開機到寫表前 DAC 輸出 0 | 可接受（開機流程固定先寫表） |
| L9 | gain index 只取低 11 bit，沒有 clamp | 超出 ±64 dB 會 wrap | 目前來源不會超出 |
| L10 | Backpressure 只是名義上的：正常路徑 tready 恆為 1、CORDIC NonBlocking、combininput 不看 tready | 若 DAC tready 變 0，mux 暫停但 CORDIC / Gain 不停 → 資料錯位 | 隱含假設 RFDC DAC tready 恆為 1 |
| L11 | Gain 飽和是 I / Q 各自限制 | 飽和區相位失真 | 屬設計選擇 |
| L12 | reset 風格混用（非同步 / 同步 / 無 reset）；Delay_Cal 的 pipe 帶 reset 無法用 SRL（2,705 FF） | 只影響啟動暫態與資源 | 候選：data pipe 去掉 reset |
| L13 | Signal Source Mux / bypass 切換沒有 flush 或 mute | 切換後約一個處理 latency 的混合暫態 | 屬預期 |
| L14 | 5 顆 CORDIC 對同一個常數 θ 每拍重算 | 約 5.4K LUT / 5.6K FF / 20 DSP 與約 20 clk latency | 候選：θ 改變時算一次 cos / sin，每 lane 複數乘法；或與 Gain 合併成一次複數乘法 |

### 16.2 待確認事項

| # | 項目 | 說明 |
|---|---|---|
| Q1 | **FIR 係數格式文件不一致** | `regmap_def.py` / `Reg_map_tx_ch_v0.1.xlsx` 寫 S1.14；RTL（`>> 15`）與 `fir_ch1.tcl`（sfix16_15）是 S0.15。已於 2026-10-16 修正 regmap_def、Register_Map.md 與 Excel（已解決） |
| Q2 | **CORDIC latency L_c** | xci 沒有記錄、netlist 加密；需用 IP GUI 或模擬確認後補到第 13 章 |
| Q3 | **bypass 或來源 tvalid = 0 時 DAC 的行為** | 正常路徑在 tvalid = 0 時 tdata 被清成 0；bypass 時 tdata 原樣送出。RFDC DAC 是否忽略 tvalid、直接輸出 tdata（推測是）需確認，會影響 Aurora 尚未釋放資料時 DAC 的輸出內容 |
| Q4 | RFSoC_TX 各通道的 FIR 係數、Delay / Phase / Gain 校正值 | 目前全部是 0 / impulse，需要在 RFSoC_TX 上量測後產生 |
| Q5 | z1 NCO 與 in_0 的頻率 | z2 改成 DAC −1.04 GHz，但 z1 的 ADC NCO 仍是 0.84 GHz（整合紀錄 §5 第 1 項）；in_0 這一路的輸出頻率理論上會偏 0.2 GHz（未驗證）。in_1（本板 loopback）不受影響 |
| Q6 | 開機預設改變 | mem39 = 0、mem38 = 0：Aurora 資料會經過處理，不再像 rev0.11 那樣直接送 DAC；需和同事確認是否接受，或預設 mem38 = 1 |
| Q7 | `bram.c` 填表寫法 | 2048 筆表值寫在 `for (i < GAIN_TBL_SIZE)` 迴圈內，整張表被重複賦值 2048 次（功能正確，只是多餘；開機時間影響待確認） |
| Q8 | 上板驗證 | 第 15.3 節所列項目全部待量測 |

---

## 17. 修訂歷程

| 版本 | 日期 | 適用 build | 內容 |
|---|---|---|---|
| v0.1 | 2026-10-16 | RFSoC_TX build 01 | 初版：由 Calibration_Gain_Control 設計解析 v0.2 §2 / §4 / §6、`AGC_EMU_Design_Note.md` §5d、`HANDOFF.md` P6 改寫成 target（8 通道、位址、時脈、PS 開機值）；新增 Signal Source Mux（`axis_iq_source_mux`，mem39）的說明（依 RTL）；依 RTL / BD 修正素材：FIR 係數格式為 sfix16_15、impulse 的 bit-exact 範圍為 −16383 ~ +16384、FIR `aclken` / 正常路徑 tready 邏輯上恆為 1、資源改用 build 01 的 `util_hier.rpt` |
