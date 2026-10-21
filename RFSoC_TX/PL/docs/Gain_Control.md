# RFSoC_TX Gain Control 設計文件（agc_emu / gain_index_mux）

| | |
|---|---|
| 專案 | PJ22045_1R8T rev0.1（Rex），`RFSoC_TX/hardware/RFSoC_TX.xpr`（Vivado 2025.2，xczu47dr-ffvg1517-2-i，top `design_1_wrapper`，z2 / 47dr2） |
| 範圍 | 8 個 `cal_plus_gain_control_chN` container 內的 hierarchy `agc_emu`（TXAGC / RXAGC / 模式控制 / 74LVC595 shift register / 數位與類比同步 / 跨時脈），以及 hierarchy 外的 `gain_index_mux_0`（數位 gain index 選擇） |
| 適用 build | RFSoC_TX build 01（2026-10-15，`RFSoC_TX/output_data/01/`） |
| 文件版本 | v0.1（2026-10-16） |
| 狀態 | RTL 與 source 專案相同，已在 source 專案以模擬 TB 驗證；**尚未上板驗證**。**Shift register 腳位（Reg1~5 SER / SRCLK / RCLK）在 RFSoC_TX 沒有拉到頂層、也沒有腳位約束**，見 §8.7 與 §14 |

> 本文件描述 RFSoC_TX 目前的設計。數值、位址、暫存器名稱、寬度與預設值以 RTL、`docs/02_RFSoC_TX/tools/regmap_def.py`、`software/app_component/src/sources/reg_map_cfg.c` 為準。設計變更時更新內文並在 §15 加一列。

---

## 1. 閱讀指引

> **本版驗證範圍**：RFSoC_TX rev0.1 目前只針對 **IF 輸出端**（DAC 輸出）做驗證，TRM 板尚未上線。Gain Control 中與 TRM 相關的功能，包括 shift register（Reg1~5）實體輸出、類比衰減器 / TX/RX 開關 / PA 控制、TX / RX 模式切換、RXAGC，都是 **TRM 板上線後才會需要的功能**。本版這些邏輯仍在 FPGA 內照常運作，但 SR 腳位刻意不接出，沒有實體效果；相關項目（§8.7，§14 第 1~4、9、18 項）在 TRM 上線時再處理，彙整於 `Follow_Up.md` T1 ~ T3。

> IF 驗證時，建議設 `gain_index_mode_sel`（mem20）= 1，以 `gain_index_manual`（mem21）固定數位 gain，避免輸出位準隨 TXAGC 跨檔跳 4~5 dB（§7）。

### 1.1 這份文件回答什麼問題

- 數位 gain（Gain_Compensation 用的 gain index）和類比衰減器（TRM 板上 DSA / 開關，經 74LVC595 設定）是怎麼分工的：§5、§7、§9。
- TX / RX 模式怎麼切換、bypass / manual 怎麼用：§4。
- RFDC 的 over_threshold / over_range / over_voltage flag 怎麼驅動 RXAGC：§6。
- 74LVC595 的位元定義與時序：§8。
- 相關暫存器、開機預設值、怎麼看狀態：§3、§11、§12。
- RFSoC_TX 和 source 專案（Calibration_Gain_Control）有哪些不同、哪些還沒確認：§2.5、§14。

### 1.2 章節導覽

- §2 功能概述與方塊圖；§3 介面與暫存器（mem20~37、sys4~13、sys16、外部輸入）。
- §4 模式控制；§5 TXAGC；§6 RXAGC；§7 gain index 與數位補償。
- §8 shift register；§9 數位 / 類比同步；§10 跨時脈。
- §11 狀態與除錯；§12 開機預設值；§13 驗證狀態；§14 已知限制 / 待確認；§15 修訂歷程。

### 1.3 名詞與單位

| 名詞 | 意義 |
|---|---|
| `clk` | FPGA_clk 256 MHz（`util_ds_buf_0/IBUF_OUT`），資料路徑時脈，3.906 ns |
| `adc_clk` | RFDC `clk_adc0~3`，240 MHz（4.167 ns）。agc_emu 除了 `agc_cdc_0` 以外全部在這個時脈 |
| `reg_clk` | `S_AXI_ACLK` = pl_clk0 100 MHz，reg map 與 RFDC AXI-Lite 時脈 |
| T | TXAGC 目標總衰減（1/16 dB 整數） |
| A | 類比衰減（TX DSA + 開關，5~130 dB，28 個檔位 state 0~27） |
| R | 數位殘差 = T − A（1/16 dB），由數位端補 |
| pf | `gain_index_power_fit`，Power Fit 結果（S5.4，+ = gain） |
| H | 換檔遲滯 `agc_tx_att_hysteresis`（U4.4 dB） |
| SR | Shift register，板上 74LVC595（SN74LVC595A @ 1.8 V） |
| S*m*.*n* | 有號定點數，*n* 位小數（S5.4 = 10 bit，1/16 dB） |
| 拍 | 一個時脈週期；若未特別說明，§4~§9 的「拍」指 adc_clk |

### 1.4 資料來源

- RTL：`RFSoC_TX/hardware/RFSoC_TX.srcs/sources_1/new/cal_plus_gain_control/agc_emu/*.v`（15 個檔）、`gain_index_mux.v`。2026-10-16 逐檔與 source 專案 `Calibration_Gain_Control/hardware/project_1.srcs/sources_1/new/` 比對，**內容完全相同**。
- BD：`sources_1/bd/cal_plus_gain_control/cal_plus_gain_control.bd`（cell、net、常數）、`sources_1/bd/design_1/design_1.bd`（8 個通道的時脈、flag、VIO、system_reg_map 接線），以 python 讀 JSON 確認。
- 暫存器：`docs/02_RFSoC_TX/tools/regmap_def.py`；開機值：`reg_map_cfg.c`；ADC threshold：`adcThresholds.c`。
- 實作結果：`RFSoC_TX/hardware/scripts/log/util_hier.rpt`、`timing_impl.rpt`（build 01）。
- 設計說明沿用 source 專案文件（設計解析 §5 / §6、`AGC_EMU_Design_Note.md`、`HANDOFF.md`），已依 target 修正；兩者不一致時以 RTL 為準。

---

## 2. 功能概述

### 2.1 做什麼

`agc_emu` 不碰 I/Q 資料本身，只產生兩種控制：

1. **類比端**：算出 TRM 板上 TX 衰減器（3 顆 5 dB-step DSA + 1 組 4-bit 開關式衰減）、RX 衰減器（2 組）、TX/RX 開關、濾波器組、PA 的控制碼，經 5 顆 74LVC595（Reg1~Reg5）送到板上。
2. **數位端**：把類比做不到的殘差 R 轉成數位 gain index（`pf − R`），在時間上與類比換檔對齊後，送給 hierarchy 外的 `gain_index_mux_0` → `calibration/Gain_Compensation_0`。

設計原則：

- **即時更新**：TXAGC 每個 adc_clk 都用最新輸入重算，沒有 FSM / trigger；Reg1~4 內容一改變就自動送出（latest wins）。
- **類比優先**：大範圍（5~130 dB）由類比負責，數位只補 0~4.9375 dB（加遲滯後 −H ~ 4.9375 + H dB）的殘差，DAC 一直在 Power Fit 設定的 goal 附近工作。
- **模式唯一來源**：`agc_reg5`（mem27）的 bit7 TXRX_SW 決定 TX / RX。
- **CDC 集中**：只有 `agc_cdc_0` 跨時脈，其他 block 都在 adc_clk。

### 2.2 在 cal_plus_gain_control 中的位置

```
 RFDC ADC flags (adcT_01/23_over_*)  ─────────────────────────────────┐
 vio_ext_inputs (rx_att_index, algo_analog_att_db) ──────────────────┐│
 system_reg_map sys4~13, sys16 (reg_agc_*) ─────────────────────────┐││
 addressable_reg_map mem22~25, mem27~37 ───────────────────────────┐│││
                                                                   ▼▼▼▼
 s_axis_iq_in_0/1 → axis_iq_source_mux_0 → axis_iq_bypass_0 → split ─┬→ in_band_flatness → calibration ──→ m_axis_iq → DAC
                                                                     │                       ▲ Gain_Compensation
                                                                     └→ power_fit_top ─pf / goal_rel─→ agc_emu ──┐
                                                                                                    │ Reg1~5 (未接到頂層)
                                                                                                    │ clear_or / clear_ov → RFDC
                                                         mem20 / mem21 (cal_cdc_0) ─┐               │
                                                                                    ▼               ▼ gain_index_tx
                                                                            gain_index_mux_0 ◀──────┘
                                                                                    └→ calibration/gain_offset_index
```

- Power Fit 量的是 Signal Source Mux（mem39 選的那一路）輸出、FIR 之前的訊號；pf 與 goal_rel 由 `power_fit_top/power_fit_db_0` 產生（細節屬 Power Fit 文件，本文只用其輸出）。
- RXAGC 看的 RFDC flag 一律是**本板 ADC**（in_1 那一路的 ADC block），與 mem39 選哪一路無關。

### 2.3 agc_emu 方塊圖

```
          reg_clk (100 MHz)                clk (256 MHz)                     adc_clk (clk_adcN, 240 MHz)
 ch mem22~25, 27~37 ─┐          rx_att_index / algo ─┐   pf / goal_rel ─┐
 sys4~13, sys16 ─────┤                               │                  │
                     ▼                               ▼                  ▼
        ┌──────────────────────────── agc_cdc_0（所有 CDC）──────────────────────────────────┐
        │ cfg 210 b: array_single + stable filter(4) + 下限 clamp → cfg_valid                 │
        │ in 12 b  : array_single + stable filter(4)                                          │
        │ pf 20 b  : xpm_cdc_handshake（send on change）  out 14 b: array_single + filter → clk │
        │ rst      : xpm_cdc_async_rst → rst_n_adc          clear_or/ov: xpm_cdc_single → reg_clk│
        └──┬───────────────┬──────────────────┬────────────────────────────────────┬──────────┘
           │ reg5_cfg /    │ manual_rx /      │ T 公式輸入 / bypass                 │ gain_index_applied
           │ cfg_valid /   │ RXAGC 週期       ▼                                     │ clamp_hi / lo
           │ hold(bypass)  │        txagc_0（txagc_calc 4 級 + decoder）── gain_index_digital ─┐
           ▼               │              │ tx_att2/3/4, sw_tx_att                  ▼          │
     agc_mode_ctrl_0       ▼              │                               gain_apply_sync_0 ──┘
     (Reg5 → mode FSM)   rxagc_0 ◀── RFDC over_* flag                        ▲ start / busy / synced
       │ agc_mode        │ sw_rx_att, rx_att2 ; clear_or/ov → agc_cdc_0      │
       │ rx_agc_enable ─▶│                                                    │
       │            rxagc_dummy_0 (0 dB) / txagc_dummy_0 (130 dB)            │
       │                 ▼                                                    │
       │          agc_att_mux_0（sel_tx = agc_mode | bypass_agc）            │
       │                 ▼                                                    │
       │  const_lna_10db_att(1) → agc_reg_pack_0 → Reg1~4 bytes              │
       ▼                 ▼                                                    │
   sr_src_mux_0（bypass：只靠 trigger；否則 Reg1~4 auto send）                │
       │ sr_reg5 / update      │ sr_reg1~4 → sr_att_concat（In0 = Reg1）     │
       ▼                       ▼                                              │
 sr_reg5_group (N_REG=1)   sr_att_group (N_REG=4) ────────────────────────────┘
 auto_send = const 0        → sr_att_pins_0 → Reg1~4 SER / SRCLK / RCLK
 busy → agc_mode_ctrl_0     
 → Reg5 SER / SRCLK / RCLK
```

### 2.4 模組清單

