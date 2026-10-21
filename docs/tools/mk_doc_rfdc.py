#!/usr/bin/env python3
# =============================================================================
# mk_doc_rfdc.py  (2026-10-16)
#   docs/tools/rfdc_params_TX.txt / _RX.txt (由 rfdc_dump.tcl 從 Vivado 讀出) ->
#     docs/02_RFSoC_TX/RFDC_Configuration.md, docs/03_RFSoC_RX/RFDC_Configuration.md
#   參數代碼的意義取自 Vivado 2025.2 usp_rf_data_converter_v2_6/component.xml
#   Usage: python3 docs/tools/mk_doc_rfdc.py
# =============================================================================
import os, re
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))

MIX_MODE = {"ADC": {"0": "Real → I/Q", "1": "I/Q → I/Q", "2": "Real → Real"},
            "DAC": {"0": "I/Q → Real", "1": "I/Q → I/Q", "2": "Real → Real"}}
MIX_TYPE = {"0": "Bypassed", "1": "Coarse", "2": "Fine", "3": "Off"}
NYQ = {"0": "Zone 1", "1": "Zone 2"}
CLK_SRC = {str(i): f"Tile {224 + i}" for i in range(8)}
CLK_DIST = {"0": "Off", "1": "Input Refclk", "2": "PLL output"}
DAC_MODE = {"0": "DUC 0 ~ Fs/2", "1": "DUC 0 ~ Fs/4", "2": "DUC Fs/4 ~ Fs/2", "3": "No DUC 0 ~ Fs/2"}
DEC_MODE = {"0": "SNR Optimized", "1": "Linearity Optimized"}
TILE_NAME = {"ADC": {t: f"ADC Tile {224 + t}" for t in range(4)}, "DAC": {t: f"DAC Tile {228 + t}" for t in range(4)}}


def load(tag):
    P, CLK, AXIS, OCLK = {}, {}, {}, {}
    for line in open(os.path.join(HERE, f"rfdc_params_{tag}.txt")):
        f = line.split(None, 2)
        if len(f) < 3:
            continue
        kind, _, rest = f
        rest = rest.strip()
        if kind == "P":
            k, _, v = rest.partition("=")
            P[k.replace("CONFIG.", "")] = v
        elif kind == "CLK":
            m = re.match(r"(\S+) <- (\S*) FREQ=(\S*)", rest)
            CLK[m.group(1)] = (m.group(2), m.group(3))
        elif kind == "AXIS":
            m = re.match(r"(\S+) -> ?(.*)", rest)
            AXIS[m.group(1)] = m.group(2).strip()
        elif kind == "OCLK":
            m = re.match(r"(\S+) FREQ=(\S+) -> ?(.*)", rest)
            OCLK[m.group(1)] = (m.group(2), m.group(3).strip())
    return P, CLK, AXIS, OCLK


def tile_table(P, kind):
    s = ("| Tile | Enable | Sampling (GSPS) | Refclk (MHz) | PLL | Clock source | Clock distribution | Fabric (MHz) | Outclk (MHz) | MTS |\n"
         "|---|---|---|---|---|---|---|---|---|---|\n")
    for t in range(4):
        g = lambda k: P.get(f"{kind}{t}_{k}", "-")
        s += (f"| {TILE_NAME[kind][t]}（{kind.lower()}{t}） | {g('Enable')} | {g('Sampling_Rate')} | {g('Refclk_Freq')} | "
              f"{'On' if g('PLL_Enable') == 'true' else 'Off'} | {CLK_SRC.get(g('Clock_Source'), g('Clock_Source'))} | "
              f"{CLK_DIST.get(g('Clock_Dist'), g('Clock_Dist'))} | {g('Fabric_Freq')} | {g('Outclk_Freq')} | {g('Multi_Tile_Sync')} |\n")
    return s


