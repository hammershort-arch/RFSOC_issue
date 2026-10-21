# xsdb 小工具（Debug_008，2026-10-19）

都經 .41 BMC 的 XVC 連到 RFSoC_TX：**TX 在 47DR1（z1）= port 2542，在 47DR2（z2）= port 2550**。
存取一律用 PSU（DAP）+ `-force`，**不會 halt A53**。位址是 RegMap v8：ch N base = `0xA009_0000` + 0x1000 ×（N−1），system = `0xA009_8000`。
寫入的值在 RFSoC 重開機 / MTS 之後回到 PS 預設（Debug_008：ch1 = all_zero + bypass，其他 0 / 0）。

先載入 Vivado 環境：`source /home/wavepro/Documents/vivado2025_2/2025.2/Vivado/settings64.sh`

| 檔案 | 用途 | 用法 |
|---|---|---|
| `../reg_rt.tcl` | 主工具（v8，用暫存器名稱、物理單位、範圍檢查）| `xsdb -interactive ../reg_rt.tcl shell xvc:192.168.68.41:2542` → `reg_ch 1`、`reg_wr signal_source_select 2`、`reg_set phase_offset ...`、`reg_list` |
| `xsdb_shell.tcl` | 互動式簡化版（offset 直接寫）| `xsdb -interactive xsdb_shell.tcl 2542` → `show`、`ch 1`、`rd 0x09C`、`wr 0x098 1`、`wr_all 0x09C 0` |
| `xsdb_reg_wr.tcl` | 批次：一個 offset 寫到 ch lo～hi 並讀回 | `xsdb xsdb_reg_wr.tcl 2542 0x09C 2 1 1`（只改 ch1 為 all_zero） |
| `xsdb_ch_mode.tcl` | 批次：ch1～8 同時設定 mem39 / mem38 | `xsdb xsdb_ch_mode.tcl 2542 1 1`（ADC loopback + bypass） |
| `mk_xsdb_fir_gain.py` | 把 `15_自動化校正資料` 產生的 `fir_chN_v2.tcl` 轉成 v8 位址的寫入 script（FIR + gain_index + bypass）| `python3 -I mk_xsdb_fir_gain.py fir_ch1_v2.tcl out.tcl --ch 1-8 --port 2542 --mode-sel 1 --manual 0 --bypass 0`，再 `xsdb out.tcl` |

常用 offset：`0x000` fir_enable、`0x004~0x040` fir_tap00~15（[31:16] Q、[15:0] I）、`0x04C` phase_offset（fix16_13 rad，≈ 143 × 度，5° = 0x2CB）、
`0x050` gain_index_mode_sel、`0x054` gain_index_manual（S6.4）、`0x098` bypass_axis_iq、`0x09C` signal_source_select（0 Aurora / 1 ADC / 2 all_zero）。

> `tool/15_自動化校正資料/04_xsdb/reference/reg_rt.tcl` 是舊的 RegMap v7（ch1 = 0xA002_0000），**不要用在 v1.0.0 / Debug_008**；請用本資料夾的 `../reg_rt.tcl`。
