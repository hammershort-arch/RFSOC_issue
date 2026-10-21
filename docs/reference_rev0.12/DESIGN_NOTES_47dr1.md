# 47DR1 (z1) — design notes

Project: `47dr1.xpr` · Vivado 2025.2 · part `xczu47dr-ffvg1517-2-i` · top `design_1_wrapper`
Source: copied from `~/Desktop/PJ22045_EV1/47DR_integrated_3` (original untouched). Part changed from `-2-e` to `-2-i`
(golden IBERT part); all IP upgraded.
GT pinout reference (read-only): `~/Desktop/board_test_item/test_item_47dr/project/ibert_47dr1To13p_ex`.
Local IP repo: `ip_repo/` (copy of `xczu47dr_new_adcdac/native/vivado/2025.2/ip` + `.../uisrc`).

## Role in the system (1R8T)
z1 is the **transmitter**: one 160-bit AXIS stream from ADC ch00 (tile 0, m00/m01) goes to the VU13P over one 2-lane Aurora; the VU13P
broadcasts it to 8 links toward z2.

```
RFDC m00/m01 (ADC tile0 ch0) → axi_stream_combininp_adc00 (160 b) → axis_packetizer_0
   → aurora_gty_47drto13p_0/S_AXIS_X0Y1_C1 → hier_tx_x0y1/tx_c1 (header_insertion) → hier_x0y1/aurora_x0y1_1 (X0Y6-7) → VU13P X1Y8 core1
```

### ADC → DAC map (z1)
| ADC ch (I/Q) | Combiner (2×80 → 160 b) | Destination |
|---|---|---|
| 00 (m00/m01) | axi_stream_combininp_adc00 | Aurora → VU13P (no DAC; s00 unused) |
| 02 (m02/m03) | axi_stream_combininp_adc02 | DAC s02 |
| 10 (m10/m11) | axi_stream_combininp_adc10 | DAC s10 |
| 12 (m12/m13) | axi_stream_combininp_adc12 | DAC s12 |
| 20 (m20/m21) | axi_stream_combininp_adc20 | DAC s20 |
| 22 (m22/m23) | axi_stream_combininp_adc22 | DAC s22 |
| 30 (m30/m31) | axi_stream_combininp_adc30 | DAC s30 |
| 32 (m32/m33) | axi_stream_combininp_adc32 | DAC s32 |
All combiners and RFDC AXIS run on FPGA_clk (256 MHz, util_ds_buf_0). Aurora RX outputs are not used in z1.

## Aurora 64B66B cores (8× 2-lane, 25.625 Gbps, 156.25 MHz MGTREFCLK0 of own quad)
Container BD `aurora_gty_47drto13p.bd` is identical to z2's. Every quad N=1..4 has the same three blocks at top level:
`hier_x0yN` (2 cores), `hier_tx_x0yN` (FIFO + header_insertion, inputs `S_AXIS_X0YN_C1` → core1, `S_AXIS_X0YN_C0` → core0)
and `hier_rx_x0yN` (header_extraction + FIFO, outputs `M_AXIS_X0YN_C0` ← core0, `M_AXIS_X0YN_C1` ← core1).

| Hierarchy | Quad (bank) | core0 lanes | core1 lanes | Peer (VU13P) | Use in z1 |
|---|---|---|---|---|---|
| hier_x0y1 | X0Y1 (128) | X0Y4-5 | X0Y6-7 | X1Y8 (228) | core1 TX = ADC ch00; RX unused |
| hier_x0y2 | X0Y2 (129) | X0Y8-9 | X0Y10-11 | X1Y9 (229) | link only |
| hier_x0y3 | X0Y3 (130) | X0Y12-13 | X0Y14-15 | X1Y10 (230) | link only |
| hier_x0y4 | X0Y4 (131) | X0Y16-17 | X0Y18-19 | X1Y11 (231) | link only |

## Refclk pins (`constrs_1/imports/new/design.xdc`, from golden ibert_47dr1To13p)
| Port | Quad | P / N |
|---|---|---|
| gt_x0y1_diff_ref | 128 | AA33 / AA34 |
| gt_x0y2_diff_ref | 129 | W33 / W34 |
| gt_x0y3_diff_ref | 130 | U33 / U34 |
| gt_x0y4_diff_ref | 131 | P31 / P32 |

