# PJ22045 1R8T — Debug_009_XDC_change 文件總覽

> **Debug_009 版（2026-10-20，文件 v0.4）**：本 `docs/` 以 `PJ22045_Release/v1.0.0_Debug7/design_document` 為基礎，加上：
> - `07_Debug008_TX_ch1_all_zero/`：RFSoC_TX 的基準 Debug_008（Signal Source Mux 加 all_zero、PS 預設 ch1 = all_zero + bypass）
> - `08_Debug009_XDC_change/`：Debug_009 的 XDC 改動、TX / RX build 報告
> - `02_RFSoC_TX/Register_Map.md` 換成 Debug_008 的 v0.2（mem39 2 bit），`Reg_map/` 多 `Reg_map_tx_ch_v0.2.xlsx`，`tools/` 換成 Debug_008 版產生器
> - `02_RFSoC_TX/MTS_Design.md`、`03_RFSoC_RX/MTS_Design.md` §6 加 Debug_009 XDC 註記
> - `tools/` 補上 md → docx 工具（`md2docx.js`、`mk_all_docx.sh`、node_modules）與 `reference_rev0.12/`（取自 Rex rev0.1 release `docs/`）
>
> 第 0 節以下是 v1.0.0_Debug7 原文。Debug_009 的總說明見 `../../README.md`（Debug_009_XDC_change 根目錄）。

## Debug_009 與 v1.0.0_Debug7 的差異

| 板子 | v1.0.0_Debug7 | Debug_009 |
|---|---|---|
| RFSoC_TX | v1.0.0 | Debug_008（all_zero mux）+ XDC：PL_SYSREF `DIFF_TERM_ADV TERM_100`、`set_input_delay`（另 11 條 max_delay 無作用）；WNS +0.006 / WHS +0.010 ns |
| RFSoC_RX | v1.0.0 | XDC 同 TX；WNS +0.052 / WHS +0.010 ns |
| VU13P | Debug_007 | 相同（不改） |

BUFGCE `PROHIBIT`（reference 有）沒有加。詳見 `08_Debug009_XDC_change/XDC_Constraints_Debug_009.md`。

# v1.0.0_Debug7 文件總覽（原文）

- Release：`PJ22045_Release/v1.0.0_Debug7`（以 `PJ22045_Release/v1.0.0` 為基準，2026-10-17）
- 內容來源：`PJ22045_Release_Debug/Debug_007_VU13P_bidirectional`
- 基準：v1.0.0（= Rex rev0.1；同事 PJ22045_1R8T rev0.12 release，2026-10-14）
- 文件版本：v0.3（2026-10-17）

## 0. v1.0.0_Debug7 與 v1.0.0 的差異

**只改 VU13P**：原本只支援 z1 → VU13P → z2，現在也支援 z2 → VU13P → z1。目的是測試 z1 = RFSoC_TX（8CH）、z2 = RFSoC_RX 時，透過外部時鐘板做 remote MTS 是否成功。

| 項目 | v1.0.0 | v1.0.0_Debug7 |
|---|---|---|
| VU13P | 只有 X1Y8 C1（z1）→ broadcaster_0 → z2 | 再加一條鏡像路徑：X1Y4 C1（z2）→ `axis_slr_x1y4_to_z1` → `axis_broadcaster_1` → X1Y8~11 → z1，另加 `ila_bcast_1` |
| VU13P dbg_hub 時脈 | Aurora x1y9 user_clk（約 400 MHz） | sys_clk 100 MHz（Aurora 沒起來也能連 ILA） |
| VU13P timing | WNS +0.011 / WHS +0.010 ns | **WNS +0.006 / WHS +0.010 ns** |
| RFSoC_RX / RFSoC_TX（PL、PS、BOOT.bin） | — | **與 v1.0.0 逐檔相同** |
| BMC | — | 與 v1.0.0 相同 |

