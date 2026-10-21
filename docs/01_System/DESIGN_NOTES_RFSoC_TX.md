# RFSoC_TX（z2）— 設計筆記

- 專案：`RFSoC_TX/hardware/RFSoC_TX.xpr` · Vivado 2025.2 · part `xczu47dr-ffvg1517-2-i` · top `design_1_wrapper`
- 來源：同事 PJ22045_1R8T rev0.12 的 `47dr2`（z2），整合 Rex 的 Calibration_Gain_Control（8 通道 Calibration / Gain Control），再以 Save Project As 搬到本專案（2026-10-15）
- 同事原專案的來源：`~/Desktop/PJ22045_EV1/47DR_integrated_3`（part 由 `-2-e` 改成 `-2-i`，IP 全部升級）
- GT 腳位參考：`~/Desktop/board_test_item/test_item_47dr/project/ibert_47dr2To13p_ex`（唯讀）
- IP repo：`hardware/ip_repo/`（由 rev0.12 release 複製，專案內相對路徑）
- 本筆記改寫自同事的 `docs/reference_rev0.12/DESIGN_NOTES_47dr2.md`；Rex 版的詳細設計見 `docs/02_RFSoC_TX/`

## 系統中的角色

z2 是**接收端**：從 VU13P 收 8 條 2-lane Aurora（每條都是 VU13P 廣播的同一份 z1 ADC 00 資料），每條驅動一個 RFSoC DAC 通道。Rex 版在每個通道加上 `cal_plus_gain_control_chN`（訊號來源選擇、calibration、gain control）。

```
VU13P X1Y4..X1Y7 ─► Aurora core ─► header_extraction（container）─► hier_rx_x0yN（delay → FIFO → aligner）
                                                                  ─► cal_plus_gain_control_chN（in_0）─► DAC
本板 ADC chN ─► rfdc_iq_combine_chN ─────────────────────────────► cal_plus_gain_control_chN（in_1）
```

## v1.0.0_Debug7：可以放在 z1 或 z2（2026-10-17）

本專案在 v1.0.0_Debug7 **沒有修改**（PL、PS、BOOT.bin 都和 v1.0.0 逐檔相同）。v1.0.0_Debug7 的 VU13P 支援雙向，所以 RFSoC_TX 放在 z1 或 z2 都可以。RFSoC_TX 不驅動任何 Aurora `S_AXIS`，所以不會往 VU13P 送資料。

| 放在 | 對端 VU13P quad（hier_x0y1 / x0y2 / x0y3 / x0y4） | 資料來源 |
|---|---|---|
| z2（47dr2，正常） | X1Y4 / X1Y5 / X1Y6 / X1Y7 | axis_broadcaster_0（z1 ADC 00） |
| z1（47dr1，交換） | X1Y8 / X1Y9 / X1Y10 / X1Y11 | axis_broadcaster_1（z2 ADC 00） |

通道 / DAC 對應以本板的 quad 為準，兩種位置都一樣（hier_x0y1 → ch3 / ch4（s10 / s12），x0y2 → ch1 / ch2，x0y3 → ch5 / ch6，x0y4 → ch7 / ch8），8 條 link 都是同一份資料。詳見 `06_Debug7_VU13P_Bidirectional/`。

## Aurora 64B66B 核心（8 × 2-lane，25.625 Gbps，各 quad 自己的 MGTREFCLK0 156.25 MHz）

| Hierarchy | Quad（bank） | core0 / core1 lanes | 對端（VU13P） | 接收鏈 | 通道（core0 / core1） | DAC（core0 / core1） |
|---|---|---|---|---|---|---|
| hier_x0y1 | X0Y1（128） | X0Y4-5 / X0Y6-7 | X1Y4（224） | hier_rx_x0y1 | ch3 / ch4 | s10 / s12 |
| hier_x0y2 | X0Y2（129） | X0Y8-9 / X0Y10-11 | X1Y5（225） | hier_rx_x0y2 | ch1 / ch2 | s00 / s02 |
| hier_x0y3 | X0Y3（130） | X0Y12-13 / X0Y14-15 | X1Y6（226） | hier_rx_x0y3 | ch5 / ch6 | s20 / s22 |
| hier_x0y4 | X0Y4（131） | X0Y16-17 / X0Y18-19 | X1Y7（227） | hier_rx_x0y4 | ch7 / ch8 | s30 / s32 |

