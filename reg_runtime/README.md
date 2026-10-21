# Reg Map runtime 設定 (xsdb over JTAG) 操作步驟

> **Debug_009 版（2026-10-20）**：與 Debug_008 完全相同（Debug_009 只改 XDC，reg map / 位址 / PS 預設都沒動；PS 預設仍是 ch1 = mem39 2 + mem38 1）。
> **Debug_008 版（2026-10-19）**：由 `PJ22045_1R8T_release_Rex_rev0.1_20261015/RFSoC_TX/reg_runtime` 複製，只改 mem39 `signal_source_select` 為 2 bit（2 = all_zero）。Debug_008 的 PS 開機預設：ch1 = mem39 2 + mem38 1，其他通道 0 / 0。
> 經 .41 BMC XVC 連線：`xsdb -interactive reg_rt.tcl shell xvc:192.168.68.41:2542`（TX 在 47DR1 / z1；在 47DR2 / z2 時用 `:2550`）。
> 其他 xsdb 小工具（`xsdb_shell.tcl`、`xsdb_reg_wr.tcl`、`xsdb_ch_mode.tcl`、`mk_xsdb_fir_gain.py`）放在 `tools/`，說明見 `tools/README.md`。

適用版本：**PJ22045_1R8T**（2026-10-14 由 `Calibration_Gain_Control/reg_runtime` 複製後修改）/ RegMap v8 + mem39（Calibration_Gain_Control `doc/Reg_map/Reg_map_tx_ch_v0.2.xlsx` + `Reg_map_emu_sys_v0.1.xlsx`）。本專案沒有 `rx_gain_control`，RX ch7 的 `rx_*` 暫存器與 `reg_dump 7`（RX）已移除；`reg_dump 7` 現在是 cal_plus_gain_control_ch7。

| reg map | BD | base | 內容 |
|---|---|---|---|
| system | `design_1/system_reg_map` | `0xA009_8000` | sys0~13、15、16 所有通道共用的設定（Power Fit mode / margin / CW goal / Pulse 更新 M 拍、TX power mode、digital_apply_delay、AGC 週期、CW 平均、TX 換檔遲滯），sys14 `build_version`（唯讀，目前 BUILD_VERSION = 0） |
| ch1 ~ ch8 | `cal_plus_gain_control_ch1` ~ `ch8` | `0xA009_0000` + 0x1000 ×（N−1）（gain BRAM `0xA009_A000` + 0x2000 ×（N−1）） | mem0~39 設定、mem64~70 狀態 |

- 8 個通道的暫存器表完全相同，用 `reg_ch 1` ~ `reg_ch 8` 切換（預設 ch1）。
- **system 暫存器不受 `reg_ch` 影響**，名稱照用即可（例如 `reg_set power_limit_margin 3` 會同時作用在所有通道）。
- 位址是 Vivado assign_bd_address 的結果（2026-10-14）；之後 Address Editor 若重新分配，要同步改 `reg_rt.tcl` 的 `::reg::CH_BASE` / `::reg::SYS_BASE`。
- `bypass_axis_iq = 1`（mem38）：Signal Source Mux 選到的輸入直接送 DAC，不經 FIR / calibration / gain control（AGC、Power Fit 仍照常計算），除錯用。
- `signal_source_select`（mem39，2026-10-14；**Debug_008 改成 2 bit**）：Signal Source Mux，0 = `s_axis_iq_in_0`（Aurora）、1 = `s_axis_iq_in_1`（本板 ADC）、**2 / 3 = all_zero**（160'd0、tvalid = 1）；選到的那一路送給 Power Fit / Calibration（mem38 bypass 也是送這一路），沒選到的那一路丟掉。
- v7 → v8 對照見 `doc/Reg_map/Reg_map_channel_v0.2.xlsx`（v0.1 = 原 v8）的 `v7_to_v8` 工作表。`cw_mode_goal_amp` / `goal_ref_amp`（振幅）改成 `cw_mode_goal_dbfs` / `goal_ref_dbfs`（dBFS，16384 = 0 dBFS，例如 8192 ≈ −6 dB）。
用途：PS 開機寫完初始值後，從筆電透過 USB-JTAG 在 runtime 讀寫 addressable_reg_map，不需改硬體或 PS 程式。

