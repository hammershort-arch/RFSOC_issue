# RFSoC_RX — Top Architecture

- 專案：PJ22045_1R8T_release_Rex_rev0.1_20261015 / RFSoC_RX（z1）
- Vivado 專案：`RFSoC_RX/hardware/RFSoC_RX.xpr`（Vivado 2025.2，xczu47dr-ffvg1517-2-i，top `design_1_wrapper`）
- 適用版本：RFSoC_RX build 01（2026-10-15），輸出 `RFSoC_RX/output_data/01/`（PL only）
- 來源：同事 PJ22045_1R8T rev0.12 的 47dr1（z1），只修改 RFDC NCO
- 文件版本：v0.1（2026-10-16）

## 1. 閱讀指引

| 想知道 | 看哪裡 |
|---|---|
| z1 在系統中的角色 | 第 2 節 |
| design_1 頂層架構 | 第 3 節 |
| ADC / DAC 的去向 | 第 4 節 |
| 時脈 | 第 5 節 |
| PS 位址表 | 第 6 節 |
| Build 結果 | 第 7 節 |
| 和同事 rev0.12 的差異 | 第 8 節 |
| 檔案與重新 build | 第 9 節 |

RFDC 細節見同目錄 `RFDC_Configuration.md`。Aurora 傳輸、封包與時間同步完全沿用同事設計，見 `docs/reference_rev0.12/SIGNAL_TRANSMISSION.md`、`TIMING_SYNC.md`，以及 `../../docs/DESIGN_NOTES_RFSoC_RX.md`。

## 2. 系統中的角色

```
RFSoC_RX (z1)  ADC 00 ──Aurora──► VU13P (廣播 1 → 8) ──8 條 Aurora──► RFSoC_TX (z2) ──► 8 個 DAC
```

RFSoC_RX（z1）是系統的**訊號源**：

- ADC 00（tile 0 第 1 個 ADC，m00 / m01）的資料加上 timestamp 封包後，經 X0Y1 core1（lanes X0Y6-7）的 Aurora 送到 VU13P X1Y8 core1，再由 VU13P 廣播到 z2 的 8 個通道。
- 其他 7 個 ADC 在本板回送到同編號的 DAC（loopback）。

## 3. 頂層架構

![RFSoC_RX design_1 頂層架構](fig/rx_top.png)

| 類別 | 模組（design_1） | 說明 |
|---|---|---|
| PS | `zynq_ultra_ps_e_0`、`rst_ps8_0_96M`、`smartconnect_0`、`axi_intc_0` | PS、AXI 互連 |
| RFDC | `usp_rf_data_converter_1` | 8 ADC + 8 DAC，3.84 GSPS（NCO 本版修改） |
| ADC 合併 | `axi_stream_combininp_adc00` ~ `adc32`（8 個） | ADC I + Q → 160-bit |
| 封包 | `axis_packetizer_0` | 加上 timestamp，送往 Aurora |
| Aurora | `aurora_gty_47drto13p_0`（BD container，與 z2 相同） | 4 quad × 2 core；z1 只用 X0Y1 core1 TX |
| 時間 / 同步 | `hier_mts`、`timer_1`、`pl_sysref_int_0`、`regs_4_sysref_0`、`sync_pulse_to_level_1`、`xpm_cdc_gen_0/1` | SYSREF、MTS、系統時間 |
| 控制 | `axi_gpio_arstn`、`axi_gpio_pma_rst`、`DMA_Ctrl`、`vio_data_delay` | Aurora reset 等 |
| 時脈 / reset | `util_ds_buf_0~3`、`dac_rst1` | FPGA_clk 256 MHz 等 |
| 除錯 | `system_ila_1`、`ilconcat_1`、`xlconstant_0` | 監看 ADC 與封包 |

除了 RFDC 的 NCO 參數與補回的 `onebit_cdc_fifo` IP，**設計與同事 rev0.12 的 47dr1 完全相同**。

## 4. ADC / DAC 去向

| ADC（I / Q） | Combiner | 去向 |
|---|---|---|
| 00（m00 / m01） | `axi_stream_combininp_adc00` | `axis_packetizer_0` → Aurora X0Y1 core1 → VU13P（DAC s00 未使用） |
| 02（m02 / m03） | `axi_stream_combininp_adc02` | DAC s02 |
| 10（m10 / m11） | `axi_stream_combininp_adc10` | DAC s10 |
| 12（m12 / m13） | `axi_stream_combininp_adc12` | DAC s12 |
| 20（m20 / m21） | `axi_stream_combininp_adc20` | DAC s20 |
| 22（m22 / m23） | `axi_stream_combininp_adc22` | DAC s22 |
| 30（m30 / m31） | `axi_stream_combininp_adc30` | DAC s30 |
| 32（m32 / m33） | `axi_stream_combininp_adc32` | DAC s32 |

## 5. 時脈

