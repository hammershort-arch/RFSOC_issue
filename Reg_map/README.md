# Reg_map（Debug_009）

Debug_009 只改 XDC，register map **與 Debug_008 完全相同**（本資料夾直接複製自 `Debug_008_TX_ch1_all_zero/RFSoC_TX/Reg_map`；Debug_009 放在根目錄，只適用 RFSoC_TX）。

| 檔案 | 內容 |
|---|---|
| `Register_Map.md` | Register map 文件 v0.2（mem39 2 bit，2 / 3 = all_zero） |
| `Reg_map_tx_ch_v0.2.xlsx` | Channel register map Excel |
| `Reg_map_emu_sys_v0.1.xlsx` | System register map Excel（同 v1.0.0） |
| `tools/` | 產生器（`regmap_def.py` → `mk_doc_register_map.py` / `mk_regmap_v8.py`） |

- `RFSoC_TX/PL/docs/Register_Map.md`（PL 原始碼附帶）仍是 v1.0.0 原文（mem39 1 bit），以本資料夾與 `docs/02_RFSoC_TX/Register_Map.md`（v0.2）為準。
- RFSoC_RX 沒有 addressable reg map（PS 只有 gpio / iic / rfdc），所以 RX 沒有 Reg_map / reg_runtime。
