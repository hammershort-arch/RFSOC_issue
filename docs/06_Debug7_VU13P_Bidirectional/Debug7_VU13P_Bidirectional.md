# v1.0.0_Debug7 — VU13P 雙向（z1 ⇄ z2）

- Release：`PJ22045_Release/v1.0.0_Debug7`；開發 / build 是在 `PJ22045_Release_Debug/Debug_007_VU13P_bidirectional` 做的
- 本文件的路徑以 `source_code_v1.0.0_Debug7/VU13P/` 為準

- 日期：2026-10-17
- 基準：`PJ22045_Release/v1.0.0/source_code_v1.0.0/VU13P`（與同事 rev0.12 release `source/vu13p` 完全相同；baseline 報告 = rev0.12 `reports/vu13p/`，build #6）
- 需求（Rex）：同事版本只支援 z1 → VU13P → z2，改成 **z1 → VU13P → z2 與 z2 → VU13P → z1 都支援**，用來測試 z1 = RFSoC_TX（8CH）、z2 = RFSoC_RX 時，透過外部時鐘板做 remote MTS 是否成功（之前的 swap 實驗 Aurora 沒有資料，是干擾因素）
- 範圍（Rex 確認）：**只改 VU13P**；RFSoC_RX / RFSoC_TX 沿用 v1.0.0（PL / PS / BOOT.bin 都不改；release 內的 RX / TX / BMC 與 v1.0.0 逐檔相同）
- 結果：timing 收斂（**WNS +0.006 / WHS +0.010 ns**），bitstream + ltx 已產生；交換配置 Multi-board MTS **10 / 10 成功**（§4.1）

## 1. 為什麼 RX / TX 不用改

| 檢查項目 | 結果（依據） |
|---|---|
| 腳位 | RX / TX 的 `design.xdc` 只差一行註解，GT / refclk 腳位相同（`05_Diff_TX_vs_RX`） |
| RFSoC_RX 的 Aurora | 只有 `S_AXIS_X0Y1_C1` ← `axis_packetizer_0`，沒有用到任何 `M_AXIS`（design_1.bd） |
| RFSoC_TX 的 Aurora | 8 個 `M_AXIS_X0Y1~4_C0/C1` → `hier_rx_x0y1~4`，**沒有任何 `S_AXIS`**（TX 不送 Aurora 資料，tvalid = 0） |
| PS app | RX / TX 的 IIC 指令集（BOOT / RFDC_INIT / RESET_DC / MTS_EXEC / MBS_PREP / PL_RESET_HOLD / RELEASE）相同，沒有寫死 z1 / z2 |
| BMC MTS 流程 | `hardware/mts/sync.go` 用 `forEachRFSoC` 對兩顆 RFSoC 執行相同步驟，不分角色 |
| PMA_RST | 兩邊都由各自的 `axi_gpio_pma_rst` 驅動，接法相同 |

所以 RFSoC 放在哪個位置，只決定它的 Aurora 接到 VU13P 的哪幾個 quad：z1 ↔ quad 228~231（X1Y8~11），z2 ↔ quad 224~227（X1Y4~7）。只要 VU13P 兩個方向都能轉送就可以。

## 2. VU13P 改動（`VU13P/scripts/debug007_bidir.tcl`）

```
原路徑（不動）：
  M_AXIS_X1Y8_C1（z1 X0Y1 core1）→ axis_slr_x1y8_to_tx → axis_broadcaster_0（1→8）→ S_AXIS_X1Y4_C0 … X1Y7_C1 → z2
新路徑（鏡像）：
  M_AXIS_X1Y4_C1（z2 X0Y1 core1）→ axis_slr_x1y4_to_z1 → axis_broadcaster_1（1→8）→ S_AXIS_X1Y8_C0 … X1Y11_C1 → z1
```