| BD cell | RTL | 功能 |
|---|---|---|
| `agc_cdc_0` | `agc_cdc.v` | 所有跨時脈（§10）、設定下限 clamp、`cfg_valid`、bypass trigger 正緣 |
| `agc_mode_ctrl_0` | `agc_mode_ctrl.v` | 依 `agc_reg5` 寫 Reg5、等 settle 後切換 `agc_mode`（§4） |
| `txagc_0` | `txagc.v` + `txagc_calc.v` | TXAGC：T → 類比檔位 → R → `pf − R`；檔位 → 板上碼 decoder；bypass 多工（§5） |
| `rxagc_0` | `rxagc.v` + `rxagc_fsm.v` | RXAGC FSM（RFDC flag）、manual RX、decoder（§6） |
| `txagc_dummy_0` / `rxagc_dummy_0` | `txagc_dummy.v` / `rxagc_dummy.v` | RX mode 的 TX 欄位 = 130 dB；TX mode / bypass 的 RX 欄位 = 0 dB |
| `agc_att_mux_0` | `agc_att_mux.v` | 依 `agc_mode` / `bypass_agc` 選 RX / TX 欄位來源 |
| `agc_reg_pack_0` | `agc_reg_pack.v` | 欄位 → Reg1~4 8-bit 內容（§8.2） |
| `sr_src_mux_0` | `sr_src_mux.v` | 正常 / bypass 的 SR 資料與觸發來源 |
| `sr_att_concat` | ilconcat 4 × 8 bit | In0 = Reg1 … In3 = Reg4 → `sr_att_group/data_in[31:0]` |
| `sr_att_group` | `sr_group_ctrl.v`（N_REG = 4） | Reg1~4：4 個獨立 595 FSM，同拍啟動（§8.3） |
| `sr_reg5_group` | `sr_group_ctrl.v`（N_REG = 1） | Reg5，只靠 trigger 送 |
| `sr_att_pins_0` | `sr_att_pins.v` | 向量 → Reg1~4 個別腳位（純接線） |
| （group 內） | `shift_register_FSM.v` | 單顆 595 的 SER / SRCLK / RCLK 協定（§8.4） |
| `gain_apply_sync_0` | `gain_apply_sync.v` | 數位 gain 與類比換檔同步（§9） |
| `const_reg5_auto_send` | ilconstant = 0 | `sr_reg5_group/auto_send` = 0 |
| `const_lna_10db_att` | ilconstant = 1 | LNA 10 dB 衰減固定不用（1 = 0 dB） |
| `gain_index_mux_0`（hierarchy 外） | `gain_index_mux.v` | gain index 來源：TXAGC 或 manual（§7） |

### 2.5 8 通道對應（target 特有）

8 個 `cal_plus_gain_control_ch1~8` 直接放在 design_1 頂層（沒有 hierarchy），BDC variant `cal_plus_gain_control_inst_8 ~ _15`。每個通道的 agc_emu 用自己 ADC tile 的 `clk_adcN`，AGC 之間不共用狀態。

| Ch | adc_clk | RFDC flag / clear | Reg map base | Gain BRAM | VIO probe（rx_att_index / algo） |
|---|---|---|---|---|---|
| 1 | clk_adc0（tile0） | adc0_01_* | 0xA009_0000 | 0xA009_A000 | probe_out0 / 1 |
| 2 | clk_adc0（tile0） | adc0_23_* | 0xA009_1000 | 0xA009_C000 | probe_out4 / 5 |
| 3 | clk_adc1（tile1） | adc1_01_* | 0xA009_2000 | 0xA009_E000 | probe_out8 / 9 |
| 4 | clk_adc1（tile1） | adc1_23_* | 0xA009_3000 | 0xA00A_0000 | probe_out12 / 13 |
| 5 | clk_adc2（tile2） | adc2_01_* | 0xA009_4000 | 0xA00A_2000 | probe_out16 / 17 |
| 6 | clk_adc2（tile2） | adc2_23_* | 0xA009_5000 | 0xA00A_4000 | probe_out20 / 21 |
| 7 | clk_adc3（tile3） | adc3_01_* | 0xA009_6000 | 0xA00A_6000 | probe_out24 / 25 |
| 8 | clk_adc3（tile3） | adc3_23_* | 0xA009_7000 | 0xA00A_8000 | probe_out28 / 29 |

和 source 專案的差異（與 AGC 有關的部分）：

| 項目 | source（Calibration_Gain_Control） | RFSoC_TX |
|---|---|---|
| 通道數 | ch1、ch3 兩個 | ch1~ch8 |
| ADC Outclk（adc_clk） | 240 MHz | 240 MHz（同事原設計 30 MHz，整合時改為 240 MHz） |
| SR 腳位 | CH1 / CH3 Reg1~5 有頂層 port 與 XDC 腳位 | **沒有拉到頂層、沒有腳位約束** |
| rx_gain_control（RX-only AGC，ch7） | 有 | **沒有** |
| Reg map 位址 | 0xA002_xxxx | 0xA009_xxxx（system 0xA009_8000） |
| VIO | 2 通道（probe_out0~7） | 8 通道（probe_out0~31） |
| ADC threshold（PS） | ch1、ch3 | ch1~ch8（tile = (N−1)/2、block = (N−1)%2） |

### 2.6 資源與 timing（build 01）

| 項目 | 數值 |
|---|---|
| agc_emu（每通道） | 約 740 LUT / 1,941 FF / 1 DSP（`txagc_0` ~305 LUT / 133 FF / 1 DSP；`agc_cdc_0` ~139 LUT / 1,528 FF；`rxagc_0` 128 LUT / 94 FF；`sr_att_group` ~60 LUT / 82 FF） |
| agc_emu × 8 | 約 5.9K LUT / 15.5K FF / 8 DSP |
| RFADC0~3_CLK setup WNS | +0.127 / +0.080 / +0.065 / +0.093 ns（hold ≥ +0.010 ns） |
| 四個 adc_clk 的最差路徑 | 全部是 `txagc_calc` 的 `s1_target_att_1in16 → s2_analog_att_db`（ch2 / ch3 / ch6 / ch8），餘裕比 source build 14（+0.39~+0.57 ns）小很多，見 §14 |

---

## 3. 介面與相關暫存器

### 3.1 agc_emu hierarchy 介面

| Port | 方向 | 寬度 | 時脈 | 接到 |
|---|---|---|---|---|
| `reg_clk` / `clk` / `adc_clk` / `rst_n` | in | 1 | — | S_AXI_ACLK（pl_clk0）/ FPGA_clk / `clk_adcN` / `dac_rst1/peripheral_aresetn` |
| `reg_*`（26 個） | in | 32 | reg_clk | channel mem22~25、27~37；system sys4~13、sys16（net `reg_<name>`） |
| `rx_att_index` | in | 3 | clk | VIO（暫時） |
| `algo_analog_att_db` | in | 9 | clk | VIO（暫時） |
| `gain_index_power_fit` / `goal_rel_db` | in | 10 / 10 | clk | `power_fit_top` |
| `over_voltage` / `over_range` / `over_threshold1` / `over_threshold2` | in | 1 | adc_clk | RFDC `adcT_01/23_*` |
| `clear_or` / `clear_ov` | out | 1 | reg_clk | RFDC `adcT_01/23_clear_or / clear_ov` |
| `gain_index_tx` | out | 12（S7.4） | clk | `gain_index_mux_0/gain_index_in`、`status_snapshot_0` |
| `tx_att_clamp` | out | 2 | clk | `system_ila_ch0/probe3`（{clamp_hi, clamp_lo}） |
| `digital_comp_index` | out | 10 | adc_clk | **無連線**（只有 port） |
| `Reg1~5_SER / SRCLK / RCLK` | out | 1 | adc_clk | container port `Reg1~5_*`；**在 design_1 沒有接任何 net** |

### 3.2 Channel 暫存器（addressable_reg_map，mem20~37）

位址 = 通道 base + 4 × mem。mem20 / 21 經 `cal_cdc_0`（reg_clk → clk）進 `gain_index_mux_0`；mem22~25、27~37 經 `agc_cdc_0`（reg_clk → adc_clk）。

| mem | Offset | 名稱 | 欄位 / 格式 | Reset | 用途 |
|---|---|---|---|---|---|
| mem20 | 0x50 | `gain_index_mode_sel` | [0] | 0 | 0 = TXAGC（`gain_index_tx`），1 = `gain_index_manual` |
| mem21 | 0x54 | `gain_index_manual` | [10:0] S6.4 | 0 | 手動 gain index（−64 ~ +63.9375 dB），不加 offset |
| mem22 | 0x58 | `gain_index_ch_offset` | [8:0] S4.4 | 0 | 通道修正（+ = gain），進 TXAGC 的 T |
| mem23 | 0x5C | `gain_index_rf_freq_offset` | [7:0] S3.4 | 0 | RF 頻率修正，進 T |
| mem24 | 0x60 | `gain_index_temperature_offset` | [7:0] S3.4 | 0 | 溫度修正，進 T |
| mem25 | 0x64 | `dac_output_ref_dbm` | [10:0] S6.4 dBm | 0x670（−25 dBm） | Manual mode 參考：goal = `goal_ref_dbfs` 時量到的 DAC 輸出；HW 限制 +10 ~ −40 dBm |
| mem26 | 0x68 | `goal_ref_dbfs` | [10:0] S6.4 dBFS | 0x7A0（−6 dBFS） | 不進 agc_emu；Power Fit 用來算 `goal_rel_db` = goal − goal_ref |
| mem27 | 0x6C | `agc_reg5` | [7:0] | 0x80 | Reg5 byte；[7] TXRX_SW（0 TX / 1 RX），[6:2] Filter {Vc2, Vc1, Vc0, Vc3, Vc4}，[1] PA_VC_D，[0] PA_VC_G |
| mem28 | 0x70 | `agc_bypass_agc` | [0] | 0 | 1 = bypass（§4.5） |
| mem29 | 0x74 | `agc_bypass_tx_att_state` | [4:0] | 0 | bypass 時的 TX 檔位 0~27 |
| mem30 | 0x78 | `agc_bypass_sr_update` | [1:0] 正緣 | 0 | bypass 時 [0] 送 Reg1~4、[1] 送 Reg5；寫 1 再寫 0 |
| mem31 | 0x7C | `agc_manual_tx_att_en` | [0] | 0 | 1 = T 直接用 `agc_manual_tx_att_db` |
| mem32 | 0x80 | `agc_manual_tx_att_db` | [7:0] U，1 dB | 0 | 手動 TX 目標衰減 |
| mem33 | 0x84 | `agc_target_power` | [7:0] S，1 dBm | 0 | Manual mode 目標輸出功率（例 0xD8 = −40 dBm） |
| mem34 | 0x88 | `agc_linear_mode_offset` | [11:0] S，1/16 dB | 0 | Linear mode offset |
| mem35 | 0x8C | `agc_manual_mode_offset` | [11:0] S，1/16 dB | 0 | Manual mode offset |
| mem36 | 0x90 | `agc_manual_rx_att_en` | [0] | 0 | 1 = RX 衰減用 `agc_manual_rx_att_state` |
| mem37 | 0x94 | `agc_manual_rx_att_state` | [2:0] | 0 | 0~6（0~60 dB） |

### 3.3 System 暫存器（system_reg_map，0xA009_8000，8 通道共用）