- 每個 quad 在頂層都有 `hier_x0yN` / `hier_tx_x0yN` / `hier_rx_x0yN`（container 內）。
- `hier_rx_x0y2~4` 是 `hier_rx_x0y1` 的複製（data_delay → axis_data_fifo → data_aligner，含 ILA）；共用 `delay`（`axi_delay`）、`timestamp`（`timer_1`），時脈 FPGA_clk 256 MHz。
- **注意**：`hier_rx_x0yN/M_AXIS_C0/C1` 在 BD 中是 Monitor mode（見下方「Rex rev0.1 的修改」）。

## Refclk 腳位（`constrs_1/imports/new/design.xdc`，來自 golden ibert_47dr2To13p）

| Port | Quad | P / N |
|---|---|---|
| gt_x0y1_diff_ref | 128 | AA33 / AA34 |
| gt_x0y2_diff_ref | 129 | W33 / W34 |
| gt_x0y3_diff_ref | 130 | U33 / U34 |
| gt_x0y4_diff_ref | 131 | P31 / P32 |

## 保留的原設計內容（來自 47DR_integrated_3）

PS、RFDC、DMA_Ctrl、hier_mts、ILA。DAC tile 3（s30 / s32）與 tile 2 相同：3.84 GSPS、outclk 240 MHz、data width 10（160-bit AXIS）、interpolation 3、fine mixer、inverse sinc 開。

## Rex rev0.1 的修改

| 項目 | 內容 | 詳細文件 |
|---|---|---|
| 8 通道 | `cal_plus_gain_control_ch1~8`（BD container，直接放在頂層）+ `rfdc_iq_combine_ch1~8` | `docs/02_RFSoC_TX/RFSoC_TX_Top_Architecture.md` |
| DAC 資料來源 | `hier_rx_x0yN` → 通道 in_0；通道 m_axis_iq → DAC（DAC 對應不變） | 同上 |
| ADC | 8 個 ADC 經 combiner 接到各通道 in_1；over_range / over_voltage / over_threshold1/2 與 clear_or / clear_ov 接到各通道 | `RFDC_Configuration.md` |
| Signal Source Mux | channel mem39：0 = Aurora、1 = 本板 ADC | `Calibration.md` |
| 暫存器 | `system_reg_map`（0xA009_8000）+ 8 × channel reg map（0xA009_0000 + 0x1000 × (N−1)）+ 8 × gain BRAM（0xA009_A000 + 0x2000 × (N−1)）；`smartconnect_0` NUM_MI 6 → 23 | `Register_Map.md` |
| RFDC | ADC0~3 Outclk 30 → 240 MHz；NCO ADC 0.84 → 1.04 GHz、DAC −0.84 → −1.04 GHz（2.3 ~ 3.3 GHz） | `RFDC_Configuration.md` |
| 外部輸入 | `vio_ext_inputs`（32 probe，暫時） | `Gain_Control.md`、`Power_Fit.md` |
| IP | 補回 `onebit_cdc_fifo`（release 清理時遺失） | `RFSoC_TX_Top_Architecture.md` §10.2 |
| XDC | `constrs_1/new/cal_plus_gain_control.xdc`（reg map → 資料時脈 false path） | `Register_Map.md` §7 |
| PS | Vitis `software/`（8 通道 reg map / BRAM / ADC threshold 初始化），BOOT.bin | `RFSoC_TX_Top_Architecture.md` §7 |
| 未修改 | Aurora container、`hier_rx_*`、`hier_mts`、`timer_1`、`axi_gpio_arstn` / `pma_rst`、`axi_delay`、`system_ila_0` | — |

