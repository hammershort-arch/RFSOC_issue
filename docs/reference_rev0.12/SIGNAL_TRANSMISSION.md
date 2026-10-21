# PJ22045.0.1 1R8T — Signal Transmission and Synchronisation

| | |
|---|---|
| Project | Folder `~/Desktop/PJ22045.0.1`: `47dr1` (**z1**, ADC transmitter), `vu13p` (relay / 1 → 8 broadcaster), `47dr2` (**z2**, 8-DAC receiver). System document: `docs/DESIGN.md` (rev 0.11) |
| Scope | How one ADC stream travels from the z1 RFSoC to eight z2 DACs: every module on the path, its RTL behaviour, its IP configuration, the serial links, flow control, clock crossings, link start-up and recovery. The time base and the scheduled playback are described in the companion document `docs/TIMING_SYNC.md` |
| Data source | IP settings were read from the three Vivado 2025.2 block designs (read-only dump of every cell `CONFIG.*` and every net, 2026-10-14, all values below are copied from that dump); RTL from `<project>.srcs/sources_1/imports/new` and `sources_1/new`; Aurora user-clock frequency from `47dr2/reports/timing_summary.rpt` |
| Revision | **1.1** (2026-10-14), matches design rev 0.12 |
| Status | Design built and timing met on all three boards; not yet run on hardware. Rev 1.1: VU13P core-1 link-reset defect (§5.4) fixed in design rev 0.12 (D19), VU13P rebuilt |

> **History policy:** this document describes the current design. When the design changes, the text is updated and
> a row is added to §13 *Revision history*. Decisions stay in `docs/DESIGN.md` §13 (D-numbers are quoted here).

---

## 1. Reading guide

* §2 gives the whole path in one table. §3–§6 follow a sample through the hardware: z1 source (§3), the 47DR link
  container that both 47DR boards share (§4), the VU13P relay (§5), the z2 receiver (§6).
* §7 describes the Aurora serial links, §8 flow control / clock crossings / FIFO budget / throughput, §9 link start-up,
  reset and synchronisation, §10 what happens when something goes wrong, §11 debug, §12 verification.
* Notation: `C0` / `C1` = Aurora core 0 / 1 of a quad; *beat* = one 128-bit Aurora word; *sample word* = one 160-bit
  RFSoC word = 5 complex samples. `FPGA_clk` = 256 MHz, `user_clk` = Aurora user clock 400.391 MHz, `axis_aclk` = VU13P
  fabric clock 400 MHz.

## 2. End-to-end path

| # | Board | Block (BD path) | Clock | Width in → out | Function |
|---|---|---|---|---|---|
| 1 | z1 | `usp_rf_data_converter_1` ADC tile 0 ch 0 | `FPGA_clk` | RF → 2 × 80 b | 3.84 GSPS, ×3 decimation, fine mixer +0.84 GHz, I and Q streams |
| 2 | z1 | `axi_stream_combininp_adc00` | `FPGA_clk` | 2 × 80 → 160 b | interleaves I/Q into the DAC word format |
| 3 | z1 | `axis_packetizer_0` (+ `ilconcat_1` time) | `FPGA_clk` | 160 b + 64 b tuser | gates the stream with `start`, `tlast` every 1024 words, carries the timestamp |
| 4 | z1 | `aurora_gty_47drto13p_0/hier_tx_x0y1/tx_c1/cdc_fifo` | `FPGA_clk` → `user_clk` | 160 + 64 | async FIFO, 16 deep |
| 5 | z1 | `…/tx_c1/header_insertion_v2_0` | `user_clk` | 160 → 128 b | inserts 64-bit header, repacks 5 words → 4 words |
| 6 | z1 | `…/tx_c1/out_fifo` → `hier_x0y1/aurora_x0y1_1` | `user_clk` | 128 b | 16-deep FIFO, Aurora TX core 1 of quad X0Y1 |
| 7 | link | GTY lanes X0Y6-7 → VU13P X1Y34-35 | — | 2 × 25.625 Gb/s | 64B66B, Framing |
| 8 | VU13P | `hier_x1y8/aurora_x1y8_1` → `link_x1y8/rx_slice_c1` → `rx_fifo_c1` | `user_clk(228)` → `axis_aclk` | 128 b | RX core, register slice, async FIFO 512 |
| 9 | VU13P | `axis_slr_x1y8_to_tx` → `axis_broadcaster_0` | `axis_aclk` | 128 b → 8 × 128 b | SLR crossing, 1 → 8 copy, no back-pressure |
| 10 | VU13P | `link_x1yN/tx_fifo_c<n>` → `tx_slice_c<n>` → `hier_x1yN/aurora_x1yN_<n>` | `axis_aclk` → `user_clk(224–227)` | 128 b | async FIFO 512, Multi-SLR slice, 8 TX cores |
| 11 | link | VU13P X1Y16…X1Y31 → z2 X0Y4…X0Y19 | — | 8 × 2 × 25.625 Gb/s | 64B66B, Framing |
| 12 | z2 | `hier_x0yN/aurora_x0yN_<n>` → `hier_rx_x0yN/rx_c<n>/in_fifo` | `user_clk` | 128 b | RX core, 512-deep FIFO |
| 13 | z2 | `…/rx_c<n>/header_extraction_v2_0` → `cdc_fifo` | `user_clk` → `FPGA_clk` | 128 → 160 b + 64 b tuser | strips header, repacks 4 → 5 words, rebuilds per-word time, async FIFO 512 |
| 14 | z2 | `hier_rx_x0yN/data_delay_<n>` → `axis_data_fifo_<n>` → `data_aligner_<n>` | `FPGA_clk` | 160 b | due time, 1024-deep holding FIFO, release at due time (`TIMING_SYNC.md`) |
| 15 | z2 | `usp_rf_data_converter_1` DAC slice | `FPGA_clk` | 160 b → RF | ×3 interpolation, fine mixer −0.84 GHz, 3.84 GSPS |

## 3. z1 — signal source (47dr1, BD `design_1`)

### 3.1 RF Data Converter — ADC side (`usp_rf_data_converter_1`, v2.6)

All four ADC tiles and all 16 ADC slices are enabled with identical slice settings; only tile 0 slice 0/1
(`m00_axis` = I, `m01_axis` = Q of ADC 00) feeds the link. The same IP configuration is used on z2 (where the ADCs
are unused).

