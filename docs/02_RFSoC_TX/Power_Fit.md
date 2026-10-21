# RFSoC_TX Power Fit 設計文件（power_fit_top）

| | |
|---|---|
| 專案 | `PJ22045_1R8T_release_Rex_rev0.1_20261015/RFSoC_TX`（z2，Vivado 2025.2，xczu47dr-ffvg1517-2-i，top `design_1_wrapper`） |
| 範圍 | `cal_plus_gain_control_ch1` ~ `ch8` 內的 hierarchy `power_fit_top`（`cw_power_calc_IQ_0`、`power_fit_db_0`、`db_log_rom`），以及它和 Signal Source Mux、`cal_cdc_0`、system / channel reg map、`vio_ext_inputs`、`agc_emu`、`status_snapshot_0` 的介面 |
| 文件版本 | v0.1（2026-10-16） |
| 適用 build | RFSoC_TX build 01（2026-10-15，`output_data/01/RFSoC_TX_01.bit / .ltx / .xsa`） |
| 資料來源 | RTL：`hardware/RFSoC_TX.srcs/sources_1/new/cal_plus_gain_control/`；BD：`cal_plus_gain_control.bd`、`design_1.bd`（JSON 讀出）；reg map：`docs/02_RFSoC_TX/tools/regmap_def.py`、`software/app_component/src/sources/reg_map_cfg.c`；build 報告：`hardware/scripts/log/util_hier.rpt`、`timing_impl.rpt` |
| 狀態 | 設計已 build、timing 收斂；**尚未上板驗證**。模擬結果來自 source 專案 Calibration_Gain_Control 的 TB（RTL 與本專案逐檔比對完全相同） |

> 本文件描述目前的設計。設計改變時更新內文，並在第 13 節「修訂歷程」加一列。

---

## 1. 閱讀指引

- 第 2 節說明 Power Fit 在通道中做什麼、放在哪裡；第 3 節是介面與暫存器總表，接線或寫軟體時先看這節。
- 第 4、5 節分別是 CW 與 Pulse 兩種模式「輸入振幅怎麼來」；第 6 節是兩種模式共用的 dB 域計算（goal、pf、goal_rel）。
- 第 7、8 節是延遲與跨時脈；第 9 節是上板時怎麼讀狀態、怎麼判讀；第 10 節是開機預設值與建議設定。
- 第 11、12 節是驗證現況與已知限制 / 待確認事項。
- 用語：
  - `clk` = FPGA_clk 256 MHz（1 拍 = 3.906 ns），資料路徑與 Power Fit 都在這個 domain。
  - `adc_clk` = RFDC `clk_adc0~3`（240 MHz），`agc_emu` 核心所在 domain。
  - `reg_clk` = `S_AXI_ACLK` = PS `pl_clk0` 100 MHz，reg map 所在 domain。
  - **pf** = `gain_index_power_fit`，Power Fit 算出的數位增益（S5.4，1/16 dB，正值 = 放大）。
  - dBFS 以 **16384 = 0 dBFS** 為基準（系統約定；例：8211 ≈ −6 dBFS，11599 ≈ −3 dBFS）。
  - S*m*.*n* / U*m*.*n* = 有號 / 無號定點數，*n* 位小數；本模組的 dB 值都是 *n* = 4（1 LSB = 1/16 dB = 0.0625 dB）。
  - `file:line` 為 2026-10-16 時本專案檔案的行號。
- 8 個通道的 Power Fit 完全相同（同一個 BD container），下文以 chN 表示任一通道。

---

## 2. 功能概述與在通道中的位置

### 2.1 做什麼

`power_fit_top` 量測（CW）或接收（Pulse）訊號的平均振幅，在 dB 域算出「把訊號位準搬到目標位準 goal 所需要的數位增益」pf，同時輸出 goal 本身與 goal 相對於參考 goal 的差：

| 輸出 | 公式 | 用途 |
|---|---|---|
| `gain_index_power_fit`（pf） | round(goal − input_dBFS)，飽和 ±511 | 送 `agc_emu`（TXAGC）做類比 / 數位增益分配 |
| `goal_rel_db` | goal − `goal_ref_dbfs`，飽和 ±511 | 送 `agc_emu`（TXAGC Manual mode 推算 DAC 輸出） |
| `goal_db` | goal | 狀態 / ILA 觀察 |
| `power_amp` | 單一 sample 的瞬間振幅 sqrt(I² + Q²) | 狀態 / ILA 觀察（**未平均**） |

goal 的定義：

| 模式（`signal_mode_select`） | 輸入振幅 | goal（dBFS） |
|---|---|---|
| 0 = CW | `cw_power_calc_IQ` 量到的振幅，區塊平均 N = 2^k 個 sample | min(`cw_mode_goal_dbfs`, −`power_limit_margin`) |
| 1 = Pulse | 外部輸入 `pulse_avg_amp`（目前由 VIO 提供），自動鎖存 | −(`power_limit_margin` + `pulse_papr`) |

**重點：Power Fit 只「算」增益，不碰資料。** 資料路徑上的 FIR / CORDIC 看到的是未經 pf 修正的訊號；pf 經 `agc_emu` → `gain_index_mux_0` → `calibration` 內的 `Gain_Compensation` 才套用到資料上。

### 2.2 在通道中的位置

```
 design_1                                  cal_plus_gain_control_chN
                              ┌──────────────────────────────────────────────────────────────────────────────────────┐
 hier_rx_x0yN/M_AXIS_Cx ─────►│ s_axis_iq_in_0 ┐                                                                     │
 (Aurora, data_aligner)       │                ├─ axis_iq_source_mux_0 ─► axis_iq_bypass_0 ─┬─────────────────────────┼─► m_axis_iq ─► RFDC DAC
 rfdc_iq_combine_chN ────────►│ s_axis_iq_in_1 ┘   (sel = mem39)            (bypass = mem38)│ (bypass = 1 時直通)     │
 (本板 ADC mXY0 / mXY1)        │                                                  m_axis_cal ▼                         │
                              │                       axis_iq_split_0 (160 b → I 80 b / Q 80 b)                       │
                              │                                 ▼                                                    │
                              │                       axis_spliter_iq_0 ── m0 ──► in_band_flatness ─► combine ─► calibration ─► axis_iq_bypass_0
                              │                                 │ m1 (同一份資料, FIR 之前)            ▲ gain_offset_index   │
                              │                                 ▼                                      │                     │
 vio_ext_inputs ─────────────►│ pulse_avg_amp / pulse_papr ─► power_fit_top ── pf / goal_rel ──► agc_emu ── gain_index_tx ─► gain_index_mux_0
 (probe_out 4N-2 / 4N-1)      │                                 │  power_amp / pf / goal_db / goal_rel          (manual: mem20 / mem21)
 system_reg_map sys0~3,15 ───►│ reg_* ─► cal_cdc_0 ────────────►│ (6 個設定)                                         │
 (0xA009_8000)                │ mem26 (addressable_reg_map) ──► cal_cdc_0                                            │
                              │                                 └──► status_snapshot_0 ─► mem65~68 ─► PS / xsdb      │
                              │                                 └──► system_ila_ch0 probe1 (power_amp) / probe2 (goal_db)
                              └──────────────────────────────────────────────────────────────────────────────────────┘
```

要點：

- **量測點**：`axis_spliter_iq_0` 的 m1 與 m0 是同一份資料（`axis_spliter_iq.v:296-309` 純組合直通），所以 Power Fit 量的是 Signal Source Mux 選到的訊號、在 in-band FIR **之前**。
- **訊號來源**：由 channel mem39 `signal_source_select` 決定（0 = Aurora `s_axis_iq_in_0`、1 = 本板 ADC `s_axis_iq_in_1`，reset 0）。沒選到的那一路資料直接丟掉，Power Fit 看不到。
- **mem38 `bypass_axis_iq` = 1** 時，DAC 輸出改為 Mux 輸出直通，但 `m_axis_cal` 仍持續送進處理路徑（`axis_iq_bypass.v` 註解與 `assign m_axis_cal_* = s_axis_iq_*`），所以 **Power Fit / AGC 照常計算**，只是結果不影響 DAC 輸出。
- pf 不直接進 `gain_index_mux_0`：`gain_index_mux_0/gain_index_in` 接的是 `agc_emu/gain_index_tx`（TXAGC 分配後、與類比同步的數位增益 pf − R）；`gain_index_mode_sel`（mem20）= 1 時改用 `gain_index_manual`（mem21），Power Fit 結果就完全不會套用到資料。

### 2.3 hierarchy 內部