**Monitor mode 的 hier pin**：同事的 `hier_rx_x0yN/M_AXIS_C0/C1` 在 BD 中是 Monitor mode（內部由 `data_aligner` 驅動）。直接接 IP 的 Slave port 沒問題；若把下游包成 hierarchy，Vivado 會把新 hier pin 推成 Monitor，HDL 中資料不會接上（validate 不報錯）。所以 8 個通道直接放在頂層。建議改成 Master。

## 同事版本移除的內容（rev0.12 前）

- ADC 回送到 DAC s00 / s02（`axi_stream_combininp_adc00/1` 輸出未使用）；x0y2 的 `data_valider` 檢查電路。
- **PARAM_RECORDER**（BDC + `axi_gpio_param_trigger`、`axi_gpio_param_length`、`xpm_cdc_gen_2`、`axis_broadcaster_0`）；PS S_AXI_HP0/HP1 關閉。
- **phase_calibration_0/1**：`hier_rx_x0y1/M_AXIS_C0/C1` 直接驅動 DAC s10 / s12。
- 未使用的 ADC 側（`axi_stream_combininp_0/1/2`）、頂層 `hier_tx_x0y1/x0y2`、`hier_0`、`vio_0`、`vio_arestn`、`vio_pma_rst`、`vio_data_delay` 等（2026-10-14 GUI 修改）。
- 未使用的原始檔（D18）：`aurora_gty_rst_47dr.bd`、PARAM_RECORDER / phase_calibration BD、約 40 個 RTL。⚠ 同時誤刪了 `onebit_cdc_fifo.xci`，Rex rev0.1 已補回。

## 腳本

| 腳本 | 用途 |
|---|---|
| `RFSoC_TX/hardware/scripts/build_and_boot.sh <idx>` | Vivado build → Vitis 更新 → 重編 app → bootgen → MANIFEST |
| `RFSoC_TX/hardware/scripts/build_full_xsa.tcl <idx>` | Vivado build（wrapper / BDC variant 檢查、失敗自動重跑） |
| 同事的腳本 | `reference_rev0.12` 對應的 release `source/scripts/`（`mod_47dr2.tcl`、`mod2~12`、`build.tcl`、`run_build.sh` 等），本專案不使用 |

Gotcha（同事記錄）：BD container 的子 BD 只新增 port 時，父 BD 不會自動更新，需要刪除 `.gen/.../bd/<container>_inst_N` 後重開。

## 命名規則（同事 2026-10-14，`scripts/naming/`）

名稱依其連接的對象（quad、Aurora core、方向）決定：

| 層級 | 名稱 |
|---|---|
| Container / 頂層 GT port | `GT_SERIAL_TX_<QUAD>_C<n>`、`GT_SERIAL_RX_<QUAD>_C<n>`（n = 該 quad 的 Aurora core 0 / 1） |
| Container 資料 port | `S_AXIS_<QUAD>_C<n>` → core n 的 TX，`M_AXIS_<QUAD>_C<n>` ← core n 的 RX |
| Refclk / 板上 port | 不變（`gt_<quad>_diff_ref`，XDC） |
| `hier_<quad>` pin | `GT_SERIAL_TX_C<n>`、`GT_SERIAL_RX_C<n>`、`S_AXIS_TX_C<n>`、`M_AXIS_RX_C<n>`、`GT_REFCLK`、`arstn_c<n>`、`pma_init`、`user_clk_out` |
| Wire | 依 driver 命名：`<cell>_<pin>` |
| Rex 新增 | `cal_plus_gain_control_chN`、`rfdc_iq_combine_chN`（N = 1~8，依輸出 DAC 順序）、net `s_axis_iq_in_0_N`、`reg_<暫存器名稱>`、`vio_ext_inputs_probe_outM` |

## 待確認