## Other design content (kept from 47DR_integrated_3)
PS (zynq_ultra_ps_e), RFDC (ADC/DAC, MTS, sysref), DMA_Ctrl, hier_mts, ILAs/VIOs.

## Removed
- 2nd X0Y1 TX path (pulse generator → core1), x0y2 data_pg / data_valider hierarchies.
- `hier_0` pulse generator (deleted by user in GUI); `hier_tx_x0y1` ungrouped by user (packetizers at top level).
- **PARAM_RECORDER** (BDC + `axi_gpio_param_trigger`, `axi_gpio_param_length`, `xpm_cdc_gen_2`, `axis_broadcaster_0`);
  PS S_AXI_HP0/HP1 disabled; `smartconnect_0` NUM_MI 8→5.
- **phase_calibration_0/1**: `hier_rx_x0y1/M_AXIS_C0/C1` now drive DAC `s10`/`s12` directly. `vio_0` probes 5–9 (old
  phase-cal controls) are now unconnected.

## Scripts (`../scripts`)
`part_47dr.tcl 47dr1` (part change) · `mod_47dr1.tcl` (pass 1) · `mod2_47dr.tcl 47dr1` + `fix2_47dr.tcl 47dr1`
(PARAM_RECORDER removal, 8-core container hookup) · `mod3_47dr.tcl 47dr1` + `fin3_47dr.tcl 47dr1` (phase_cal removal)
· `mod4_container.tcl 47dr1` (X0Y3/X0Y4 flattened + hier_tx) · `mod8_container.tcl 47dr1` (uniform links) · `mod6_47dr1.tcl` (ADC→DAC loopbacks) · `run_build.sh 47dr1 [jobs]` → `build.tcl` (synth → impl → bitstream + reports in `reports/`).

## Naming convention (2026-10-14, `scripts/naming/`)
Every name is derived from what it is connected to (quad, Aurora core, direction); generated and checked by
`scripts/naming/gen_container.py` / `gen_top.py`, applied with `apply_container.tcl` / `apply_top.tcl` (`lib.tcl`).
| Level | Name |
|---|---|
| Container / top GT ports | `GT_SERIAL_TX_<QUAD>_C<n>`, `GT_SERIAL_RX_<QUAD>_C<n>` (n = Aurora core 0/1 of that quad) |
| Container data ports | `S_AXIS_<QUAD>_C<n>` → TX of core n, `M_AXIS_<QUAD>_C<n>` ← RX of core n |
| Refclk / board ports | unchanged (`gt_<quad>_diff_ref`, XDC) |
| `hier_<quad>` pins | `GT_SERIAL_TX_C<n>`, `GT_SERIAL_RX_C<n>`, `S_AXIS_TX_C<n>`, `M_AXIS_RX_C<n>`, `GT_REFCLK`, `arstn_c<n>`, `pma_init`, `user_clk_out` |
| TX/RX/link hierarchy pins | `S_AXIS_TX_C<n>`, `M_AXIS_TX_C<n>`, `S_AXIS_RX_C<n>`, `M_AXIS_RX_C<n>`, `user_clk` (Aurora), `axis_aclk` (fabric), `arstn_c<n>` |
| Per-core sub-hierarchies / leaf cells | `tx_c<n>`, `rx_c<n>`; `tx_fifo_c<n>`, `tx_slice_c<n>`, `rx_slice_c<n>`, `rx_fifo_c<n>`, `user_rst_sync_c<n>`, `axis_rst_sync_c<n>`, `cdc_fifo`, `in_fifo`, `out_fifo` |
| Wires (all levels) | named after their driver: `<cell>_<pin>`, or the input port / hierarchy input pin driving it |
| Kept for XDC / software | Aurora core cells `aurora_<quad>_<n>`, `hier_<quad>`, container instance names, AXI peripherals (address map) |

## Open items / assumptions
- Lane wiring assumed straight to VU13P (X0Y4-5 ↔ X1Y32-33 …).
- `aurora_gty_rst_47dr.bd` (standalone link-debug BD, not in the top hierarchy) still in the project and now stale.
- Synthesis/implementation not yet completed (see History).

## History
- **2026-10-13** Project created from 47DR_integrated_3; IP repo localized; part → `xczu47dr-ffvg1517-2-i`, IP upgraded
  (`part_47dr.tcl`).