```
                    ┌──────────────────────────────── power_fit_top ───────────────────────────────────┐
 s_axis_i (80 b) ──►│ cw_power_calc_IQ_0                                                              │
 s_axis_q (80 b) ──►│   取 sample 2 ─► power_computation_wrapper ─► power_computation                 │
                    │                 (I² + Q², 2 DSP) ─► square_root (6 拍) ─► o_power_amp ─┬──────────►│ power_amp
                    │                                                    o_power_valid      │           │
                    │                                                         │             ▼           │
 pulse_avg_amp ────►│ power_fit_db_0 ◄────────────── cw_valid ─────────────────┘        cw_amp         │
 pulse_papr ───────►│   Pulse 自動鎖存 / CW 區塊平均 ─► goal 選擇 ─► msb + db_log_rom ─► goal − input  │
 6 個設定 ─────────►│   (signal_mode_select, power_limit_margin, cw_mode_goal_dbfs,                    │──► gain_index_power_fit
 (cal_cdc_0)        │    goal_ref_dbfs, pulse_update_stable_cycle, cw_power_avg_log2)                  │──► goal_rel_db
                    │                                                                                  │──► goal_db
 clk / rst_n ──────►│ 兩個子模組共用（rst_n → cw_power_calc_IQ_0/resetn、power_fit_db_0/rst_n）        │
                    └──────────────────────────────────────────────────────────────────────────────────┘
```

BD 內部接線（`cal_plus_gain_control.bd` → `power_fit_top`）：

| Net | 連接 |
|---|---|
| `axis_spliter_iq_0_m1_axis_i / _q` | hierarchy `s_axis_i / s_axis_q` → `cw_power_calc_IQ_0/s_axis_i / s_axis_q` |
| `cw_power_calc_IQ_0_o_power_amp` | → `power_fit_db_0/cw_amp` 與 hierarchy port `power_amp`（同一條 net） |
| `cw_power_calc_IQ_0_o_power_valid` | → `power_fit_db_0/cw_valid` |
| `clk_1` / `rst_n_1` | 兩個子模組共用 |
| 其他設定、`pulse_*`、三個輸出 | hierarchy port 與 `power_fit_db_0` 同名 port 直通 |

### 2.4 8 個通道的對應

| Ch | 資料來源 in_0（Aurora） / in_1（ADC） | Reg map base（mem26 / mem64~68） | VIO `pulse_avg_amp` / `pulse_papr` |
|---|---|---|---|
| 1 | `hier_rx_x0y2/M_AXIS_C0` / m00、m01 | 0xA009_0000 | probe_out2 / probe_out3 |
| 2 | `hier_rx_x0y2/M_AXIS_C1` / m02、m03 | 0xA009_1000 | probe_out6 / probe_out7 |
| 3 | `hier_rx_x0y1/M_AXIS_C0` / m10、m11 | 0xA009_2000 | probe_out10 / probe_out11 |
| 4 | `hier_rx_x0y1/M_AXIS_C1` / m12、m13 | 0xA009_3000 | probe_out14 / probe_out15 |
| 5 | `hier_rx_x0y3/M_AXIS_C0` / m20、m21 | 0xA009_4000 | probe_out18 / probe_out19 |
| 6 | `hier_rx_x0y3/M_AXIS_C1` / m22、m23 | 0xA009_5000 | probe_out22 / probe_out23 |
| 7 | `hier_rx_x0y4/M_AXIS_C0` / m30、m31 | 0xA009_6000 | probe_out26 / probe_out27 |
| 8 | `hier_rx_x0y4/M_AXIS_C1` / m32、m33 | 0xA009_7000 | probe_out30 / probe_out31 |

- system_reg_map（`0xA009_8000`）的 sys0~3、sys15 同時接到 8 個通道，**模式、margin、CW goal、M、k 是 8 通道共用的**；每個通道自己的只有 `goal_ref_dbfs`（mem26）與 `pulse_avg_amp` / `pulse_papr`。
- VIO probe 編號規則：chN 的 `pulse_avg_amp` = probe_out(4N − 2)、`pulse_papr` = probe_out(4N − 1)（由 `design_1.bd` 讀出）。

### 2.5 資源用量（build 01，routed，`util_hier.rpt`）

| Hierarchy（ch1） | LUT | FF | RAMB36 | RAMB18 | DSP |
|---|---|---|---|---|---|
| `power_fit_top` | 735 | 457 | 0 | 1 | 2 |
| `cw_power_calc_IQ_0` | 466 | 213 | 0 | 0 | 2 |
| `power_fit_db_0` | 269 | 244 | 0 | 1 | 0 |

8 個通道的 `power_fit_top` 在 730~735 LUT 之間，FF / BRAM / DSP 完全相同；8 通道合計約 5.9K LUT、3,656 FF、8 個 RAMB18、16 個 DSP（佔整個 `cal_plus_gain_control_chN` 的 DSP 363 個中的 2 個）。

---

## 3. 介面

### 3.1 hierarchy port（`power_fit_top`）

| Port | Dir | 寬度 | Clock | 格式 / 意義 |
|---|---|---|---|---|
| `clk` | I | 1 | — | FPGA_clk 256 MHz（design_1 `util_ds_buf_0/IBUF_OUT`） |
| `rst_n` | I | 1 | clk | active-low，同步使用；來源 `dac_rst1/peripheral_aresetn` |
| `s_axis_i_tdata / tvalid / tready` | I / I / O | 80 / 1 / 1 | clk | 每拍 5 個 I sample，每個 16-bit 有號，sample k 在 `[16k+15:16k]`；tready 恆為 1 |
| `s_axis_q_tdata / tvalid / tready` | I / I / O | 80 / 1 / 1 | clk | 同上，Q |
| `pulse_avg_amp` | I | 16 | clk | Pulse 平均振幅，U16，16384 = 0 dBFS |
| `pulse_papr` | I | 9 | clk | Pulse PAPR，U5.4 dB（0 ~ 31.9375 dB） |
| `signal_mode_select` | I | 1 | clk | 0 = CW，1 = Pulse |
| `power_limit_margin` | I | 3 | clk | U3.0 dB（0 ~ 7） |
| `cw_mode_goal_dbfs` | I | 11 | clk | S6.4 dBFS |
| `goal_ref_dbfs` | I | 11 | clk | S6.4 dBFS |
| `pulse_update_stable_cycle` | I | 4 | clk | M，單位 clk（0 ~ 15） |
| `cw_power_avg_log2` | I | 4 | clk | k，CW 平均 N = 2^k（> 12 視為 12） |
| `power_amp` | O | 16 | clk | 單一 sample 的瞬間振幅（U16，同 sample 刻度） |
| `gain_index_power_fit` | O | 10 | clk | pf，S5.4 dB，±511（±31.9375 dB） |
| `goal_rel_db` | O | 10 | clk | S5.4 dB，±511 |
| `goal_db` | O | 12 | clk | S7.4 dBFS |

注意：hierarchy **沒有輸出 valid / update strobe**。下游 `agc_cdc` 以「值有改變」作為更新事件。

### 3.2 輸入來源（BD 接線）

| 輸入 | 來源 | 說明 |
|---|---|---|
| `s_axis_i / s_axis_q` | `axis_spliter_iq_0/m1_axis_i / m1_axis_q` | 上游依序為 `axis_iq_split_0` ← `axis_iq_bypass_0/m_axis_cal` ← `axis_iq_source_mux_0`，全部是組合邏輯（0 拍） |
| `pulse_avg_amp / pulse_papr` | container port → design_1 `vio_ext_inputs` | VIO clk = FPGA_clk，與 Power Fit 同一個 domain；沒有 valid；**暫時的輸入來源**，之後由前級取代 |
| `signal_mode_select` | `cal_cdc_0` ← container `reg_signal_mode_select` ← `system_reg_map/sys0` | reg_clk → clk |
| `power_limit_margin` | `cal_cdc_0` ← `sys1` | 同上 |
| `cw_mode_goal_dbfs` | `cal_cdc_0` ← `sys2` | 同上 |
| `pulse_update_stable_cycle` | `cal_cdc_0` ← `sys3` | 同上 |
| `cw_power_avg_log2` | `cal_cdc_0` ← `sys15` | 同上 |
| `goal_ref_dbfs` | `cal_cdc_0` ← `addressable_reg_map/mem26` | 同上（每個通道各自一份） |

上游資料格式：`axis_iq_source_mux_0` 輸出為 160-bit，每個 sample 32-bit = {Q[15:0], I[15:0]}，共 5 個；`axis_iq_split_0` 拆成 I / Q 各 80-bit。

- in_0（Aurora）：`data_aligner` 依 timestamp 釋放資料，`m_axis_tvalid = out_valid && s_axis_tvalid`，未到釋放時間時 tvalid = 0、tdata = 0。
- in_1（ADC）：`rfdc_iq_combine_chN`（`axi_stream_combininput`）把 RFDC mXY0 / mXY1 合併，RFDC 兩路都 valid 時輸出 valid（1 拍暫存）。

### 3.3 輸出去向（BD 接線）