| sys | Offset | 名稱 | 欄位 | Reset | HW 下限 | 用途 |
|---|---|---|---|---|---|---|
| sys4 | 0x10 | `agc_tx_power_mode` | [0] | 0 | — | 0 = Linear，1 = Manual（§5.2） |
| sys5 | 0x14 | `digital_apply_delay` | [7:0] adc_clk | 35 | — | SR start 後第 N 拍套用數位 gain（35 = RCLK，§9） |
| sys6 | 0x18 | `agc_sr_update_period` | [7:0] adc_clk | 50 | 50 | SR 一輪時間（208 ns ~ 1.06 µs），Reg1~4 與 Reg5 共用值、各自計時 |
| sys7 | 0x1C | `agc_mode_settle_cycle` | [15:0] adc_clk | 64 | 1 | Reg5 送完後等 TXRX_SW 生效的時間 |
| sys8 | 0x20 | `agc_rx_watch_cycle` | [31:0] adc_clk | 1000 | 1 | RXAGC S_WATCHING 時間（依 PRI 設定） |
| sys9 | 0x24 | `agc_rx_wait_dsa_cycle` | [7:0] | 6 | 1 | RXAGC S_WAIT_DSA |
| sys10 | 0x28 | `agc_rx_set_dsa_cycle` | [7:0] | 6 | 1 | RXAGC S_SET_DSA |
| sys11 | 0x2C | `agc_rx_wait_cycle` | [7:0] | 50 | 1 | RXAGC S_WAIT（RF settling 後才清 flag） |
| sys12 | 0x30 | `agc_rx_set_clear_cycle` | [7:0] | 6 | 6 | clear_or / clear_ov 脈衝寬度（6 × 4.167 = 25 ns > 2 個 reg_clk） |
| sys13 | 0x34 | `agc_rx_wait_clear_cycle` | [7:0] | 16 | 1 | RXAGC S_WAIT_CLEAR |
| sys16 | 0x40 | `agc_tx_att_hysteresis` | [7:0] U4.4 dB | 16（1 dB） | — | TXAGC 換檔遲滯 H（0 = 無遲滯） |

- 下限在 `agc_cdc.v` 做（不是 reg map）：寫入值低於下限時硬體以下限使用，**讀回仍為寫入值**。
- `dac_output_ref_dbm` 在 `agc_cdc` 內 clamp 到 +160 ~ −640（+10 ~ −40 dBm）。
- 其他 system 暫存器（sys0~3、sys15：signal_mode_select、power_limit_margin、cw_mode_goal_dbfs、pulse_update_stable_cycle、cw_power_avg_log2）屬 Power Fit，不進 agc_emu。

### 3.4 外部輸入（vio_ext_inputs，暫時來源）

`vio_ext_inputs` 有 32 個 probe_out，每通道 4 個，clk = FPGA_clk。第 N 通道使用 probe_out 4(N−1) ~ 4(N−1)+3：

| probe | 訊號 | 格式 | 給誰 |
|---|---|---|---|
| +0 | `rx_att_index[2:0]` | 0~6 = 0~60 dB（每階 10 dB），> 6 視為 6 | agc_emu（TXAGC Linear 的 T） |
| +1 | `algo_analog_att_db[8:0]` | S8.0 dB，+ = 衰減 | agc_emu（T） |
| +2 | `pulse_avg_amp[15:0]` | 16384 = 0 dBFS | power_fit_top（Pulse） |
| +3 | `pulse_papr[8:0]` | U5.4 dB | power_fit_top（Pulse） |

- BD 沒有設定 probe 初值（`C_PROBE_OUTx_INIT_VAL` 未設，預設 0），所以上電時 rx_att_index = 0、algo = 0。
- 沒有 valid；`rx_att_index` / `algo` 在 `agc_cdc_0` 以 array_single + stable filter 進 adc_clk（§10）。正式來源（RSP / 同事模組）的介面、時脈、更新率尚未定義（§14）。

### 3.5 RFDC flag 與 clear

| 訊號 | RFDC 腳位（ch1 例） | 說明 |
|---|---|---|
| `over_threshold1` | `adc0_01_over_threshold1` | RXAGC 的 high threshold（→ FSM `over_thres_high`） |
| `over_threshold2` | `adc0_01_over_threshold2` | RXAGC 的 low threshold（→ FSM `over_thres_low`） |
| `over_range` | `adc0_01_over_range` | sticky，靠 `clear_or` 清 |
| `over_voltage` | `adc0_01_over_voltage` | sticky，靠 `clear_ov` 清 |
| `clear_or` / `clear_ov` | `adc0_01_clear_or / clear_ov` | 由 RXAGC 在 adc_clk 產生，經 `xpm_cdc_single` 到 reg_clk（RFDC 以 s_axi_aclk = pl_clk0 取樣） |

PS 在 `main.c` 呼叫 `adcInitThresh()` 設定 8 通道的 threshold（`adcThresholds.c`）：

| Threshold | Mode | Over | Under | AvgVal |
|---|---|---|---|---|
| threshold 0（→ over_threshold1） | Hysteresis | 11599（−3.0 dBFS） | 10950（−3.5 dBFS） | 10 |
| threshold 1（→ over_threshold2） | Hysteresis | 2913（−15.0 dBFS） | 2750（−15.5 dBFS） | 10 |

通道對應：ch N → ADC tile (N−1)/2、block (N−1)%2。

---

## 4. 模式控制（TX / RX、bypass、manual）

### 4.1 模式總表

| 模式 | 進入條件 | Reg1~4 RX 欄位 | Reg1~4 TX 欄位 | SR 送出 | 數位 gain index（`gain_index_tx`） |
|---|---|---|---|---|---|
| RX mode | `agc_reg5[7]` = 1，`agc_mode` = 0 | RXAGC（或 manual RX） | dummy 130 dB | Reg1~4 內容變就自動送；Reg5 由 mode ctrl 送 | 仍跟隨 TXAGC 的 `pf − R`（見 §7.4） |
| TX mode | `agc_reg5[7]` = 0，`agc_mode` = 1 | dummy 0 dB | TXAGC 結果 | 同上 | `pf − R`，與類比換檔同步 |
| 切換中 / 上電 | TXRX_SW 改變、reset 後 | 依舊 `agc_mode` | 依舊 `agc_mode` | 同上 | 同上；`agc_mode_valid` = 0，RXAGC 停在 S_IDLE |
| Bypass | `agc_bypass_agc` = 1 | dummy 0 dB（不看 TXRX_SW） | `agc_bypass_tx_att_state` 經 decoder | 只在 `agc_bypass_sr_update` [0] / [1] 正緣送 | `pf`（R = 0） |

`TXRX_SW_TX_LEVEL` 參數 = 0（`agc_mode_ctrl.v`）：TXRX_SW = 0 為 TX。`agc_reg5` reset 與開機值都是 0x80，所以**上電一定是 RX mode**。

### 4.2 agc_mode_ctrl FSM

`agc_reg5` 是 AGC mode 的唯一來源。本 module 保證「先把 Reg5 送到硬體、等 TXRX 開關實際生效、再切換 AGC 演算法」。

```
   resetn = 0 / hold (= bypass_agc) = 1 / cfg_valid = 0
   → 同步回 S_INIT，agc_mode_valid = 0（reg5_data / agc_mode 只有 resetn = 0 時清 0）
                         │
                         ▼
   S_INIT ──（一定寫 Reg5，mode_change = 1）──────────────┐
                                                          ▼
   S_IDLE ──（reg5_cfg ≠ reg5_data：寫 Reg5）────────► S_WAIT_SR
     ▲      TXRX_SW 改變：mode_change = 1、valid = 0       │ !reg5_busy && !reg5_update
     │      只改 Filter / PA：mode_change = 0             │
     │                                  mode_change = 0 ──┴── mode_change = 1
     └──────────────────────────────────────────┐             ▼
                                                 └──── S_SETTLE（timer 0 .. settle−1）
                                                       到時：agc_mode ← mode_target，valid ← 1
```

| 輸出 | 意義 |
|---|---|
| `agc_mode` | 0 RX / 1 TX（生效中），給 `agc_att_mux_0` |
| `agc_mode_valid` | 0 = 初始化 / 切換中 / bypass（BD 未接出） |
| `rx_agc_enable` | `valid & ~mode` → `rxagc_0/agc_enable` |
| `tx_agc_enable` | `valid & mode`（未使用；TXAGC 沒有 enable，一直在算） |
| `reg5_data` / `reg5_update` | 給 `sr_src_mux_0` → `sr_reg5_group`（update 為單拍） |

- `S_WAIT_SR` 同時檢查 `!reg5_update`：update 那一拍 `sr_group_ctrl` 的 `busy` 已由 `trig_rise` 組合拉高，之後 start、FSM busy、`in_period` 接續，busy 沒有空檔，不會提早離開。
- `S_SETTLE` 的起點是 Reg5 **一整輪**（含 `agc_sr_update_period`）結束，不是 RCLK。
- 只改 Filter / PA bit：寫一次 Reg5，不暫停 AGC。
- 在 S_WAIT_SR / S_SETTLE 期間 `agc_reg5` 再變：不理會，回 S_IDLE 後才比較差異再送。

### 4.3 TX / RX 切換時序（預設值）

以 PS 寫 `agc_reg5` = 0x00（RX → TX）為例：

| 時間（adc_clk） | 事件 |
|---|---|
| 0 | AXI 寫入完成（reg_clk） |
| ≈ +9 | `agc_cdc_0`：3 FF + 1 + stable filter 4 拍後 `reg5_cfg` 更新（約 45 ns） |
| +1 | mode ctrl 送 `reg5_update`，`agc_mode_valid` = 0 → RXAGC 回 S_IDLE（RX 衰減回 0 dB，Reg1~4 會多送一次） |
| +2 | `sr_reg5_group` start；+37 RCLK（Reg5 = 0x00 鎖存，TXRX_SW = TX） |
| +52 | Reg5 一輪（50 拍）結束，進 S_SETTLE |
| +116 | settle 64 拍到，`agc_mode` = 1、`valid` = 1；`agc_att_mux` 把 TX 欄位從 dummy 130 dB 換成 TXAGC 結果，Reg1~4 自動送出 |

總計約 125 拍 ≈ 520 ns（不含 595 輸出延遲與開關切換時間）。

切換順序的含義：

- RX → TX：開關先切到 TX，等 settle 後 TX 衰減才從 130 dB 換成工作值 → TX 從最大衰減開始，安全。
- TX → RX：開關先切到 RX，TX 欄位在 settle（+ 一輪 SR）期間仍是 TXAGC 工作值，之後才換 dummy 130 dB（與 RX → TX 不對稱，§14）。
- 切換期間 RXAGC 被 disable，`rx_att_state` 歸 0，切回 RX 時 RXAGC 從 0 dB 重新收斂（不記憶上次值）。

### 4.4 agc_att_mux

`sel_tx = agc_mode | bypass_agc`，純組合：

| sel_tx | RX 欄位（sw_rx_att、rx_att2） | TX 欄位（tx_att2/3/4、sw_tx_att） |
|---|---|---|
| 0（RX mode） | `rxagc_0` | `txagc_dummy_0`（130 dB） |
| 1（TX mode 或 bypass） | `rxagc_dummy_0`（0 dB） | `txagc_0`（bypass 時為 PS 指定檔位） |

選擇用生效中的 `agc_mode`（不是 Reg5 的 TXRX_SW），所以切換期間維持舊 mode 的欄位，直到 settle 完成。

### 4.5 Bypass（`agc_bypass_agc` = 1）

| 項目 | `agc_bypass_agc` = 0 | `agc_bypass_agc` = 1 |
|---|---|---|
| TX 欄位 | TXAGC（TX mode）/ dummy（RX mode） | `agc_bypass_tx_att_state`（0~27）經 `txagc_0` decoder，不看 TXRX_SW |
| RX 欄位 | RXAGC（RX mode）/ dummy（TX mode） | dummy 0 dB |
| `gain_index_digital` | `pf − R` | `pf`（R = 0，clamp 旗標 = 0） |
| Reg1~4 送出 | 內容變就自動送 | `agc_bypass_sr_update[0]` 正緣 |
| Reg5 內容 / 送出 | mode ctrl / 自動 | `agc_reg5` 原值 / `agc_bypass_sr_update[1]` 正緣 |
| AGC | 執行 | `agc_mode_ctrl` 停在 S_INIT（`hold`），RXAGC 停住 |