| Setting (per slice, all 16 identical) | Value | Meaning |
|---|---|---|
| `ADC_Data_Type` | 1 | I/Q output (two AXIS streams per converter: m*x*0 = I, m*x*1 = Q) |
| `ADC_Decimation_Mode` | 3 | ×3 decimation: 3.84 GSPS → 1.28 GSPS complex |
| `ADC_Mixer_Type` / `ADC_NCO_Freq` | 2 (fine) / **+0.84 GHz** | NCO down-conversion |
| `ADC_Data_Width` | 5 | 5 samples of 16 bit = 80 bit per stream per fabric clock |
| `ADC_Nyquist` | 1 | first Nyquist zone |
| `ADC_CalOpt_Mode` / `ADC_Dither` | 1 / false | calibration mode 1, no dither |

| Tile setting | ADC0 | ADC1 | ADC2 | ADC3 |
|---|---|---|---|---|
| `Sampling_Rate` | 3.84 GSPS | 3.84 | 3.84 | 3.84 |
| `PLL_Enable` / `Refclk_Freq` | off / 3840 MHz | **on / 256 MHz** | off / 3840 | off / 3840 |
| `Clock_Source` / `Clock_Dist` | 1 / 0 | 1 / **2** | 1 / 0 | 1 / 0 |
| `Fabric_Freq` / `Outclk_Freq` | 256 / 30 MHz | 256 / 30 | 256 / 30 | 256 / 30 |
| `Multi_Tile_Sync` | true | true | true | true |

* Tile ADC1 (`adc1_clk` board port) runs its PLL from a 256 MHz reference and distributes the 3.84 GHz sampling
  clock (`Clock_Dist = 2`); tiles 0, 2, 3 run without PLL on the distributed 3.84 GHz clock.
* All AXIS ports (`m0..m3_axis_aclk`, `s0..s3_axis_aclk`) are clocked by `FPGA_clk` (`util_ds_buf_0`) and reset by
  `dac_rst1/peripheral_aresetn` (PS reset synchronised to `FPGA_clk`). AXI-Lite at 0xA004_0000 on `pl_clk0`.
* `Sysref_Source = 1`, `user_sysref_adc/dac` from `regs_4_sysref_0` — multi-tile sync, see `TIMING_SYNC.md` §4.4.

### 3.2 `axi_stream_combininput` (module reference, `sources_1/new/axi_stream_combininput.v`)

Eight instances (`axi_stream_combininp_adc00 … adc32`), one per ADC converter. `adc00` feeds the packetizer, the
other seven loop back to the same-index z1 DAC (`s02_axis` … `s32_axis`, requirement R8).

| Port | Width | Connection (adc00) |
|---|---|---|
| `s0` | 80 b | RFDC `m00_axis` (I0…I4) |
| `s1` | 80 b | RFDC `m01_axis` (Q0…Q4) |
| `m` | 160 b | `axis_packetizer_0/s_axis` (+ `system_ila_1` slot 1) |
| `clk` | — | `FPGA_clk` |

Behaviour (one register stage, no reset):
* When `s0_tvalid` **and** `s1_tvalid`: `m_tdata <= {Q4,I4,Q3,I3,Q2,I2,Q1,I1,Q0,I0}` (bits `[16k+15:16k]`: even k = I,
  odd k = Q, sample 0 in the LSBs), `m_tvalid <= 1`. Otherwise `m_tdata <= 0`, `m_tvalid <= 0`.
* `s0_tready = s1_tready = m_tready` (pass-through). The RFDC ADC AXIS has no back-pressure, so the combiner never
  stalls; it is exactly one `FPGA_clk` cycle of latency.
* The 160-bit word is the RFDC DAC I/Q input format (DAC `Data_Width = 10` × 16 bit, §6.4), so the same word drives a
  DAC unchanged on z1 (loopback) and on z2 (after the link).

### 3.3 `axis_packetizer` (module reference, `imports/new/axis_packetizer.v`)

| Parameter | Value |
|---|---|
| `DATA_WIDTH` | 160 |
| `USER_WIDTH` | 64 |
| `PACKET_LENGTH` | 1024 |

| Port | Connection |
|---|---|
| `s_axis` | combiner `adc00/m`; `s_axis_tuser` = `ilconcat_1/dout` = `{24'b0, timer_1/timestamp[39:0]}` |
| `m_axis` | container `S_AXIS_X0Y1_C1` (+ `system_ila_1` slot 0) |
| `start` | `sync_pulse_to_level_1/level_ref` (time-base start, `TIMING_SYNC.md` §4) |
| `aclk` / `aresetn` | `FPGA_clk` / `xpm_cdc_gen_1/dest_rst_out` (= `axi_gpio_arstn`) |

Behaviour:
* Data and `tuser` pass straight through (combinational). `m_axis_tvalid = s_axis_tvalid & start`: nothing is sent
  before the time base starts, so the first transmitted word carries time ≈ 0.
* A 10-bit counter `cnt` advances on every accepted word (`s_tvalid & m_tready & start`) and wraps at 1023;
  `m_axis_tlast = (cnt == 1023)`. One packet = **1024 sample words = 4 µs**.
* `s_axis_tready = m_axis_tready`, but the combiner ignores `tready`: if the z1 TX FIFO were full, words would be lost
  (counted in simulation as `drop_tx`; never happens, §8.3).

### 3.4 Other z1 blocks on the path

| Cell | IP / config | Role |
|---|---|---|
| `ilconcat_1` | inline concat, `NUM_PORTS 2`, `IN0_WIDTH 40`, `IN1_WIDTH 24`, `dout 64` | `tuser = {xlconstant_0 (24'b0), timer_1/timestamp}` |
| `xlconstant_0` | `CONST_VAL 0`, `CONST_WIDTH 24` | upper tuser bits |
| `system_ila_1` | 2 AXIS monitor slots, depth 1024, `FPGA_clk`, reset `irstn` | slot 0 packetizer out, slot 1 combiner out |
| `vio_data_delay` | 1 output probe, 40 bit, unconnected | left-over from the EV1 design (D13 replaced it on z2); no function on z1 |

## 4. 47DR link container (`aurora_gty_47drto13p`, identical on z1 and z2)

### 4.1 Structure

One BD container, instantiated as `aurora_gty_47drto13p_0` in both 47DR `design_1`s. Per quad X0Y*N* (N = 1…4):