- 不需要方向選擇：兩組 broadcaster 都沒有 tready，放 RFSoC_RX 的那一側才有資料。同一個 VU13P bitstream 正常配置和交換配置都可以用（見 §2）。
- VU13P 的 bitstream / ltx：`source_code_v1.0.0_Debug7/VU13P/output_data/VU13P_Debug_007.{bit,ltx}`。
- 詳細內容：`06_Debug7_VU13P_Bidirectional/Debug7_VU13P_Bidirectional.md`；VU13P 設計筆記：`01_System/DESIGN_NOTES_vu13p.md` 開頭的「v1.0.0_Debug7 修改」。
- **上板結果（2026-10-17，.41）**：交換配置（Z1 = TX、Z2 = RX）+ VU13P Debug_007（RFSoC 燒的是 Debug_003 BOOT：PL / bitstream 與 v1.0.0 相同，app 只多 RFDC debug log），Multi-board MTS **10 / 10 成功**，兩顆 8 個 tile 開機 PLL 全部 LOCKED，SysRef 480 / 480。Aurora 是否實際帶資料尚未用 ILA 確認。正常配置尚未在 Debug_007 上測試。

## 1. 閱讀指引

| 想知道 | 看哪裡 |
|---|---|
| v1.0.0_Debug7 改了什麼 | 第 0 節、`06_Debug7_VU13P_Bidirectional/` |
| 系統由哪三塊板子組成、各自的版本 | 第 2 節 |
| 各文件放在哪裡 | 第 3 節 |
| 同事 rev0.12 原始文件 | 第 4 節 |
| 簡報 | 第 3.4 節 |
| 如何由 md 產生 docx | 第 5 節 |

## 2. 系統組成與版本

```
正常配置：RFSoC_RX (z1, 47dr1)  ADC 00 ──Aurora──► VU13P (broadcaster_0，1 → 8) ──8 條 Aurora──► RFSoC_TX (z2, 47dr2) ──► 8 個 DAC
交換配置：RFSoC_RX (z2, 47dr2)  ADC 00 ──Aurora──► VU13P (broadcaster_1，1 → 8) ──8 條 Aurora──► RFSoC_TX (z1, 47dr1) ──► 8 個 DAC   ← v1.0.0_Debug7 新增
```

| 配置 | z1（47DR1） | z2（47DR2） | VU13P |
|---|---|---|---|
| 正常 | RFSoC_RX（`BOOT_RX.bin`） | RFSoC_TX 8ch（`BOOT_TX.bin`） | `VU13P_Debug_007.bit` |
| 交換 | RFSoC_TX 8ch（`BOOT_TX.bin`） | RFSoC_RX（`BOOT_RX.bin`） | 同一個 bit |

> 以下內容是 v1.0.0（Rex rev0.1）原文，表格中的路徑是 rev0.1 release 當時的路徑；v1.0.0_Debug7 的原始碼在 `source_code_v1.0.0_Debug7/`。

| 板子 | 專案 | 來源 | Rex rev0.1 的修改 | 輸出 |
|---|---|---|---|---|
| RFSoC_TX（z2，47dr2） | `RFSoC_TX/hardware/RFSoC_TX.xpr` | 整合專案 dev（Save Project As） | 8 × cal_plus_gain_control（Signal Source Mux、Calibration、Power Fit、Gain Control）+ system_reg_map；RFDC NCO 1.04 / −1.04 GHz；PL + PS | `RFSoC_TX/output_data/01/`（bit / ltx / xsa / BOOT.bin） |
| RFSoC_RX（z1，47dr1） | `RFSoC_RX/hardware/RFSoC_RX.xpr` | rev0.12 release `source/47dr1` | 只改 RFDC NCO（0.84 → 1.04 GHz）；補回 `onebit_cdc_fifo`；PL only | `RFSoC_RX/output_data/01/`（bit / ltx / xsa） |
| VU13P | 同事 rev0.12 | rev0.12 release | 無（v1.0.0_Debug7：雙向，見第 0 節） | 沿用 rev0.12（v1.0.0_Debug7：`VU13P/output_data/VU13P_Debug_007.bit`） |