- **2026-10-13** Pass 1 (`mod_47dr1.tcl`): TX only, 1 core (X0Y1 core0) carrying ADC1; x0y2 removed; XDC x0y2 removed.
- **2026-10-13** Synthesis attempt: wrapper missing from fileset → wrong auto-top; fixed in `run_synth.tcl`. OOC runs
  crashed (Vivado bus error under heavy parallel load from several sessions) — not a design error; to be rerun.
- **2026-10-13** Per user: keep 8× 2-lane Aurora on X0Y1–X0Y4 → container replaced by z2's 8-core container;
  XDC refclks 128–131 restored/added; X0Y1 core1 RX reconnected to hier_rx_x0y1; ADC1 still on X0Y1 core0.
- **2026-10-13** Per user: PARAM_RECORDER removed (see Removed). s10 reconnected after dangling-net fix (`fix2_47dr.tcl`).
- **2026-10-13** Per user: phase_calibration removed; DAC s10/s12 fed directly from hier_rx_x0y1. BD validated, wrapper
  regenerated, top = `design_1_wrapper`.
- **2026-10-13 22:02–22:06** User edited design_1 in the Vivado GUI (journal `~/Desktop/vivado.jou`): deleted `hier_0`
  (pulse generator), ungrouped `hier_tx_x0y1` (packetizers now at top level), and reconnected
  `axis_packetizer_0/m_axis` (ADC1) → `aurora_gty_47drto13p_0/S_AXIS_X0Y1` (+ system_ila_1 monitor).
  Note: `S_AXIS_X0Y1` feeds **core1** (lanes X0Y6-7 → VU13P X1Y8 core1); `axis_packetizer_1/s_axis` now has no
  source (tied off).
- **2026-10-13** Per user: container restructured so X0Y3/X0Y4 match X0Y1/X0Y2 — `rxq3/rxq4` groups flattened,
  added `hier_tx_x0y3` / `hier_tx_x0y4` (copies of hier_tx_x0y2, own-quad clocks/resets) with ports
  `S_AXIS_X0Y3[_1]`, `S_AXIS_X0Y4[_1]`; rx chain clock/reset re-hooked after ungroup (`mod4_container.tcl`,
  `refresh_design1.tcl`). BD validated, wrapper regenerated.
- **2026-10-13** ADC1 core mismatch resolved per user (option b): VU13P broadcaster now takes X1Y8 core1, matching
  z1's ADC1 on X0Y1 core1 (`S_AXIS_X0Y1`). No change in this project.
- **2026-10-13 22:25–22:33** User edited design_1 in the Vivado GUI (journal `~/Desktop/vivado.jou`): removed `vio_pma_rst`
  (Aurora `ini_pma_rst` now from `xpm_cdc_gen_0/dest_rst_out`), `vio_arestn` (`sync_pulse_to_level_1/rst_n` from
  `xpm_cdc_gen_1/dest_rst_out`), `axis_packetizer_1`, `ila_1`, `system_ila_0`, ilslice/ilconcat/ilconstant, the
  phase-cal VIO nets and `hier_rx_x0y1` (Aurora RX no longer used in z1); Aurora TX source changed to ADC ch00
  (`axi_stream_combininp_0` → `axis_packetizer_0`); ADC ch10 looped back to DAC s10 (`axi_stream_combininp_2`);
  container cell upgraded (`upgrade_bd_cells`).
- **2026-10-13** Per user: remaining ADC channels looped back to the same-index DAC like ch10 — new combiners
  `axi_stream_combininp_adc12/20/22/30/32` → DAC s12/s20/s22/s30/s32 (`mod6_47dr1.tcl`). BD validated, wrapper
  regenerated, top = `design_1_wrapper`.