| 檔案 | 說明 |
|---|---|
| `reg_rt.tcl` | 主腳本：暫存器表（名稱、位址、格式、範圍）與讀寫指令 |
| `reg_template.tcl` | **全部暫存器範本**：每行預設註解，要改哪顆就拿掉 `#`、填值（沒拿掉的不會寫） |
| `fir_ch1_example.tcl` | 只改 ch1 In-band FIR（enable + 16 taps，共 17 顆）的範例 |
| `my_cfg_example.tcl` | 設定檔範例（TX Manual mode 等） |
| `att_step.tcl` | Bypass mode 逐檔切換 TX 類比衰減器（`source att_step.tcl` 後用 `att_on` / `att_next` / `att_prev` / `att_set` / `att_db` / `att_list` / `att_off`） |
| `README.md` | 本文件 |

---

## 1. 事前準備（每台筆電做一次）

1. **安裝工具**：需要 `xsdb` 與 `hw_server`。
   - Vivado 2025.2 完整版或 Vitis 都有附（例：`<安裝路徑>/2025.2/Vivado/bin/xsdb`、`hw_server`）。
   - 若只裝 Vivado Lab Edition，請確認 `bin/` 底下有 `xsdb`；沒有的話改用第 6 節的「遠端連線」做法。
2. **USB-JTAG 驅動**：
   - Windows：安裝 Vivado 時勾選 cable driver。
   - Linux：執行 `<安裝路徑>/data/xicom/cable_drivers/lin64/install_script/install_drivers/install_drivers`（需 root）。
3. **複製 `reg_runtime` 資料夾**到筆電，例如 `C:\reg_runtime` 或 `~/reg_runtime`。
4. **確認 USB 線是 JTAG**，不是 UART。如果是 UART，本做法不適用。

## 1.1 連線方式
| 方式 | 需要的東西 | 怎麼連 |
|---|---|---|
| **經 BMC 的 XVC（網路 JTAG，建議）** | 筆電接到 SDR 所在的網段（192.168.68.x），不需要 JTAG 線 | `REG_HW_URL=xvc:192.168.68.42:2542`（47DR1）或 `:2550`（47DR2），或 `reg_connect xvc:192.168.68.42:2542` |
| 直接 JTAG 線 | JTAG 下載線（Platform Cable USB II / Digilent HS2、HS3）接板上 JTAG 接頭 | `reg_connect`（本機 hw_server） |

- XVC 和燒錄網頁共用 BMC 的 XVC server；燒錄進行中不要同時用 xsdb 連同一顆。
- 板上是否有可直接接線的 JTAG 接頭，需要跟硬體同事確認。

## 2. 上板前：離線檢查設定檔（不接板子）

改好設定檔後，先用模擬模式檢查名稱、數值範圍與換算結果。

**Linux：**
```bash
source <安裝路徑>/2025.2/Vivado/settings64.sh
cd ~/reg_runtime
xsdb reg_rt.tcl sim my_cfg.tcl
```

**Windows**（cmd）：
```bat
cd C:\reg_runtime
<安裝路徑>\2025.2\Vivado\bin\xsdb.bat reg_rt.tcl sim my_cfg.tcl
```

模擬模式會：
- 逐行印出每個暫存器寫入的物理值、raw 值與位址。
- 最後列出所有暫存器的值（未寫的維持 reset 值）。
- 名稱打錯、超出格式範圍、不是數字時，會指出檔名和行號並停止。

## 3. 上板操作步驟

### 3.1 接線與開機
1. 板子上電，等 PS 開機完成：bitstream 已載入，PS 程式已寫完初始值。
2. 筆電接上 USB-JTAG。
3. Vivado Hardware Manager（ILA / VIO）可以同時開著，兩邊共用同一個 hw_server。

### 3.2 開啟 xsdb
- **Linux**：`source .../settings64.sh`，再執行 `xsdb`。
- **Windows**：在 cmd 執行 `<安裝路徑>\2025.2\Vivado\bin\xsdb.bat`，或開「Vivado 2025.2 Tcl Shell」後輸入 `xsdb`。

