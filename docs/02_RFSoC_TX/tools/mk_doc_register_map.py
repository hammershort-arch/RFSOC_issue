#!/usr/bin/env python3
# =============================================================================
# mk_doc_register_map.py  (2026-10-16)
#   docs/02_RFSoC_TX/tools/regmap_def.py -> docs/Register_Map.md (RFSoC_TX Register map 設計文件)
#   暫存器表由 regmap_def.py 產生 (與 Excel / RTL 同一個定義來源), 說明文字寫在本檔
#   Usage: python3 docs/02_RFSoC_TX/tools/mk_doc_register_map.py
# =============================================================================
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import regmap_def as D
OUT = os.path.join(os.path.dirname(HERE), "Register_Map.md")

XSDB_NAME = {"fir_enable": "in_band_fir_enable"}          # 其餘與 regmap_def 相同; FIR tap 用 reg_fir_tap 寫入
CH_BASE, SYS_BASE, BRAM_BASE = 0xA0090000, 0xA0098000, 0xA009A000


def esc(s):
    return str(s).replace("|", "/").replace("\n", " ")


def bits(r):
    return f"[{r['msb']}:0]" if r["msb"] else "[0]"


def reset_txt(r):
    if r["access"] in ("RO", "TRIG"):
        return "-"
    v = r["reset"]
    if v and r["signed"] and r["frac"]:
        w = r["msb"] + 1
        sv = v - (1 << w) if v >> (w - 1) else v
        return f"0x{v:X} ({sv / (1 << r['frac']):g})"
    return f"0x{v:X}"


def acc(r):
    return {"RW": "R/W", "RO": "R", "TRIG": "W1 / R"}[r["access"]]


def reg_table(regs, prefix, fir_compact=False):
    s = "| 暫存器 | Offset | 名稱 | 位元 | 存取 | Reset | 格式 / 單位 | 範圍 / 說明 | 生效 |\n|---|---|---|---|---|---|---|---|---|\n"
    done_fir = False
    for r in regs:
        if fir_compact and r["name"].startswith("fir_tap"):
            if done_fir:
                continue
            done_fir = True
            s += (f"| {prefix}1~16 | 0x004~0x040 | fir_tap00 ~ fir_tap15 | [31:0] | R/W | 0x0 | {esc(r['fmt'])} | "
                  f"Complex FIR tap 0~15 係數（XSDB：`reg_fir_tap <t> <I> <Q>`） | {esc(r['effect'])} |\n")
            continue
        s += (f"| {prefix}{r['idx']} | 0x{4 * r['idx']:03X} | {r['name']} | {bits(r)} | {acc(r)} | {reset_txt(r)} | "
              f"{esc(r['fmt'])} | {esc(r['rng'])}；{esc(r['desc'])} | {esc(r['effect'])} |\n")
    return s


def used_table(regs, prefix):
    s = "| 暫存器 | 名稱 | 使用者（BD） | 群組 |\n|---|---|---|---|\n"
    for r in regs:
        if r["name"].startswith("fir_tap") and r["name"] != "fir_tap00":
            continue
        nm = "fir_tap00 ~ 15" if r["name"] == "fir_tap00" else r["name"]
        ix = f"{prefix}1~16" if r["name"] == "fir_tap00" else f"{prefix}{r['idx']}"
        s += f"| {ix} | {nm} | `{esc(r['used'])}` | {r['group']} |\n"
    return s


lo, hi = D.CH_RESERVED
ch_tab = "| 通道 | BD cell | Reg map base | Gain BRAM base | 範圍 |\n|---|---|---|---|---|\n"
for n in range(1, 9):
    ch_tab += (f"| ch{n} | `cal_plus_gain_control_ch{n}` | 0x{CH_BASE + 0x1000 * (n - 1):08X} | "
               f"0x{BRAM_BASE + 0x2000 * (n - 1):08X} | reg 4 KB / BRAM 8 KB |\n")