| Hierarchy | Contents |
|---|---|
| `hier_x0yN` | `aurora_x0yN_0` (core 0, owns QPLL), `aurora_x0yN_1` (core 1), `auto_reset_aurora`, `aurora_rstn_0/1`, `x0yN_core_status_0/1` (VIO) |
| `hier_tx_x0yN` | `tx_c0`, `tx_c1` (`cdc_fifo` → `header_insertion_v2_0` → `out_fifo`), `axis_rst_sync_c0/c1` |
| `hier_rx_x0yN` | `rx_c0`, `rx_c1` (`in_fifo` → `header_extraction_v2_0` → `cdc_fifo`); quad 1 core 0 also has a header ILA |
| `ila_x0yN` | system ILA, 4 AXIS slots (TX C0, TX C1, RX C0, RX C1), depth 2048, quad `user_clk` |

Plus one `ini_system_0` (pma_init generator for all quads). Container ports: `S_AXIS_X0YN_C<n>` (TX in),
`M_AXIS_X0YN_C<n>` (RX out), `GT_SERIAL_TX/RX_X0YN_C<n>`, `gt_x0yN_diff_ref`, `s_axis_aclk` (= `FPGA_clk`), `init_clk`
(100 MHz, `util_ds_buf_2`), `ini_pma_rst` (`xpm_cdc_gen_0` = `axi_gpio_pma_rst`).

Used ports: z1 uses only `S_AXIS_X0Y1_C1` (TX of the ADC stream); its RX outputs are unused. z2 uses all eight
`M_AXIS_X0YN_C<n>`; its TX inputs are unused. All 8 links per board are built and train (R6).

### 4.2 TX chain per core (`hier_tx_x0yN/tx_c<n>`)

| Cell | IP | Configuration |
|---|---|---|
| `cdc_fifo` | `axis_data_fifo` 2.0 | depth **16**, `IS_ACLK_ASYNC 1`, 20 bytes tdata, `TUSER_WIDTH 64`, tlast yes, tkeep no, sync stages 3, memory auto, packet mode off |
| `header_insertion_v2_0` | module ref | `WORD_WIDTH 32`, `DIN_WORDS 5`, `DOUT_WORDS 4`, `IP_WIDTH 16`, `TYPE_WIDTH 8`, `TIME_WIDTH 40`, `USER_WIDTH 64`, `BUFF_DEPTH 4` |
| `out_fifo` | `axis_data_fifo` 2.0 | depth **16**, synchronous (`user_clk`), 16 bytes, tlast + tkeep, no tuser |

Clocks / resets: `cdc_fifo` write side `FPGA_clk` with `axis_rst_sync_c<n>` (`xpm_cdc_async_rst`, 4 stages, link reset
into `FPGA_clk`); read side, `header_insertion` and `out_fifo` on the quad `user_clk` with `arstn_c<n>` (link reset).

### 4.3 `header_insertion_v2` — design (160 → 128 bit with header)

The module is a 32-bit-word shift register of `BUFF_DEPTH × DIN_WORDS` = 20 words (640 bits) with a fill counter
`data_rem` (0…20). Words enter at the top (MSB) side and leave as 4-word beats from the top.

| Signal | Rule |
|---|---|
| `s_axis_tready` | `data_rem ≤ 15` **and not** `m_axis_tlast` (one-cycle stall after each packet end) |
| `in_words` | 5 per accepted sample word; **7** for the first word of a packet (`sof`): 2 header words + 5 data words |
| `out_words` | 4 if `data_rem + in_words ≥ 4` and not `m_axis_tlast`, else 0 |
| header | `{ip[15:0], type[7:0], time[39:0]}` = the packet's first `s_axis_tuser` (ip = type = 0 here); placed in the **top 64 bits** of the register, ahead of all remaining data |
| `m_axis_tdata` | top 128 bits of the register (word order MSB-first: header, then sample words, each sample word `[159:128]` first) |
| `m_axis_tvalid` | registered: 1 when a beat is formed, held while `!m_axis_tready` |
| `m_axis_tlast` | registered copy of the accepted input `tlast`; held until the beat is accepted |
| `m_axis_tkeep` | `~(0xFFFF >> (out_words × 4))` = 0xFFFF for every full beat |
| `sof` | 1 after reset and after each accepted `tlast`; cleared by the next accepted word |

Packet arithmetic: 64 + 1024 × 160 = 163 904 bits = 5122 words = **1280.5 beats**. When the last sample word of
a packet is accepted, 2 words (half a beat) stay in the register. At the next `sof` the register is shifted down by
64 bits and the new header is written on top, so the next packet's first beat is
`{header(n+1) [127:64], last 2 words of packet n [63:0]}`. Consequences:

* Packets alternate between **1280 beats** (2 words carried) and **1281 beats** (no carry): odd packets
  2 + 5120 = 5122 words, even packets 2 + 2 + 5120 = 5124 words.
* The stream of sample words is continuous across packets — the carried words are delivered in order — but the
  64-bit alignment of every packet depends on the previous one (lost-packet effect, §10).
* After every packet the module inserts **one idle cycle** (`m_axis_tlast` blocks `tready`), so a packet occupies
  ≈ 1281.5–1282.5 `user_clk` cycles (§8.4).

### 4.4 RX chain per core (`hier_rx_x0yN/rx_c<n>`) and `header_extraction_v2`

| Cell | IP | Configuration |
|---|---|---|
| `in_fifo` | `axis_data_fifo` 2.0 | depth **512**, synchronous (`user_clk`), 16 bytes, tlast + tkeep, no tuser |
| `header_extraction_v2_0` | module ref | `WORD_WIDTH 32`, `DIN_WORDS 4`, `DOUT_WORDS 5`, `USER_WIDTH 64`, `TIME_WIDTH 40`, `BUFF_DEPTH 3` |
| `cdc_fifo` | `axis_data_fifo` 2.0 | depth **512**, `IS_ACLK_ASYNC 1`, 20 bytes, `TUSER_WIDTH 64`, tlast + tkeep, sync stages 3 |
| `system_ila_0` (`hier_rx_x0y1/rx_c0` only) | system ILA | 3 AXIS slots (RX in, `in_fifo` out, extraction out) + probes `header[63:0]`, `err`, depth 1024 |

`header_extraction_v2` is the inverse of §4.3 with a 12-word register:
* `sof` = first beat after an accepted `tlast` (and after reset). On that beat the top 64 bits are the header:
  `header_valid = 1`, `header = s_axis_tdata[127:64]`, and only the lower 2 words (`in_words = 2`) enter the register.
  Other beats add 4 words.