出現 `xsdb%` 提示字元就可以輸入指令。

### 3.3 互動模式（一次改一兩個值、邊看邊調）
一行啟動：載入腳本、連線，然後停在 `xsdb%` 提示字元（在 `reg_runtime` 資料夾下執行）。連線失敗時也會留在提示字元，可以直接再打 `reg_connect <位址>` 重試：
```bash
xsdb -interactive reg_rt.tcl shell xvc:192.168.68.42:2542     # 經 BMC 的 XVC（網路），47DR1；47DR2 用 2550
xsdb -interactive reg_rt.tcl shell xvc:192.168.68.42:2542 3   # 同上，一開始就切到 ch3
xsdb -interactive reg_rt.tcl shell TCP:localhost:31000        # 接到已經在跑的 hw_server（例如 Vivado 開的，port 31000）
xsdb -interactive reg_rt.tcl shell                            # 本機 USB-JTAG（例如 JTAG-HS3 插在這台電腦）
xsdb -interactive reg_rt.tcl shell sim                        # 不接板子，練習用
```
Windows 用 `<安裝路徑>\2025.2\Vivado\bin\xsdb.bat -interactive reg_rt.tcl shell`。

之後直接打指令，不需要寫檔案：
```tcl
xsdb% reg_wr in_band_fir_enable 0            ;# 單顆測試: FIR 關
xsdb% reg_wr in_band_fir_enable 1            ;# FIR 開
xsdb% reg_run my_cfg.tcl                     ;# 同一個視窗也能跑整份設定檔
```

也可以手動載入（效果相同）：
```tcl
xsdb% cd C:/reg_runtime                      ;# Windows 路徑請用 /
xsdb% source reg_rt.tcl
xsdb% reg_connect                            ;# 連 localhost:3121，選 APU target
xsdb% reg_list                               ;# 列出全部暫存器目前值
xsdb% reg_set agc_target_power -40           ;# 以物理單位寫入 (dBm)
xsdb% reg_get agc_target_power               ;# 讀回 -> -40
xsdb% reg_set digital_apply_delay 30
xsdb% reg_list agc_rx_*                      ;# 只列出名稱符合的
xsdb% reg_info dac_output_ref_dbm            ;# 查位址 / 格式 / 說明
xsdb% exit
```

**第一次連線必做的確認：**
- `reg_connect` 會先印出 target 清單，接著讀 `agc_reg5` 與 `power_limit_margin`。
- 如果 PS 沒改過這兩個暫存器，讀回應該是 `0x80` 與 `0x3`（reset 值）。
- 能讀到合理的值，就代表 JTAG → AXI → reg map 這條路徑是通的。

### 3.4 批次模式（一次套用一組設定，例如 10 個暫存器）
**設定檔只會寫它列出的暫存器，沒列出的完全不會碰。**

1. 建立設定檔，兩種方式擇一：
   - 複製 `reg_template.tcl`，只把要改的那幾行拿掉 `#`、填值，例如只改 FIR 就只開 17 行。
   - 從零開始寫，一行一個指令，例如 `fir_ch1_example.tcl`。
   - 要改 ch3，在檔案開頭加 `reg_ch 3`。
2. 先離線檢查：`xsdb reg_rt.tcl sim my_cfg.tcl`。
3. 上板執行：`xsdb reg_rt.tcl run my_cfg.tcl`。

每一行都會印出寫入值並讀回比對。任何一行失敗會停在該行，並顯示檔名與行號。

### 3.5 備份與還原
```bash
xsdb reg_rt.tcl save before_test.tcl   # 把目前所有暫存器 (system + 目前通道) 存成設定檔 (v7 叫 dump)
xsdb reg_rt.tcl run  before_test.tcl   # 之後要還原時執行
xsdb reg_rt.tcl list                   # 只看目前值
```

還原時依序寫回（system 先，再 mem0 → mem38，最後 RX ch7 rx0~6），過程中會出現中間狀態。建議在不量測時執行。

