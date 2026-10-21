# RFSoC_RX（z1）— 設計筆記

- 專案：`RFSoC_RX/hardware/RFSoC_RX.xpr` · Vivado 2025.2 · part `xczu47dr-ffvg1517-2-i` · top `design_1_wrapper`
- 來源：同事 PJ22045_1R8T rev0.12 release 的 `source/47dr1`（z1），複製到暫存區後以 Save Project As 建立本專案（2026-10-15），只修改 RFDC NCO
- 同事原專案的來源：`~/Desktop/PJ22045_EV1/47DR_integrated_3`（part 由 `-2-e` 改成 `-2-i`，IP 全部升級）
- GT 腳位參考：`~/Desktop/board_test_item/test_item_47dr/project/ibert_47dr1To13p_ex`（唯讀）
- IP repo：`hardware/ip_repo/`（由 rev0.12 release 複製，專案內相對路徑）
- 本筆記改寫自同事的 `docs/reference_rev0.12/DESIGN_NOTES_47dr1.md`；Rex 版的文件見 `docs/03_RFSoC_RX/`

## 系統中的角色

z1 是**發送端**：ADC 00（tile 0，m00 / m01）的 160-bit AXIS 經一條 2-lane Aurora 送到 VU13P，VU13P 再廣播成 8 條 link 送往 z2。

```
RFDC m00/m01（ADC tile0 ch0）→ axi_stream_combininp_adc00（160 b）→ axis_packetizer_0
   → aurora_gty_47drto13p_0/S_AXIS_X0Y1_C1 → hier_tx_x0y1/tx_c1（header_insertion）→ hier_x0y1/aurora_x0y1_1（X0Y6-7）→ VU13P X1Y8 core1
```

### ADC → DAC 對應（z1）

| ADC ch（I/Q） | Combiner（2 × 80 → 160 b） | 去向 |
|---|---|---|
| 00（m00/m01） | axi_stream_combininp_adc00 | Aurora → VU13P（沒有 DAC；s00 未使用） |
| 02（m02/m03） | axi_stream_combininp_adc02 | DAC s02 |
| 10（m10/m11） | axi_stream_combininp_adc10 | DAC s10 |
| 12（m12/m13） | axi_stream_combininp_adc12 | DAC s12 |
| 20（m20/m21） | axi_stream_combininp_adc20 | DAC s20 |
| 22（m22/m23） | axi_stream_combininp_adc22 | DAC s22 |
| 30（m30/m31） | axi_stream_combininp_adc30 | DAC s30 |
| 32（m32/m33） | axi_stream_combininp_adc32 | DAC s32 |

所有 combiner 與 RFDC AXIS 都在 FPGA_clk（256 MHz，`util_ds_buf_0`）。z1 不使用 Aurora RX 輸出。

## v1.0.0_Debug7：可以放在 z1 或 z2（2026-10-17）

本專案在 v1.0.0_Debug7 **沒有修改**（PL、PS、BOOT.bin 都和 v1.0.0 逐檔相同）。v1.0.0_Debug7 的 VU13P 支援雙向，所以 RFSoC_RX 放在 z1 或 z2 都可以：

| 放在 | ADC 00 的去向（X0Y1 core1，lanes X0Y6-7） | VU13P |
|---|---|---|
| z1（47dr1，正常） | VU13P X1Y8 core1 | axis_broadcaster_0 → z2 |
| z2（47dr2，交換） | VU13P X1Y4 core1 | axis_broadcaster_1 → z1 |

可以這樣放的依據：RX / TX 的 GT / refclk 腳位相同；RFSoC_RX 只驅動 `S_AXIS_X0Y1_C1`；PS 的 IIC 指令集和 BMC 的 MTS 流程都沒有區分角色。詳見 `06_Debug7_VU13P_Bidirectional/`。

## Aurora 64B66B 核心（8 × 2-lane，25.625 Gbps，各 quad 自己的 MGTREFCLK0 156.25 MHz）

Container BD `aurora_gty_47drto13p.bd` 與 z2 相同。每個 quad（N = 1~4）在頂層有 `hier_x0yN`（2 core）、`hier_tx_x0yN`（FIFO + header_insertion）、`hier_rx_x0yN`（header_extraction + FIFO）。

| Hierarchy | Quad（bank） | core0 lanes | core1 lanes | 對端（VU13P） | z1 的用途 |
|---|---|---|---|---|---|
| hier_x0y1 | X0Y1（128） | X0Y4-5 | X0Y6-7 | X1Y8（228） | core1 TX = ADC ch00；RX 未使用 |
| hier_x0y2 | X0Y2（129） | X0Y8-9 | X0Y10-11 | X1Y9（229） | 只有 link |
| hier_x0y3 | X0Y3（130） | X0Y12-13 | X0Y14-15 | X1Y10（230） | 只有 link |
| hier_x0y4 | X0Y4（131） | X0Y16-17 | X0Y18-19 | X1Y11（231） | 只有 link |

## Refclk 腳位（`constrs_1/imports/new/design.xdc`，來自 golden ibert_47dr1To13p）

| Port | Quad | P / N |
|---|---|---|
| gt_x0y1_diff_ref | 128 | AA33 / AA34 |
| gt_x0y2_diff_ref | 129 | W33 / W34 |
| gt_x0y3_diff_ref | 130 | U33 / U34 |
| gt_x0y4_diff_ref | 131 | P31 / P32 |