def adc_table(P):
    s = ("| ADC | Data type | Mixer | Mixer mode | NCO (GHz) | Nyquist | Decimation | Data width（sample / clk） | AXIS |\n"
         "|---|---|---|---|---|---|---|---|---|\n")
    for t in range(4):
        for b in ("0", "2"):
            k = f"{t}{b}"
            g = lambda n: P.get(f"ADC_{n}{k}", "-")
            s += (f"| ADC {k} | {'I/Q' if g('Data_Type') == '1' else 'Real'} | {MIX_TYPE.get(g('Mixer_Type'), g('Mixer_Type'))} | "
                  f"{MIX_MODE['ADC'].get(g('Mixer_Mode'), g('Mixer_Mode'))} | {g('NCO_Freq')} | {NYQ.get(g('Nyquist'), g('Nyquist'))} | "
                  f"{g('Decimation_Mode')}x | {g('Data_Width')} | m{t}{b} (I) / m{t}{int(b) + 1} (Q) |\n")
    return s


def dac_table(P):
    s = ("| DAC | Mixer | Mixer mode | NCO (GHz) | Nyquist | Interpolation | Data width（16-bit word / clk） | Inverse sinc | Mode | Decoder |\n"
         "|---|---|---|---|---|---|---|---|---|---|\n")
    for t in range(4):
        for b in ("0", "2"):
            k = f"{t}{b}"
            g = lambda n: P.get(f"DAC_{n}{k}", "-")
            s += (f"| DAC {k}（s{k}） | {MIX_TYPE.get(g('Mixer_Type'), g('Mixer_Type'))} | {MIX_MODE['DAC'].get(g('Mixer_Mode'), g('Mixer_Mode'))} | "
                  f"{g('NCO_Freq')} | {NYQ.get(g('Nyquist'), g('Nyquist'))} | {g('Interpolation_Mode')}x | {g('Data_Width')} | "
                  f"{'On' if g('Invsinc_Ctrl') == 'true' else 'Off'} | {DAC_MODE.get(g('Mode'), g('Mode'))} | {DEC_MODE.get(g('Decoder_Mode'), g('Decoder_Mode'))} |\n")
    return s


def axis_table(AXIS, CLK):
    s = "| RFDC AXIS | 接到 |\n|---|---|\n"
    for k in sorted(AXIS, key=lambda x: (x[0] != "m", x)):
        s += f"| {k} | {('`' + AXIS[k] + '`') if AXIS[k] else '（未接）'} |\n"
    s += "\n| RFDC 時脈輸入 | 來源 | 頻率 |\n|---|---|---|\n"
    for k in ["m0_axis_aclk", "m1_axis_aclk", "m2_axis_aclk", "m3_axis_aclk", "s0_axis_aclk", "s1_axis_aclk", "s2_axis_aclk", "s3_axis_aclk", "s_axi_aclk"]:
        if k in CLK:
            src, f = CLK[k]
            s += f"| {k} | `{src.lstrip('/')}` | {float(f) / 1e6:.3f} MHz |\n"
    return s


def oclk_table(OCLK):
    s = "| RFDC 輸出時脈 | 頻率 | 使用者 |\n|---|---|---|\n"
    for k in sorted(OCLK):
        f, users = OCLK[k]
        s += f"| {k} | {float(f) / 1e6:.0f} MHz | {users.replace('/', '').replace(' ', '、') if users else '（未使用）'} |\n"
    return s


def nco_check(P):
    adc = sorted({P.get(f"ADC_NCO_Freq{t}{b}") for t in range(4) for b in "02"})
    dac = sorted({P.get(f"DAC_NCO_Freq{t}{b}") for t in range(4) for b in "02"})
    return adc, dac


COMMON_FREQ = """### {n}.1 RF 頻段與 NCO

ADC / DAC 取樣率都是 **3.84 GSPS**，Nyquist zone 都設在 **Zone 2**（1.92 ~ 3.84 GHz）。在 Zone 2 中，RF 頻率 f 會折到 3.84 − f：

| 項目 | rev0.12（同事原設定） | **Rex rev0.1（目前）** |
|---|---|---|
| ADC NCO | 0.84 GHz | **1.04 GHz** |
| DAC NCO | −0.84 GHz | **−1.04 GHz** |
| 對應 RF 中心頻率（3.84 GHz − NCO 絕對值） | 3.0 GHz | **2.8 GHz** |
| 使用頻段（中心 ± 0.5 GHz） | 2.5 ~ 3.5 GHz | **2.3 ~ 3.3 GHz** |

- ADC：Fine mixer，Real → I/Q，把 RF 降到基頻後 3x decimation，輸出 1.28 GSPS 的複數 I/Q（每 256 MHz 時脈 5 個 sample，I、Q 各一條 AXIS）。
- DAC：輸入 1.28 GSPS 複數 I/Q（每時脈 5 個 sample），3x interpolation 後 Fine mixer I/Q → Real 升頻，輸出到 Zone 2。
- NCO 的正負號（ADC +1.04、DAC −1.04）與 Zone 2 的頻譜反轉一起決定實際的 RF 位置與頻譜方向；目前設定與 Calibration_Gain_Control（source 板）相同。
- 本表的頻率換算是依 RFDC 設定推算，**尚未在板上量測確認**。
"""