| 新增 cell | 設定（與原路徑相同） |
|---|---|
| `axis_slr_x1y4_to_z1` | axis_register_slice，REG_CONFIG 15（SLR crossing），NUM_SLR_CROSSINGS 1，PIPELINES_MASTER / SLAVE 1 |
| `axis_broadcaster_1` | NUM_MI 8，**HAS_TREADY 0**，16 byte tdata，TKEEP / TLAST |
| `ila_bcast_1` | system_ila，9 個 AXIS slot，1024 深；slot 0 = broadcaster 輸入（z2 來的資料），slot 1~8 = M00~M07（送 z1） |

- 時脈 `clk_wiz_0/clk_out1`（400 MHz）、reset `util_vector_logic_0/Res`，跟原路徑相同。
- **不需要方向選擇**：兩組 broadcaster 都沒有 tready，哪一顆板子放 RFSoC_RX，那一側的 core1 才有資料；另一組 broadcaster 沒有輸入（tvalid = 0），就保持閒置。所以同一個 bitstream 正常配置和交換配置都可以用。
- broadcaster M0x 對應 quad 的順序和原路徑相同：M00/M01 → X1Y8 C0/C1，M02/M03 → X1Y9，M04/M05 → X1Y10，M06/M07 → X1Y11。
- Container（`aurora_gty_vu13pto47dr.bd`）沒有修改，只是接上本來就存在、但沒有接的 port。BD validate 沒有 critical warning；16 條連線已用腳本讀回確認（腳本會印出 `CONN` 行；log 在 Debug_007 資料夾）。

### 2.1 dbg_hub 時脈（`target.xdc`，Rex 同意後修改）

第一次 build（try1）timing 失敗：**WNS −0.188 ns，83 個 endpoint**，全部在 debug hub 的 XSDB 路徑上（dbg_hub → `ila_bcast_1`、`ila_x1y8`、`ila_x1y11` 等），資料路徑本身是通過的。原因是同事的 dbg_hub 用的是 Aurora x1y9 的 user_clk（約 400 MHz，clock `txoutclk_out[0]_14`），多加一個 ILA 之後，XSDB 路徑要跨 3 個 SLR。baseline 在同一個時脈上也只有 +0.011 ns。

修改內容（原設定保留成註解，原檔備份在 `scripts/target.xdc.orig`）：

```
set_property C_CLK_INPUT_FREQ_HZ 100000000 [get_debug_cores dbg_hub]                 # 原 300000000
connect_debug_port dbg_hub/clk [get_nets {aurora_gty_vu13p_rst_i/util_ds_buf_0_IBUF_OUT[0]}]   # 原 [get_nets clk]
```

順帶的好處：sys_clk 是一直在跑的時脈，**Aurora link 沒起來時，ILA / VIO 一樣可以連線**。原本 hub 掛在 x1y9 的 user_clk 上，那條 link 沒起來的話，所有 debug core 都連不上。
確認：sys_clk 的 endpoint 數從 10,797 增加到 67,504（XSDB 邏輯已經移到 sys_clk）。try1 的報告保留在 `VU13P/reports/try1_dbg_hub_aurora_clk/`（只放報告，bit 沒有放進 release）。

## 3. Build 結果（`VU13P/reports/`）

| 項目 | Baseline（rev0.12 build #6） | try1（dbg_hub 用 Aurora clk） | **Debug_007（最終）** |
|---|---|---|---|
| WNS / TNS | +0.011 / 0 | −0.188 / −7.534（83 endpoints） | **+0.006 / 0** |
| WHS | +0.010 | +0.010 | **+0.010** |
| 最差的 clock | txoutclk_out[0]_14（x1y9） | txoutclk_out[0]_14（dbg_hub） | clk_out1 400 MHz |
| LUT | 56,397（3.26%） | 58,483（3.38%） | 58,415（3.38%） |
| FF | 162,078（4.69%） | 161,941（4.69%） | 161,201（4.66%） |
| BRAM | 493.5（18.36%） | — | 483（17.97%） |
| Total on-chip power | （rev0.12 沒有 power 報告） | 31.585 W | **30.872 W**（dynamic 26.868 / static 4.004） |
| GT / refclk 位置 | golden | — | **與 baseline 完全相同**（`gt_placement.txt`） |
| DRC / methodology | PDCN-1569 ×3、RTSTAT-10 ×1；TIMING-4 / 27（原本就有的 clk_wiz） | — | 相同（XDCB-5 18 → 20） |