| 時脈 | 頻率 | 來源 | 使用者 |
|---|---|---|---|
| FPGA_clk | 256 MHz | `util_ds_buf_0/IBUF_OUT` | RFDC AXIS、combiner、packetizer |
| clk_adc0 | 30 MHz | RFDC ADC tile 0 outclk | `hier_mts` |
| clk_dac0 | 240 MHz | RFDC DAC tile 0 outclk | `hier_mts` |
| pl_clk0 | 100 MHz | PS | AXI-Lite |
| Aurora user_clk / txoutclk | — | GT | Aurora container 內部 |

ADC Outclk 維持同事的 30 MHz（RFSoC_RX 沒有 Gain Control，不需要 240 MHz）。

## 6. PS 位址表

| 位址 | 大小 | 模組 |
|---|---|---|
| 0xA000_0000 | 64 KB | `DMA_Ctrl/axi_lite_interface_0` |
| 0xA001_0000 | 64 KB | `axi_gpio_arstn` |
| 0xA002_0000 | 64 KB | `axi_gpio_pma_rst` |
| 0xA003_0000 | 64 KB | `axi_intc_0` |
| 0xA004_0000 | 256 KB | `usp_rf_data_converter_1`（RFDC） |

## 7. Build 結果（build 01）

| 項目 | 結果 |
|---|---|
| Timing | WNS +0.063 ns / WHS +0.010 ns，All user specified timing constraints are met |
| Critical warning | synth 0 / impl 0 |
| LUT / FF | 62,320（14.7%）/ 85,553（10.1%） |
| BRAM / DSP | 224.5 tile（20.8%）/ 0 |

| Clock | WNS (ns) | WHS (ns) |
|---|---|---|
| FPGA_clk（256 MHz） | +0.161 | +0.013 |
| clk_pl_0（100 MHz） | +1.610 | +0.012 |
| RFDAC0_CLK | +2.125 | +0.078 |

- 整體最差（+0.063 ns）在 Aurora 的 GT 時脈 group；FPGA_clk 最差是 RFDC ADC FIFO → `axi_stream_combininp_adc32`。
- 用量與同事 README 記錄的 z1（LUT 14.7% / FF 10.1% / BRAM 20.8%）相同。
- 輸出：`output_data/01/RFSoC_RX_01.bit / .ltx / .xsa`、`MANIFEST.txt`。

## 8. 與同事 rev0.12（47dr1）的差異

| 項目 | rev0.12 47dr1 | RFSoC_RX | 說明 |
|---|---|---|---|
| RFDC ADC NCO（00/02/10/12/20/22/30/32） | 0.84 GHz | **1.04 GHz** | 與 RFSoC_TX 對齊，頻段 2.3 ~ 3.3 GHz |
| RFDC DAC NCO（同上） | −0.84 GHz | **−1.04 GHz** | 同上 |
| `onebit_cdc_fifo` | release 中遺失（impl 會 black box 失敗） | 補回（與 RFSoC_TX 同一份） | `hier_mts/daq_timing_ctrl_0` 使用 |
| `design_1_wrapper` | release 沒有附 `.gen`，開啟專案時 top 會被自動換成 `daq_timing_ctrl` | build 腳本重新產生 wrapper 並設為 top | 同同事 `build.tcl` 的做法 |
| ip_repo | `source/47dr1/ip_repo` | 複製到 `hardware/ip_repo`（相對路徑） | 專案獨立 |
| 其他 | — | 相同 | — |

修改腳本：`hardware/scripts/rx_nco_onebit.tcl`。

## 9. 檔案與重新 build

```
RFSoC_RX/
├ hardware/RFSoC_RX.xpr          Vivado 專案（ip_repo 在 hardware/ip_repo）
├ hardware/scripts/
│   rx_nco_onebit.tcl            本版修改（NCO、onebit_cdc_fifo、ip_repo）
│   build_full_xsa.tcl <idx>     Vivado build（補 wrapper、失敗自動重跑）→ output_data/<idx>/
└ output_data/<idx>/             RFSoC_RX_<idx>.bit / .ltx / .xsa、MANIFEST.txt
（文件已移到 release 根目錄 docs/03_RFSoC_RX/：本文件、RFDC_Configuration）
```

重新 build（在 `RFSoC_RX/hardware/` 執行）：

```
vivado -mode batch -source scripts/build_full_xsa.tcl -tclargs 02
```

## 10. 待確認

1. RFSoC_RX 這一版沒有 PS 程式（Vitis），RFDC / MTS 開機流程依同事原本方式處理。
2. NCO 必須與 RFSoC_TX 一致；不要與舊版 z1（rev0.11 / rev0.12 release，0.84 GHz）混用。
3. 尚未上板驗證。

## 11. 修訂歷程

| 版本 | 日期 | 說明 |
|---|---|---|
| v0.1 | 2026-10-16 | 第一版，對應 RFSoC_RX build 01（NCO 1.04 / −1.04 GHz） |