md = f"""# RFSoC_TX — Register Map

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
| system_reg_map | `design_1/system_reg_map` | 0x{SYS_BASE:08X} | 4 KB（64 × 32-bit） | sys0~13、15、16 設定；sys14 build_version（唯讀） |
| addressable_reg_map | `cal_plus_gain_control_chN/addressable_reg_map` | 見下表 | 4 KB（128 × 32-bit） | mem0~{lo - 1} 設定；mem{lo}~{hi} 保留；mem64~70 狀態 |
| gain 表 BRAM | `cal_plus_gain_control_chN/calibration/axi_bram_ctrl_0` | 見下表 | 8 KB（2048 × 32-bit） | Gain_Compensation 用的增益表 |

{ch_tab}
- 位址是 Vivado Address Editor 分配的結果（2026-10-14）。同事原有的位址（0xA000_0000 ~ 0xA008_FFFF）沒有變動。
- 8 個通道的暫存器表完全相同，只差 base address。
- system 暫存器只有一份，8 個通道讀到的值相同。

## 3. AXI 存取規則

- 介面：AXI4-Lite，32-bit，`addressable_reg_map` 9-bit 位址、`system_reg_map` 8-bit 位址（RTL 由 `gen_reg_maps.py` 產生）。
- **沒有 reset**：設定暫存器的初值是 FPGA 上電時的值（= 表中 Reset 欄），不受 `S_AXI_resetn` 影響。PS 重新開機不會把值恢復，要恢復需要重新寫入或重新載入 bitstream。
- 寫入：支援 WSTRB 位元組寫入；AW / W 可以同拍或分開到達。
- 設定暫存器整個 32-bit 都可讀寫；超出「位元」欄的高位元會被保留並讀回，但硬體不使用。
- 有號欄位使用二補數；`S6.4` 表示 11-bit、1/16 dB 步階（例：−6.0 dB = −96 = 0x7A0）。
- 保留位址（mem{lo}~{hi}、mem71~127、sys17~63）讀回 0，寫入無效。
- 唯讀暫存器（狀態、sys14）寫入無效。
- dBFS 基準：16384 = 0 dBFS。

## 4. System 暫存器（`system_reg_map`，base 0x{SYS_BASE:08X}）

{reg_table(D.SYSTEM, "sys")}
- sys14 `build_version` 由 Vivado 參數 `BUILD_VERSION` 決定；RFSoC_TX build 01 目前是 **0**（沒有設定）。
- sys6~13 的 AGC 週期暫存器若寫入小於硬體最小值，硬體會以最小值運作（讀回仍是寫入的值）。

### 4.1 System 暫存器的使用者

{used_table(D.SYSTEM, "sys")}
## 5. Channel 設定暫存器（`addressable_reg_map`，每通道一份）

Base address 見第 2 節（ch1 = 0x{CH_BASE:08X}，chN = 0x{CH_BASE:08X} + 0x1000 × (N−1)）。

{reg_table(D.CHANNEL, "mem", fir_compact=True)}
- mem{lo}~{hi} 保留給之後擴充，讀回 0。
- **mem39 `signal_source_select`** 是 RFSoC_TX 新增的 Signal Source Mux 選擇：0 = `s_axis_iq_in_0`（Aurora，`hier_rx_x0yN`），1 = `s_axis_iq_in_1`（本板 ADC，`rfdc_iq_combine_chN`），**2 / 3 = all_zero**（Debug_008 新增：160'd0、tvalid = 1，用來看 DAC 收到全 0 時的輸出）。mem39 在 Debug_008 是 2 bit（`cal_cdc` 同步寬度 1 → 2）。
- **mem38 `bypass_axis_iq`** = 1 時，Mux 選到的輸入直接送 DAC，不經 FIR / calibration / gain（AGC 與 Power Fit 仍照常計算）。

### 5.1 Channel 暫存器的使用者

{used_table(D.CHANNEL, "mem")}
## 6. 狀態暫存器（mem64~70）與 snapshot

{reg_table(D.CH_STATUS, "mem")}
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
- 位址 chN = 0x{BRAM_BASE:08X} + 0x2000 × (N−1)；第 i 筆在 base + 4 × i。
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
"""
open(OUT, "w", encoding="utf-8").write(md)
print("wrote", OUT)