### 3.6 狀態 snapshot（v8 新增）
```bash
xsdb reg_rt.tcl status all             # 批次: 連線後 ch1 + ch3 + rx ch7 snapshot 並印出
```
互動模式下直接打 `reg_dump`（目前通道）、`reg_dump 3`、`reg_dump 7`（RX ch7）或 `reg_dump all`：
- 硬體在同一拍鎖存 `power_amp`、`gain_index_power_fit`、`goal_db`、`goal_rel_db`、`gain_index_tx` 與 RFDC flag（over_threshold1/2、over_range、over_voltage），再讀出來換成實際單位。
- 同時印出當下的主要設定（mode、margin、CW goal、TX power mode、goal_ref、dac_ref、target）。
- 結果寫成 `reg_status_<日期時間>.txt`，並附加一行到 `reg_status_<日期>.csv`（同一天的結果累積在同一個 CSV，可用 Excel 比較）。
- RX ch7（`reg_dump 7`）：鎖存 `st_rx_att_state`（目前 RX 衰減檔位，×10 dB）、RFDC flag、`st_rxagc_stable`、`st_rx_agc_enable`（RXAGC 是否在跑），另存在 `reg_rx_status_<日期>.csv`。
- `reg_version` 讀 build 號（sys14），例如 `14` = `calibration_gain_control_14`。

## 4. 指令一覽

| 指令 | 說明 | 範例 |
|---|---|---|
| `reg_connect ?url? ?target?` | 連 hw_server 並選 target | `reg_connect`、`reg_connect TCP:192.168.1.20:3121` |
| `reg_ch <1\|3>` | 切換通道（之後的指令都作用在該通道） | `reg_ch 3` |
| `reg_fir_tap <t> <I> <Q>` | FIR tap t（0~15），I / Q 為 signed 16-bit，自動打包成 [15:0] I、[31:16] Q | `reg_fir_tap 7 16384 0` |
| `reg_template <file>` | 重新產生全部暫存器範本 | `xsdb reg_rt.tcl template my_all.tcl` |
| `reg_set <name> <value>` | 以物理單位寫入，自動換算、檢查範圍、讀回確認 | `reg_set gain_index_rf_freq_offset -3.5` |
| `reg_get <name>` | 讀物理值 | `reg_get dac_output_ref_dbm` |
| `reg_wr <name> <raw>` | 直接寫 raw 值 | `reg_wr agc_reg5 0x50` |
| `reg_rd <name>` | 讀 raw 值（hex） | `reg_rd agc_reg5` |
| `reg_pulse <name> <raw>` | 寫入後立刻清 0（正緣觸發用） | `reg_pulse agc_bypass_sr_update 0x3` |
| `reg_list ?pattern?` | 列出暫存器，名稱可用 `*` | `reg_list gain_index_*` |
| `reg_info <name>` | 位址 / 格式 / reset / 說明 | `reg_info agc_linear_mode_offset` |
| `reg_run <file>` | 執行設定檔 | `reg_run my_cfg.tcl` |
| `reg_save <file>` | 目前值（system + 目前通道 + RX ch7）存成設定檔（v7 的 `reg_dump <file>`） | `reg_save backup.tcl` |
| `reg_dump ?1\|3\|7\|all? ?csv?` | 狀態 snapshot 並印出 / 存成 txt + CSV（7 = RX ch7） | `reg_dump all` |
| `reg_version` | 讀 build 號 | `reg_version` |
| `reg_sim` | 切到離線模擬（不碰硬體） | |

**單位：**
- `reg_set` 用的單位：dB、dBFS、dBm、clk（v8 起 goal 都改用 dBFS）。
- 1/16 dB 格式（S6.4、S4.4、S3.4、S7.4）直接寫小數，例如 `-3.5`、`0.5`。不是 1/16 整數倍的值會四捨五入，並提示實際寫入的值。
- 只有 raw 意義的暫存器用 `reg_wr`：`agc_reg5`、`phase_offset` 等。FIR 係數建議用 `reg_fir_tap`。

## 5. 設定檔寫法

設定檔就是上面的指令，一行一個，`#` 開頭為註解，行尾註解用 `;#`：

```tcl
# 先改參數
reg_set dac_output_ref_dbm      -25
reg_set agc_manual_mode_offset  0
reg_set agc_target_power        -40
# 最後才切 mode
reg_set agc_tx_power_mode       1      ;# 1: Manual
```