| 輸出 | 接到 |
|---|---|
| `power_amp` | `system_ila_ch0/probe1`、`status_snapshot_0/power_amp`（→ mem65 `st_power_amp`） |
| `gain_index_power_fit` | `agc_emu/gain_index_power_fit`、`status_snapshot_0/gain_index_power_fit`（→ mem66） |
| `goal_rel_db` | `agc_emu/goal_rel_db`、`status_snapshot_0/goal_rel_db`（→ mem68） |
| `goal_db` | `system_ila_ch0/probe2`、`status_snapshot_0/goal_db`（→ mem67） |

`agc_emu` 內的用法（細節屬 agc_emu 範圍，這裡只列和 Power Fit 有關的部分；來源 `txagc_calc.v`、`txagc.v`）：

| TXAGC 模式 | 目標總衰減 T（1/16 dB） | pf / goal_rel 的角色 |
|---|---|---|
| Linear（`agc_tx_power_mode` sys4 = 0） | 1545 + linear_mode_offset − rx_att_index × 160 + **pf** − offs + algo × 16 | pf 加進類比衰減目標，數位端再補 pf − R，使總增益與 Power Fit 無關 |
| Manual（sys4 = 1） | dac_output_ref_dbm + **goal_rel_db** + 800 − target_power × 16 + manual_mode_offset − offs + algo × 16 | 數位位準由 pf 維持在 goal，goal_rel 用來推算 goal 改變後的 DAC 輸出 |
| `agc_bypass_agc` = 1 | 類比 = PS 指定檔位 | 數位 gain index = pf |

TXAGC 輸出的數位 gain index = pf − R（R = 數位殘差），經 `gain_apply_sync` 與類比同步、`agc_cdc` 回到 clk，成為 `gain_index_tx` → `gain_index_mux_0` → `calibration/Gain_Compensation`。

### 3.4 時脈與 reset

| 訊號 | 來源 | 說明 |
|---|---|---|
| `clk` | `util_ds_buf_0/IBUF_OUT`（FPGA_clk 256 MHz） | Power Fit 全部在此 domain；VIO、Signal Source Mux、資料路徑同 domain |
| `rst_n` | `dac_rst1/peripheral_aresetn` | 只 reset `power_fit_db` 的鎖存 / 平均邏輯與 `power_computation` / `square_root` 的 valid；datapath 暫存器只有上電初值、沒有 reset |

### 3.5 相關暫存器

System（`system_reg_map`，base `0xA009_8000`，8 通道共用）：

| Reg | Offset | 名稱 | 位元 | Reset | 格式 / 範圍 | 說明 |
|---|---|---|---|---|---|---|
| sys0 | 0x000 | `signal_mode_select` | [0] | 0 | bit | 0 = CW，1 = Pulse |
| sys1 | 0x004 | `power_limit_margin` | [2:0] | 3 | U3.0 dB，0 ~ 7 | power limit = −margin dBFS |
| sys2 | 0x008 | `cw_mode_goal_dbfs` | [10:0] | 0x7A0（−6.0） | S6.4 dBFS，建議 −64 ~ 0 | CW goal；硬體另限制 ≤ −margin |
| sys3 | 0x00C | `pulse_update_stable_cycle` | [3:0] | 4 | clk，0 ~ 15 | Pulse 自動鎖存所需的穩定拍數 M |
| sys15 | 0x03C | `cw_power_avg_log2` | [3:0] | 8 | 0 ~ 12（> 12 視為 12） | CW 區塊平均 N = 2^k |
| sys14 | 0x038 | `build_version` | [31:0] | 唯讀 | — | build 01 目前讀回 **0**（BUILD_VERSION 參數未設定） |

Channel（`addressable_reg_map`，base `0xA009_0000` + 0x1000 × (N − 1)）：

| Reg | Offset | 名稱 | 位元 | Reset | 格式 | 說明 |
|---|---|---|---|---|---|---|
| mem20 | 0x050 | `gain_index_mode_sel` | [0] | 0 | bit | 0 = TXAGC（含 pf），1 = 手動（pf 不套用到資料） |
| mem21 | 0x054 | `gain_index_manual` | [10:0] | 0 | S6.4 dB | 手動 gain index |
| mem26 | 0x068 | `goal_ref_dbfs` | [10:0] | 0x7A0（−6.0） | S6.4 dBFS | 量 `dac_output_ref_dbm` 時的 goal；goal_rel = goal − goal_ref |
| mem38 | 0x098 | `bypass_axis_iq` | [0] | 0 | bit | 1 = DAC 直接輸出 Mux 結果（Power Fit 照常計算） |
| mem39 | 0x09C | `signal_source_select` | [0] | 0 | bit | Power Fit 量測來源：0 = Aurora，1 = 本板 ADC |
| mem64 | 0x100 | `status_snapshot` | [15:0] | 0 | W: bit0 = 1 觸發；R: 完成次數 | 見第 9 節 |
| mem65 | 0x104 | `st_power_amp` | [15:0] | 唯讀 | U16 | snapshot 當拍的 `power_amp`（瞬間值） |
| mem66 | 0x108 | `st_gain_index_power_fit` | [9:0] | 唯讀 | S5.4 dB，符號擴展 | pf |
| mem67 | 0x10C | `st_goal_db` | [11:0] | 唯讀 | S7.4 dBFS，符號擴展 | goal |
| mem68 | 0x110 | `st_goal_rel_db` | [9:0] | 唯讀 | S5.4 dB，符號擴展 | goal_rel |
| mem69 | 0x114 | `st_gain_index_tx` | [11:0] | 唯讀 | S7.4 dB，符號擴展 | TXAGC 給 gain_index_mux 的值（pf − R），對照用 |

定點換算：raw = round(dB × 16)，取 11-bit 二補數。例：−6.0 dBFS → −96 → 0x7A0；−3.0 → −48 → 0x7D0；−10.0 → −160 → 0x760。

### 3.6 VIO 輸入（`vio_ext_inputs`）

- 32 個 probe_out，每通道 4 個：rx_att_index[2:0]、algo_analog_att_db[8:0]、**pulse_avg_amp[15:0]**、**pulse_papr[8:0]**；clk = FPGA_clk。
- 初值全部為 0（xci `C_PROBE_OUTn_INIT_VAL` = 0）。所以開機後若切到 Pulse mode 而沒有設 VIO，`pulse_avg_amp` = 0 → pf = +511（見 6.6）。
- VIO 的多個 probe 不保證在同一拍更新，`power_fit_db` 的自動鎖存（第 5 節）就是為此設計。

---

## 4. CW 模式

### 4.1 `cw_power_calc_IQ`：取一個 sample

`cw_power_calc_IQ.v:51-54`：

```verilog
wire [15:0] sample3_i = s_axis_i_tdata[47:32];   // 0-based sample 2
wire [15:0] sample3_q = s_axis_q_tdata[47:32];
wire sample_valid = s_axis_i_tvalid && s_axis_q_tvalid;
```

- 每拍 5 個 complex sample 中**只用 index 2**（第 3 個），等效 256 MS/s 抽樣。
- `tready` 恆為 1（沒有 back-pressure）；`axis_spliter_iq` 的上游 tready = m0 && m1，所以節奏由 FIR 那一路決定。
- `sys_reset = ~resetn` 轉成 active-high 給下層；`power_computation_wrapper.v` 只是 SystemVerilog 模組的 1:1 Verilog 包裝（讓 BD module reference 能用），沒有邏輯。

### 4.2 `power_computation`：I² + Q²

```
i_inphase    ─► $signed × $signed ─► inp_squ_reg[30:0] ─┐ (拍 1)
i_quadrature ─► $signed × $signed ─► qua_squ_reg[30:0] ─┴─► + ─► inp_qua_add_reg[31:0] (拍 2) ─► square_root (6 拍) ─► o_power
i_valid ─────► valid[0] (拍 1) ─► valid[1] (拍 2) ──────────────────────────────────► square_root.i_valid ─► o_valid
```

- 有號平方，最大 (−32768)² = 2^30，取 `[30:0]` 不會遺失；相加最大 2^31，32-bit 無號足夠。
- 兩個乘法各 1 個 DSP。乘法器**輸入端沒有暫存器**（I/Q 直接從上游組合路徑進 DSP），這是 build 01 near-critical path 的成因（見 12.1）。
- 開根號後最大值 floor(sqrt(2^31)) = 46340，16-bit 不會溢位。

### 4.3 `square_root`：逐位開根號