* A 160-bit word is output whenever ≥ 5 words are buffered. `s_axis_tready = (data_rem ≤ 8) & !tlast_r` (one idle
  cycle after each packet end).
* **Timestamp rebuild:** `m_axis_tuser` is loaded with the header on the `sof` beat and incremented on every output
  handshake → every sample word gets back the z1 time it was stamped with (details and the one-count step after the
  first packet: `TIMING_SYNC.md` §7).
* `m_axis_tlast` = registered input `tlast` (marks the word output in the cycle the last beat arrived).
* `err = (w0 != w0 ^ w1 ^ w2 ^ w3 ^ w4[22:0])` on the output word, i.e. `err = 1` whenever `w1^w2^w3^w4[22:0] ≠ 0`.
  This is a test-pattern check from the original design; for ADC data it is almost always 1 and carries no meaning.
  (It also only uses 23 bits of word 4: `m_axis_tdata[150:128]`.)
* `cdc_fifo` (512) carries data + 64-bit tuser + tlast from `user_clk` to `FPGA_clk`. Its read side (z2 `hier_rx`)
  never back-pressures (`data_delay.s_axis_tready = 1`).

### 4.5 Aurora 64B66B cores (`aurora_64b66b` 13.0) — identical on all three boards

All 72 core instances in the three projects (16 on z1, 16 on z2, 40 on the VU13P incl. the 13P↔13P link) were
compared: every setting below is the same; only the start lane / quad / refclk source differ.