## 6. 注意事項

1. **每寫一個暫存器就立即生效**，兩筆之間約有 ms 等級的間隔。寫入順序就是生效順序，不會亂序。但中間會有幾 ms 是「部分新值、部分舊值」的狀態，硬體也會照這個狀態動作，例如類比衰減器可能會切換。
   - 建議：先改參數，最後才切 mode 或 enable（如 `agc_tx_power_mode`、`agc_manual_tx_att_en`、`gain_index_mode_sel`）。
2. **`agc_bypass_agc = 1` 不等於「凍結」。** bypass 期間類比衰減器維持原狀，不會重送 SR；但數位 gain 會立刻改成 pf，原本由數位補的 R（0 ~ 4.94 dB）會被拿掉，輸出會跳高最多約 4.94 dB。不要拿 bypass 當作「改參數時保持輸出不變」的手段。
3. **PS 程式會覆蓋**：如果 PS 之後又寫同一個暫存器，你的值會被蓋掉。目前 PS 只在開機寫一次，所以沒問題。
4. **觸發型暫存器**：`agc_bypass_sr_update` / `rx_bypass_sr_update` 是正緣觸發，請用 `reg_pulse`（寫 1 再寫 0）。只用 `reg_set` 寫 1 的話，下一次寫 1 不會產生新的正緣。
5. **硬體有效範圍**：有些暫存器格式上能寫，但硬體會再限制，例如 `dac_output_ref_dbm` 只認 +10 ~ −40 dBm、`agc_sr_update_period` 最小 50。超出時腳本會照寫，但會印出 `WARNING` 和硬體實際的行為。
6. **讀回比對**：每次 `reg_set` / `reg_wr` 寫完都會讀回比對，不一致時會報錯。可能原因：PS 同時也在寫、位址錯誤，或 XSA 版本不對。
7. **版本對應**：reg map 改版（位址或格式變更）時，要同步修改 `reg_rt.tcl` 的 `::reg::def` 表；通道 base address 改變時修改 `::reg::CH_BASE`。目前對應 RegMap v8 / XSA _14；`::reg::def` 表依 `doc/tools/regmap_def.py` 更新，system base 在 `::reg::SYS_BASE`，RX ch7 base 在 `::reg::RX_BASE`。
9. **`reg_run` 會改變目前通道**：設定檔裡的 `reg_ch` 在執行完後仍然有效，例如跑完 `fir_ch1_example.tcl` 會停在 ch1。之後在互動模式下單顆指令前，留意目前是哪個通道（`reg_connect` / `reg_ch` 會印出來）。
8. **改 FIR 係數**：16 個 tap 是逐顆寫入，寫到一半時 FIR 會用新舊混合的係數。範例 `fir_ch1_example.tcl` 先把 `in_band_fir_enable` 寫 0（輸出改走 impulse response），係數寫完再寫 1。

## 7. 疑難排解

| 現象 | 處理方式 |
|---|---|
| `reg_connect` 連不上 | 先另開一個視窗執行 `hw_server`，再重試；檢查 USB 線與 cable driver；Vivado Hardware Manager 能看到板子代表 JTAG 正常 |
| target 選不到 / 讀寫失敗 | 在 xsdb 打 `targets` 看清單，改用 `reg_connect "" "*PSU*"`；或設定環境變數 `REG_TARGET` |
| 讀寫出現 memory / bus error | PL 尚未載入 bitstream，或 PS 尚未開好 AXI 時鐘；請等 PS 開機完成再試 |
| 讀回值與寫入不同 | 見第 6 節第 6 點 |
| 遠端連線：xsdb 裝在另一台電腦 | 筆電執行 `hw_server`，另一台執行 `reg_connect TCP:<筆電IP>:3121`（或設定 `REG_HW_URL`）；注意防火牆需開放 3121 port |

> 本腳本的換算、範圍檢查、設定檔流程已用離線模擬模式測過；實機的 JTAG 讀寫（`mwr` / `mrd`）尚未上板驗證。第一次使用請照 3.3 先做讀取確認。