- 演算法：digit-by-digit restoring 整數開根號。32-bit 被開方數切成 16 個 2-bit pair（MSB 先），每處理一個 pair 決定 root 的一個 bit：`cur = {rem, pair}`、`test = {root, 2'b01}`，cur ≥ test 時 rem' = cur − test、root' = {root, 1}，否則 root' = {root, 0}。結果為 floor(sqrt(X))。
- Pipeline：step3、6、8、10、12 輸出加暫存器，再加 `o_out` 暫存器，共 6 級；尚未用到的 pair 走「三角形延遲線」（`pairs_p` → `pairs_d1` … `pairs_d4`，每級丟掉已用的 pair）以省 FF。
- valid：`valid_reg[4:0]` 5 級 + `o_ready` 1 級 = **6 拍**，與資料對齊（`square_root.sv:60-61` 註解）。
- `i_rst` 有接到每個 `square_iter`，但內部未使用。

`cw_power_calc_IQ` 總 latency：平方 + 加法 2 拍 + square_root 6 拍 = **8 拍**（I/Q 在邊緣 E0 被取樣，`o_power_amp / o_power_valid` 在 E7 之後有效）。

### 4.4 CW 區塊平均（`power_fit_db.v:74-104`）

`cw_power_calc` 給的是單一 sample 的瞬間振幅，每拍都會晃（source 板上 CW 實測 1736 ± 35）。若直接拿來算 pf，pf 幾乎每拍改變（HANDOFF P7 的上板問題）。所以 CW 模式先做 integrate-and-dump：

```
avg_k   = min(cw_power_avg_log2, 12) ;  avg_nm1 = 2^avg_k − 1
每個 cw_valid:
    if cw_cnt >= avg_nm1 : cw_sum <= cw_acc + cw_amp ; cw_k <= avg_k ; cw_done <= 1 ; cw_acc <= 0 ; cw_cnt <= 0
    else                 : cw_acc <= cw_acc + cw_amp ; cw_cnt <= cw_cnt + 1
if cw_done : snap_cw <= cw_sum >> cw_k          // 下一拍除以 N (floor)
```

- 每 N 個 `cw_valid` 產生一次 `snap_cw = floor(Σ cw_amp / N)`；`cw_acc` 28 bit（4096 × 65535 < 2^28，不溢位）。
- 數的是 **valid 的 sample 數**，不是 clk 數：資料連續時 N 個 sample = N 拍；Aurora 來源在 `data_aligner` 尚未釋放資料時 tvalid = 0，這些拍不計入。
- `cw_k` 在 dump 時一起鎖存，讓「被加總的個數」與「除數」屬於同一個 k。
- 結果是**振幅平均 mean|x|**，不是功率平均（見 12.2）。
- 預設 k = 8：N = 256 ≈ 1.0 µs 更新一次；k = 0 等於不平均（每個 sample 更新一次）；k = 12：N = 4096 ≈ 16 µs。
- `snap_cw` 為 0（reset 後還沒完成第一個區塊，或來源一直沒有 valid）時被當作 1 處理，pf = +511（見 6.6）。

### 4.5 CW goal

```verilog
// power_fit_db.v:109-110, 118
wire signed [11:0] lim = -$signed({5'd0, power_limit_margin, 4'd0});   // -margin (1/16 dB)
wire signed [11:0] cwg = {cw_mode_goal_dbfs[10], cw_mode_goal_dbfs};
g1 <= signal_mode_select ? pulg : ((cwg > lim) ? lim : cwg);
```

CW 的 PAPR = 0，goal = min(`cw_mode_goal_dbfs`, −margin)，也就是硬體強制 CW goal 不超過 power limit。預設 cw goal −6、margin 3 → goal = −6 dBFS。若把 `cw_mode_goal_dbfs` 設成 −2 而 margin 為 3，實際 goal 會是 −3（PS 的 `register_map.c` 開機時會印 `[NOTE]` 提示）。

### 4.6 和訊號來源有關的注意事項

- **切換 mem39** 時，正在累加的那個區塊會同時包含兩個來源的 sample，下一個區塊之後才完全是新來源的結果（最多約 2N 個 sample）。
- **Aurora 沒有資料**（link 未建立或 data_aligner 未釋放）：`cw_valid` 一直為 0，`snap_cw` 停在上一次的值（reset 後為 0 → pf = +511），沒有任何 flag 表示「CW 量測停止」。
- **mem38 bypass = 1**：Power Fit 仍量測 Mux 輸出並更新 pf，只是 DAC 輸出不經 gain。

---

## 5. Pulse 模式

### 5.1 介面約定

- `pulse_avg_amp`：Pulse 的平均振幅，刻度 **16384 = 0 dBFS**，量測點應與資料路徑相同（FIR 之前、Signal Source Mux 選到的 I/Q 振幅）。刻度錯 1 bit 就是 6 dB 誤差，硬體無法偵測。
- `pulse_papr`：U5.4 dB（例：3 dB = 48、10 dB = 160）。
- 前級（目前是 VIO）**不提供 valid**，而且 avg 與 PAPR 可能在不同拍改變。
- 和前級的約定（HANDOFF P6）：訊號峰值 ≤ 16384，即 avg ≤ 16384 × 10^(−PAPR/20)（PAPR 3 / 6 / 10 / 20 dB → 約 11600 / 8210 / 5180 / 1640）。在這個約定下 pf ≥ −margin，不會負向飽和。

### 5.2 自動更新（`power_fit_db.v:42-72`）

```
avg_d / papr_d <= 輸入（每拍）
if (輸入 != 上一拍)               pend <= 1, stable_cnt <= 0        // 有變化 → 重新計時
else if (pend)
    if (stable_cnt + 1 >= M)      snap_avg / snap_papr <= avg_d / papr_d, pend <= 0   // 連續 M 拍不變 → 一起鎖存
    else                          stable_cnt <= stable_cnt + 1
```

- avg 與 PAPR **一起**鎖存，pf / goal_rel / goal_db 由同一組鎖存值算出、**同一拍**輸出，所以下游 `agc_cdc` 只看到一次變化 → TXAGC 只算一次 → SR 只傳一次（HANDOFF P1）。
- `pend` 的 reset 值為 1：reset 放開後不必等輸入變化，連續 M 拍穩定就先鎖存一次。
- 比較式用 5 bit（`{1'b0, stable_cnt} + 5'd1 >= {1'b0, M}`），`stable_cnt = 15` 時 +1 不會溢位。
- **M = 0 與 M = 1 行為相同**（都在變化後第 2 拍鎖存）。
- 鎖存邏輯與 `signal_mode_select` 無關：CW 模式下也持續追蹤 Pulse 輸入，切到 Pulse 時直接用最新的 snapshot。
- 若輸入以 ≤ M 拍的間隔持續改變，會一直不鎖存（starvation），pf 停在舊值，且沒有狀態可看（見 12.2）。

### 5.3 時間推導

設 t0 = 新值出現的那個邊緣：

| 邊緣 | 動作 |
|---|---|
| t0 + 1 | 偵測到 `輸入 != avg_d` → pend = 1、cnt = 0 |
| t0 + 2 … t0 + M | 每拍比較相等並計數 |
| t0 + 1 + M | `cnt + 1 >= M` → 鎖存 snap_avg / snap_papr |
| t0 + M + 7 | 三個輸出同時更新（鎖存後固定 6 拍，見第 6 節） |

M = 4（預設）：11 拍 = 43 ns；M = 15（最大）：22 拍 ≈ 86 ns。TB 實測 M = 4 為 11.0 拍、M = 10 為 17.0 拍。

### 5.4 Pulse goal

```verilog
// power_fit_db.v:111
wire signed [11:0] pulg = -$signed({1'b0, {power_limit_margin, 4'd0} + {1'b0, snap_papr}});   // -(margin + PAPR)
```

goal = −(margin + PAPR) dBFS：讓平均位準退後 PAPR，使峰值落在 −margin dBFS。margin 與 PAPR 本來就是 dB，不需要 log 運算。範圍 0 ~ −38.94 dB（margin 7 + PAPR 31.94）。

注意：`power_limit_margin` 不經過自動鎖存（`pulg` 是組合邏輯，直接用 cal_cdc 的輸出），margin 改變會在 6 拍後直接反映到 goal，與 PAPR 的鎖存無關。

---

## 6. dB 域計算

### 6.1 Pipeline（`power_fit_db.v`）

```
stage 0  輸入鎖存      snap_avg / snap_papr（Pulse 自動鎖存）      snap_cw（CW 區塊平均）
            │
stage 1  x1 <= mode ? max(snap_avg,1) : max(snap_cw,1)    g1 <= mode ? pulg : min(cwg, lim)        (:115-119)
            │  p1 = msb_pos(x1)，norm = x1 << (15 − p1)                                          (組合)
stage 2  p2 <= p1，m2 <= norm[14:5]，g2 <= g1                                                     (:137-141)
stage 3  db_log_rom q1 <= ROM[m2]                p3, g3                                           (db_log_rom, :150-153)
stage 4  db_log_rom q  <= q1（= q4）             p4, g4
            │  in_q8 = pk(p4) + q4 ；goal_q8 = g4 × 16                                           (組合, 1/256 dB)
stage 5  diff5 <= goal_q8 − in_q8，g5 <= g4                                                       (:166-173)
            │  pf_r = (diff5 + 8) >>> 4 ；rel = g5 − goal_ref_dbfs
stage 6  gain_index_power_fit / goal_rel_db / goal_db 同時 <=（飽和）                              (:178-184)
```