def doc(tag, P, CLK, AXIS, OCLK):
    adc_nco, dac_nco = nco_check(P)
    if tag == "TX":
        title = "RFSoC_TX — RFDC Configuration"
        board = "RFSoC_TX（z2，接收 Aurora 並由 8 個 DAC 輸出）"
        proj = "`RFSoC_TX/hardware/RFSoC_TX.xpr`，build 01（2026-10-15）"
        role = """z2 的 RFDC 有兩個用途：

- **DAC（8 個，s00 ~ s32）**：輸出 8 個通道的 RF。每通道的資料來自 `cal_plus_gain_control_chN/m_axis_iq`（經 Signal Source Mux 選擇 Aurora 或本板 ADC，再經 calibration / gain control）。
- **ADC（8 個，m00 ~ m33）**：每個 ADC 的 I / Q 經 `rfdc_iq_combine_chN` 合併成 160-bit，接到 `cal_plus_gain_control_chN/s_axis_iq_in_1`（ADC loopback 來源）。ADC 的 over_range / over_voltage / over_threshold flag 給 RXAGC 使用。

```
ADC m{T}{0/2} (I) ─┐
ADC m{T}{1/3} (Q) ─┴─► rfdc_iq_combine_chN ─► cal_plus_gain_control_chN (in_1) ─┐
hier_rx_x0yN (Aurora) ─────────────────────────────► cal_plus_gain_control_chN (in_0) ─┴─► m_axis_iq ─► DAC s{T}{0/2}
RFDC clk_adcT (240 MHz) ─► cal_plus_gain_control_chN/adc_clk（AGC）
```"""
        diff = """| 項目 | rev0.12 47dr2（同事） | RFSoC_TX | 原因 |
|---|---|---|---|
| ADC0~3 Outclk（clk_adc0~3） | 30 MHz | **240 MHz** | clk_adcN 是 Gain Control（AGC）的 adc_clk，對齊 Calibration_Gain_Control 的設計（2026-10-14） |
| ADC NCO（8 組） | 0.84 GHz | **1.04 GHz** | 使用頻段改成 2.3 ~ 3.3 GHz（2026-10-15） |
| DAC NCO（8 組） | −0.84 GHz | **−1.04 GHz** | 同上 |
| ADC AXIS 用途 | m00/m01、m02/m03 經 combiner 後沒有使用 | 8 個 ADC 都經 `rfdc_iq_combine_chN` 接到各通道 in_1 | ADC loopback 路徑 |
| DAC AXIS 來源 | `hier_rx_x0yN` 直接接 DAC | `cal_plus_gain_control_chN/m_axis_iq` | 8 通道 calibration / gain control |
| ADC flag / clear | 未使用 | `adcT_01/23` 的 4 個 flag 與 clear_or / clear_ov 接到 chN | RXAGC |

`clk_adc0` 也驅動同事原有的 `hier_mts/sync_out_latch_1`（只是 latch，與頻率無關；請同事確認 MTS 流程不受影響）。"""
        ps = """PS 程式（`RFSoC_TX/software/app_component/src/sources/rfdc.c`、`main.c`，沿用 Calibration_Gain_Control）：

1. `rfdc_dev_init()`：XRFdc 初始化。
2. `adcInitThresh()`（`adcThresholds.c`）：8 個 ADC 都設定 threshold 0 / 1（chN = tile (N−1)/2、block (N−1)%2）：
   - threshold 0：hysteresis mode，avg 10，under 10950（−3.5 dBFS）/ over 11599（−3.0 dBFS）→ `over_threshold1`
   - threshold 1：hysteresis mode，avg 10，under 2750（−15.5 dBFS）/ over 2913（−15.0 dBFS）→ `over_threshold2`
3. `rfdc_reset_dc()`：依序 shutdown / startup 所有啟用的 ADC（順序 1, 0, 2, 3）與 DAC tile。
4. GPIO handshake（BMC）→ `rfdc_mts_exec()`：DAC / ADC 各做 multi-tile sync（tiles 0x0F）→ handshake。
5. `rfdc_mbs_prep()`：關閉 MTS sysref；DAC / ADC mixer、DAC QMC、DAC coarse delay 的 event source 改成 SYSREF，reset DAC NCO phase → handshake。

NCO 頻率使用 IP 中的設定，PS 不會改寫（只改 event source）。"""
        todo = """1. 頻段與頻譜方向（2.3 ~ 3.3 GHz）尚未在板上量測確認。
2. ADC Outclk 30 → 240 MHz 對同事 `hier_mts`（MTS / SYSREF）流程的影響，需和同事確認。
3. RFSoC_RX（z1）的 ADC NCO 已同步改成 1.04 GHz（Rex rev0.1）；舊版 z1（rev0.11 / rev0.12 release）仍是 0.84 GHz，兩者不能混用。"""
    else:
        title = "RFSoC_RX — RFDC Configuration"
        board = "RFSoC_RX（z1，ADC 訊號源，經 Aurora 送往 VU13P）"
        proj = "`RFSoC_RX/hardware/RFSoC_RX.xpr`，build 01（2026-10-15）"
        role = """z1 的 RFDC：

- **ADC 00（m00 / m01）**：系統的訊號源。經 `axi_stream_combininp_adc00` 合併成 160-bit → `axis_packetizer_0` → Aurora（X0Y1 core1）→ VU13P → 廣播到 z2 的 8 個通道。
- **其他 7 個 ADC（02 ~ 32）**：各自經 `axi_stream_combininp_adcXX` 回送到同編號的 DAC（本板 loopback）。
- **DAC 00（s00）沒有使用**（ADC 00 送到 Aurora）。

```
ADC m00/m01 ─► axi_stream_combininp_adc00 ─► axis_packetizer_0 ─► Aurora X0Y1 core1 ─► VU13P
ADC mXY / mX(Y+1) ─► axi_stream_combininp_adcXY ─► DAC sXY   (XY = 02, 10, 12, 20, 22, 30, 32)
```"""
        diff = """| 項目 | rev0.12 47dr1（同事） | RFSoC_RX | 原因 |
|---|---|---|---|
| ADC NCO（8 組） | 0.84 GHz | **1.04 GHz** | 與 RFSoC_TX 對齊，使用頻段改成 2.3 ~ 3.3 GHz（2026-10-15） |
| DAC NCO（8 組） | −0.84 GHz | **−1.04 GHz** | 同上 |
| 其他 RFDC 參數 | — | 相同 | 只改 NCO |

ADC Outclk 維持同事的 30 MHz（RFSoC_RX 沒有 Gain Control，不需要 240 MHz 的 adc_clk）。"""
        ps = """RFSoC_RX 這一版只有 PL（bitstream / XSA），**沒有 PS 程式**。RFDC 的初始化、MTS 與 NCO 相關的 PS 流程，依同事原本的方式（`docs/reference_rev0.12/DESIGN.md` §15 bring-up procedure）處理。"""
        todo = """1. 頻段（2.3 ~ 3.3 GHz）尚未在板上量測確認。
2. RFSoC_RX 與 RFSoC_TX 的 NCO 必須一致；請勿與舊版 z1（rev0.11 / rev0.12 release，0.84 GHz）混用。
3. RFSoC_RX 尚無 PS 程式，RFDC / MTS 的開機流程需另行確認。"""

    n_freq = 6
    s = f"""# {title}

- 專案：PJ22045_1R8T_release_Rex_rev0.1_20261015 / {board}
- 適用版本：{proj}
- 參數來源：以 Vivado 2025.2 唯讀開啟專案讀出的 RFDC（`usp_rf_data_converter_1`，v2.6）完整設定（`docs/tools/rfdc_params_{tag}.txt`，本文件由 `docs/tools/mk_doc_rfdc.py` 產生）
- 文件版本：v0.1（2026-10-16）

## 1. 閱讀指引

| 想知道 | 看哪裡 |
|---|---|
| RFDC 在這塊板子上做什麼 | 第 2 節 |
| 各 tile 的時脈、取樣率、PLL | 第 3 節 |
| ADC / DAC 每個通道的 mixer、NCO、decimation / interpolation | 第 4、5 節 |
| AXIS 與輸出時脈接到哪裡 | 第 6 節 |
| 頻率規劃（NCO 與 RF 頻段） | 第 {n_freq} 節 |
| 和同事版本的差異 | 第 7 節 |
| PS 端的設定流程 | 第 8 節 |

## 2. 功能概述

{role}

- 元件：`design_1/usp_rf_data_converter_1`（Zynq UltraScale+ RFSoC Data Converter v2.6），xczu47dr：4 個 ADC tile、4 個 DAC tile。
- AXI-Lite 控制介面 `s_axi` 在 0xA004_0000（256 KB），時脈 pl_clk0 100 MHz。
- 所有 ADC / DAC AXIS 都在 **FPGA_clk 256 MHz**（`util_ds_buf_0/IBUF_OUT`）。

## 3. Tile 與時脈

### 3.1 ADC tiles

{tile_table(P, "ADC")}
### 3.2 DAC tiles

{tile_table(P, "DAC")}
- Clock source / distribution：ADC tile 225（adc1）使用 PLL（refclk 256 MHz），並把 PLL 輸出分配給其他 ADC tile（其他 ADC tile 的 refclk = 3840 MHz、PLL 關閉）；DAC tile 228（dac0）以 256 MHz refclk 啟用 PLL 並分配 input refclk。
- Fabric（AXIS）時脈 256 MHz；Outclk 是 RFDC 輸出給 PL 的 `clk_adcN` / `clk_dacN`（見第 6 節）。
- 全部 tile 開啟 Multi-Tile Sync（MTS），SYSREF 來源 = {P.get('Sysref_Source', '-')}。
- DAC VOP mode = {P.get('DAC_VOP_Mode', '-')}，各 DAC tile VOP = {P.get('DAC0_VOP', '-')} mA。

## 4. ADC 設定

{adc_table(P)}
- 每個 tile 啟用 4 個 ADC slice（I/Q 模式下每個 ADC 佔兩個 slice，輸出 I、Q 兩條 AXIS）。
- Data width 5：每個 256 MHz 時脈輸出 5 個 16-bit sample（每條 AXIS 80-bit）；3.84 GSPS ÷ 3（decimation）= 1.28 GSPS = 256 MHz × 5。
- ADC Real-time signal（RTS）：{P.get('ADC_RTS', '-')}（over_range / over_voltage / over_threshold 等 flag 由 PL 腳位輸出）。
- 目前全部 ADC 的 NCO：{', '.join(a for a in adc_nco if a)} GHz。

## 5. DAC 設定

{dac_table(P)}
- 每個 tile 啟用 slice 0、2（共 8 個 DAC）；slice 1、3 關閉。
- Data width 10：每個 256 MHz 時脈輸入 10 個 16-bit word = 5 個複數 sample（160-bit AXIS，每 sample 32-bit = {{Q[15:0], I[15:0]}}）。
- 目前全部 DAC 的 NCO：{', '.join(d for d in dac_nco if d)} GHz。

## 6. AXIS 與輸出時脈

{axis_table(AXIS, CLK)}
{oclk_table(OCLK)}
{COMMON_FREQ.format(n=n_freq).replace("### 6.1", "### 6.1")}
## 7. 與同事版本（rev0.12）的差異

{diff}

## 8. PS 端設定流程

{ps}

## 9. 待確認

{todo}

## 10. 修訂歷程

| 版本 | 日期 | 說明 |
|---|---|---|
| v0.1 | 2026-10-16 | 第一版，對應 {'RFSoC_TX' if tag == 'TX' else 'RFSoC_RX'} build 01（NCO 1.04 / −1.04 GHz） |
"""
    # 第 6 節同時放 AXIS 與頻率, 把頻率小節移到第 6 節結尾
    return s


for tag, sub in (("TX", "02_RFSoC_TX"), ("RX", "03_RFSoC_RX")):
    P, CLK, AXIS, OCLK = load(tag)
    out = os.path.join(ROOT, "docs", sub, "RFDC_Configuration.md")
    open(out, "w", encoding="utf-8").write(doc(tag, P, CLK, AXIS, OCLK))
    print("wrote", out)