- 最差的 path（+0.006）：`axis_slr_x1y4_to_z1` 的 slr_slave 輸出 → `ila_bcast_1` probe（debug 用的路徑，不是資料路徑）。
- SLR 分布（`VU13P/reports/slr_placement.txt`）：`axis_slr_x1y4_to_z1` 跨在 SLR1（299）和 SLR2（766）之間，`link_x1y4` 全部在 SLR1、`link_x1y8` 全部在 SLR2，跟原路徑對稱。
- BRAM 比 baseline 少：ila_bcast_1 有增加 BRAM，但 dbg_hub 換了位置之後整體配置不同，兩邊合計反而比較少。這裡只描述數字，實際的分配請看 `utilization_hier.rpt`。

### 3.1 Build 時間

| 階段 | 時間 |
|---|---|
| try1 OOC（207 個 IP run，包含 Aurora × 40）+ synth_1 | 19:04:53 → 19:14:58，約 10 分鐘 |
| try1 impl_1 + bitstream | 19:14:58 → 19:37:27，約 22.5 分鐘 |
| 最終版 synth_1（OOC 沿用） | 19:56:17 → 19:57:14，約 1 分鐘 |
| 最終版 impl_1 + bitstream | 19:57:14 → 20:16:57，約 20 分鐘 |
| 最終版總時間（含報告） | 27 分鐘 |

第一次 build 失敗：腳本直接 launch 所有 OOC run，其中包含 xpr 裡同事刪掉 source 之後留下的空 fileset（例如 `Aurora_RST_RX_inst_*`），結果出現 `No Verilog or VHDL sources`。已經改成跟同事 build.tcl 一樣，只 launch synth_1（log 在 Debug_007 資料夾，沒有放進 release）。

## 4. 上板使用方式

| 組合 | z1（47DR1） | z2（47DR2） | VU13P | 資料方向 |
|---|---|---|---|---|
| 正常（回歸測試） | RFSoC_RX | RFSoC_TX 8ch | `VU13P_Debug_007.bit` | z1 ADC00 → X1Y8 C1 → broadcaster_0 → z2 8 DAC |
| **交換（本次目的）** | **RFSoC_TX 8ch** | **RFSoC_RX** | `VU13P_Debug_007.bit` | z2 ADC00 → X1Y4 C1 → broadcaster_1 → z1 8 DAC |

- RX / TX 的 BOOT.bin 用 v1.0.0 的 `BOOT_RX.bin` / `BOOT_TX.bin`。上板測試（§4.1）燒的是 Debug_003（`PJ22045_Release_Debug/Debug_003_RelPL_RFDC_debug_log`）：PL / bitstream 和 v1.0.0 相同，app 只多了 RFDC debug log，方便分析 PLL / MTS 狀態。
- z1 放 TX 時，通道對應跟 TX 文件一樣，以 quad 為準：`hier_x0y1`（← VU X1Y8）→ ch3 / ch4（s10 / s12），`hier_x0y2`（← X1Y9）→ ch1 / ch2，`hier_x0y3`（← X1Y10）→ ch5 / ch6，`hier_x0y4`（← X1Y11）→ ch7 / ch8。8 條 link 都是同一份 z2 ADC00 資料。
- ILA：交換配置看 `ila_bcast_1`（slot 0 = 從 z2 收到的資料），正常配置看 `ila_bcast`。現在 dbg_hub 用的是 sys_clk，Aurora 沒起來時也可以連 ILA，例如用 `ila_x1y4` 看 X1Y4 C1 有沒有收到資料。
- 建議順序：先跑正常配置確認沒有退化，再跑交換配置做 multi-board MTS（跟 Debug_003～005 一樣用 `tools/sdr_capture.py` 記錄）。