- 鎖存 → 輸出固定 **6 拍**；沒有迴圈，每拍都可以吐新結果。
- `signal_mode_select`、`power_limit_margin`、`cw_mode_goal_dbfs` 在 stage 1 進入（6 拍後反映）；`goal_ref_dbfs` 在 stage 6 才進入（1 拍後反映，只影響 goal_rel）。

### 6.2 振幅 → dBFS

設 x ≥ 1，p = 最高位 1 的位置（`msb_pos`，`:124-130`），x = 2^p × (1 + f)：

```
dBFS(x) = 20·log10(x / 16384) = 20·log10(2) × (p − 14) + 20·log10(1 + f)
        ≈ (p − 14) × 6.0206 + 20·log10(1 + m / 1024)
```

- `norm = x1 << (15 − p1)` 把 leading one 對齊到 bit15，`m = norm[14:5]` 取接下來 10 bit（**截斷**，不是四捨五入）。
- `pk(p) = round(256 × 6.0206 × (p − 14))`（`:158-165`，16 筆 case；p = 14 → 0、p = 15 → +1541、p = 0 → −21578），單位 1/256 dB。
- `db_log_rom`：`q = round(256 × 20·log10(1 + m/1024))`，m = 0 ~ 1023，單位 1/256 dB（0 ~ 1540）。
- `in_q8 = pk(p4) + q4`（1/256 dB），範圍 −21578（x = 1，−84.29 dBFS）~ +3081（x = 65535，+12.04 dBFS）。

### 6.3 `db_log_rom`（`db_log_rom.v`）

- 1024 × 11-bit `case` 表，`(* rom_style = "block" *)`，每通道推成 1 個 RAMB18。
- 兩級暫存：`q1 <= ROM[m]` + `q <= q1`（BRAM output register），latency 2 拍；讓 BRAM clock-to-out 不和後面的 17-bit 加法、減法擠在同一拍。
- 檔頭標示「由 `hardware/scripts/gen_db_rom.py` 產生，請勿手改」。該腳本在 source 專案 `Calibration_Gain_Control/hardware/scripts/gen_db_rom.py`，**RFSoC_TX 專案內沒有**；要改精度（例如 m 改 11 bit）時用 source 專案的腳本重新產生。

### 6.4 pf、goal_rel、goal_db 與飽和（`power_fit_db.v:178-184`）

```verilog
wire signed [13:0] pf_r = (diff5 + 18'sd8) >>> 4;        // 1/256 → 1/16 dB，round half up
wire signed [12:0] rel  = g5 - goal_ref_dbfs;
gain_index_power_fit <= (pf_r > 511) ? 511 : (pf_r < -511) ? -511 : pf_r[9:0];
goal_rel_db          <= (rel  > 511) ? 511 : (rel  < -511) ? -511 : rel[9:0];
goal_db              <= g5;
```

- 捨入：`(diff + 8) >>> 4` = floor(diff/16 + 0.5)，round-half-up（負數的 .5 往 0 方向）。
- 飽和 ±511（±31.9375 dB）：10-bit 有號下限其實是 −512，取 −511 讓正負對稱。飽和時**沒有任何 flag**。
- `pf_r` 在 18 bit 運算後取 14 bit；`diff5` 實際範圍 ±(32768 + 21578)，右移後 ±3397，不會因截斷翻號。
- 三個輸出在同一拍、由同一組 g5 / diff5 更新。

### 6.5 數值格式

| 訊號 | 寬度 | 格式 | 範圍 |
|---|---|---|---|
| `lim` | S12 | 1/16 dB | −112 ~ 0（−7 ~ 0 dB） |
| `pulg` | S12 | 1/16 dB | −623 ~ 0 |
| `cwg` | S12 | 1/16 dB | −1024 ~ +1023 |
| `g1` ~ `g5`、`goal_db` | S12 | 1/16 dB | 實際 −1024 ~ 0（−64 ~ 0 dBFS） |
| `x1` | U16 | 振幅 | 1 ~ 65535 |
| `p2` ~ `p4` | U4 | leading-one 位置 | 0 ~ 15 |
| `m2` | U10 | mantissa | 0 ~ 1023 |
| `q4` | U11 | 1/256 dB | 0 ~ 1540 |
| `in_q8` | S17 | 1/256 dB | −21578 ~ +3081 |
| `goal_q8` | S17 | 1/256 dB | g4 × 16 |
| `diff5` | S18 | 1/256 dB | |
| `pf_r` | S14 | 1/16 dB | 飽和前 |
| `rel` | S13 | 1/16 dB | |

### 6.6 邊界情況

| 情況 | 結果 |
|---|---|
| 輸入振幅 x = 0（無訊號、reset 後未鎖存、VIO 為 0） | 當作 x = 1（−84.29 dBFS），pf = **+511**（+31.94 dB） |
| 輸入過小：x < goal − 31.94 dB（CW goal −6 時 x < 約 208） | pf 正向飽和 +511 |
| 輸入過大：x 最大可到 65535（+12.04 dBFS） | pf 可到 −(12.04 + 38.94)，超過 −31.94 dB 時負向飽和 −511 |
| goal_ref 與 goal 差超過 ±31.94 dB | goal_rel 飽和 ±511 |

`x = 0 當作 1`（`:116-117`）：`msb_pos(0)` 會回 0、`norm = 0`，結果其實和 x = 1 相同；這個 mux 是把 log(0) 的情況在原始碼上明示處理。

### 6.7 精度

- m 截斷造成 f 少算 < 1/1024 → 最多 20·log10(1 + 1/1024) ≈ 0.0085 dB（input 低估、pf 偏大）；ROM 與 pk 各有 ±1/512 dB 的捨入誤差。
- 對 x = 1 ~ 65535 全掃（source 設計解析 §3.4.5）：x < 1024 時誤差 ≤ 0.0037 dB；1024 ≤ x ≤ 32767 最大 −0.0099 dB；x ≥ 32768 最大 −0.0110 dB。都遠小於輸出 LSB（0.0625 dB），只在 .5 LSB 邊界偶爾差 1 LSB（TB D2：2000 筆中 84 筆差 1 LSB）。
- `power_fit_db.v` 檔頭寫的「誤差 ≤ 0.009 dB」略為樂觀（見 12.3）。

### 6.8 換算範例

例（Pulse）：avg = 4000、PAPR = 48（3 dB）、margin = 3。

```
p = 11，norm = 4000 << 4 = 64000，m = 976，ROM[976] = 1489，pk(11) = −4624
in_q8   = −4624 + 1489 = −3135      (−12.246 dB，真值 −12.247)
goal    = −(3 + 3) dB = −96 (1/16)  → goal_q8 = −1536
diff5   = −1536 − (−3135) = 1599
pf      = (1599 + 8) >>> 4 = 100    → +6.25 dB（真值 6.247）
```

常用振幅對照（16384 = 0 dBFS）：

| 振幅 | dBFS | CW goal −6 時的 pf |
|---|---|---|
| 16384 | 0.00 | −6.00 dB（−96） |
| 11599 | −3.00 | −3.00 dB（−48） |
| 8211 | −6.00 | 0（0） |
| 5181 | −10.00 | +4.00 dB（64） |
| 1736 | −19.50 | +13.50 dB（216） |
| 1638 | −20.00 | +14.00 dB（224） |
| 518 | −30.00 | +24.00 dB（384） |
| 208 | −37.93 | +31.93 dB（511，接近飽和） |

### 6.9 程式寫法注意：`$signed` 與 concatenation

```verilog
// power_fit_db.v:166-167
wire signed [16:0] in_q8   = pk(p4) + $signed({6'd0, q4});
wire signed [16:0] goal_q8 = $signed({g4, 4'd0});        // concat 為無號, 需轉回有號再符號擴展
```

Verilog 的 concatenation 結果永遠是 unsigned。若寫成 `wire signed [16:0] goal_q8 = {g4, 4'd0};`，16-bit 無號值指定到 17-bit 時會 zero-extend，負的 goal 會變成很大的正數，pf 直接飽和 +511（build 12 開發時發生過）。運算式中只要有一個 unsigned 運算元，整個式子就按 unsigned 計算，所以 `{6'd0, q4}` 先補 0 再 `$signed`。`lim`、`pulg` 同理。修改這段程式時要保留這些 `$signed`。

---

## 7. 時序與延遲