- Lane 直連 VU13P 的假設；DAC 通道對應（哪條 Aurora → 哪個 DAC）需依板子 / 類比需求確認（同事）。
- RFDC ADC Outclk 改成 240 MHz 對 `hier_mts` 的影響（Rex rev0.1）。
- `onebit_cdc_fifo` 補回的設定與 release 更新（Rex rev0.1）。
- `hier_rx_*` 的 `M_AXIS_C0/C1` 改成 Master（建議）。
- Gain Control 的 SR 腳位沒有拉到頂層：本版只驗證 IF 輸出端，TRM 相關功能（SR、TX / RX 模式、RXAGC）待 TRM 板上線後處理；VIO 是暫時的輸入來源。
- Timing 餘裕 0（最差在同事 `hier_rx_x0y1` 的 debug ILA；另有 Power Fit +0.003 ns、adc_clk `txagc_calc` +0.065 ns），建議下一版修正。
- 尚未上板驗證。
- 後續版本優化項目與 TRM 上線後處理項目見 `docs/02_RFSoC_TX/Follow_Up.md`。

## 歷程

同事（47dr2，節錄；完整英文版見 `docs/reference_rev0.12/DESIGN_NOTES_47dr2.md`）：

- **2026-10-13** 由 47DR_integrated_3 建立專案、IP repo 本地化、part 改 `-2-i`；container 擴充成 8 core、X0Y2~4 接收鏈、DAC 對應、DAC tile 3 比照 tile 2；移除 PARAM_RECORDER、phase_calibration；container 結構統一（四個 quad 時脈 / reset 接法相同）。
- **2026-10-14** 移除未使用的 ADC 側、各種 VIO；新增 `axi_delay`（0xA008_0000，預設 0x200，驅動四個 `hier_rx` 的 delay；需先釋放 arstn 才能寫入）。
- **2026-10-14** 端對端檢查（BD 追蹤 + RTL 模擬）：每個 sample 在 z1 timestamp 後 `delay + 1` 拍準時輸出；限制：delay − link latency < 約 1000、掉 1 個封包會錯位到 reset、z1 / z2 的 FPGA_clk 需同源並在同一個 SYSREF 前釋放 arstn。
- **2026-10-14** 全面命名整理、FIFO 深度檢查與 FIFO budget 模擬（link 負載約 82.6%）、debug ILA、MTS CDC 約束（D16）。
- **2026-10-14** Build #5：WNS +0.023 ns / WHS +0.010 ns；移除未使用原始檔（D18）；release rev0.11、rev0.12。

Rex rev0.1：

- **2026-10-14** Calibration_Gain_Control 加入 Signal Source Mux（mem39）；8 個 `cal_plus_gain_control` + `system_reg_map` 整合到 rev0.12_dev（47dr2 副本）；補回 `onebit_cdc_fifo`；RFDC ADC Outclk 30 → 240 MHz；VIO、RFDC flag 接線。
- **2026-10-14** build 01（包成 `hier_8CH`）：發現 Monitor mode hier pin 造成 Aurora 資料沒接進通道，**作廢**。
- **2026-10-15** 拆掉 `hier_8CH`，build 02（WNS +0.007 ns）；Vitis 8 通道 app、BOOT.bin；target Register map Excel。
- **2026-10-15** RFDC NCO 改成 1.04 / −1.04 GHz，build 03（WNS 0.000 ns）。
- **2026-10-15** 以 Save Project As 建立本專案 `RFSoC_TX`（ip_repo 複製進專案），RFSoC_TX build 01：WNS 0.000 / WHS +0.010 ns，與 build 03 結果相同；重建 Vitis、BOOT.bin。
- **2026-10-16** 中文設計文件（本筆記與 `docs/02_RFSoC_TX/`）。

v1.0.0_Debug7：

- **2026-10-17** 本專案沒有修改；VU13P 改成雙向之後，可以放在 z1 或 z2（見上方「v1.0.0_Debug7」一節）。