- **2026-10-13** Per user ("all links the same"): container links made identical (`mod8_container.tcl`, both 47DR
  projects): `hier_tx_x0y2` core1 FIFO reset now from its own `hier_x0y2/arstn1` (was X0Y1's — original-design slip);
  `hier_tx_x0y1` reset pins renamed to `m_axis_aresetn`/`m_axis_areset1`; unused `hier_rx_x0y1/m_axis_aresetn`
  removed. All four quads now have identical TX/RX clock/reset wiring (debug ILA kept in `hier_rx_x0y1` only).
- **2026-10-14** Build #2: synth_1 failed — project still listed BlockSrcs filesets of the deleted
  `phase_calibration_inst_*` / `PARAM_RECORDER_inst_*` container instances → `build.tcl` now deletes BlockSrcs
  filesets whose `.bd` no longer exists. (Build #1 had failed on SIGBUS OOC crashes — fixed with
  `XILINX_LOCAL_USER_DATA=no`.)
- **2026-10-14 01:18** Build #3 crashed (segfault in `update_compile_order`): `build.tcl` deleted the BlockSrcs fileset of
  the live `aurora_gty_rst_47dr` container because `run_build.sh` had just removed its gen cache. Fixed: `run_build.sh`
  no longer clears that cache; `build.tcl` deletes only `phase_calibration_inst_*` / `PARAM_RECORDER_inst_*` filesets.
  The crashed run had already saved `47dr1.xpr` without that fileset (Vivado recreates it when `aurora_gty_rst_47dr` is
  regenerated).
- **2026-10-14** Check: no design change in this project since 2026-10-13 23:11. ⚠ The VU13P now takes the broadcaster
  source from X1Y8 **core0** (user edit), while z1 still sends ADC ch00 on X0Y1 **core1** (`S_AXIS_X0Y1`) — awaiting
  user decision.
- **2026-10-14** End-to-end check of the 1R8T data path (BD trace + RTL simulation `scripts/sim_chain/run.sh`, xsim,
  real RTL: axis_packetizer → header_insertion_v2 → 2 Aurora hops w/ back-pressure gaps → header_extraction_v2 →
  data_delay → FIFO 1024 → data_aligner). Verified: all Aurora cores Framing, 25.625 G, 2-lane, lanes as tabled;
  tuser = {24'b0, timer[39:0]} on z1; 160 b → 128 b (+64 b header once per 1024-beat packet) → 160 b with tuser
  rebuilt per beat; RFDC z1 ADC00 and z2 DACs both 3.84 GSPS ×3 dec/int = 1.28 GSPS, 5 IQ/clk @ 256 MHz.
  Sim results: delay 512 and 200 → every sample on the DAC exactly `delay+1` cycles after its z1 timestamp, no gaps,
  no drops; 40-bit timer wrap passes cleanly. Limits found:
  (1) delay − link latency must stay < ~1000 (z2 `hier_rx` FIFO depth 1024; delay 1400 → overflow, samples lost —
  `data_delay` ignores tready); (2) losing 1 packet on any link → 64-bit word misalignment, garbage until reset
  (packet = 64 + 1024×160 b = 1280.5 beats, the half beat is carried into the next packet); PACKET_LENGTH 1022 makes
  packets beat-aligned and recovers; (3) a timestamp jump > delay+1024 (≥2 lost packets) freezes `data_delay`'s
  timestamp guard → z2 output stops until reset; (4) z1/z2 timers only agree if both boards' FPGA_clk share a reference
  and both `arstn` are released before the same SYSREF pulse.
- **2026-10-14** Per user: ADC link stays on **X0Y1 core1**; VU13P broadcaster reverted to X1Y8 core1 to match.
- **2026-10-14** Per user: full naming pass (see *Naming convention*): container (220 renames + 338 wires; e.g.
  `S_AXIS_X0Y1`→`S_AXIS_X0Y1_C1` — the old name hid that it feeds core1; `GT_SERIAL_TX_3`→`GT_SERIAL_TX_X0Y1_C0`;
  wires named after wrong quads like `aurora_x0y4_0_*` inside hier_x0y1, `rxq3_*`, `hier_x0y13_*` fixed) and design_1
  (GT ports, combiners `axi_stream_combininp_adc00/02/10`, RF ports `vout02/10/12/20/22/30/32` now match their DAC pin —
  the old `vout01` was DAC ch02 etc., 76 wires). Checks: 32/32 container ports match traced core; net counts unchanged;
  validate clean; XDC ports present. Note: stale `aurora_gty_rst_47dr.bd` still instantiates the container with the old
  port names (not in the build hierarchy).
- **2026-10-14** Per user: FIFO depths of every link read from Vivado (`scripts/check/fifo_report.tcl`): z1 TX
  cdc/out 16/16, VU13P rx/tx 512/512, z2 in/cdc 512/512, z2 hold 1024. FIFO-budget simulation with header/framing
  overhead and Aurora pause model (`scripts/sim_chain/run_fifo.sh`): link load ≈ 82.6 %, no loss in normal operation
  or with a 1 µs VU13P TX stall (peak 321/512); a 3 µs stall overflows the VU13P TX FIFO. System design document
  `docs/DESIGN.md` (rev 0.9) and deck `docs/pj22045_1r8t_design.pptx` written in the format of
  `~/Downloads/serdes_selecio_axis/docs`.
- **2026-10-14** Per user: `docs/DESIGN.md` rev 0.10 — §6 *Time base and timers (whole system)* added; DESIGN.docx / deck regenerated.
- **2026-10-14 12:41** Per user: build #4 started (synth → impl → bitstream, `run_build.sh 47dr1 8`, log `scripts/build_47dr1.log`) on the renamed rev 0.10 designs; results pending.
- **2026-10-14 12:43** Build #4 attempt 1 crashed (segfault in `update_compile_order`) right after `build.tcl` deleted the leftover `PARAM_RECORDER_inst_0` / `phase_calibration_inst_1` BlockSrcs filesets. Fix: fileset deletion removed from `build.tcl`; the stale `phase_calibration_inst_1` FileSet block removed from `47dr1.xpr` with Vivado closed (backup `backup/47dr1_pre_mod11.xpr`; `scripts/mod11_47dr_remove_unused_bd.tcl` confirmed the unused BDs are no longer registered). Build #4 relaunched.
- **2026-10-14 12:55** Build #4 attempt 2: synth_1 failed again on the missing `phase_calibration_inst_1.bd` — Vivado re-added the fileset from a stale `BlockContainer` entry in the generated `47dr1.gen/sources_1/bd/design_1/design_1.bxml`. Removed that entry (and the FileSet block in `47dr1.xpr`) with Vivado closed; backups in `backup/`. Relaunched.
- **2026-10-14** Per user: debug ILAs (`mod12_add_ila.tcl`): `ila_x0y1`…`ila_x0y4` in the container (TX C0/C1, RX C0/C1,
  2048 deep); `system_ila_1` slot 1 = ADC combiner `adc00`.
- **2026-10-14** MTS clock-crossing constraint added to `design.xdc` (D16): false path `waitsysref` → `waitforsysref_d1`
  + `ASYNC_REG`; build #4 had failed only these two paths (as the original project).
- **2026-10-14** Build #5 (with ILAs): timing met (WNS +0.008 ns, WHS +0.010 ns), 16 GTs X0Y4–X0Y19 and refclk
  pins = golden, DRC warnings only, no methodology critical warnings.
- **2026-10-14** Per user: unused sources removed (D18): `aurora_gty_rst_47dr.bd`, PARAM_RECORDER / phase_calibration
  BDs, standalone IPs, ~40 RTL files; backup `backup/pre_cleanup_20261014.tgz`.
- **2026-10-14** XSA: `47dr1/z1_47dr1.xsa` (`write_hw_platform -fixed -include_bit`, `scripts/export_xsa.tcl`). Release rebuild
  started 14:23 because the cleanup left the runs out of date.
- **2026-10-14 15:00** Release `PJ22045_1R8T_release_rev0.11_20261014.tar.gz` (45 MB, project root): bitstreams + .ltx, z1/z2 XSA, docs, reports, sources; all runs up to date, 1815 files SHA256-checked after extraction (`scripts/release/make_release.sh`).
- **2026-10-14** Per user: two detailed documents in the format of `docs/DESIGN.docx`: `docs/SIGNAL_TRANSMISSION.md/.docx`
  (every module and IP configuration on the signal path, links, flow control, start-up, errors) and `docs/TIMING_SYNC.md/.docx`
  (time base, SYSREF, stamping, header carry/rebuild, `data_delay`/`data_aligner` design, latency, alignment, failure modes,
  bring-up). IP values read from a read-only dump of all BDs; `scripts/docs/make_docx.py <NAME>` now builds any of the three.
  Findings (not fixed): PL_SYSREF has no input-delay constraint (timer start edge untimed); RTL analysis of `data_delay` guard /
  `data_aligner` epoch corrects DESIGN.md §6.9 rows (z1 reset, z2 reset, delay change).
- **2026-10-14** Docs: all three documents use generated figures (`scripts/docs/make_figs.py` → `docs/fig/`) instead of ASCII diagrams; DESIGN.md rev 0.12 (D19 VU13P reset fix, D20, §6.9 corrected). No change to this project.
- **2026-10-14 17:33** Release `PJ22045_1R8T_release_rev0.12_20261014.tar.gz` (52 MB, 1843 files SHA256-checked): VU13P build #6 (D19), z1/z2 build #5, three documents + figures.