單位：clk = 3.906 ns；adc_clk = 4.167 ns。

| 路徑 | 延遲 | 來源 |
|---|---|---|
| `cw_power_calc_IQ`：I/Q 取樣 → `o_power_amp` | 8 拍 | RTL |
| `square_root` 單獨 | 6 拍 | RTL、tb_square_root |
| `power_fit_db`：鎖存（snap_*）→ 三個輸出 | 6 拍 | RTL |
| CW：區塊最後一個 sample 的 `cw_valid` 邊緣 e → 輸出 | e + 7 拍 | RTL |
| CW：區塊最後一個 sample 進 hierarchy → pf | 約 15 拍（≈ 60 ns） | RTL（8 + 7） |
| CW：更新週期 | N 個 valid sample（預設 256 ≈ 1.0 µs，資料連續時） | RTL |
| CW：輸入位準改變 → pf 完全反映 | N ~ 2N 個 sample + 15 拍 | RTL |
| Pulse：輸入改變 t0 → 輸出 | M + 7 拍（M = 4：11 拍 = 43 ns） | RTL、TB D6 |
| `signal_mode_select` / margin / cw goal（cal_cdc 輸出後）→ 輸出 | 6 拍 | RTL |
| `goal_ref_dbfs`（cal_cdc 輸出後）→ `goal_rel_db` | 1 拍 | RTL |
| PS 寫暫存器 → cal_cdc 輸出 | 約 1 個 reg_clk + 3 級同步 + 5 拍穩定濾波（約 40 ~ 50 ns） | RTL（cal_cdc） |
| pf 改變 → `agc_cdc` 的 adc_clk 端 | 約 25 ~ 28 ns | tb_pulse_timeline |

系統層 timeline（`tb_pulse_timeline`，Pulse avg 與 PAPR 同拍改變，M = 4，`agc_sr_update_period` 50，`digital_apply_delay` 35，Manual / Linear 相同）：

| 事件 | 距 t0 |
|---|---|
| pf / goal_rel / goal_db 輸出 | 43.0 ns（11 拍） |
| `agc_cdc` adc_clk 端收到 pf / goal_rel | 67.6 ~ 71.4 ns |
| TXAGC `tx_att_state` / `gain_index_digital` | 84.3 ~ 88.1 ns |
| SR 傳送開始 | 88.4 ~ 92.3 ns |
| RCLK（類比衰減鎖存） | 238.4 ~ 242.2 ns |
| `gain_index_tx`（clk，→ gain_index_mux） | 273.4 ~ 277.3 ns |
| 數位增益套用到資料（+ Gain_Compensation 4 拍） | 約 289 ~ 293 ns |

不含：595 輸出延遲、衰減器切換時間、Gain_Compensation 之後的資料路徑（RFDC DAC）。以上為模擬值，**尚未上板量測**。

---

## 8. 跨時脈

`power_fit_top` 內部全部在 clk domain，跨時脈都在外面：

| 方向 | 訊號 | 處理方式 | 模組 |
|---|---|---|---|
| reg_clk → clk | 6 個設定（sys0~3、sys15、mem26） | `xpm_cdc_array_single`（SRC_INPUT_REG 1、DEST_SYNC_FF 3），整組 71 bit 連續 4 拍（`STABLE_CYCLES`）不變才更新輸出 | `cal_cdc_0` |
| clk（VIO） | `pulse_avg_amp` / `pulse_papr` | 不需 CDC（VIO 在 FPGA_clk）；多 probe 不同拍更新由自動鎖存處理 | `power_fit_db` |
| clk → adc_clk | `gain_index_power_fit` + `goal_rel_db`（20 bit） | `xpm_cdc_handshake`（SRC / DEST_SYNC_FF 3）：值改變就送，傳送中再改變則傳完後送最新值；兩個欄位同時到達 | `agc_emu/agc_cdc_0` |
| clk → reg_clk | `power_amp`、pf、`goal_db`、`goal_rel_db`（及 `gain_index_tx`） | snapshot 觸發脈衝 `xpm_cdc_pulse` 到 clk，在同一拍鎖存；鎖存值保持不變，以 `xpm_cdc_array_single` 同步回 reg_clk | `status_snapshot_0` |
| clk | `power_amp`、`goal_db` | `system_ila_ch0` 與 Power Fit 同 clk，無 CDC | ILA |

說明：

- `cal_cdc_0` 的穩定濾波是對**整組**設定一起判斷：任何一個欄位在變，所有欄位都暫停更新，直到整組連續 4 拍不變。reset 期間 `cal_cdc_0` 輸出全為 0（mode = CW、margin = 0、cw goal = 0、goal_ref = 0、M = 0、k = 0），reset 放開後約 5 拍載入暫存器的值。
- PS 一次只能寫一個暫存器，依序寫 margin、cw goal 等多個欄位時，中間組合可能各自產生一次 pf 更新；最終會收斂到全部寫完的設定。
- pf 改 handshake 的原因（HANDOFF P7）：build 12 用「穩定濾波」跨 pf，CW 時 pf 幾乎每拍變，濾波一直不放行，TXAGC 用的 pf 卡在舊值數秒。handshake 保證每次改變都送到（速率約每 25 ns 一筆，期間的中間值被最新值取代）。
- `agc_cdc_0` 的 handshake 來源端使用 `rst_n`（clk domain），目的端使用 `rst_n_adc`（`xpm_cdc_async_rst` 同步到 adc_clk），reset 時 adc_clk 端的 pf / goal_rel 為 0。

---

## 9. 狀態讀取與除錯

### 9.1 status snapshot（mem64 ~ 70）

1. 寫 mem64 `status_snapshot` bit0 = 1 → reg map 產生 1 拍脈衝。
2. 脈衝經 `xpm_cdc_pulse` 到 clk 與 adc_clk，兩個 domain 各在收到的那一拍鎖存（相差 < 約 20 ns）。clk 端一起鎖存 `power_amp`、pf、`goal_db`、`goal_rel_db`、`gain_index_tx`，所以這幾個值屬於**同一拍**。
3. 兩個 domain 都鎖存完成後 mem64 讀值（完成次數）+ 1；軟體看到計數改變再讀 mem65 ~ 70。有號欄位讀回時已符號擴展。

判讀注意：

- `st_power_amp` 是 snapshot 那一拍 sample 2 的**瞬間振幅**，不是 pf 實際使用的區塊平均 `snap_cw`。CW 抖動時多次 snapshot 會看到 ±幾 % 的變化；要和 pf 對照時，應多讀幾次取平均，或直接用 pf 反推：input_dBFS ≈ goal − pf。
- Pulse 模式下 `st_power_amp` 仍是 CW 量測路徑的值（與 pf 無關），pf 來自 `pulse_avg_amp`。
- 換算：dBFS = 20·log10(st_power_amp / 16384)；pf / goal / goal_rel 的 raw ÷ 16 = dB。

### 9.2 XSDB `reg_dump`（`reg_runtime/reg_rt.tcl`）

```
xsdb reg_rt.tcl status 1            # 連線、snapshot ch1、印出並存檔
xsdb reg_rt.tcl status all          # ch1 ~ ch8
xsdb -interactive reg_rt.tcl shell <url>
xsdb% reg_dump 5                    # 互動模式下 snapshot ch5
xsdb% reg_dump all
```

- `<url>`：`TCP:localhost:31000`（既有 hw_server）、BMC XVC（`reg_runtime/README.md` 記載 47DR2 為 `xvc:192.168.68.42:2550`，本板實際位址待確認），省略 = 本機 USB-JTAG。
- 每個通道印一段：`=== chN status  snapshot #n  <時間>  build <sys14> ===`，接著 `st_power_amp`、`st_gain_index_power_fit`（dB）、`st_goal_db`（dBFS）、`st_goal_rel_db`（dB）、`st_gain_index_tx`（dB）、adc_flags，以及一行 settings（mode、margin、cw_goal、tx_power_mode、goal_ref、dac_ref、target）。
- 同時寫 `reg_status_<日期時間>.txt`，並附加一列到 `reg_status_<日期>.csv`。
- build 01 的 `build_version`（sys14）讀回 0，不是 1。
- 設定類：`reg_set signal_mode_select 1`、`reg_set power_limit_margin 3`、`reg_set cw_mode_goal_dbfs -6`、`reg_set pulse_update_stable_cycle 4`、`reg_set cw_power_avg_log2 8`（system 暫存器，不受 `reg_ch` 影響，8 通道同時生效）；`reg_ch 3` 後 `reg_set goal_ref_dbfs -6`（只改 ch3）。

### 9.3 ILA 與 VIO