- 寫 bypass state 不會送出任何東西；寫 `agc_bypass_sr_update` = 0x3（再寫 0）會讓 Reg1~4 與 Reg5 同一拍 start、同時 RCLK。正緣偵測在 `agc_cdc` 的 cfg 上做，**必須寫 1 再寫 0**，連寫兩次 1 不會產生第二個脈衝。
- 只能指定 TX 類比檔位；Vc_Bar、N/C、LNA bit 仍由 `agc_reg_pack` 產生。
- `txagc_calc` 在 bypass 期間照常計算（`h_state` 繼續追蹤 T），離開時直接接續。
- 離開 bypass：mode ctrl 走 S_INIT，重寫 Reg5 並視為 mode change（與上電相同）；Reg1~4 若與 AGC 結果不同會自動送出。
- 進入 bypass 時數位立刻由 `pf − R` 變成 `pf`（跳 R），類比要等 PS trigger 才變（§14）。
- `reg_runtime/att_step.tcl` 是 bypass 逐檔量測的腳本（`att_on` 會同時設 TX mode、數位 gain 固定 0 dB）；在 RFSoC_TX 因 SR 腳位沒接出，目前沒有實際效果（§8.7）。

### 4.6 Manual 設定一覽

| 功能 | 暫存器 | 效果 |
|---|---|---|
| 手動 TX 目標衰減 | mem31 = 1、mem32 = dB | T = `manual_tx_att_db × 16`，其他輸入都不加；仍走類比優先分配（類比 + R），例 48 dB → 45 dB + R 3 dB |
| TXAGC Manual mode | sys4 = 1、mem33 目標功率 | 以 DAC 參考推算輸出功率（§5.2），**8 通道一起切換** |
| 手動 RX 衰減 | mem36 = 1、mem37 = state | RX 衰減 = state × 10 dB，不經 FSM、不清 flag；只在 RX mode 有效 |
| 手動數位 gain | mem20 = 1、mem21 = S6.4 | Gain_Compensation 改用手動值，AGC 的 `gain_index_tx` 不再作用（§7） |
| 完全手動類比 | bypass（§4.5） | PS 指定 TX 檔位與 Reg5，PS 觸發送出 |

---

## 5. TXAGC（txagc_0：類比優先分配）

### 5.1 概念

TXAGC 沒有 FSM，每個 adc_clk 用最新輸入重算：

```
 輸入 → Stage 1: T → Stage 2: 名目類比檔位 → Stage 3: 換檔遲滯 → 輸出: A、R、pf − R、clamp
                                                                   │
                                                                   ├ tx_att_state → decoder → 板上碼 → agc_att_mux → SR
                                                                   └ gain_index_digital → gain_apply_sync → gain_index_tx
```

A + R = T，數位 gain = pf − R。類比負責 5~130 dB，R 只剩 0 ~ 4.9375 dB（有遲滯時 −H ~ 4.9375 + H dB）。

### 5.2 Stage 1：目標總衰減 T

全部以 1/16 dB 整數（18-bit signed）計算：

| 條件（優先順序） | T |
|---|---|
| `agc_manual_tx_att_en` = 1 | `manual_tx_att_db × 16` |
| Linear（sys4 = 0） | `1545 + linear_mode_offset − rx_idx × 160 + pf − offs + algo × 16` |
| Manual（sys4 = 1） | `dac_output_ref_dbm + goal_rel_db + 800 − target_power × 16 + manual_mode_offset − offs + algo × 16` |

- `offs` = `gain_index_ch_offset`（S4.4）+ `gain_index_rf_freq_offset`（S3.4）+ `gain_index_temperature_offset`（S3.4），+ = gain，所以在 T 裡是減。
- `rx_idx` = `rx_att_index`（> 6 視為 6）；`algo` = `algo_analog_att_db`（S8.0，+ = 衰減）。
- 常數：`LINEAR_BASE` 1545 = 96.5625 dB（TRM RX gain + TX gain）；`G_TX` 800 = 50 dB（TRM TX gain）。兩者都是標稱值，實際插入損失要靠 offset 或之後的校正表（§14）。

公式意義（A + R = T、數位 = pf − R）：

- **Linear**：TX 側淨增益 = (pf − R) − A = pf − T = −96.5625 − lin + rx_att + offs − algo（dB），pf 被完全抵銷。整條鏈（RX gain + TX gain − rx_att + TX 側）= −lin + offs − algo，也就是回波以固定的總增益（標稱 0 dB）通過模擬器，與 RX 衰減、Power Fit 的數位放大無關。
- **Manual**：輸出功率 = DAC 輸出（dac_ref + goal_rel）+ G_TX − R − A = target − man_off + offs − algo，對準 `agc_target_power`。pf 不進 T，因為 Power Fit 已把數位位準固定在 goal；goal 改變（PAPR / margin / CW goal）時由 `goal_rel_db` 追蹤。

### 5.3 Stage 2：名目類比檔位

`target_att_int = T >>> 4`（floor 到 1 dB），取「不超過 T 的最大衰減」：

| T（dB） | state | A（dB） |
|---|---|---|
| ≥ 130 | 0 | 130（clamp_hi 區） |
| 45 ~ 129 | `(134 − T) / 5`，以 `(x × 205) >> 10` 實作 | `130 − 5 × state` |
| 5 ~ 44 | `17 + ((48 − T) >> 2)` | `45 − 4 × (state − 17)` |
| < 5 | 27 | 5（clamp_lo 區） |

28 個檔位：state 0~17 為 130 → 45 dB（每檔 5 dB），state 17~27 為 45 → 5 dB（每檔 4 dB）。除以 5 的近似在 x = 5~89 範圍內 floor 結果完全正確（誤差 ≤ 0.018 < 1 − 0.8）。

### 5.4 Stage 3：換檔遲滯（sys16）

`h_state` = 目前送給硬體的檔位。T 落在 [A(h) × 16 − H, A(h−1) × 16 + H) 就維持（state 0 沒有上限），否則跳到名目檔位。

```verilog
// txagc_calc.v
wire keep = (s2_target_att_1in16 >= lo_b) && ((h_state == 5'd0) || (s2_target_att_1in16 < hi_b));
// lo_b = A(h)*16 - H,  hi_b = A(h-1)*16 + H
```

- 跳到名目檔位後，新的 T 一定在新檔位的遲滯窗內，不會立刻再跳。
- R = T − A，飽和在 [−H, 79 + H]。在維持窗內 R 不會碰到飽和（5 dB 區最大 79 + H、4 dB 區最大 63 + H），飽和只發生在 clamp 區，所以**遲滯不改變總增益**，只是把邊界附近的小變化從「類比換檔 + 數位補 5 dB」變成「數位多補 ±H」。R 為負代表數位比 pf 再多放大 |R|（最多 H）。
- H = 0 時行為與無遲滯版本相同。

### 5.5 輸出、clamp 旗標與 latency

| 輸出 | 內容 |
|---|---|
| `tx_att_state` | 0~27（遲滯後），bypass 時 = `agc_bypass_tx_att_state` |
| `digital_comp_index` | R（S，1/16 dB，−H ~ 79 + H）；bypass 時 0；BD 未接出 |
| `gain_index_digital` | `pf − R`（S7.4，12 bit）；bypass 時 = pf（符號擴展） |
| `analog_clamp_hi` | T ≥ 2160 + H（135 dB + H：類比已 130 dB 且 R 飽和） |
| `analog_clamp_lo` | T < 80 − H（5 dB − H） |

旗標為 1 表示數位已經補不到，實際輸出會偏離目標；旗標經 `agc_cdc_0` 回到 clk 成為 `tx_att_clamp`，接 ILA probe3。

Pipeline：

| Stage | 暫存器 | 內容 |
|---|---|---|
| in → s1 | `s1_target_att_1in16`、`s1_pf` | T 加總 |
| s1 → s2 | `s2_target`、`s2_pf`、`s2_analog_att_db`、`s2_tx_att_state` | 名目檔位（shift、比較、×205、×5） |
| s2 → s3 | `s3_target`、`s3_pf`、`s3_analog_att_db`、`h_state` | 遲滯判斷 |
| s3 → out | `tx_att_state`、`digital_comp_index`、`gain_index_digital`、clamp | R 飽和、pf − R |

- Latency = 4 adc_clk。所有輸出在同一個 edge 更新，`tx_att_state`（經組合 decoder 成為 SR `data_in`）與 `gain_index_digital` 時間上對齊，這是 §9 同步的前提。
- pf 跟著 T 一起走 pipeline（s1_pf → s3_pf），R 與 pf 永遠來自同一組輸入。
- Reset 值：`tx_att_state` = 0（130 dB）、`h_state` = 0、`gain_index_digital` = 0。
- Timing：stage 2（s1 → s2）是四個 adc_clk 的最差路徑（§2.6）。

### 5.6 Decoder（`txagc.v`，檔位 → 板上碼）

| state | A（dB） | tx_att2 | tx_att3 | tx_att4 | sw_tx_att |
|---|---|---|---|---|---|
| 0~6 | 130 → 100 | 110 → 000（每檔 −1） | 110 | 110 | 0000 |
| 7~11 | 95 → 75 | 000 | 101 → 001 | 110 | 0000 |
| 12~17 | 70 → 45 | 000 | 001 | 101 → 000 | 0000 |
| 18~27 | 41 → 5 | 000 | 001 | 000 | 1000、0100、0010、0001、1001、0101、0011、1011、0111、1111 |
| 28~31（default） | 130 | 110 | 110 | 110 | 0000 |

由表反推的規則：DSA 3-bit 碼 n = n × 5 dB（110 = 30 dB）；`sw_tx_att` bit3/2/1/0 = 4/8/12/16 dB 段，全 0 = 40 dB、全 1 = 0 dB；`tx_att3` 從 state 11 起固定 001（5 dB），所以類比最小 5 dB。RTL 註解寫「此處以示意解碼排列，可依實體板載 DSA 腳位對應修改」，**碼值尚未對實體 DSA datasheet / 板上量測確認**（§14）。

`txagc_dummy_0`：tx_att2/3/4 = 110（各 30 dB）、sw_tx_att = 0000（40 dB）= 130 dB，等於 state 0。

### 5.7 數值範例（單位 1/16 dB，括號為 dB；來自 source TB）

| 案例 | T | 檔位 / A | R | 數位 gain index |
|---|---|---|---|---|
| Linear：rx_idx 2、rf_freq −3.5 dB（−56）、lin +1 dB（16）、pf 0 | 1545 + 16 − 320 + 56 = 1297（81.06） | 10 / 80 | 17（1.06） | −17 |
| Manual：dac_ref −25 dBm（−400）、target −40 dBm | −400 + 800 + 640 = 1040（65.0） | 13 / 65 | 0 | pf |
| Manual + goal_rel −7 dB（−112） | 928（58.0） | 15 / 55 | 48（3.0） | pf − 48 |
| Manual target −120 dBm | 2320（145） | 0 / 130（clamp） | 79 + H 飽和 | pf − R，`clamp_hi` = 1 |
| Manual target +25 dBm | 0 | 27 / 5（clamp） | −H 飽和 | pf + H，`clamp_lo` = 1 |
| manual TX 48 dB | 768 | 17 / 45 | 48（3.0） | pf − 48 |
| Linear，pf 13.4375（215） | 1760（110.0） | 4 / 110 | 0 | 215 |

（表中 clamp 列在 H = 0 時 R 分別為 79 / 0，與 source TB T12 相同。）

最後一列是 source build 12 的問題情境：T 剛好在 110 dB 邊界。pf 下抖 1/16 dB → T = 1759 → state 5（105 dB）、R = 79 → 數位 8.44 dB；pf 回 215 → state 4、數位 13.44 dB。沒有遲滯時數位在 13.44 / 8.44 dB 間跳，沒接 TRM 時就直接看到 5 dB 跳動。H = 1 dB 後 state 4 的維持窗為 [109, 116) dB、state 5 為 [104, 111) dB，T 在 109~111 dB 抖動都不換檔。