| Build | Timing | 用量（LUT / FF / BRAM / DSP） |
|---|---|---|
| RFSoC_TX 01 | WNS 0.000 ns / WHS +0.010 ns | 50.2% / 40.4% / 52.5% / 68.0% |
| RFSoC_RX 01 | WNS +0.063 ns / WHS +0.010 ns | 14.7% / 10.1% / 20.8% / 0% |
| VU13P Debug_007（v1.0.0_Debug7） | WNS +0.006 ns / WHS +0.010 ns | 3.38% / 4.66% / 17.97% / — |

> NCO 三塊板必須一致：RFSoC_TX 與 RFSoC_RX 都是 1.04 GHz（RF 中心 2.8 GHz，頻段 2.3 ~ 3.3 GHz）。不要與同事 rev0.11 / rev0.12 的 z1（0.84 GHz）混用。

> 全部尚未上板驗證。RFSoC_TX 本版只針對 IF 輸出端做驗證；Gain Control 中與 TRM 相關的功能（SR、TX / RX 模式、RXAGC）是 TRM 板上線後才需要的功能（見 `docs/02_RFSoC_TX/Gain_Control.md` §1）。

## 3. 文件索引

2026-10-16 起，原本分散在 `docs/`、`RFSoC_TX/docs/`、`RFSoC_RX/docs/` 的文件全部集中到 release 根目錄的 `docs/`，依層級分資料夾：

```
docs/
├ README.md / .docx             本文件（總覽、索引）
├ 01_System/                    系統層：三塊板子的設計筆記
├ 02_RFSoC_TX/                  RFSoC_TX（z2，47dr2）詳細設計
│   ├ fig/                      頂層架構圖
│   ├ Reg_map/                  暫存器表 Excel
│   ├ tools/                    Register map 定義與產生器
│   └ history/                  整合過程紀錄（dev 階段）
├ 03_RFSoC_RX/                  RFSoC_RX（z1，47dr1）詳細設計
│   └ fig/
├ 04_Presentation/              簡報（pptx）與產生腳本（v1.0.0 版，未更新 Debug7）
├ 05_Diff_TX_vs_RX/             RFSoC_TX 與 RFSoC_RX 差異比較
├ 06_Debug7_VU13P_Bidirectional/  v1.0.0_Debug7：VU13P 雙向修改與 build 報告
├ 07_Debug008_TX_ch1_all_zero/   Debug_008：TX all_zero（Debug_009 TX 的基準）
├ 08_Debug009_XDC_change/        Debug_009：XDC 改動、TX / RX build 報告
├ reference_rev0.12/            同事 rev0.12 原始文件（未修改）
└ tools/                        共用工具（md → docx、RFDC 讀出、架構圖原始檔）
```

### 3.1 系統層（`docs/01_System/`）

| 文件 | 內容 |
|---|---|
| `DESIGN_NOTES_RFSoC_TX.md` | RFSoC_TX（z2）設計筆記：角色、Aurora、refclk、Rex 修改、命名、歷程（改寫自同事 DESIGN_NOTES_47dr2） |
| `DESIGN_NOTES_RFSoC_RX.md` | RFSoC_RX（z1）設計筆記（改寫自同事 DESIGN_NOTES_47dr1） |
| `DESIGN_NOTES_vu13p.md` | VU13P 設計筆記（開頭是 v1.0.0_Debug7 的修改，中文；後面是同事原文，路徑是同事 release 的路徑） |

### 3.1.1 v1.0.0_Debug7（`06_Debug7_VU13P_Bidirectional/`）

| 文件 | 內容 |
|---|---|
| `../02_RFSoC_TX/MTS_Design.md`、`../03_RFSoC_RX/MTS_Design.md` | RX / TX 各自的 MTS 相關電路設計（由 `tools/mk_mts_design.py` 產生） |
| `Debug7_VU13P_Bidirectional.md` | 為什麼 RX / TX 不用改、VU13P 改動、dbg_hub 時脈、build 結果與時間、上板使用方式、待確認事項 |