- `system_ila_ch0`（每個通道一個，clk domain）：probe0 = `gain_index_mux_0/gain_index_out`、**probe1 = `power_amp`**、**probe2 = `goal_db`**、probe3 = `agc_emu/tx_att_clamp`。ltx：`output_data/01/RFSoC_TX_01.ltx`。
- `vio_ext_inputs`：chN 的 `pulse_avg_amp` = probe_out(4N − 2)、`pulse_papr` = probe_out(4N − 1)。

### 9.4 常見現象判讀

| 現象 | 可能原因 | 檢查 |
|---|---|---|
| pf = +31.9375 dB（+511） | 無訊號；CW 的 `cw_valid` 從未出現（Aurora 未送資料、mem39 選錯來源）；Pulse 模式 VIO 還是 0；reset 後還沒完成第一個區塊 | `st_power_amp` 是否為 0 / 很小；mem39；`signal_mode_select`；VIO probe 值 |
| pf = −31.9375 dB（−511） | 輸入振幅過大（> goal + 31.94 dB），或 `pulse_avg_amp` 刻度錯 | `st_power_amp` / VIO 值是否 > 16384 |
| `st_goal_db` 不是預期的 cw goal | margin 限制（goal = min(cw goal, −margin)）；或目前是 Pulse 模式 | settings 行的 mode / margin / cw_goal |
| Pulse 改了 VIO，pf 不變 | 輸入一直在變（starvation，M 太大）；或目前是 CW 模式 | `pulse_update_stable_cycle`；`signal_mode_select` |
| CW pf 每次 snapshot 都不同 | k 太小（N = 1 時 pf 跟著每個 sample 變） | `cw_power_avg_log2`（建議 ≥ 8） |
| 量 S21 時頻響有 5 dB 跳動或邊緣翹起 | AGC 閉迴路下 S21 = 通道 + AGC 補償 | 量通道本身時固定數位 gain：`reg_set gain_index_manual 0`、`reg_wr gain_index_mode_sel 1`（恢復：`reg_wr gain_index_mode_sel 0`） |

---

## 10. 開機預設值與建議設定

### 10.1 硬體 reset 值與 PS 開機初值

| 暫存器 | 硬體 reset | PS 開機寫入（`reg_map_cfg.c`） |
|---|---|---|
| sys0 `signal_mode_select` | 0（CW） | 0（CW） |
| sys1 `power_limit_margin` | 3 | 3 dB |
| sys2 `cw_mode_goal_dbfs` | 0x7A0 | −6.0 dBFS |
| sys3 `pulse_update_stable_cycle` | 4 | 4 |
| sys15 `cw_power_avg_log2` | 8 | 8（N = 256） |
| mem26 `goal_ref_dbfs`（ch1 ~ ch8） | 0x7A0 | −6.0 dBFS |
| mem20 `gain_index_mode_sel` | 0 | 0（TXAGC） |
| mem38 `bypass_axis_iq` | 0 | 0 |
| mem39 `signal_source_select` | 0 | 0（Aurora） |
| VIO `pulse_avg_amp` / `pulse_papr` | 0 / 0 | （VIO，PS 不寫） |

- PS 寫入順序（`register_map.c`）：system 先寫 Power Fit 參數，**`signal_mode_select` 最後寫**；之後各通道依序寫，`goal_ref_dbfs` 在「gain index / TXAGC 參考」那一段。
- 開機後狀態：CW 模式、goal = −6 dBFS、來源 = Aurora。Aurora 尚未送資料前 pf = +511。

### 10.2 建議設定

| 用途 | 設定 |
|---|---|
| CW 一般操作 | sys0 = 0、margin 3、cw goal −6、k = 8（每 1 µs 更新一次，抖動小）；需要更快反應時 k 降到 4 ~ 6（N = 16 ~ 64），但 pf 抖動會增加 |
| Pulse（VIO 模擬前級） | 先在 VIO 設好該通道的 `pulse_avg_amp`、`pulse_papr`，再 `reg_set signal_mode_select 1`；M 維持 4（足以吸收 VIO 不同拍更新） |
| 量通道頻響 / FIR | `gain_index_mode_sel` = 1、`gain_index_manual` = 0（數位增益固定 0 dB，Power Fit 不影響資料） |
| 改 goal_ref_dbfs | 必須等於量測 `dac_output_ref_dbm`（mem25）時的 goal；改了 goal_ref 就要重新量 dac_output_ref_dbm，否則 Manual mode 的 DAC 輸出推算會偏移 |
| 改 k | 盡量在 CW 未運作時改，或改完後忽略第一次更新（見 12.2 第 7 項） |

### 10.3 上板 bring-up 檢查順序（建議）

1. `xsdb reg_rt.tcl status all`：每個通道的 snapshot 計數都會增加；`st_goal_db` = −6.000 dBFS（CW 預設）。
2. 用本板 ADC 送 CW：`reg_ch N`、`reg_wr signal_source_select 1`；確認 `st_power_amp` 與輸入位準一致（dBFS = 20·log10(x/16384)），pf ≈ −6 − input_dBFS。
3. 切回 Aurora（`signal_source_select` 0），在 Aurora 資料流動時重複第 2 步。
4. Pulse：VIO 設 avg = 4000、PAPR = 48（3 dB），`reg_set signal_mode_select 1` → 預期 `st_goal_db` = −6.0、pf = +6.25 dB（第 6.8 節範例）。
5. 改 margin / PAPR，確認 goal 依 −(margin + PAPR) 變化、goal_rel = goal − goal_ref。

---

## 11. 驗證狀態

### 11.1 模擬（source 專案 `Calibration_Gain_Control/verification/`，`sim/run_sim.sh`，最後一次回歸 2026-10-14 18:02）

RFSoC_TX 的 Power Fit 相關 RTL（`power_fit_db.v`、`db_log_rom.v`、`cw_power_calc_IQ.v`、`power_computation*.sv/.v`、`square_root.sv`、`cal_cdc.v`、`status_snapshot.v`、`agc_emu/*.v`、`axis_iq_source_mux.v` 等）與 source 專案逐檔比對完全相同，所以以下結果適用。

| TB | 內容 | 結果 |
|---|---|---|
| `tb_power_fit_db` | D1 Pulse goal_db = −(margin + PAPR)，margin 0 ~ 7 × PAPR 0 ~ 511 全掃；D2 2000 組隨機 avg / PAPR，pf 與實數參考差 ≤ 1 LSB、goal_rel 完全相等；D3 CW goal = min(cw_goal, −margin)、無 cw_valid 不更新；D4 goal_rel 飽和 +511 與 +96；D5 avg = 1 / 0 → +511、avg = 65535 → −511；D6 自動鎖存（同拍改變一次更新、三輸出同拍、latency 11 拍；相隔 2 拍改變仍一次；M = 1 相隔 4 拍兩次；M = 10 latency 17 拍）；D7 CW 1736 ± 35 抖動，N = 256 時 40 個區塊 pf 只變 1 次且 = 平均振幅的 pf（215，期望 216 ± 1），N = 1 時 1024 拍變 716 次 | PASS，17 checks |
| `tb_square_root` | square_root 與 floor(sqrt) 逐筆比對 20000 筆（含 k²、k² + 1、0xFFFF_FFFF、隨機） | PASS（TB 印出的 first-sample latency 7 是從送輸入那拍起算，實際 6 拍） |
| `tb_pulse_timeline` | 系統層 timeline（power_fit_db → agc_cdc → TXAGC → SR / Gain_Compensation），Manual / Linear 各 26 phase，每級只變一次；CW 抖動 400 µs：N = 1 / H = 0 → SR 換檔 1658 次，N = 256 / H = 1 dB → 0 次，TXAGC pf 與 Power Fit pf 最多差 23 ns | PASS |
| `tb_gain_index` | cal_cdc（dBFS goal、pulse_update_stable_cycle）、gain_index_mux、Gain_Compensation | PASS |
| `tb_reg_maps` | system / channel reg map reset 值、R/W、status_snapshot 計數 / 值 / 符號擴展 | PASS |
| `tb_axis_iq_source_mux` | Signal Source Mux：sel 0 / 1、latency 0、沒選到的一路 tready = 1、與 bypass 的關係 | PASS，12 checks |

### 11.2 實作（build 01）

- Timing 收斂：整體 WNS 0.000 ns / WHS +0.010 ns，0 critical warning。
- 和 Power Fit 有關的 near-critical path：FPGA_clk slack **+0.003 ns**，`hier_rx_x0y3/data_aligner_0/sys_time_reg` → `cal_plus_gain_control_ch5/axis_iq_source_mux_0` → `power_fit_top/cw_power_calc_IQ_0/.../inp_squ_reg_reg`（DSP），10 級邏輯（見 12.1）。

### 11.3 覆蓋缺口

