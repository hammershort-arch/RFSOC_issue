# Debug_008_TX_ch1_all_zero

> 本文件複製自 `PJ22045_Release_Debug/Debug_008_TX_ch1_all_zero/README.md`（Debug_009 的 RFSoC_TX 以 Debug_008 為基準），文中相對路徑以原位置為準。

- 日期：2026-10-19
- 基準：`PJ22045_Release/v1.0.0_Debug7/source_code_v1.0.0_Debug7/RFSoC_TX`（= v1.0.0 RFSoC_TX，byte-identical）
- 需求（Rex）：Signal Source Mux 多一路 **all_zero**（仍是 160-bit AXIS 格式）；Debug_008 的 PS 讓 **ch1** 預設走 all_zero + `bypass_axis_iq = 1`，開機後 DAC s00 直接收到全 0，用 SA 觀察 DAC 本身的行為。其他通道不動。
- 結果：timing 收斂（WNS +0.033 / WHS +0.010 ns），CW 0；BOOT.bin 已產生；2026-10-19 已上板（.41 z1，見「上板紀錄」）。
- 詳細：PL 改動 / power / timing / utilization / build 時間 → [`RFSoC_TX/PL/Debug_008_PL_Build_Report.md`](RFSoC_TX/PL/Debug_008_PL_Build_Report.md)

## Reg map / xsdb（2026-10-19 補上）

| 路徑 | 內容 |
|---|---|
| `RFSoC_TX/Reg_map/Register_Map.md` | Register map 文件 v0.2（Debug_008：mem39 2 bit，2 / 3 = all_zero；PS 預設 ch1 = all_zero + bypass） |
| `RFSoC_TX/Reg_map/Reg_map_tx_ch_v0.2.xlsx` | Channel register map Excel（v0.2 = v0.1 + mem39 2 bit；Examples 新增「G. all_zero」） |
| `RFSoC_TX/Reg_map/Reg_map_emu_sys_v0.1.xlsx` | System register map（Debug_008 沒有改，內容同 v1.0.0） |
| `RFSoC_TX/Reg_map/tools/` | 產生器（`regmap_def.py` → `mk_doc_register_map.py` / `mk_regmap_v8.py`，複製自 v1.0.0 再改 mem39） |
| `RFSoC_TX/reg_runtime/reg_rt.tcl` | xsdb 主工具 RegMap v8（複製自 rev0.1 `RFSoC_TX/reg_runtime`），**mem39 寬度 1 → 2**（舊版寫 2 會被範圍檢查擋下）；`reg_template.tcl` 依新表重新產生 |
| `RFSoC_TX/reg_runtime/tools/` | `xsdb_shell.tcl`（互動）、`xsdb_reg_wr.tcl`、`xsdb_ch_mode.tcl`、`mk_xsdb_fir_gain.py`，說明見 `tools/README.md` |

- 驗證：`reg_rt.tcl sim` 寫 `signal_source_select 2` 可接受、寫 4 會被擋；2026-10-19 19:4x 以 `REG_HW_URL=xvc:192.168.68.41:2542 xsdb reg_rt.tcl list` 唯讀讀 .41 z1（Debug_008）：ch1 mem39 = 2、mem38 = 1，與 PS 預設一致。
- 經 .41 XVC 互動：`xsdb -interactive RFSoC_TX/reg_runtime/reg_rt.tcl shell xvc:192.168.68.41:2542`（TX 在 z1；z2 用 `:2550`）→ `reg_ch 1`、`reg_wr signal_source_select 2`、`reg_wr bypass_axis_iq 1`。
- `RFSoC_TX/PL/docs/Register_Map.md` 仍是 v1.0.0 的原文（mem39 1 bit），以 `RFSoC_TX/Reg_map/Register_Map.md` 為準；`reg_runtime/Reg_Runtime_SOP.pptx` 也是 rev0.1 原檔，未更新 all_zero。
- `tool/15_自動化校正資料/04_xsdb/reference/reg_rt.tcl` 是 RegMap v7（ch1 0xA002_0000），不能用在 Debug_008。

## 上板紀錄

- 2026-10-19 19:3x：.41 z1（47DR1）= `BOOT_TX_DEBUG_008.bin`（sha 與 MANIFEST 一致 `5f3ca2ed…`），z2 = `BOOT_RX.bin`。開機後 reg map 讀回與 PS 預設一致（ch1 2 / 1，ch2～8 0 / 0）。
- 同時 VU13P（Debug_007，開機策略自動燒錄）die 97.75 °C、風扇轉速 2 RPM → 19:37 擦除（Rex 同意）；之後 Rex 把 ch1～8 bypass 都設 1，觀察 ch1 all_zero + bypass 的 DAC 輸出（VU13P 擦除後 ch2～8 的 Aurora 沒有資料）。