### 3.1.2 Debug_008（`07_Debug008_TX_ch1_all_zero/`）

| 文件 | 內容 |
|---|---|
| `Debug_008_README.md` | Debug_008 總說明：all_zero 硬體改動、PS 預設、Reg map / xsdb、上板紀錄 |
| `Debug_008_PL_Build_Report.md` | Debug_008 PL 改動、power / timing / utilization / build 時間 |

### 3.1.3 Debug_009（`08_Debug009_XDC_change/`）

| 文件 | 內容 |
|---|---|
| `XDC_Constraints_Debug_009.md` | 與 reference XDC 的比對、加了哪些約束、實際效果（含 max_delay 無作用的原因）、沒搬的約束、SYSREF input slack |
| `Debug_009_RFSoC_TX_PL_Build_Report.md` | TX build：timing / power / utilization / clock 擺放 / CW / build 時間（vs Debug_008） |
| `Debug_009_RFSoC_RX_PL_Build_Report.md` | RX build（vs v1.0.0） |

### 3.2 RFSoC_TX（`docs/02_RFSoC_TX/`）

| 文件 | 內容 |
|---|---|
| `RFSoC_TX_Top_Architecture.md` | design_1 頂層架構、8 通道、時脈、位址表、build 結果、與 rev0.12 差異 |
| `Register_Map.md` | 每通道暫存器（mem0~39）、system_reg_map（sys0~16）、gain 表 BRAM、位址（由 `tools/regmap_def.py` 產生） |
| `Calibration.md` | Signal Source Mux、bypass、In-band FIR、Delay / Phase calibration、Gain compensation、gain 表 |
| `Power_Fit.md` | CW / Pulse 功率量測、dB 域計算、goal、時序 |
| `Gain_Control.md` | TXAGC / RXAGC、gain index、shift register（74LVC595）、數位 / 類比同步 |
| `RFDC_Configuration.md` | RFDC 參數（由 Vivado 讀出）、NCO、時脈、與 rev0.12 差異 |
| `MTS_Design.md` | **MTS 相關電路設計**（v1.0.0_Debug7 新增）：時脈 / SYSREF 輸入、RFDC MTS 設定、PL SYSREF 路徑、hier_mts、reset、XDC、PS I2C 指令、BMC 流程、量測紀錄、與 RX 的差異 |
| `Follow_Up.md` | 已知現象與後續版本優化建議（F1 ~ F5）、TRM 上線後處理項目（T1 ~ T3） |
| `Reg_map/*.xlsx` | 暫存器表 Excel |
| `tools/regmap_def.py` | Register map 定義；`mk_doc_register_map.py` → `Register_Map.md`，`mk_regmap_v8.py` → `Reg_map/*.xlsx` |
| `history/cal8ch_integration_20261014.md` | 整合過程紀錄（dev 階段，保留原文，文中路徑是當時 dev 專案的路徑） |

### 3.3 RFSoC_RX（`docs/03_RFSoC_RX/`）

| 文件 | 內容 |
|---|---|
| `RFSoC_RX_Top_Architecture.md` | design_1 頂層架構、ADC / DAC 去向、時脈、位址表、build 結果、與 rev0.12 差異 |
| `RFDC_Configuration.md` | RFDC 參數、NCO 修改 |
| `MTS_Design.md` | **MTS 相關電路設計**（v1.0.0_Debug7 新增；內容與 TX 版同架構，差異見其 §10） |

### 3.4 簡報（`docs/04_Presentation/`）

| 檔案 | 內容 |
|---|---|
| `PJ22045_1R8T_Rex_rev0.1.pptx` | Rex rev0.1 設計簡報（風格沿用同事 `reference_rev0.12/pj22045_1r8t_design.pptx`），內容取自本目錄各文件 |
| `make_ppt.py` | 簡報產生腳本（python-pptx，以同事簡報為版型） |