| Setting | Value |
|---|---|
| `C_LINE_RATE` | **25.625 Gb/s** per lane |
| `C_AURORA_LANES` | **2** |
| `interface_mode` | **Framing** (AXIS with `tlast` / `tkeep`) |
| `flow_mode` | None (no native / user flow control) |
| `dataflow_config` | Duplex |
| `crc_mode` | false (no CRC) |
| `C_REFCLK_FREQUENCY` / source | 156.25 MHz / `MGTREFCLK0_of_Quad_<quad>` |
| `C_PLL_TYPE` (GT_SETTINGS `TX/RX_PLL_TYPE`) | LCPLL (QPLL) |
| `C_INIT_CLK` / `DRP_FREQ` | 100 MHz / 100 MHz |
| `SupportLevel` | **1 on core 0** (shared logic in core: QPLL, clocking, `user_clk_out`); **0 on core 1** (uses core 0's) |
| RX equalisation | `RX_EQ_MODE AUTO`, `INS_LOSS_NYQ 20` dB, `RX_COUPLING AC`, `RX_TERMINATION PROGRAMMABLE` 800 mV, `RX_PPM_OFFSET 0`, `RX_SSC_PPM 0` |
| `C_USE_BYTESWAP`, `C_USER_K`, `C_DOCCPORT_ENABLE`, `TransceiverControl`, `drp_mode` | false / false / false / false / Disabled |
| `C_INT_DEBUG` | true |
| `SINGLEEND_INITCLK` | true (`init_clk` from a fabric buffer) |

User clock: TXOUTCLK-derived **400.391 MHz** (= 25.625 Gb/s / 64, timing report). The 128-bit user interface
(2 lanes × 64 bit) pauses 1 cycle in 33 for the 64b/66b gearbox, so the payload rate is
400.391 × 32/33 × 128 = **49.69 Gb/s** per link before clock compensation.

### 4.6 Core 0 / core 1 sharing and reset chain inside `hier_x0yN`

| Core 1 pin | Driven by | Purpose |
|---|---|---|
| `gt_qpllclk_quad1_in`, `gt_qpllrefclk_quad1_in`, `refclk1_in` | core 0 `gt_qpll*_out`, `gt_refclk1_out` | shared QPLL and refclk |
| `user_clk`, `sync_clk` | core 0 `user_clk_out`, `sync_clk_out` | same user clock for both cores (one `user_clk` per quad) |
| `reset_pb` | core 0 `sys_reset_out` | core 1 leaves reset after core 0 |
| `pma_init` | core 0 `gt_reset_out` | — |

| Core 0 pin | Driven by |
|---|---|
| `reset_pb` | `auto_reset_aurora` (held 1 until `gt_pll_lock` is high for 4 `init_clk` cycles) |
| `pma_init` | container `ini_system_0/ini_pma` |
| `init_clk` | 100 MHz `init_clk` |

Reset helper RTL (identical on the three boards):

| Module | Behaviour |
|---|---|
| `auto_reset_aurora` | 4-flop shift of `pll_lock` on `init_clk`; `reset_pb = 0` only when all 4 are 1 (initial value 1) |
| `ini_system` | 9-bit saturating counter on `init_clk` from configuration; `ini_pma = 1` while `i_pma_rst` = 1 or `cnt[7:0] ≠ 0xFF`. Result: `pma_init` high for the first 255 cycles (2.55 µs), **one cycle low at cnt = 255**, high again until cnt = 511, then low (released) for good. The one-cycle release at 255 is harmless (the GT ignores sub-µs `pma_init` pulses) but is a quirk of the original RTL |
| `aurora_rstn` | `arstn = !system_rst & channel_up` (combinational): a core's link reset is released only while its channel is up |
| `xpm_cdc_gen` (`axis_rst_sync_c<n>`, `user_rst_sync_c<n>`) | `xpm_cdc_async_rst`, `DEST_SYNC_FF 4`, active-low: brings `arstn_c<n>` into `FPGA_clk` / `axis_aclk` (assert async, release sync) |

Status VIOs `x0yN_core_status_0/1` (3 inputs each, on the quad `user_clk`): `channel_up`, `gt_pll_lock`, `lane_up[1:0]`.

## 5. VU13P relay (BD `aurora_gty_vu13p_rst`)

### 5.1 Top level

| Cell | IP / config | Connections |
|---|---|---|
| `util_ds_buf_0` | IBUFDS | `sys_clk` 100 MHz (BA15) → `init_clk` of both containers, `clk_wiz_0`, `hier_rst` |
| `clk_wiz_0` | clk_wiz 6.0, MMCM, in 100 MHz, `CLKFBOUT_MULT_F 12`, `CLKOUT0_DIVIDE_F 3` → **`clk_out1` 400 MHz** (jitter 90 ps), no reset / locked pins | `s_axis_aclk` = `axis_aclk` of both containers, slice, broadcaster, `ila_bcast` |
| `util_ds_buf_1` | IBUFDS | board `pma_rst` LVDS input (AU16/AV16, driven by z1/z2 `PMA_RST`) |
| `xpm_cdc_gen_1` | `xpm_cdc_async_rst`, 4 stages, dest `sys_clk` | `pma_rst` → `hier_rst/i_pma_rst` |
| `hier_rst/ini_system_0` | `ini_system` (§4.6) | `ini_pma` → `ini_pma_rst` of both containers |
| `xpm_cdc_gen_0` + `util_vector_logic_0` (NOT) | async reset sync into `axis_aclk`, then inverted | `aresetn` of `axis_slr_x1y8_to_tx` and `axis_broadcaster_0` = !`ini_pma` |
| `axis_slr_x1y8_to_tx` | `axis_register_slice` 1.1, `REG_CONFIG 15` (Multi-SLR crossing), `NUM_SLR_CROSSINGS 1`, pipelines master 1 / slave 1 / middle 0, 16 bytes, tlast + tkeep | container `M_AXIS_X1Y8_C1` → broadcaster `S_AXIS` (D11: quad 228 and quads 224–227 are in different SLRs) |
| `axis_broadcaster_0` | `axis_broadcaster` 1.1, `NUM_MI 8`, **`HAS_TREADY 0`**, tlast + tkeep, `M0x_TDATA_REMAP tdata[127:0]`, `M0x_TUSER_REMAP 1'b0` | `M00…M07_AXIS` → container `S_AXIS_X1Y4_C0, X1Y4_C1, X1Y5_C0 … X1Y7_C1` |
| `ila_bcast` | system ILA, 9 AXIS slots, depth 1024, `axis_aclk` | slot 0 broadcaster input, slots 1–8 outputs |

Broadcaster without `tready` (D12): every output gets every beat in the same cycle; a full TX FIFO on one link drops
that link's beats only, the other seven continue.

### 5.2 Container `aurora_gty_vu13pto47dr` (8 quads X1Y4 … X1Y11)

Per quad: `hier_x1yN` (2 Aurora cores, `auto_reset_aurora`, `aurora_rstn_0/1`, status VIOs — same as §4.6),
`link_x1yN` (identical plumbing for all eight quads, D9) and `ila_x1yN` (4 slots, depth 2048, quad `user_clk`).

| Cell in `link_x1yN` (per core n) | IP | Configuration |
|---|---|---|
| `rx_slice_c<n>` | `axis_register_slice` 1.1 | `REG_CONFIG 1`, no SLR crossing, 16 bytes, tlast + tkeep, `user_clk` |
| `rx_fifo_c<n>` | `axis_data_fifo` 2.0 | depth **512**, async (`user_clk` → `axis_aclk`), 16 bytes, tlast + tkeep, no tuser |
| `tx_fifo_c<n>` | `axis_data_fifo` 2.0 | depth **512**, async (`axis_aclk` → `user_clk`), 16 bytes, tlast, no tkeep, tuser 64 (unused) |
| `tx_slice_c<n>` | `axis_register_slice` 1.1 | `REG_CONFIG 15` Multi-SLR crossing, `NUM_SLR_CROSSINGS 2`, pipelines 1/1/1, 16 bytes, tlast, `user_clk` |
| `user_rst_sync_c<n>` | `xpm_cdc_async_rst`, 4 stages | `arstn_c<n>` → `user_clk` (slices, `rx_fifo` write side) |
| `axis_rst_sync_c<n>` | `xpm_cdc_async_rst`, 4 stages | `user_rst_sync` output → `axis_aclk` (`tx_fifo` write side) |

Used: `M_AXIS_X1Y8_C1` (ADC stream in) and `S_AXIS_X1Y4_C0 … S_AXIS_X1Y7_C1` (eight outputs). The quads X1Y9–X1Y11
and X1Y8 C0 are trained links with no data (they pair with z1 X0Y2–X0Y4 and X0Y1 C0).

### 5.3 13P↔13P container (`aurora_gty_vu13ptovu13p`)

Quads X0Y11 and X0Y13 (2 cores each, same Aurora settings, `link` FIFOs 512, register slices), kept unchanged from
the EV1 design. Not part of the 1R8T path.

### 5.4 Fixed defect (rev 0.12, D19): core-1 link reset on the VU13P quads X1Y4 … X1Y11

Up to rev 0.11, in every `hier_x1yN` of `aurora_gty_vu13pto47dr`, `aurora_rstn_1/channel_up` was driven by the net
**`aurora_x1yN_0_lane_up`** (core 0's 2-bit `lane_up`, bit 0 used) instead of `aurora_x1yN_1_channel_up`.
`system_rst` is correct (`aurora_x1yN_1_sys_reset_out`). The 4 cores of the 13P↔13P container and all 16 cores of
the 47DR containers are wired correctly (checked: 28 of 36 `aurora_rstn` correct, these 8 wrong).

* Origin: the EV1 source design had this wiring on `hier_x1y4` only (X1Y8 was correct). Rev 0.5 copied the X1Y4
  plumbing to all quads (D9), so it now also affects **X1Y8 core 1, the ADC-stream receiver**, and the four
  broadcaster outputs on core 1 (M01, M03, M05, M07 → z2 DACs s12, s02, s22, s32).
* Effect: the core-1 FIFOs and slices of a quad are released when **core 0 lane 0** is up, not when core 1's channel
  is up. In normal operation both cores train together and nothing is visible. If core 1 drops while core 0 stays
  up, its FIFOs are **not** flushed (stale or partial packets continue into the broadcaster); if core 0 is down, the
  ADC stream on core 1 is held in reset although core 1 is up.
* **Fix (rev 0.12, `scripts/mod13_vu13p_rstn.tcl`):** `aurora_rstn_1/channel_up` now on net `aurora_x1yN_1_channel_up`
  (with `aurora_x1yN_1/channel_up` and the status VIO) in all eight `hier_x1yN`; BD validated; VU13P rebuilt.
  Backup of the old BDs: `backup/pre_rstn_fix_20261014.tgz`. All 36 `aurora_rstn` in the three projects now follow
  their own core.

## 6. z2 — receiver (47dr2, BD `design_1`)

### 6.1 Path per Aurora core

Container `M_AXIS_X0YN_C<n>` (§4.4: `in_fifo` 512 → `header_extraction_v2` → `cdc_fifo` 512) → `hier_rx_x0yN`:

| Cell (per core n) | IP | Configuration |
|---|---|---|
| `data_delay_<n>` | module ref `data_delay.v` | `DATA_WIDTH 160`, `USER_DATA_WIDTH 64`, `TIME_WIDTH 40`; `delay` = `axi_delay` (32 bit) |
| `axis_data_fifo_<n>` | `axis_data_fifo` 2.0 | depth **1024**, synchronous `FPGA_clk`, 20 bytes, `TUSER_WIDTH 64`, no tlast, no tkeep, memory auto |
| `data_aligner_<n>` | module ref `data_aligner.v` | `DATA_WIDTH 160`, `USER_DATA_WIDTH 64`, `TIME_WIDTH 40`; `timestamp` = z2 `timer_1` |
| `system_ila_<n>` | system ILA | 4 AXIS slots (delay in, delay out, FIFO out, aligner out) + probes `timestamp[39:0]`, `sys_time[40:0]`, `data_time[40:0]`, `end_time[39:0]`; depth 1024, `FPGA_clk` |

Clock `FPGA_clk`, reset `xpm_cdc_gen_1/dest_rst_out` (= `axi_gpio_arstn`). The design of `data_delay` and
`data_aligner` is in `TIMING_SYNC.md` §8. `data_aligner` ignores `m_axis_tready` (the RFDC DAC is always ready) and
outputs zeros while no sample is due.

### 6.2 Link-to-DAC map

| Container port | `hier_rx` | RFDC input | DAC (tile, ch) | Board port |
|---|---|---|---|---|
| `M_AXIS_X0Y1_C0` / `_C1` | `hier_rx_x0y1` | `s10_axis` / `s12_axis` | 1.0 / 1.2 | `vout10` / `vout12` |
| `M_AXIS_X0Y2_C0` / `_C1` | `hier_rx_x0y2` | `s00_axis` / `s02_axis` | 0.0 / 0.2 | `vout00` / `vout02` |
| `M_AXIS_X0Y3_C0` / `_C1` | `hier_rx_x0y3` | `s20_axis` / `s22_axis` | 2.0 / 2.2 | `vout20` / `vout22` |
| `M_AXIS_X0Y4_C0` / `_C1` | `hier_rx_x0y4` | `s30_axis` / `s32_axis` | 3.0 / 3.2 | `vout30` / `vout32` |

`system_ila_0` (top) monitors `s00_axis` (DAC 0.0).

### 6.3 RF Data Converter — DAC side (z2, same IP configuration on z1)

| Setting (per enabled slice: 00, 02, 10, 12, 20, 22, 30, 32) | Value |
|---|---|
| `DAC_Data_Type` | 0 |
| `DAC_Interpolation_Mode` | 3 (×3: 1.28 GSPS complex → 3.84 GSPS) |
| `DAC_Data_Width` | **10** (10 × 16 bit = 160-bit word, I/Q interleaved = the combiner format) |
| `DAC_Mixer_Type` / `DAC_NCO_Freq` | 2 (fine) / **−0.84 GHz** |
| `DAC_Nyquist` / `DAC_Invsinc_Ctrl` / `DAC_Decoder_Mode` | 1 / true (inverse-sinc on) / 0 |

| Tile setting | DAC0 | DAC1 | DAC2 | DAC3 |
|---|---|---|---|---|
| `Sampling_Rate` | 3.84 GSPS | 3.84 | 3.84 | 3.84 |
| `PLL_Enable` / `Refclk_Freq` | on / 256 MHz | on / 256 | on / 256 | on / 256 |
| `Clock_Source` / `Clock_Dist` | 4 / **1** | 4 / 0 | 4 / 0 | 4 / 0 |
| `Fabric_Freq` / `Outclk_Freq` | 256 / 240 MHz | 256 / 240 | 256 / 240 | 256 / 240 |
| `VOP` (output current) | 32 mA | 32 | 32 | 32 |
| `Multi_Tile_Sync` | true | true | true | true |

DAC tile 0 takes the 256 MHz reference from the `dac0_clk` board port and distributes it (`Clock_Dist = 1`); each
tile runs its own PLL to 3.84 GHz.

### 6.4 Control registers (PS `M_AXI_HPM0_FPD`, 64 bit, `pl_clk0` 100 MHz via `smartconnect_0`)

| Peripheral | Address | Configuration | Function |
|---|---|---|---|
| `axi_gpio_arstn` | 0xA001_0000 | 1 bit, all outputs, default 0 | `arstn` → `xpm_cdc_gen_1` (`xpm_cdc_sync_rst`, 4 stages) → `FPGA_clk` reset of timer, packetizer (z1), `hier_rx` (z2) |
| `axi_gpio_pma_rst` | 0xA002_0000 | 1 bit, all outputs, default 0 | → `xpm_cdc_gen_0` (sync to `init_clk`) → container `ini_pma_rst` and `util_ds_buf_1` OBUFDS `PMA_RST` (to the VU13P) |
| `axi_delay` (z2 only) | 0xA008_0000 | 32 bit, all outputs, **default 0x0000_0200** | `delay` of all eight `data_delay` |
| RFDC | 0xA004_0000 (256 K) | — | converter control, MTS |
| `axi_intc_0` | 0xA003_0000 | 1 level interrupt (RFDC `irq`) | — |
| `DMA_Ctrl` | 0xA000_0000 | `axi_lite_interface` + `status_reg` | EV1 MTS / capture control (`hier_mts`), not on the data path |

## 7. Serial links

### 7.1 Lane map

| z1 quad · lanes (C0 / C1) | VU13P quad · lanes (C0 / C1) | z2 quad · lanes (C0 / C1) | Data |
|---|---|---|---|
| X0Y1 · X0Y4-5 / **X0Y6-7** | X1Y8 (228) · X1Y32-33 / **X1Y34-35** | — | **ADC stream on C1** |
| X0Y2 · X0Y8-9 / X0Y10-11 | X1Y9 (229) · X1Y36-37 / X1Y38-39 | — | none |
| X0Y3 · X0Y12-13 / X0Y14-15 | X1Y10 (230) · X1Y40-41 / X1Y42-43 | — | none |
| X0Y4 · X0Y16-17 / X0Y18-19 | X1Y11 (231) · X1Y44-45 / X1Y46-47 | — | none |
| — | X1Y4 (224) · X1Y16-17 / X1Y18-19 | X0Y1 · X0Y4-5 / X0Y6-7 | broadcaster M00 / M01 |
| — | X1Y5 (225) · X1Y20-21 / X1Y22-23 | X0Y2 · X0Y8-9 / X0Y10-11 | M02 / M03 |
| — | X1Y6 (226) · X1Y24-25 / X1Y26-27 | X0Y3 · X0Y12-13 / X0Y14-15 | M04 / M05 |
| — | X1Y7 (227) · X1Y28-29 / X1Y30-31 | X0Y4 · X0Y16-17 / X0Y18-19 | M06 / M07 |

Reference clocks 156.25 MHz on MGTREFCLK0 of each quad (pins in `DESIGN.md` §3). GT serial pins are placed by the
Aurora IP location constraint. Lane pairing C0 ↔ C0 / C1 ↔ C1 across boards is assumed straight; the IBERT golden
projects confirm the quad pairing only.

### 7.2 What the link carries

* Aurora Framing: each AXIS frame (`tlast`) becomes one Aurora frame. With 2 lanes the 128-bit beat is striped over the
  two lanes; frames are separated by control blocks (one separator per frame), clock compensation is inserted by the
  core (3 cycles in 5000 assumed in the FIFO model).
* There is no CRC and no retransmission: a corrupted block is delivered as received; a frame lost to a lane error is
  simply missing at the receiver (§10).
* Only the ADC stream link (z1 X0Y1 C1 → VU13P X1Y8 C1) and the eight VU13P → z2 links carry data. All other cores
  train and stay idle (their status is visible on the VIOs).

## 8. Flow control, clock crossings, FIFO budget, throughput

### 8.1 Where back-pressure exists

| Point | `tready` honoured? | Protection |
|---|---|---|
| RFDC ADC → combiner → packetizer | no (RFDC has no ready) | z1 `tx_c1/cdc_fifo` (16) drains at `user_clk` with 17 % link headroom |
| `header_insertion` ↔ `out_fifo` ↔ Aurora TX (z1) | yes | Aurora TX pauses (gearbox, CC, separator) back-pressure into `out_fifo` (16) |
| Aurora RX (VU13P, z2) | no (Aurora has no RX ready) | VU13P `rx_fifo` (512); z2 `in_fifo` (512) |
| VU13P broadcaster | no (`HAS_TREADY 0`, D12) | `tx_fifo_c<n>` (512) per link |
| VU13P `tx_fifo` → slice → Aurora TX | yes | — |
| z2 `header_extraction` | yes (to `in_fifo` / `cdc_fifo`) | — |
| z2 `data_delay` | no (`s_axis_tready = 1`) | holding FIFO (1024) + the delay range (`TIMING_SYNC.md` §9) |
| z2 aligner → DAC | no (`m_axis_tready` ignored) | DAC is always ready |

### 8.2 Clock-domain crossings on the path

| Crossing | Method |
|---|---|
| z1 `FPGA_clk` → z1 `user_clk` (X0Y1) | `tx_c1/cdc_fifo`, async `axis_data_fifo` 16, 3 sync stages |
| VU13P `user_clk` (228) → `axis_aclk` | `link_x1y8/rx_fifo_c1`, async 512 |
| VU13P `axis_aclk` → `user_clk` (224–227) | `link_x1yN/tx_fifo_c<n>`, async 512 |
| z2 `user_clk` (X0Y1…X0Y4) → `FPGA_clk` | `rx_c<n>/cdc_fifo`, async 512 |
| link reset (`channel_up`) → FIFO / slice domains | `xpm_cdc_async_rst`, 4 stages |
| `arstn`, `pma_rst` GPIO (`pl_clk0`) → `FPGA_clk` / `init_clk` | `xpm_cdc_sync_rst`, 4 stages |
| Aurora TX out clocks vs board clocks | `set_clock_groups -asynchronous` (XDC) |

The VU13P clocks (`sys_clk`, 400 MHz `axis_aclk`) have no relation to z1/z2: every crossing is a FIFO with headroom.

### 8.3 FIFO budget

Simulated with the real RTL, the real FIFO depths, an Aurora TX model (gearbox pause 1 in 33, clock compensation
3 in 5000, one separator per frame), three independent user clocks and the 400 MHz VU13P clock
(`scripts/sim_chain/run_fifo.sh`, Vivado simset `sim_fifo` in `47dr2.xpr`):

| FIFO | Depth | Peak fill, normal | 1 µs VU13P TX stall | 3 µs stall |
|---|---|---|---|---|
| z1 `tx_c1/cdc_fifo` | 16 | 1 | 1 | 1 |
| z1 `tx_c1/out_fifo` | 16 | 4 | 4 | 4 |
| VU13P `rx_fifo_c1` | 512 | 1 | 1 | 1 |
| VU13P `tx_fifo_c<n>` | 512 | 4 | **321** | **512 — overflow, 450 beats lost** |
| z2 `rx_c<n>/in_fifo` | 512 | 1 | 1 | 1 |
| z2 `rx_c<n>/cdc_fifo` | 512 | 6 | 259 | 411 |
| z2 `hier_rx` holding FIFO | 1024 | 504 (= delay − transport) | 504 | 1024 (overflow) |

No loss in normal operation and with a 1 µs stall of one VU13P TX link; stall tolerance ≈ 512 beats ≈ **1.6 µs**.

### 8.4 Throughput

| Quantity | Value |
|---|---|
| ADC payload | 160 b × 256 MHz = **40.96 Gb/s** (1.28 GSPS complex, 16-bit I/Q) |
| Header | 64 b per 1024 words = +0.04 % |
| Link beats per 4 µs packet | 1280.5 data + 1 separator + 1 insertion stall ≈ **1282.5** |
| Link capacity per 4 µs | 400.391 MHz × 32/33 × 4 µs ≈ **1553 beats** (49.69 Gb/s), minus ≈ 0.06 % clock compensation |
| **Link utilisation** | **≈ 82.6 %** (17 % headroom) |
| VU13P fabric | 128 b × 400 MHz = 51.2 Gb/s (> link rate, `rx_fifo` never fills) |

## 9. Link start-up, reset and synchronisation

### 9.1 Power-up sequence of one quad

1. `ini_system` holds `pma_init` of core 0 high for ≈ 5.1 µs after configuration (511 `init_clk` cycles), or as long
   as `pma_rst` / `axi_gpio_pma_rst` is 1.
2. Core 0 brings up the QPLL; `auto_reset_aurora` releases core 0 `reset_pb` 4 `init_clk` cycles after `gt_pll_lock`.
3. Core 1 follows: its `reset_pb` is core 0 `sys_reset_out`, its `pma_init` is core 0 `gt_reset_out`.
4. Each core trains lane alignment and channel bonding with its partner on the other board; `lane_up[1:0]` then
   `channel_up` go high (VIOs).
5. `aurora_rstn` releases the core's link reset `arstn_c<n>` = `channel_up & !sys_reset_out` (VU13P core 1 since rev 0.12, §5.4);
   the `xpm_cdc_async_rst` stages release the FIFOs and slices in the fabric clock domain 4 cycles later.

The VU13P additionally holds the slice and broadcaster in reset while its own `ini_pma` is 1.

### 9.2 Packet synchronisation

There is no training pattern or sequence number on the data path. Synchronisation to the packet structure comes from:
* `tlast` carried by Aurora Framing end-to-end (z1 → VU13P → z2 unchanged);
* `sof` in `header_extraction_v2` = 1 after reset and after every `tlast` → the first beat after reset (or after a
  `tlast`) is taken as a header.

So the receiver is synchronised **only if its first received beat after reset is the first beat of a packet**. The
normal start order guarantees that: z2 and the VU13P links are up and idle before z1 starts sending (z1 sends nothing
until the time base starts, §3.3; the start procedure is in `TIMING_SYNC.md` §5).

### 9.3 Re-synchronisation rule

After any link drop, link reset or board reset while data is flowing: hold `arstn` low on z1 and z2, wait for all
`channel_up`, then restart the time base (`TIMING_SYNC.md` §5). A link that comes up in the middle of a packet
interprets a data beat as a header and stays misaligned (§10).

## 10. Error behaviour

| Event | What happens on the data path | Recovery |
|---|---|---|
| One packet lost on a link (lane error, link drop) | the 2 words carried across packets (§4.3) are missing → every later packet on that link is shifted by 64 bits → wrong samples and wrong times on that output until reset | restart (§9.3). Proposal P1: `PACKET_LENGTH = 1022` (64 + 1022 × 160 = 1278 whole beats, no carry) — simulated: a lost packet then only blanks its own 4 µs |
| ≥ 2 packets lost | time jump > `delay` + 1024 → `data_delay` guard freezes the due time (`TIMING_SYNC.md` §8.1) | restart |
| z2 link comes up mid-stream | first beat taken as header → misaligned output | restart |
| VU13P TX link stalls > 1.6 µs | that `tx_fifo` overflows, beats dropped (broadcaster has no ready) → as a lost packet, on that link only | restart |
| z2 holding FIFO overflow (`delay` too large) | `data_delay` ignores `tready` → samples lost | keep `delay` − transport < ≈ 1000 |
| Corrupted bits (no CRC) | delivered as received; a corrupted header gives a wrong time for one packet | none needed for data; time: see `TIMING_SYNC.md` §11 |
| VU13P core 1 drops (any core) | that core's FIFOs and slices are reset while its channel is down, data lost on that link | restart (§9.3) |

## 11. Debug on hardware

| Board | ILA | Clock | What to look at |
|---|---|---|---|
| z1 | `system_ila_1` | `FPGA_clk` | slot 1 combiner out, slot 0 packetizer out (`tuser` time, `tlast` every 1024) |
| z1 | `ila_x0y1` slot 1 | quad `user_clk` | 128-bit TX beats; first beat after `tlast`: header in `[127:64]` = `{0, 0, time}` |
| VU13P | `ila_x1y8` slot 3 | quad 228 `user_clk` | same beats received on X1Y8 C1 |
| VU13P | `ila_bcast` | `axis_aclk` | slot 0 input, slots 1–8 outputs; outputs must follow the input |
| VU13P | `ila_x1y4 … x1y7` slots 0/1 | quad `user_clk` | beats entering the eight TX cores |
| z2 | `ila_x0yN` slots 2/3 | quad `user_clk` | beats received on every quad |
| z2 | `hier_rx_x0y1/rx_c0/system_ila_0` | quad 1 `user_clk` | `header[63:0]` per packet (`err` is not meaningful, §4.4) |
| z2 | `hier_rx_x0yN/system_ila_<n>` | `FPGA_clk` | delay in/out, FIFO out, aligner out, `timestamp`, `sys_time`, `data_time`, `end_time` |
| all | `x0yN_core_status_<n>`, `x1yN_core_status_<n>` VIOs | quad `user_clk` | `channel_up`, `gt_pll_lock`, `lane_up[1:0]` |

Trigger on `tlast` to align a capture to a packet start (one packet ≈ 1281 beats fits in the 2048-deep link ILAs).

## 12. Verification

| Test | Tool | Result |
|---|---|---|
| End-to-end chain, delay 512 / 200 | `scripts/sim_chain/run.sh` = Vivado simset `sim_1` in `47dr2.xpr` (real RTL, 2 Aurora hops with random gaps, 3 user clocks) | every sample at the DAC exactly `delay + 1` cycles after its z1 ADC time; no drops; 50 498 samples checked |
| Delay 1400 | same | holding FIFO overflow (expected) |
| 1 / 2 lost packets | same, `LOSS` generic | misalignment until reset / time freeze (§10); `PACKET_LENGTH 1022` limits loss to one packet |
| FIFO budget, stalls 0 / 1 / 3 µs | `run_fifo.sh` = simset `sim_fifo` | §8.3 |
| Aurora settings | BD dump, 72 cores | all identical (§4.5) |
| Reset wiring | BD dump, 36 `aurora_rstn` | rev 0.11: 8 wrong on the VU13P; fixed in rev 0.12 (§5.4) |

Testbench note: the `align_err` and `tuser_mismatch` counters of `tb.v` / `tb_fifo.v` count almost every word. They
compare against the first output word (a start-up zero) and against `data_ts + 1` while the model stamps
`tuser = data_ts + 1` and the rebuild adds one more count after the first packet. The latency histogram (exact
`delay + 1` for every sample) is the valid check; the two counters should be fixed before they are used.

## 13. Revision history

| Rev | Date | Author | Changes |
|---|---|---|---|
| 1.0 | 2026-10-14 | Claude Code (for johnny@jxense.com) | First issue: per-module design and IP configuration of the whole signal path, read from the rev 0.11 block designs; VU13P core-1 reset defect (§5.4), `ini_system` one-cycle release and `header_extraction` `err` meaning documented. |
| 1.1 | 2026-10-14 | Claude Code (for johnny@jxense.com) | §5.4 defect fixed (design rev 0.12, D19), VU13P rebuilt; §9.1, §10, §12 updated. |