## 保留的原設計內容（來自 47DR_integrated_3）

PS（zynq_ultra_ps_e）、RFDC（ADC / DAC、MTS、sysref）、DMA_Ctrl、hier_mts、ILA / VIO。

## Rex rev0.1 的修改

| 項目 | rev0.12 47dr1 | RFSoC_RX |
|---|---|---|
| RFDC ADC NCO（00/02/10/12/20/22/30/32） | 0.84 GHz | **1.04 GHz**（與 RFSoC_TX 對齊，頻段 2.3 ~ 3.3 GHz） |
| RFDC DAC NCO（同上） | −0.84 GHz | **−1.04 GHz** |
| `onebit_cdc_fifo` | release 清理時遺失（impl 會 black box 失敗） | 補回（與 RFSoC_TX 同一份） |
| `design_1_wrapper` | release 沒有附 `.gen`，開專案時 top 會被自動改成 `daq_timing_ctrl` | build 腳本重新產生 wrapper 並設為 top（同同事 `build.tcl`） |
| ip_repo | `source/47dr1/ip_repo` | 複製到 `hardware/ip_repo` |
| 其他設計 | — | 與 rev0.12 47dr1 相同 |

修改腳本：`RFSoC_RX/hardware/scripts/rx_nco_onebit.tcl`；build：`RFSoC_RX/hardware/scripts/build_full_xsa.tcl <idx>`。
RFDC 細節見 `docs/03_RFSoC_RX/RFDC_Configuration.md`，頂層架構見 `docs/03_RFSoC_RX/RFSoC_RX_Top_Architecture.md`。

## 同事版本移除的內容（rev0.12 前）

- X0Y1 第二條 TX 路徑（pulse generator → core1）、x0y2 的 data_pg / data_valider。
- `hier_0` pulse generator（GUI 刪除）、`hier_tx_x0y1` 打散（packetizer 放到頂層）。
- **PARAM_RECORDER**（BDC + `axi_gpio_param_trigger`、`axi_gpio_param_length`、`xpm_cdc_gen_2`、`axis_broadcaster_0`）；PS S_AXI_HP0/HP1 關閉；`smartconnect_0` NUM_MI 8 → 5。
- **phase_calibration_0/1**。
- `vio_pma_rst`、`vio_arestn`、`axis_packetizer_1`、`ila_1`、`system_ila_0`、`hier_rx_x0y1`（z1 不再使用 Aurora RX）等（GUI 修改）。
- 未使用的原始檔（D18）。⚠ 同時誤刪了 `onebit_cdc_fifo.xci`，Rex rev0.1 已補回。

## 命名規則（同事 2026-10-14，`scripts/naming/`）

與 RFSoC_TX 相同（見 `DESIGN_NOTES_RFSoC_TX.md`）。z1 頂層的 combiner 為 `axi_stream_combininp_adcXY`，RF port `vout02/10/12/20/22/30/32` 對應同編號 DAC。

## 待確認

- Lane 直連 VU13P 的假設（同事）。
- RFSoC_RX 這一版沒有 PS 程式，RFDC / MTS 開機流程依同事原本方式。
- NCO 必須與 RFSoC_TX 一致，不要與舊版 z1（0.84 GHz）混用。
- 尚未上板驗證。

## 歷程

同事（47dr1，節錄；完整英文版見 `docs/reference_rev0.12/DESIGN_NOTES_47dr1.md`）：

- **2026-10-13** 由 47DR_integrated_3 建立專案、IP repo 本地化、part 改 `-2-i`；保留 8 × 2-lane Aurora（X0Y1~X0Y4）；移除 PARAM_RECORDER、phase_calibration、pulse generator；Aurora TX 來源改成 ADC ch00（X0Y1 core1）；其餘 ADC 回送到同編號 DAC；container 結構統一。
- **2026-10-14** 確認 ADC link 維持 X0Y1 core1，VU13P broadcaster 改回 X1Y8 core1 對應。
- **2026-10-14** 端對端檢查與 RTL 模擬、全面命名整理、FIFO 深度與 budget 模擬、debug ILA（`system_ila_1` slot 1 = ADC combiner adc00）、MTS CDC 約束（D16）。
- **2026-10-14** Build #5：WNS +0.008 ns / WHS +0.010 ns；移除未使用原始檔（D18）；release rev0.11、rev0.12。

Rex rev0.1：

- **2026-10-15** 由 rev0.12 release `source/47dr1` 建立 `RFSoC_RX`（ip_repo 複製進專案）；RFDC NCO 改成 ADC 1.04 / DAC −1.04 GHz（與 RFSoC_TX 對齊）；補回 `onebit_cdc_fifo`；重新產生 `design_1_wrapper`。
- **2026-10-15** RFSoC_RX build 01：WNS +0.063 ns / WHS +0.010 ns，0 critical warning；用量與同事 z1 相同。
- **2026-10-16** 中文設計文件（本筆記與 `docs/03_RFSoC_RX/`）。

v1.0.0_Debug7：

- **2026-10-17** 本專案沒有修改；VU13P 改成雙向之後，可以放在 z1 或 z2（見上方「v1.0.0_Debug7」一節）。