- **尚未上板驗證**（RFSoC_TX build 01 尚未在板上執行；source 板的 build 13 CW 平均 / handshake 修正也還在「待上板驗證」）。
- `cw_power_calc_IQ` / `power_computation` 整體（sample 選取、平方、valid 對齊、8 拍 latency）沒有獨立 TB；`power_fit_top` 整個 hierarchy（I/Q → pf）沒有端到端模擬，也沒有接上 Signal Source Mux / Aurora `data_aligner` 的模擬。
- 執行中改 `cw_power_avg_log2`、k > 12 的鉗位、k = 12 的累加上限。
- reset 中 / reset 剛放開時的輸出序列；CW ↔ Pulse 切換瞬間；Pulse 鎖存期間 margin / goal_ref 改變的交互。
- Pulse starvation、M = 0。
- 負數 .5 邊界的捨入方向（TB 以 ±1 LSB 容忍，沒有 bit-exact 參考模型）。

---

## 12. 已知限制 / 待確認

後續版本要優化的項目（timing、pf = +511 無 flag、8 通道共用設定、sys14）已彙整於 `Follow_Up.md` F1 ~ F4。

### 12.1 本專案（target）特有

1. **Timing 餘裕幾乎為 0**：build 01 中 Aurora 來源的 `data_aligner`（timestamp 比較 → tdata mux）經 Signal Source Mux 直接進 `cw_power_calc` 的平方 DSP，中間沒有暫存器，ch5 slack 只有 +0.003 ns。之後任何改動（加 ILA、改擺放）都可能讓這條路徑失敗。建議在 `cw_power_calc_IQ` 輸入端加一級暫存器（CW 結果晚 1 拍，對 Power Fit 無影響），或在 Signal Source Mux 後加 register slice（會改變資料路徑 latency，需要評估）。**建議下一版修正**（12.4 第 1 項）。
2. **pulse_avg_amp / pulse_papr 目前由 VIO 提供**，不是真正的前級；前級的介面（是否有 valid、更新節奏、avg 的定義是 RMS 還是 mean|x|、刻度是否為 16384 = 0 dBFS、量測點是否在 Signal Source Mux 之後）**待與同事確認**。
3. **Aurora 來源的振幅刻度**：Power Fit 以 16384 = 0 dBFS 為基準，Aurora 送來的資料（z1 ADC 經 Aurora）是否沿用同一刻度待確認；刻度不同時 pf 會整體偏移。
4. **8 通道共用 sys0 ~ 3、sys15**：所有通道必須同為 CW 或同為 Pulse，margin / cw goal / M / k 也相同；只有 `goal_ref_dbfs` 與 Pulse 輸入是每通道各自的。若之後需要各通道不同模式，要把這些暫存器搬到 channel reg map。
5. **Aurora 沒資料時沒有指示**：`cw_valid` 停止時 `snap_cw` 保持舊值（reset 後為 0 → +511），沒有 timeout 或 status flag。
6. **切換 mem39 時**，一個區塊會混到兩個來源的 sample（4.6）。
7. `build_version`（sys14）在 build 01 讀回 0，reg_dump 檔案裡的 build 欄位無法區分版本。
8. `db_log_rom.v` 檔頭提到的 `hardware/scripts/gen_db_rom.py` 不在本專案內（在 source 專案）。

### 12.2 設計本身（沿用 source）

1. **CW 只用 5 個 sample 中的 1 個**（`cw_power_calc_IQ.v` 取 `[47:32]`）：統計量少，對調變訊號 / 雜訊的估計方差較大；若訊號頻率與 1/5 抽樣有特定關係可能有偏差。
2. **振幅平均 ≠ 功率平均**：CW 兩者相同；對類雜訊訊號（Rayleigh），mean|x| = (√π/2)·RMS，低約 1.05 dB，pf 會偏大約 1 dB。PAPR 一般以功率定義，Pulse 與 CW 的刻度定義可能不一致。
3. **飽和沒有 flag**：pf ±511、goal_rel ±511、輸入 > 16384 都沒有 status；無訊號時 pf = +31.94 dB，可能把雜訊放大到接近滿刻度。
4. **FIR / CORDIC 看到的是未經 pf 修正的訊號**（HANDOFF P6）：FIR 輸出不飽和（超過 ±32767 會翻號），CORDIC fix16_14 超過 1.0 是規格外。硬體保護目前不做（Rex 決定），依賴前級遵守振幅約定。
5. **Reset 行為**：reset 期間 `snap_avg = snap_cw = 0` → 約 6 拍後 pf = +511；reset 放開後 CW 要等第一個 N 區塊（預設約 1 µs）、Pulse 要等 M 拍才有正確值；cal_cdc reset 時 k = 0、mode = CW。下游 TXAGC 在這段期間會看到 +31.94 dB（推測影響有限，因 agc_emu 同時也在啟動流程中，未驗證）。
6. **CW 平均 N 與反應時間的取捨**：區塊平均（非滑動）使更新延遲在 N ~ 2N 之間。
7. **執行中把 k 改小的暫態**：`avg_nm1` 用即時的 `avg_k`，但 `cw_cnt` 已累積；若 `cw_cnt ≥ 新的 avg_nm1`，會立即 dump 一個樣本數 > 2^k_new 的區塊再除以 2^k_new，`cw_sum >> cw_k` 可能超過 16 bit 而在指定給 `snap_cw` 時被截斷，產生一次錯誤的 pf（可能觸發一次多餘的類比換檔）。改大 k 只會讓該區塊延長。
8. **沒有 valid / update strobe 輸出**：下游只能用「值改變」判斷更新；無法統計更新次數。
9. **Pulse starvation**：輸入以 ≤ M 拍間隔持續改變時永遠不鎖存，pf 停在舊值且沒有狀態可看；M 最大 15 拍（58.6 ns），前級 multi-bit 偏移更大時仍可能分兩次更新。
10. **捨入不對稱**：round-half-up，負數 .5 往 0 方向，影響 ≤ 1 LSB。
11. `st_power_amp` 是瞬間值，和 pf 實際使用的平均值不同，看 status 時容易誤判（9.1）。

### 12.3 文件 / 註解不一致（RTL 功能正確，只是文字）

1. `power_fit_db.v` 檔頭寫「誤差 ≤ 0.009 dB」，實際全範圍最大 0.0099 dB（≤ 0 dBFS）/ 0.011 dB（> +6 dBFS）。
2. `agc_cdc.v`（`goal_rel_db` port 註解）與 `txagc_calc.v` 把 `goal_rel_db` 寫成「20log10(goal / goal_ref)」，是 build 11 以前振幅域的說法；數學上等價，但現在是 dBFS 直接相減。

### 12.4 未來可改良

| # | 改良 | 效益 | 成本 |
|---|---|---|---|
| 1 | `cw_power_calc_IQ` 輸入加暫存器（**建議下一版**） | 解除 12.1 第 1 項的 timing 風險 | 160 FF / 通道，CW 晚 1 拍 |
| 2 | 用全部 5 個 sample 計算 | 統計量 ×5，抖動約 ↓√5 | +8 DSP / 通道 |
| 3 | 功率域平均 + 10·log10（移除 square_root） | 得到真正 RMS，與 PAPR 定義一致；省約 450 LUT、6 拍 | 累加器變寬；需與前級確認 avg 定義 |
| 4 | 輸出 update strobe | 下游可直接觸發、可計數 | 1 FF + agc_cdc 介面修改 |
| 5 | Status sticky flag（pf 飽和、輸入 > 16384、x = 0、CW 無 valid timeout）、鎖存 / 區塊計數、`snap_cw` 進 status_snapshot | 上板除錯可直接從 reg_dump 判斷 | 數十 FF + status 位址 |
| 6 | k 改變時重新開始區塊 | 消除 12.2 第 7 項的暫態 | 數個 LUT |
| 7 | reset / 無訊號時輸出 0 或保持，而不是 +511 | 啟動行為更安全 | 改 x = 0 的語意，TB D5 要同步改 |
| 8 | m 四捨五入或 ROM 改 11 bit（仍為 1 RAMB18） | 轉換誤差降到約 0.004 dB | 改 `gen_db_rom.py` |
| 9 | Pulse 鎖存加 timeout | 前級持續變化時不會停在舊值 | 計數器 + 暫存器 |
| 10 | 模式 / margin / cw goal 改為每通道 | 8 通道可各自操作 | reg map 改版、PS / reg_rt.tcl 同步修改 |

---

## 13. 修訂歷程

| 版本 | 日期 | 適用 build | 內容 |
|---|---|---|---|
| v0.1 | 2026-10-16 | RFSoC_TX build 01 | 初版：由 source 專案設計解析 §3（power_fit_top）、AGC_EMU Design Note 5b / 5c、HANDOFF P1 / P2 / P6 / P7 改寫為 RFSoC_TX（8 通道、位址 0xA009_xxxx、Signal Source Mux 來源、VIO probe 對應、build 01 用量與 timing）。同日補充：timing 風險（12.1 第 1 項）列為建議下一版修正 |