每份 md 旁邊都有同名 `.docx`（由 md 產生，內容相同）。

## 4. 同事 rev0.12 原始文件（`docs/reference_rev0.12/`）

完整複製自同事 rev0.12 release 的 `docs/`，**僅供參考，未修改**：

| 文件 | 內容 |
|---|---|
| `DESIGN.md / .docx` | 系統設計總覽 |
| `SIGNAL_TRANSMISSION.md / .docx` | Aurora 傳輸、封包、FIFO（RFSoC_TX / RX 的 Aurora 部分沿用） |
| `TIMING_SYNC.md / .docx` | 時間同步、MTS、SYSREF |
| `DESIGN_NOTES_47dr1.md`、`DESIGN_NOTES_47dr2.md`、`DESIGN_NOTES_vu13p.md` | 同事英文設計筆記 |
| `pj22045_1r8t_design.pptx`、`fig/` | 簡報與圖 |

注意：同事文件中的 z1 / z2 NCO（0.84 GHz）與 TX 通道處理（直接送 DAC）已被 Rex rev0.1 取代。

## 5. 工具

共用工具在 `docs/tools/`，RFSoC_TX 專用的 Register map 工具在 `docs/02_RFSoC_TX/tools/`：

| 檔案 | 用途 |
|---|---|
| `tools/md2docx.js` | md → docx（樣式對齊同事文件：A4 橫向、navy 標題 / 表頭、支援圖片） |
| `tools/mk_all_docx.sh` | 一次產生所有 docx（README、01_System、02_RFSoC_TX（含 history）、03_RFSoC_RX） |
| `tools/rfdc_dump.tcl` | 以唯讀方式開啟兩個專案、讀出 RFDC 參數 → `rfdc_params_TX.txt / RX.txt` |
| `tools/mk_doc_rfdc.py` | 由 `rfdc_params_*.txt` 產生 `02_RFSoC_TX/` 與 `03_RFSoC_RX/` 的 `RFDC_Configuration.md` |
| `tools/fig_src/*.dot` | 頂層架構圖原始檔（graphviz） |
| `02_RFSoC_TX/tools/regmap_def.py` | Register map 定義 |
| `02_RFSoC_TX/tools/mk_doc_register_map.py` | 產生 `02_RFSoC_TX/Register_Map.md` |
| `02_RFSoC_TX/tools/mk_regmap_v8.py` | 產生 `02_RFSoC_TX/Reg_map/*.xlsx`（檔案已存在時不覆蓋） |
| `04_Presentation/make_ppt.py` | 產生簡報 |

```
cd docs/tools && ./mk_all_docx.sh
```

docx 的目錄是 Word 欄位：第一次開啟時 Word 會詢問是否更新欄位，選「是」；或在目錄上按右鍵 → 更新功能變數。

## 6. 修訂歷程

| 版本 | 日期 | 說明 |
|---|---|---|
| v0.1 | 2026-10-16 | 第一版：RFSoC_TX build 01、RFSoC_RX build 01 |
| v0.2 | 2026-10-16 | 文件集中到 `docs/` 並分層（01_System / 02_RFSoC_TX / 03_RFSoC_RX / 04_Presentation）；新增簡報 |
| v0.4 | 2026-10-20 | Debug_009_XDC_change：新增 07 / 08、Register_Map v0.2（Debug_008）、MTS_Design §6 XDC 註記、補 docx 工具與 reference_rev0.12 |
| v0.3 | 2026-10-17 | v1.0.0_Debug7：VU13P 雙向（z2 → VU13P → z1）、dbg_hub 改用 sys_clk；新增第 0 節與 `06_Debug7_VU13P_Bidirectional/`；更新 `01_System/` 三份設計筆記；加入上板結果；新增 `02_RFSoC_TX/MTS_Design.md`、`03_RFSoC_RX/MTS_Design.md`（MTS 相關電路設計，2026-10-18）；source code 的 RX / TX / BMC 確認與 v1.0.0 逐檔相同 |