---

## 6. RXAGC（rxagc_0）

### 6.1 功能

RX mode 下依 RFDC flag 選 RX 衰減 state 0~6（0~60 dB，每階 10 dB），每次調整後送出 `clear_or / clear_ov` 清 RFDC 的 sticky flag。`rxagc.v` = manual 選擇 + decoder；`rxagc_fsm.v` = 演算法。`agc_enable`（= `rx_agc_enable`）為 0 時 FSM 等同 reset：停在 S_IDLE、state = 0。

FSM 輸入對應：`over_threshold1` → `over_thres_high`、`over_threshold2` → `over_thres_low`。

### 6.2 FSM

```
 S_IDLE ──► S_WAIT_DSA ─(wait_dsa)─► S_SET_DSA ─(set_dsa, rx_att_update)─► S_WAIT ─(wait)─► S_SET_CLEAR
               ▲                                                                    (clear_or/ov = 1, rx_att_ready,
               │                                                                     set_clear 拍)
    S_TOO_HIGH ┤（state + 1，上限 6）                                                       │
    S_TOO_LOW  ┘（state = 0）                                                               ▼
        ▲    ▲                                                                       S_WAIT_CLEAR ─(wait_clear)─┐
 ov|or|high  │ watch_cnt ≥ watch_cycle                                                                         │
        │    │                                                                                                  ▼
   S_EVALUATE ◄──（low = 1）── S_WATCHING ◄──（high = 0 且 low = 0）────────────────────────────────── S_EVALUATE
   （只有 low = 1：停在 EVALUATE）
```

| 狀態 | 轉移條件 | 動作 |
|---|---|---|
| S_IDLE | 無條件 → S_WAIT_DSA | state = 0、計數器清 0 |
| S_EVALUATE | ov / or / high → TOO_HIGH；high = low = 0 → WATCHING；只有 low → 停留 | 計數器清 0 |
| S_WATCHING | low → EVALUATE；`watch_cnt ≥ watch_cycle` → TOO_LOW | watch_cnt++ |
| S_TOO_HIGH | → WAIT_DSA | state + 1（飽和 6） |
| S_TOO_LOW | → WAIT_DSA | state = 0（直接回 0 dB，不逐階） |
| S_WAIT_DSA / S_SET_DSA / S_WAIT / S_SET_CLEAR / S_WAIT_CLEAR | 各自 `cnt ≥ cycle − 1` | 計數；SET_DSA 送 `rx_att_update`；SET_CLEAR 送 clear 與 `rx_att_ready` |

語意：訊號在 [low, high] 之間 = 正常，停在 EVALUATE；超過 high 或 OR / OV = 加 10 dB；低於 low 持續 `watch_cycle`（預設 1000 拍 = 4.17 µs，依 PRI 設定）= 沒有訊號，回 0 dB。

- RFDC threshold 必須是 Hysteresis mode（PS 已設定，§3.5）；若設成 sticky，EVALUATE 可能永遠不會離開。
- 計數比較都用 `cycle − 1`，所以 `agc_cdc` 的下限 1 是必要的（cycle = 0 在 8 bit 下會變 255）。

### 6.3 時序

一次加衰減的循環 = 1（TOO_HIGH）+ 6 + 6 + 50 + 6 + 16 = 85 拍 ≈ 354 ns（預設），0 → 60 dB 最多 6 次 ≈ 2.1 µs + 判斷時間。

類比衰減其實在 S_TOO_HIGH 的下一拍就開始送：`rx_att_state` 一改，經 decoder → att_mux → reg_pack，`sr_att_group` 立刻偵測到內容變化（即時更新模型）。WAIT_DSA / SET_DSA 只是等待，`rx_att_update` 脈衝沒有接到任何東西。因此：

| 事件 | 相對 `rx_att_state` 改變 |
|---|---|
| SR start | +1 ~ +2 拍 |
| RCLK（595 鎖存） | ≈ +37 拍 |
| clear 開始（S_WAIT 結束） | +62 拍，也就是 RCLK 後約 25 拍（~100 ns） |

若衰減器切換 + RF settling 超過約 100 ns，要調大 `agc_rx_wait_cycle`（sys11）。clear 經 CDC 到 reg_clk 約 30~40 ns，再加 RFDC 內部清除時間，若超過 WAIT_CLEAR（16 拍 = 67 ns），EVALUATE 會看到舊的 OR flag 再加 10 dB（§14）。

### 6.4 Decoder 與 manual

| state | sw_rx_att | rx_att2 | dB |
|---|---|---|---|
| 0 | 111 | 00 | 0 |
| 1 | 111 | 01 | 10 |
| 2 | 111 | 10 | 20 |
| 3 | 011 | 10 | 30 |
| 4 | 101 | 10 | 40 |
| 5 | 001 | 10 | 50 |
| 6 | 001 | 11 | 60 |
| 7（default） | 111 | 00 | 0 |

- `rx_att_state = manual_rx_att_enable ? manual_rx_att_state : fsm_state`；manual 不經 FSM、不清 flag。manual state 7 解成 0 dB（不是 60 dB）。
- `rxagc_dummy_0`：sw_rx_att = 111、rx_att2 = 00（0 dB）。

### 6.5 RFSoC_TX 上的意義

- 板子開機在 RX mode（`agc_reg5` = 0x80），RXAGC 會依本板 ADC 的 flag 動作、送 clear 給 RFDC，即使 SR 腳位沒接出、RX 衰減不會真的改變。
- 因為衰減沒有實體效果，持續過載時 FSM 會一路加到 state 6 並停在那裡（或在 TOO_LOW 與 TOO_HIGH 間循環），clear_or / clear_ov 會週期性清掉 RFDC 的 sticky flag。若有其他邏輯或 PS 也在看 RFDC 的 over_range / over_voltage，需注意會被 RXAGC 清掉（待確認是否有影響，§14）。

---

## 7. Gain index 與數位補償

### 7.1 路徑

```
 txagc_0/gain_index_digital (pf − R, S7.4, adc_clk)
   → gain_apply_sync_0（與類比換檔對齊，§9）
   → agc_cdc_0（adc_clk → clk，array_single + stable filter，約 30 ns）
   → agc_emu/gain_index_tx（S7.4, clk）
   → gain_index_mux_0/gain_index_in ──┐
     mem21 gain_index_manual（S6.4）──┤ mem20 gain_index_mode_sel（經 cal_cdc_0）
                                      ▼
                         gain_index_out（12 bit）→ calibration/gain_offset_index → Gain_Compensation_0
                                                 → system_ila_ch0/probe0
```

### 7.2 gain_index_mux

| `gain_index_mode_sel` | 輸出 |
|---|---|
| 0（預設） | `gain_index_in` = `gain_index_tx`（TXAGC 數位 pf − R，已與類比同步） |
| 1 | `gain_index_manual`（11-bit S6.4，符號擴展成 12 bit；不加任何 offset） |

- **純組合邏輯（0 拍）**，`clk` port 沒有使用。
- Gain_Compensation 以 gain index 的**低 11 bit** 查 gain BRAM（2048 筆，11-bit 二補數排列），gain 為 unsigned fixed_32_21，輸出 round-half-even、飽和 ±16384，latency 4 clk。gain 表在各通道 gain BRAM（§2.5，由 PS 載入）；細節屬 Calibration 文件。
- 有效範圍：BRAM 只用 11 bit，所以實際可用 −64 ~ +63.9375 dB。`gain_index_tx` 的值域為 pf（±31.94 dB）− R（−H ~ 4.94 + H dB），在 H 為預設 1 dB 時遠在範圍內。

### 7.3 格式

| 訊號 | 格式 | 範圍 |
|---|---|---|
| `gain_index_power_fit`（pf） | S5.4（10 bit） | ±31.9375 dB |
| R（`digital_comp_index`） | S（10 bit），1/16 dB | −H ~ 79 + H |
| `gain_index_digital` / `gain_index_tx` | S7.4（12 bit） | pf − R |
| `gain_index_manual` | S6.4（11 bit） | −64 ~ +63.9375 dB |

### 7.4 各模式下的數位 gain

| 情況 | `gain_index_tx` |
|---|---|
| TX mode | `pf − R`，類比換檔時在 start + N 拍更新，其餘即時跟隨（§9） |
| RX mode | **仍跟隨 TXAGC 的 `pf − R`**（TXAGC 一直在算，`gain_apply_sync` 在 synced 時跟隨）。R 對應的是沒有送出的 TX 檔位。source 設計筆記寫「RX mode 不使用數位 gain index」，與 RTL 不一致，以 RTL 為準 |
| Bypass | `pf`（R = 0） |
| `gain_index_mode_sel` = 1 | AGC 結果不作用，Gain_Compensation 用 `gain_index_manual` |

### 7.5 量測建議

- 量通道響應（FIR / 通帶 / S21）時固定數位 gain：`gain_index_mode_sel` = 1、`gain_index_manual` = 0（數位 0 dB），不受 AGC 閉迴路影響。恢復：`gain_index_mode_sel` = 0。
- **RFSoC_TX 特別注意**：SR 腳位沒接出，類比換檔沒有實體效果，但數位仍會隨 R 補償。T 每跨過一個檔位邊界（超過 ±H），輸出位準就會跳約 4~5 dB；在檔位內則隨 R 在 −H ~ 4.94 + H dB 之間變動。

---

## 8. Shift register（74LVC595，Reg1~5）

### 8.1 架構

| Group | Cell | 內容 | 送出方式 |
|---|---|---|---|
| Reg1~4 | `sr_att_group`（`sr_group_ctrl`，N_REG = 4） | 衰減器欄位（`agc_reg_pack_0`） | 正常：內容一變就自動送（auto_send = `~bypass_agc`）；bypass：`agc_bypass_sr_update[0]` |
| Reg5 | `sr_reg5_group`（N_REG = 1） | TXRX_SW / Filter / PA（`agc_reg5`） | 只靠 trigger（`const_reg5_auto_send` = 0）：正常由 `agc_mode_ctrl`、bypass 由 `agc_bypass_sr_update[1]` |

- 每顆 595 有自己的 SER / SRCLK / RCLK（4 + 1 個獨立 `shift_register_FSM`），同一個 group 共用 `start`，所以同拍移位、同拍 RCLK，4 組衰減器同時改變。
- 兩個 group 分開：Reg5 帶 TXRX_SW / PA，必須由 mode ctrl 控制順序與 settle；Reg1~4 頻繁變動用 auto-send，兩者互不阻塞。代價是非 bypass 時 Reg5 與 Reg1~4 不能原子更新（順序由 mode ctrl 保證）。

### 8.2 Reg1~5 位元定義（bit7 = QA … bit0 = QH）

| Reg | bit7..5 | bit4..2 | bit1..0 |
|---|---|---|---|
| Reg1 | TX_ATT2_Vc A0..A2（`tx_att2`） | TX_ATT2_Vc_Bar（= Vc） | Rx_ATT2_Vc A0, A1（`rx_att2`） |
| Reg2 | TX_ATT3_Vc（`tx_att3`） | TX_ATT3_Vc_Bar（= Vc） | Rx_ATT2_Vc_Bar（= Vc） |
| Reg3 | TX_ATT4_Vc（`tx_att4`） | TX_ATT4_Vc_Bar（= Vc） | N/C（00） |

| Reg | bit7..4 | bit3..1 | bit0 |
|---|---|---|---|
| Reg4 | SW_TX_ATT Vc1..Vc4（`sw_tx_att`） | SW_RX_ATT Vc1..Vc3（`sw_rx_att`） | LNA_10dB_ATT_Vc（固定 1 = 0 dB） |

| Reg | bit7 | bit6..2 | bit1 | bit0 |
|---|---|---|---|---|
| Reg5 | TXRX_SW（0 TX / 1 RX） | Filter Vc2, Vc1, Vc0, Vc3, Vc4 | PA_VC_D | PA_VC_G |