## 硬體改動摘要

```
s_axis_iq_in_0 (Aurora) ─┐
s_axis_iq_in_1 (ADC)   ─┼─ axis_iq_source_mux (sel = mem39[1:0]) ─► axis_iq_bypass (mem38) ─► m_axis_iq ─► DAC
all_zero (160'd0, tvalid=1) ┘                                          └─ bypass=0: FIR / cal / gain 路徑
```

| mem39 (0x09C) | 來源 |
|---|---|
| 0 | in_0 Aurora（reset 預設，同 v1.0.0） |
| 1 | in_1 本板 ADC loopback |
| **2** | **all_zero**（新增） |
| 3 | all_zero（保留） |

- 改的是 8 通道共用的 BDC（`cal_plus_gain_control.bd`），所以 **ch1～ch8 的硬體都有 all_zero 選項**；只有 PS 預設值決定誰使用。
- reg map 不用改（mem39 本來就存 32 bit），`cal_cdc` 同步寬度 1 → 2 bit。
- 位址表、RFDC 設定、Aurora、MTS、ILA 都沒動。

## PS 改動（`RFSoC_TX/PS/app_src`，相對 v1.0.0_Debug7 `PS_Integrated/app_tx/src`）

| 檔案 | 改動 |
|---|---|
| `platform/reg_map_cfg.c` | **只改 CH1**：`signal_source_select = 2`（all_zero）、`bypass_axis_iq = 1`；CH2～CH8 仍為 0 / 0 |
| `platform/register_map.c` | mem39 寫入：範圍檢查 0～1 → **0～2**，寫入 mask 寬度 1 → **2 bit**（`wr()` 會依寬度 mask，不改的話寫 2 會變 0） |
| `platform/register_map.h` | 只改註解 |

- 開機流程同 v1.0.0：reg map 初值在開機時寫入。寫入前（FSBL 載入 bit 到 app 寫完 reg map 之間）ch1 仍是 reset 預設 0（Aurora）+ 完整處理。
- MTS S1 會重開機 → app 重寫初值 → ch1 會回到 all_zero。
- UART 已確認為 PS UART1（objdump：FSBL `#0xff01` ×28、app ×2）。
- 一鍵執行：`RFSoC_TX/PS/scripts/build_ps.sh RFSoC_TX_Debug_008 app_tx`（耗時 3.5 min）

## output_data（`RFSoC_TX/output_data/`）

| 檔案 | 說明 |
|---|---|
| `BOOT.bin` | fsbl.elf + RFSoC_TX_Debug_008.bit + app_tx.elf（格式同 v1.0.0：no PMUFW，app 在 A53-0 EL3） |
| `RFSoC_TX_Debug_008.bit` / `.ltx` / `.xsa` | PL bitstream / ILA + VIO probes / XSA |
| `app_tx.elf` / `fsbl.elf` / `boot.bif` | PS 程式 / FSBL / bootgen 輸入 |
| `MANIFEST.txt` | sha256（BOOT.bin `5f3ca2ed…`） |

## 上板 / 執行期切換

此 BOOT.bin 是 **TX** 版，燒在目前擔任 TX 的那顆 RFSoC。執行期可以用 xsdb 切換 ch1（ch1 base 0xA009_0000，`-force` 不 halt A53，重開機 / MTS 後回到 PS 預設）：

```bash
xsdb PJ22045_Release_Debug/tools/xsdb_reg_wr.tcl <xvc_port> 0x09C 2 1 1
```

- 上面 = ch1 mem39 = 2（all_zero）；改回 Aurora：值 `0`；ADC loopback：值 `1`。
- bypass（mem38，0x098）：值 `1` = 直接送 DAC，`0` = 經 FIR / cal / gain。all_zero + bypass=0 時，全 0 會經過 FIR / calibration / AGC 再送到 DAC，可以拿來比對。
- 注意 `tools/xsdb_ch_mode.tcl` 會同時寫 ch1～ch8，只想改 ch1 請用 `xsdb_reg_wr.tcl ... 1 1`。

## 重現步驟

```bash
cd RFSoC_TX/PL
vivado -mode batch -source scripts/debug008_all_zero.tcl
vivado -mode batch -source scripts/build_full_xsa.tcl -tclargs RFSoC_TX_Debug_008
cd ../PS
./scripts/build_ps.sh RFSoC_TX_Debug_008 app_tx
```