## 4.1 上板結果（2026-10-17 20:40～20:44，.41）

| 項目 | 結果 |
|---|---|
| 配置 | 交換：Z1 = `BOOT_TX_Debug_003.bin`（TX 8ch）、Z2 = `BOOT_RX_Debug_003.bin`、VU13P = `VU13P_Debug_007`（開機策略 ALWAYS Debug_007） |
| Multi-board MTS | **10 / 10 成功**（S0～S5 全部 success，每次約 18 s） |
| RFDC 開機 PLL | 兩顆 8 個 tile 全部 `pll_lock_api=LOCKED`（10 / 10）；UNLOCKED 只在 post_shutdown 和已知的 ADC1 state 3 |
| SysRef period | 20 次都是 480 / 480 |
| DAC latency | 636～660 |
| VU13P VCCINT（中位數） | 4.67 / 2.50 / 4.97 / 2.87 A（舊 VU13P 的交換實驗 F：2.70 / 0.52 / 2.88 / 0.56 A） |

- Aurora 是否實際把 Z2 的資料送到 Z1，**還沒有用 ILA 確認**（VU13P 電流變大可能是新 bitstream 本身的邏輯造成，不能當證據）。
- 原始資料：`PJ22045_Release_Debug/experiments/G_Debug007_swap_Z1TX_Z2RX/`；紀錄：`PJ22045_Release_Debug/Debug_007_VU13P_bidirectional/test_results/Debug_007_Test_Log.md`。

## 5. 待確認 / 限制

- 交換配置已上板（§4.1）；正常配置還沒有在 Debug_007 上測試。
- X1Y4 core1 的 RX 方向（z2 → VU13P）跟 v1.0.0 已經在用的 VU13P → z2 方向用的是同一對 lane。Aurora 64B66B 是 duplex，channel_up 需要兩個方向都通，所以 v1.0.0 這條 link 能 channel_up，就表示 RX 方向的 lane 是通的。但「z2 RX 的 ADC00 經由這條 link 送出」這件事本身還沒有實測。
- VU13P 的 `pma_rst` 輸入接的是哪一顆 RFSoC，目前還不知道（兩顆的 PS 對 PL_RESET 指令的動作相同，所以交換後應該不影響）。
- timing 餘裕只有 +0.006 ns（最差在 ILA probe）；如果之後要拿掉 ILA 或改設定，要重新確認。

## 6. 資料夾

| 路徑 | 內容 |
|---|---|
| `VU13P/` | `source_code_v1.0.0_Debug7/VU13P/`：Vivado 專案（`vu13p.srcs` + `vu13p.xpr`，格式跟 v1.0.0 一樣，從 xpr 開啟，top = `aurora_gty_vu13p_rst_wrapper`） |
| `VU13P/scripts/debug007_bidir.tcl` | BD 修改腳本 |
| `VU13P/scripts/build_vu13p.tcl` | build 腳本（同事 build.tcl 改成專案相對路徑，加 power / SLR 報告、分段計時、失敗重跑）：`cd VU13P; vivado -mode batch -source scripts/build_vu13p.tcl -tclargs <name> 8` |
| `VU13P/scripts/target.xdc.orig` | 修改前的 target.xdc |
| `VU13P/reports/` | timing / utilization / power / DRC / methodology / CDC / gt_placement / slr_placement |
| `VU13P/output_data/VU13P_Debug_007.bit` | sha256 `e917b322189dd0ad4bd7266505f5086816eef3cc2f58e578f683dfdc0f54e690` |
| `VU13P/output_data/VU13P_Debug_007.ltx` | sha256 `8c0a9facf10f05c29c8706fa88ed779ca46a252917519fcc6fecc23f41c740d0` |