```verilog
// agc_reg_pack.v
assign reg1 = { tx_att2, tx_att2, rx_att2 };
assign reg2 = { tx_att3, tx_att3, rx_att2 };
assign reg3 = { tx_att4, tx_att4, 2'b00   };
assign reg4 = { sw_tx_att, sw_rx_att, lna_10db_att_vc };
```

- Vc 與 Vc_Bar 給相同值（RTL 註解：反向在元件內處理，RFIC spec. 4/4）。若實際需要外部反相，要改成 `~tx_att2` 等（§14）。
- Reg5 不經過 `agc_reg_pack`，是 PS 寫的原始 byte；Filter / PA 的邏輯與 PA bias 上電順序尚未設計（§14）。
- 開機 Reg5 = 0x80：RX、Filter 全 0、PA bit 全 0。

### 8.3 sr_group_ctrl：傳送與排程

| Port | 意義 |
|---|---|
| `auto_send` | 1：`data_in` ≠ 上次送出的 `data_q` 就送 |
| `trig_update` | 正緣觸發；忙碌時記成 `pending`，idle 後補送一次（多次合併） |
| `update_period` | 一輪時間 P（start 起算），每輪 start 時鎖存，修改從下一輪生效 |
| `busy` | `trig_rise` OR `pending` OR `start` OR `~fsm_idle`（含 period 期間） |
| `synced` | `~busy & ~changed`（bypass 時退化為 `~busy`） |
| `start` | 一輪開始的單拍（前一拍鎖存 `data_q`），給 `gain_apply_sync` |

```verilog
// sr_group_ctrl.v
wire fsm_idle = ~|fsm_busy & ~in_period;
wire changed  = auto_send & (data_in != data_q);
if ((pending || trig_rise || changed) && fsm_idle && !start) begin
    data_q <= data_in; start <= 1'b1; pending <= 1'b0;
end else if (trig_rise) pending <= 1'b1;
```

- **Latest wins**：比較對象是「上次送出的內容」。傳送中 `data_in` 變多次不排隊；一輪結束後若仍不同，以最新值再送；若中途變回原值則不再送。
- start-to-start = P 拍（P ≥ 50）。P = 傳輸 ~37 拍 + 595 RCLK→Q（≤ 18.2 ns @ 1.8 V）+ 衰減器切換。
- `sr_group_ctrl` 與 `shift_register_FSM` 用 async reset（`posedge clk or negedge rst_n`），其他 module 用同步 reset；同一個 `rst_n_adc` 下功能正確。

範例（c = 送 A 的 start 拍，P = 50；傳送期間 `data_in` 依序變成 B、C、D）：

| 拍 | 事件 |
|---|---|
| c−1 | idle 且 changed：鎖存 `data_q` = A、`period_q` = 50 |
| c | `start` = 1，FSM 載入 A |
| c+1 ~ c+36 | 傳送 A；`data_in` 變 B、C、D，但 `fsm_idle` = 0，不動作 |
| c+35 結束的 edge | RCLK ↑，硬體 = A |
| c+37 ~ c+48 | FSM idle，但 `in_period` = 1（硬體 settling），仍不動作 |
| c+49 | `fsm_idle` = 1、changed（D ≠ A）→ 鎖存 D |
| c+50 | `start` = 1 |
| c+85 結束的 edge | RCLK ↑，硬體 = D |

B、C 不會出現在 595 上；衰減器每 P 拍最多改變一次，最後一定收斂到最新值。

### 8.4 shift_register_FSM：協定與時序

5 個狀態，每個狀態停 `WAIT_CYCLES`（= 2）拍，所有輸出都是暫存器（無組合 glitch）：

```
 IDLE ─start─► SHIFT_LOW（ser = bit）─► SHIFT_HIGH（srclk = 1；結束時右移、bit_cnt++）─┬─ bit_cnt < 7 ─► SHIFT_LOW
                                                                                      └─ bit_cnt = 7 ─► LATCH_WAIT ─► LATCH_HIGH（rclk = 1）─► IDLE
```

- **LSB first**：`ser <= shift_reg[0]`，每 bit 後右移。data[0] 先進，8 個 SRCLK 後落在 QH；data[7] 最後進，留在 QA，所以「bit7 = QA」的打包約定成立。
- 一輪（start 所在拍 = c）：SHIFT c+1 ~ c+32（每 bit 4 拍）、LATCH_WAIT c+33 ~ c+34、LATCH_HIGH c+35 ~ c+36；RCLK 在 c+35 結束的 edge 上升，FSM busy 在 c+36 結束時降。一輪傳輸 ≈ 37 拍 ≈ 154 ns。

```
 adc_clk   │c+1│c+2│c+3│c+4│c+5│c+6│ ... │c+32│c+33│c+34│c+35│c+36│c+37│
 SER       ─────<  bit0         ><  bit1 ...      bit7      >──────────────
 SRCLK     ________________┌───────┐______ ... ┌────────┐_______________________
                           c+4~c+5                c+32~c+33
 RCLK      ____________________________________________________________┌────────┐
                                                                        c+36~c+37
```

74LVC595 時序檢查（SN74LVC595A @ VCC 1.8 V，adc_clk 240 MHz，WAIT_CYCLES = 2）：

| 參數 | 設計值 | 規格 |
|---|---|---|
| SER → SRCLK↑ setup | 8.33 ns | ≥ 5.5 ns |
| SRCLK 高電位寬度 | 8.33 ns | ≥ 7 ns |
| SRCLK↑ → SER hold | 8.33 ns | ≥ 2 ns |
| 最後 SRCLK↑ → RCLK↑ | 16.7 ns | ≥ 8.5 ns |
| RCLK 高電位寬度 | 8.33 ns | ≥ 7 ns |
| RCLK → Q（595 輸出） | — | worst 18.2 ns（由 `agc_sr_update_period` 吸收） |

### 8.5 開機時的 SR 行為

- `sr_att_group` 的 `data_q` reset 為 0，與 `data_in`（RX 0 dB + TX dummy 130 dB）不同，所以 **Reg1~4 會在 `cfg_valid` 之前就先送一次這個安全值**。
- Reg5 要等 `cfg_valid` 後由 mode ctrl 送出（0x80）。
- 595 上電輸出在第一次 RCLK 前為未知，TXRX_SW / PA bit 的初始狀態由板上 OE / MR 決定，不在 RTL 範圍內（§14）。

### 8.6 sr_att_pins

純接線：`{Reg4, Reg3, Reg2, Reg1}_SER = ser[3:0]`（SRCLK、RCLK 同），對應 concat 的 In0 = Reg1。

### 8.7 RFSoC_TX 的腳位現況（重要）

| 項目 | 現況 |
|---|---|
| container port | 8 個 `cal_plus_gain_control_chN` 都有 `Reg1~5_SER / SRCLK / RCLK` 15 個輸出 port |
| design_1 | **沒有任何 net 接到這些 port，也沒有拉到 design_1 / `design_1_wrapper` 頂層** |
| XDC | `constrs_1` 內（`cal_plus_gain_control.xdc`、`overvoltage_sign.xdc`、`design.xdc`）**沒有 Reg1~5 的腳位約束**（source 專案有 CH1 / CH3 的腳位） |
| 影響 | 板上 TRM 的衰減器 / 開關 / PA 不受 FPGA 控制；TXAGC、RXAGC、mode ctrl 仍照常計算，數位 gain（pf − R）仍作用在 DAC 資料 |
| 合成結果（推測） | SER / SRCLK / RCLK 沒有負載，相關暫存器可能被 opt_design 移除；`util_hier.rpt` 的 `sr_att_group` 只有 82 FF，少於完整邏輯應有的數量，與此推測一致。busy / start / synced 有負載（`gain_apply_sync`、`agc_mode_ctrl`），排程行為保留 |

本版只驗證 IF 輸出端，TRM 板尚未上線，SR 腳位不接出是預期的（§1）。TRM 上線後要接上實體 SR，需要：(1) 確認 z2 板 8 通道 TRM 控制線的 FPGA 腳位與 IO 標準（1.8 V）；(2) 在 design_1 建 port 並連到 `design_1_wrapper`；(3) 加 XDC 腳位；(4) 重新 build（§14 第 1 項）。

---

## 9. 數位 / 類比同步（gain_apply_sync）

### 9.1 為什麼需要

類比要經過 SR 一輪（start 後約 35 拍才 RCLK）才生效，數位幾乎立刻生效。沒有同步的話，換檔瞬間會有一段約 5 dB 的功率跳動。`gain_apply_sync_0` 用 `sr_att_group` 的 `start` 當時間基準，一個暫存器 N（sys5 `digital_apply_delay`）就能在 bench 上前後微調。

### 9.2 行為（優先順序）

```verilog
// gain_apply_sync.v
gain_req_d <= gain_req;                          // 與 sr_group_ctrl 鎖存 data_q 同一拍的值
if (sr_start) begin
    if (apply_delay == 0) gain_applied <= gain_req_d;               // N = 0：start 當拍套用
    else begin gain_snap <= gain_req_d; cnt <= apply_delay - 1; pend <= 1; end
end else if (pend) begin
    if (cnt == 0) begin gain_applied <= gain_snap; pend <= 0; end
    else cnt <= cnt - 1;
end else if (!sr_busy && sr_synced)
    gain_applied <= gain_req;                    // 類比沒在換：即時跟隨
```

1. **配對**：`sr_group_ctrl` 在 c−1 拍鎖存 `data_q`、c 拍 `start` = 1；本 module 在 c 拍取 `gain_req_d`（= c−1 拍的 gain_req），恰好與被鎖存的類比檔位成對。
2. **延遲 N**：`gain_applied` 在 c + N 結束的 edge 更新。RCLK 在 c + 35 結束的 edge 上升，所以 N = 35 與 RCLK 同一個 edge（source TB T13 量測 ±0.5 ns）。
3. **跟隨**：不在 pend、SR 不忙、且硬體內容 = 目前要求（synced）時，每拍跟隨 `gain_req`。只有 R 或 pf 變、類比不換檔時，數位在 calc 輸出後下一拍就更新，不經過 SR。
4. pend 結束到一輪結束（c+36 ~ c+P−1）之間不更新（busy），之後才跟隨最新值；最多延遲 P − N − 1 ≈ 14 拍（58 ns）。

### 9.3 時序圖（N = 35，P = 50，類比換檔後 pf 再小變一次）

```
 拍            c-1     c      c+1 ... c+34   c+35        c+36 ... c+49   c+50
 tx_state      S_new   S_new
 gain_req      G1      G1     ...  G1 → G2（pf 小變，類比不換）
 data_q        ←鎖存 S_new
 start         0       1      0
 gain_req_d            G1
 pend / cnt            1/34   1/33 ... 1/0
 gain_applied  G0      G0     G0  ...  G0 → G1（c+35 結束的 edge，與 RCLK 同一個 edge）
 RCLK                                    ↑
 sr_busy               1 ...................................... 1     0
 gain_applied                               G1 ........................ → G2（busy 結束且 synced 後）
```

### 9.4 N 的調法

對齊條件：數位套用時間 + 數位路徑延遲 = RCLK + 類比路徑延遲。

| 路徑 | 組成 |
|---|---|
| 數位 | `gain_apply_sync` → `agc_cdc_0` 回 clk（array_single 3 FF + stable filter 4，約 30 ns）→ `gain_index_mux`（0 拍）→ `Gain_Compensation`（4 clk）→ RFDC 內插 / DAC |
| 類比 | RCLK → 595 輸出（≤ 18.2 ns）→ 走線 → 衰減器切換 |

- 數位較慢 → N 調小（可早於 RCLK）；衰減器較慢 → N 調大。N = 35 時，數位作用到資料（Gain_Compensation 輸出）約比 RCLK 晚 50 ns（不含 DAC）。
- 規格要求 N < `agc_sr_update_period`，硬體不檢查；若 N ≥ P，下一次 start 會覆蓋 `gain_snap`，前一次的數位值不會套用（§14）。
- 同步只針對 Reg1~4（TX / RX 衰減），Reg5（PA / 濾波器）不在其內。
- **RFSoC_TX 目前 SR 沒接出，N 無法在板上調；N 的實測調整要等腳位接上**。

### 9.5 端到端時間線（source TB `tb_pulse_timeline`，Pulse 輸入改變）

| 段落 | 時間 |
|---|---|
| Pulse 輸入改變 t0 → Power Fit 輸出 pf / goal_rel | M + 7 clk（M = 4：11 clk ≈ 43 ns） |
| pf handshake 到 adc_clk | 約 23 ns |
| txagc_calc | 4 adc_clk |
| SR start → RCLK | 35 adc_clk |
| t0 → RCLK（類比鎖存） | 238 ~ 242 ns |
| t0 → 數位作用到資料（Gain_Compensation 輸出） | 約 289 ~ 293 ns |

不含 595 輸出延遲、衰減器切換時間與 Gain_Compensation 之後的 RFDC DAC 路徑。

---

## 10. 跨時脈（agc_cdc_0）

### 10.1 路徑總表

| # | 方向 | 內容 | 機制 |
|---|---|---|---|
| 1 | clk（async）→ adc_clk | `rst_n` → `rst_n_adc` | `xpm_cdc_async_rst`，DEST_SYNC_FF 4 |
| 2 | reg_clk → adc_clk | 210-bit 設定 bundle（mem22~25、27~37、sys4~13、sys16） | `xpm_cdc_array_single`（3 FF，SRC_INPUT_REG 1）+ stable filter 4 拍 + 下限 / 範圍 clamp + `cfg_valid` + bypass trigger 正緣偵測 |
| 3 | clk → adc_clk | `rx_att_index[2:0]`、`algo_analog_att_db[8:0]` | array_single + stable filter 4 拍 |
| 3a | clk → adc_clk | `gain_index_power_fit[9:0]`、`goal_rel_db[9:0]` | `xpm_cdc_handshake`（WIDTH 20，SRC / DEST_SYNC_FF 3，send on change） |
| 3b | adc_clk → clk | `gain_index_applied[11:0]`、`{clamp_hi, clamp_lo}` | array_single + stable filter 4 拍（clk） |
| 4 | adc_clk → reg_clk | `clear_or`、`clear_ov` | `xpm_cdc_single` × 2 |

只有 `agc_cdc_0` 跨 domain，其他 block 都是單一 adc_clk，report_cdc 審查集中在一個 module。AGC 核心放在 adc_clk 的理由：RFDC flag 由 RFDC 以 `clk_adcN` 產生，RXAGC 可直接在同一個 domain 一拍內反應。8 個通道各用自己 tile 的 `clk_adcN`（ch1/2 = clk_adc0 … ch7/8 = clk_adc3）。

### 10.2 Stable filter

```verilog
// agc_cdc.v
cfg_sync_d <= cfg_sync;
if (cfg_sync != cfg_sync_d)              stable_cnt <= 0;
else if (stable_cnt < STABLE_CYCLES - 1) stable_cnt <= stable_cnt + 1;
else begin cfg_q <= cfg_sync_d; cfg_valid <= 1; end
```

- `xpm_cdc_array_single` 對每個 bit 各自同步，多 bit 欄位可能有一拍新舊混合值。即時更新模型下任何一拍的錯值都會被算成新檔位並送到衰減器，所以要求整個 bundle 連續 4 拍相同才採用。
- 延遲：AXI 寫入 → `cfg_q` 約 45 ns。210 bit 共用一個計數器，任一欄位改變整包重新等 4 拍（其他欄位維持舊值）。
- 限制：輸入若變化得比約 5 拍還快就永遠不放行。reg map 由 PS 慢速寫入沒問題；`rx_att_index` / `algo` 目前是 VIO（靜態）也沒問題，但換成每拍變動的正式來源時會卡住（§14）。
- `cfg_valid`：reset 後第一次穩定時拉高，之後不再降。`agc_mode_ctrl` 在 `cfg_valid` 之前不寫 Reg5，避免用全 0 的 `cfg_q` 寫一次 Reg5 = 0x00（TX mode、PA 全 0）。

### 10.3 pf / goal_rel handshake

- pf 一改變就送一次；傳送中 pf 再變不排隊，傳完後比較 `pf_cur != pf_last`，送最新值（latest wins）。一輪四相握手約 14~20 拍，延遲約 23 ns。
- pf 與 goal_rel 包在同一個 handshake，一定同一拍到達 adc_clk，`txagc_calc` 不會看到「新 pf + 舊 goal_rel」。
- 由來（source build 12 → 13）：CW mode 的 pf 幾乎每拍變，原本的 stable filter 幾乎永遠不放行，TXAGC 用的 pf 卡在舊值數秒，T 又剛好在檔位邊界，PNA S21 每次掃描跳 4~6 dB。build 13 起改成 handshake，並加 CW 區塊平均（sys15）與換檔遲滯（sys16）。

### 10.4 回到 clk 與 clear

- `gain_index_tx` / `tx_att_clamp`：array_single + 4 拍 filter，約 30 ns。上游變化速率受 handshake 限制（最快約每 14~20 adc_clk 一次），遠慢於 filter 需要的 ~5 clk，目前不會卡住（但依賴上游速率）。
- `clear_or` / `clear_ov`：`xpm_cdc_single` 只同步準位，脈衝寬度由 `agc_rx_set_clear_cycle` ≥ 6（25 ns > 2 × 10 ns）保證被 100 MHz 取樣到。

### 10.5 XPM 參數

| 參數 | 值 | 理由 |
|---|---|---|
| `SRC_INPUT_REG` | 1 | 來源端先打一拍，避免組合 glitch 被目的端取到 |
| `DEST_SYNC_FF` | 3（async_rst 為 4） | MTBF 餘裕 |
| `INIT_SYNC_FF` | 1 | 模擬時同步器有初值 |
| `SIM_ASSERT_CHK` | 0 | 多 bit 同時變化本來就由 filter 處理，關掉 assertion |

---

## 11. 狀態與除錯

### 11.1 狀態暫存器（status_snapshot_0，每通道）

寫 `status_snapshot`（mem64）= 1 → 所有 st_* 在 clk 與 adc_clk 各同一拍鎖存，之後慢慢讀；mem64 讀回完成次數。

| mem | Offset | 名稱 | 格式 | 與 AGC 的關係 |
|---|---|---|---|---|
| mem64 | 0x100 | `status_snapshot` | W：bit0 = 1 觸發；R：[15:0] 完成次數 | — |
| mem66 | 0x108 | `st_gain_index_power_fit` | S5.4（符號擴展） | TXAGC 輸入 pf |
| mem68 | 0x110 | `st_goal_rel_db` | S5.4（符號擴展） | Manual mode 輸入 |
| mem69 | 0x114 | `st_gain_index_tx` | S7.4（符號擴展） | `agc_emu/gain_index_tx`（pf − R，clk domain） |
| mem70 | 0x118 | `st_adc_flags` | [0] over_threshold1、[1] over_threshold2、[2] over_range、[3] over_voltage | RXAGC 輸入（snapshot 當下值，非 sticky） |

`tx_att_state`、`rx_att_state`、`agc_mode` / `agc_mode_valid`、R、`synced` 等 AGC 內部狀態**沒有進 status_snapshot**，上板只能用 ILA 看（§14）。可由 `st_gain_index_power_fit − st_gain_index_tx` 反推 R（兩者不同 domain，僅供參考）。

### 11.2 ILA（system_ila_ch0，每通道一個，clk = FPGA_clk）

| Probe | 訊號 |
|---|---|
| probe0 | `gain_index_mux_0/gain_index_out`（實際送 Gain_Compensation 的 index） |
| probe1 | `power_fit_top/power_amp` |
| probe2 | `power_fit_top/goal_db`（S7.4 dBFS） |
| probe3 | `agc_emu/tx_att_clamp`（{clamp_hi, clamp_lo}） |

BD 內未接出（若需要觀察要另外加 ILA）：`rxagc_0/rx_att_state, rx_att_update, rx_att_ready, rx_att_db`、`txagc_0/tx_att_state`、`agc_mode_ctrl_0/agc_mode_valid, tx_agc_enable`、`sr_reg5_group/synced, start`、`rxagc_dummy_0/rx_att_db`、`agc_emu/digital_comp_index`。

### 11.3 XSDB（`reg_runtime/reg_rt.tcl`）

```tcl
reg_ch 3                          ;# 切到 ch3（1 ~ 8；system 暫存器不受影響）
reg_set agc_reg5 0x00             ;# TXRX_SW = 0 → 切到 TX mode
reg_set agc_tx_power_mode 1       ;# Manual mode（system，8 通道一起）
reg_set agc_target_power -40      ;# 目標 -40 dBm
reg_set agc_tx_att_hysteresis 1   ;# H = 1 dB
reg_wr  gain_index_mode_sel 1     ;# 數位 gain 改用 manual
reg_set gain_index_manual 0       ;#   manual = 0 dB（量通道響應）
reg_dump 3                        ;# snapshot + 讀狀態區，印出並存 CSV / txt
```

常用操作：

| 目的 | 做法 |
|---|---|
| 確認 AGC 有在算 | 改 VIO `rx_att_index` 或 `algo_analog_att_db`，`reg_dump` 看 `st_gain_index_tx` 是否隨 R 改變 |
| 固定數位 gain 量測 | `gain_index_mode_sel` = 1、`gain_index_manual` = 0 |
| 看 TX 類比檔位 | 目前只能加 ILA 到 `txagc_0/tx_att_state`（未接出） |
| 看 RXAGC | `reg_dump` 的 `st_adc_flags`；RX 檔位要加 ILA |
| Bypass 逐檔 | `att_step.tcl`（RFSoC_TX 上 SR 腳位未接，暫無實際效果；腳本註解仍寫 `reg_ch 1 / 3`） |

### 11.4 常見現象與判讀

| 現象 | 可能原因 |
|---|---|
| 輸出位準隨輸入功率變化時跳約 4~5 dB | 類比換檔沒有實體效果（SR 未接 / 沒接 TRM），數位仍補 R；量測時固定數位 gain |
| `tx_att_clamp` 有值 | T 超出 5~130 dB + R 範圍，數位補不到；檢查 offset、target_power、dac_output_ref_dbm |
| `st_gain_index_tx` 不跟著 pf 變 | 是否在 bypass（= pf）、`gain_index_mode_sel` = 1（mux 之後）、或 SR 一直 busy（period 太長） |
| RX mode 下數位 gain 仍在變 | 正常（§7.4） |
| RFDC over_range 讀不到 | RXAGC 在 RX mode 會週期性 clear（§6.5） |

---

## 12. 開機預設值

### 12.1 硬體 reset 值與 PS 開機值

`reg_map_cfg.c` 的 AGC 相關值與硬體 reset 值相同；PS 開機時 8 個通道寫入相同設定：

| 暫存器 | 值 | 意義 |
|---|---|---|
| mem20 `gain_index_mode_sel` | 0 | 數位 gain = TXAGC |
| mem21 `gain_index_manual` | 0 dB | |
| mem22~24 offsets | 0 dB | |
| mem25 `dac_output_ref_dbm` | −25 dBm | |
| mem26 `goal_ref_dbfs` | −6 dBFS | |
| mem27 `agc_reg5` | 0x80 | **RX mode**，Filter / PA 全 0 |
| mem28~30 bypass | 0 | |
| mem31~35 TX manual / target / offsets | 0 | target_power 0 dBm（只在 Manual mode 作用） |
| mem36 / 37 RX manual | 0 | |
| sys4 `agc_tx_power_mode` | 0 | Linear |
| sys5 `digital_apply_delay` | 35 | = RCLK |
| sys6 `agc_sr_update_period` | 50 | 208 ns |
| sys7 `agc_mode_settle_cycle` | 64 | 267 ns |
| sys8~13 RXAGC | 1000 / 6 / 6 / 50 / 6 / 16 | |
| sys16 `agc_tx_att_hysteresis` | 1 dB（16） | |
| VIO `rx_att_index` / `algo_analog_att_db` | 0 / 0 | BD 未設初值 |

（相關的 Power Fit system 值：signal_mode_select 0（CW）、power_limit_margin 3、cw_mode_goal_dbfs −6、pulse_update_stable_cycle 4、cw_power_avg_log2 8；mem38 = 0、mem39 = 0（Aurora）。）

### 12.2 上電序列

1. `rst_n` 釋放 → 4 個 adc_clk 後 `rst_n_adc` 釋放。所有 adc_clk block 開始運作，`cfg_q` 仍為全 0。
2. `agc_mode` = 0（RX），RXAGC 因 `agc_mode_valid` = 0 停在 S_IDLE；`agc_att_mux` 選 RX 欄位 = 0 dB + TX dummy 130 dB；`sr_att_group` 的 `data_q` reset 為 0 ≠ `data_in`，Reg1~4 先送一次這個安全值。
3. 約 3 + 1 + 4 拍後 `cfg_valid` = 1，mode ctrl 從 S_INIT 送出 Reg5 = 0x80。
4. Reg5 一輪（50 拍）結束後進 S_SETTLE 64 拍，`agc_mode` = 0、`agc_mode_valid` = 1，RXAGC 從 S_IDLE → S_WAIT_DSA 開始第一個循環（第一輪不看 flag，先送 0 dB 並清一次 flag）。
5. 約 130 拍（~540 ns）後 AGC 開始真正動作。PS 之後寫入的設定經 CDC 生效，結果收斂到最終設定（逐一寫入時可能送出中間組合）。

### 12.3 開機後的實際狀態（RFSoC_TX）

- 8 個通道都在 **RX mode、Linear**；TXAGC 照算：T = 1545 + pf（rx_att_index、offset、algo 都是 0），即 96.5625 + pf dB（pf 在 ±31.94 dB 內，T 約 64.6~128.5 dB，名目類比檔位落在 state 1~14 之間，依輸入功率而定），但 RX mode 下 TX 欄位送的是 dummy 130 dB，而且 SR 腳位沒接出。
- 數位 gain = `pf − R`（§7.4），所以 DAC 輸出 ≈ Power Fit 的 goal 再減 R（−1 ~ 5.94 dB，H = 1 dB）。
- 若要 TX mode：`agc_reg5` 寫 0x00（或保留 Filter / PA bit，只清 bit7）。

---

## 13. 驗證狀態

### 13.1 模擬（source 專案，RTL 與 RFSoC_TX 相同）

TB 位於 source 專案 `Calibration_Gain_Control/verification/`（`sim/run_sim.sh`），RFSoC_TX 專案內沒有複製 TB。整合後 source 回歸 11 個 TB 全部 PASS（2026-10-14，含新增的 `tb_axis_iq_source_mux`）。與本文相關的：

| TB | 內容 | 結果 |
|---|---|---|
| `tb_agc_emu_top` | channel + system reg map + 與 BD hierarchy 相同結構的 `sim_top/agc_emu_top.v`，3 個時脈，5 個 `lvc595_model` 還原硬體 Reg1~5 並做 1.8 V timing check：T1 上電、T2 RXAGC、T3 manual RX、T4 RX→TX（Linear）、T5 rx_att_index 改變只傳一次、T6 Manual、T7 manual TX、T8 / T9 bypass 進出、T10 TX→RX、T11 週期暫存器下限 / SR period、T12 類比 / 數位分配 M1~M7 / L1~L4、T13 數位 / 類比同步（N = 35 / 20 / 0 / 45）、T14 遲滯 | PASS 90 checks |
| `tb_txagc_calc_model` | `txagc_calc` 對獨立行為模型：manual 0~255 dB、Linear T 全掃、H = 1 dB 上下來回、1,000,000 組隨機（H 0~48） | PASS 1,007,538 vectors |
| `tb_pulse_timeline` | power_fit_db + agc_emu 整鏈時間線（§9.5）；CW 抖動 400 µs：N = 1 / H = 0 → 1658 次換檔，N = 256 / H = 1 dB → 0 次 | PASS |
| `tb_gain_index` | reg map reset 值、cal_cdc、gain_index_mux、Gain_Compensation | PASS 18 checks |
| `tb_reg_maps` | channel / system reg map R/W、reset 值、snapshot | PASS 6 checks |

### 13.2 覆蓋缺口

1. RXAGC 的 S_WATCHING / S_TOO_LOW 路徑：TB 把 `over_threshold2` 綁 1，「無訊號 → 回 0 dB」沒有被模擬；`over_voltage` 綁 0；state 6 飽和未測。
2. 實體衰減碼正確性：TB 的 `tx_code()` / `rx_code()` 與 RTL 用同一套規則，屬自我一致性檢查。
3. RFDC flag / clear 的真實時序（TB 用理想模型）。
4. H > 3 dB、`digital_apply_delay` ≥ `agc_sr_update_period`、N = 255。
5. Bypass 進出的數位跳動、bypass state 28~31、bypass 期間改 TXRX_SW。
6. Mode 切換期間再改 Reg5、reset 在 SR 傳送中途。
7. **多通道**：TB 只模擬單一通道；8 通道的 adc_clk 分配與接線只由 BD 讀取確認。
8. 沒有 gate-level / post-route 模擬（只靠 STA）。

### 13.3 上板

**RFSoC_TX build 01 尚未上板驗證**。source 專案 build 13 / 14 的 handshake、遲滯、CW 平均也還在「待上板驗證」狀態。在 RFSoC_TX 上，SR 相關功能（衰減器、TXRX 開關、`digital_apply_delay` 對齊）因腳位未接出無法驗證；可驗證的是暫存器讀寫、`st_gain_index_tx` 隨 pf / R 變化、RXAGC 對 RFDC flag 的反應（clear）。

本版驗證範圍只到 IF 輸出端（§1）；TRM 相關功能（SR、TX / RX 模式、RXAGC）在 TRM 板上線後再驗證。

---

## 14. 已知限制 / 待確認

狀態「TRM 上線後處理」：本版只驗證 IF 輸出端，這些是 TRM 板上線後才需要的功能，本版不處理。

| # | 項目 | 說明 | 狀態 |
|---|---|---|---|
| 1 | **SR 腳位未接出** | 8 通道 `Reg1~5_SER / SRCLK / RCLK` 在 design_1 沒有 net、沒有頂層 port、沒有 XDC 腳位。本版只驗證 IF 輸出端，不接出是預期的；TRM 上線時需確認 z2 板 TRM 控制線的腳位 / IO 標準後接出 | **TRM 上線後處理** |
| 2 | SR 未接時的數位行為 | 類比換檔沒有實體效果，數位仍補 R → 輸出隨 T 跨檔跳 4~5 dB。IF 驗證時以 mem20 = 1 固定數位 gain 避開（§1）；TRM 上線、類比衰減有實體效果後即為正常行為 | TRM 上線後處理 |
| 3 | 開機在 RX mode | `agc_reg5` = 0x80，開機在 RX mode。TX / RX 模式是控制 TRM 的 TX/RX 開關用，TRM 上線後再決定開機模式；本版對 IF 輸出沒有實體影響（數位 gain 見第 2、9 項） | TRM 上線後處理 |
| 4 | RXAGC clear 對 RFDC flag 的影響 | RX mode 下 RXAGC 會週期性 clear 本板 ADC 的 OR / OV sticky flag；若同事或 PS 也用這些 flag 要協調。RXAGC 屬 TRM 上線後的功能 | TRM 上線後處理 |
| 5 | adc_clk timing 餘裕小 | RFADC0~3 WNS +0.127 / +0.080 / +0.065 / +0.093 ns，最差路徑都是 `txagc_calc` stage 2；改善方案：stage 2 改查表或拆一級 | **建議下一版修正** |
| 6 | Decoder / 打包為示意 | DSA bit 權重、A0~A2 對 QA~QH 的順序、Vc_Bar = Vc、`sw_tx_att` 4/8/12/16 dB 權重都尚未對實體 datasheet / 量測確認 | 待確認（需板子） |
| 7 | 標稱增益常數 | `LINEAR_BASE` 96.5625 dB、`G_TX` 50 dB 為標稱；實際插入損失（RX +4.3 / TX +9.5 dB）要靠 offset 或校正表 | 待辦 |
| 8 | 外部輸入介面 | `rx_att_index` / `algo_analog_att_db` / `pulse_avg_amp` / `pulse_papr` 目前由 VIO 提供；正式來源、時脈、valid 未定。若改成每拍變動的來源，`rx_att_index` / `algo` 的 stable filter 會卡住（需改 handshake） | 待確認 |
| 9 | RX mode 數位 gain | RTL 在 RX mode 仍套用 `pf − R`；source 設計筆記寫「不使用」，兩者不一致。RX mode 屬 TRM 上線後的功能，屆時再確認意圖 | TRM 上線後處理 |
| 10 | Bypass 進出跳動 | 進入 bypass 時數位立刻由 pf − R 變 pf，類比要等 PS trigger；離開時可能送兩次 | 已知（除錯模式） |
| 11 | Mode 切換不對稱 | TX → RX 時 TX 衰減在 settle 期間維持工作值；RX → TX 會多送一次 RX 0 dB | 已知 |
| 12 | N ≥ P 不檢查 | `digital_apply_delay` ≥ `agc_sr_update_period` 時前一次換檔的數位值不會套用；硬體不 clamp | 已知 |
| 13 | 遲滯 H 不限制 | H 最大 15.94 dB，R 可到 −H，數位可能推過 goal 碰到 Gain_Compensation 飽和；硬體不限制 H ≤ 一階 | 已知 |
| 14 | RXAGC clear 往返 | clear 發出到 EVALUATE 只有 6 + 16 拍；若 CDC + RFDC 清除時間超過，會多加 10 dB | 待 bench |
| 15 | RXAGC 演算法 | TOO_LOW 直接回 0 dB；所有過載都只加 10 dB；manual state 7 = 0 dB | 已知 |
| 16 | AGC 內部狀態不可讀 | `tx_att_state`、`rx_att_state`、`agc_mode`、R、synced 沒進 status_snapshot，只能用 ILA | 可改良 |
| 17 | 595 上電狀態 / Reg5 Filter / PA | 第一次 RCLK 前 595 輸出未知（板上 OE / MR 決定）；Reg5 Filter / PA 邏輯與 PA bias 順序未設計 | 待確認（需板子） |
| 18 | SR 邏輯被最佳化 | 腳位沒有負載，SER / SRCLK / RCLK 暫存器可能被移除（`util_hier` FF 數支持此推測）；接出腳位後需重新 build | 推測（TRM 上線後處理） |
| 19 | `att_step.tcl` 註解 | 仍寫「reg_ch 1 / 3」（source 的通道），target 為 1~8 | 小項 |

---

## 15. 修訂歷程

| 版本 | 日期 | 作者 | 內容 |
|---|---|---|---|
| v0.1 | 2026-10-16 | Claude Code（for tsungyurex@jxense.com） | 初版，對應 RFSoC_TX build 01。由 source 專案設計解析 §5 / §6、AGC_EMU_Design_Note、HANDOFF 改寫為 target（8 通道、clk_adc0~3 240 MHz、0xA009_xxxx、無 rx_gain_control）；RTL / BD / regmap / reg_map_cfg / adcThresholds / build 01 報告逐項確認；明列 SR 腳位未接出與待確認事項。同日依 Rex 意見補充：本版只驗證 IF 輸出端，TRM 相關功能（SR、TX / RX 模式、RXAGC）標為 TRM 上線後處理；adc_clk timing 列為建議下一版修正 |
