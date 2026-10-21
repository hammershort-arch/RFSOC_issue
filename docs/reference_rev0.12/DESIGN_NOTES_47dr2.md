# 47DR2 (z2) — design notes

Project: `47dr2.xpr` · Vivado 2025.2 · part `xczu47dr-ffvg1517-2-i` · top `design_1_wrapper`
Source: copied from `~/Desktop/PJ22045_EV1/47DR_integrated_3` (original untouched). Part changed from `-2-e` to `-2-i`
(golden IBERT part); all IP upgraded.
GT pinout reference (read-only): `~/Desktop/board_test_item/test_item_47dr/project/ibert_47dr2To13p_ex`.
Local IP repo: `ip_repo/`.

## Role in the system (1R8T)
z2 is the **receiver**: 8× 2-lane Aurora from the VU13P (each carrying the broadcast z1 ADC1 stream), each driving one
RFSoC DAC channel.

```
VU13P X1Y4..X1Y7 ─► aurora core ─► header_extraction (container) ─► hier_rx_x0yN (delay → FIFO → aligner) ─► DAC
```

## Aurora 64B66B cores (8× 2-lane, 25.625 Gbps, 156.25 MHz MGTREFCLK0 of own quad)

| Hierarchy | Quad (bank) | core0 / core1 lanes | Peer (VU13P) | RX chain | DAC (core0 / core1) |
|---|---|---|---|---|---|
| hier_x0y1 | X0Y1 (128) | X0Y4-5 / X0Y6-7 | X1Y4 (224) | hier_rx_x0y1 | s10 / s12 |
| hier_x0y2 | X0Y2 (129) | X0Y8-9 / X0Y10-11 | X1Y5 (225) | hier_rx_x0y2 | s00 / s02 |
| hier_x0y3 | X0Y3 (130) | X0Y12-13 / X0Y14-15 | X1Y6 (226) | hier_rx_x0y3 | s20 / s22 |
| hier_x0y4 | X0Y4 (131) | X0Y16-17 / X0Y18-19 | X1Y7 (227) | hier_rx_x0y4 | s30 / s32 |

Container: every quad has `hier_x0yN` / `hier_tx_x0yN` / `hier_rx_x0yN` at top level
(`S_AXIS_X0YN_C1` → core1, `S_AXIS_X0YN_C0` → core0 — naming inherited from the original).

`hier_rx_x0y2..4` (in design_1) are copies of `hier_rx_x0y1` (data_delay → axis_data_fifo → data_aligner, with ILAs); shared
`delay` (vio_data_delay), `timestamp` (timer_1), clock = FPGA_clk 256 MHz, reset = vio_arestn.
Container ports `M_AXIS_X02Y*` renamed to `M_AXIS_X0Y2*`.

DAC tile 3 (`s30/s32`) mirrors tile 2: 3.84 GSPS, outclk 240 MHz, data width 10 (160-bit AXIS), interpolation 3,
fine mixer, NCO −0.84, invsinc on. Tile 3 clock-source settings left as in the original.

## Refclk pins (`constrs_1/imports/new/design.xdc`, from golden ibert_47dr2To13p)
| Port | Quad | P / N |
|---|---|---|
| gt_x0y1_diff_ref | 128 | AA33 / AA34 |
| gt_x0y2_diff_ref | 129 | W33 / W34 |
| gt_x0y3_diff_ref | 130 | U33 / U34 |
| gt_x0y4_diff_ref | 131 | P31 / P32 |

## Other design content (kept from 47DR_integrated_3)
PS, RFDC, DMA_Ctrl, hier_mts, ILAs/VIOs, TX side (ADC1 → X0Y1 core0, pulse gen → X0Y1 core1, data_pg → X0Y2) still
present; the VU13P does not consume z2's TX data.

## Removed
- ADC loopback to DAC s00/s02 (`axi_stream_combininp_adc00/1` outputs now unused); x0y2 `data_valider` checker hierarchy.
- **PARAM_RECORDER** (BDC + `axi_gpio_param_trigger`, `axi_gpio_param_length`, `xpm_cdc_gen_2`, `axis_broadcaster_0`);
  PS S_AXI_HP0/HP1 disabled; `smartconnect_0` NUM_MI 8→5.
- **phase_calibration_0/1**: `hier_rx_x0y1/M_AXIS_C0/C1` drive DAC `s10`/`s12` directly; `vio_0` probes 5–9 unconnected.

## Scripts (`../scripts`)
`part_47dr.tcl 47dr2` · `mod_47dr2.tcl` (8-core container, rx chains, DAC map, DAC tile 3) · `mod2_47dr.tcl 47dr2` +
`fix2_47dr.tcl 47dr2` (PARAM_RECORDER removal) · `mod3_47dr.tcl 47dr2` + `fin3_47dr.tcl 47dr2` (phase_cal removal) ·
`run_synth.tcl 47dr2`.

Gotcha: BD container parent does not refresh when the child only adds ports — delete
`47dr2.gen/sources_1/bd/design_1/bd/aurora_gty_47drto13p_inst_1` before reopening design_1.

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
- Lane wiring assumed straight to VU13P.
- DAC channel order (which Aurora → which DAC) is a proposal; confirm against board/analog requirements.
- `aurora_gty_rst_47dr.bd` (standalone link-debug BD) still in the project and now stale.
- Synthesis/implementation not yet completed (see History). `axi_delay` at 0xA008_0000.

## History
- **2026-10-13** Project created from 47DR_integrated_3; IP repo localized; part → `xczu47dr-ffvg1517-2-i`, IP upgraded.
- **2026-10-13** `mod_47dr2.tcl`: container extended to 8 cores (X0Y3/X0Y4 copies of X0Y2), rx chains for X0Y2–4,
  DAC map above, ADC loopback removed, DAC tile 3 mirrored; XDC refclk 130/131 + clock groups. BD validated.
- **2026-10-13** Synthesis attempt synthesized wrong auto-top (`data_store`, wrapper missing from fileset) — fixed;
  rerun crashed (Vivado bus error under heavy parallel load from several sessions) — to be rerun.
- **2026-10-13** Per user: PARAM_RECORDER removed; s10 reconnected after dangling-net fix.
- **2026-10-13** Per user: phase_calibration removed; DAC s10/s12 fed directly. BD validated, wrapper regenerated,
  top = `design_1_wrapper`.
- **2026-10-13** Per user: container restructured so X0Y3/X0Y4 match X0Y1/X0Y2 — `rxq3/rxq4` groups flattened,
  added `hier_tx_x0y3` / `hier_tx_x0y4` (copies of hier_tx_x0y2, own-quad clocks/resets) with ports
  `S_AXIS_X0Y3[_1]`, `S_AXIS_X0Y4[_1]`; rx chain clock/reset re-hooked after ungroup (`mod4_container.tcl`,
  `refresh_design1.tcl`). BD validated, wrapper regenerated.
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
- **2026-10-14 09:5x–10:05** User edited design_1 in the Vivado GUI (journal `~/Desktop/vivado.jou`): removed the unused
  ADC side (`axi_stream_combininp_0/1/2`), top-level `hier_tx_x0y1`/`hier_tx_x0y2`, `hier_0`, `system_ila_1`, `ila_1`,
  il* constants/concat/slice, `vio_0` (old phase-cal), `vio_arestn`, `vio_pma_rst`, `vio_data_delay`. Aurora
  `ini_pma_rst` now from `xpm_cdc_gen_0` (axi_gpio_pma_rst), `sync_pulse_to_level_1/rst_n` from `xpm_cdc_gen_1`.
  New `axi_delay` (axi_gpio, all outputs, 32 b, default 0x200, FPGA_clk, smartconnect M05, NUM_MI 6) drives `delay`
  of all four `hier_rx_x0yN`; `data_delay.v` `delay` input narrowed to 32 b and module refs updated.
  Check (`validate_bd_design`): all 8 Aurora RX → DAC paths intact (X0Y1→s10/s12, X0Y2→s00/s02, X0Y3→s20/s22,
  X0Y4→s30/s32); delay pins 32 b everywhere. ⚠ CRITICAL WARNING BD 41-1356: `/axi_delay/S_AXI/Reg` not assigned in
  `/zynq_ultra_ps_e_0/Data` (needs `assign_bd_address`). Note: `axi_delay` is held in reset by `irstn`
  (= axi_gpio_arstn via xpm_cdc_gen_1) — SW must release arstn before writing the delay register.
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
- **2026-10-14** Per user: `axi_delay` assigned at **0xA008_0000** (64 KB) in `/zynq_ultra_ps_e_0/Data` (`mod10_47dr2.tcl`).
- **2026-10-14** Per user: full naming pass (see *Naming convention*): container as in 47dr1 (220 renames + 338 wires),
  design_1: GT ports, `hier_rx_x0yN` pins `S_AXIS_C0/C1`, `M_AXIS_C0/C1`, RF ports renamed to the DAC/ADC pin they
  carry (`vout02`=DAC ch02 … was `vout01`), 109 wires. Checks as in 47dr1; validate clean.
- **2026-10-14** Per user: FIFO depths of every link read from Vivado (`scripts/check/fifo_report.tcl`): z1 TX
  cdc/out 16/16, VU13P rx/tx 512/512, z2 in/cdc 512/512, z2 hold 1024. FIFO-budget simulation with header/framing
  overhead and Aurora pause model (`scripts/sim_chain/run_fifo.sh`): link load ≈ 82.6 %, no loss in normal operation
  or with a 1 µs VU13P TX stall (peak 321/512); a 3 µs stall overflows the VU13P TX FIFO. System design document
  `docs/DESIGN.md` (rev 0.9) and deck `docs/pj22045_1r8t_design.pptx` written in the format of
  `~/Downloads/serdes_selecio_axis/docs`.
- **2026-10-14** Per user: `docs/DESIGN.md` rev 0.10 — §6 *Time base and timers (whole system)* added; DESIGN.docx / deck regenerated.
- **2026-10-14 12:41** Per user: build #4 started (synth → impl → bitstream, `run_build.sh 47dr2 8`, log `scripts/build_47dr2.log`) on the renamed rev 0.10 designs; results pending.
- **2026-10-14 12:43** Build #4 attempt 1 crashed (segfault in `update_compile_order`) right after `build.tcl` deleted the leftover `PARAM_RECORDER_inst_0` / `phase_calibration_inst_1` BlockSrcs filesets. Fix: fileset deletion removed from `build.tcl`; the stale `phase_calibration_inst_1` FileSet block removed from `47dr2.xpr` with Vivado closed (backup `backup/47dr2_pre_mod11.xpr`; `scripts/mod11_47dr_remove_unused_bd.tcl` confirmed the unused BDs are no longer registered). Build #4 relaunched.
- **2026-10-14 12:55** Build #4 attempt 2: synth_1 failed again on the missing `phase_calibration_inst_1.bd` — Vivado re-added the fileset from a stale `BlockContainer` entry in the generated `47dr2.gen/sources_1/bd/design_1/design_1.bxml`. Removed that entry (and the FileSet block in `47dr2.xpr`) with Vivado closed; backups in `backup/`. Relaunched.
- **2026-10-14 13:35** Build #5 (with ILAs): synth_1 failed — module `aurora_gty_47drto13p_inst_1_cdc_fifo_4` not found; the regenerated container had no OOC runs for most of its IPs (57 vs 70 in 47dr1). `build.tcl` now runs `generate_target` + `create_ip_run` on the top BD before launching. Relaunched.
- **2026-10-14** Per user: debug ILAs (`mod12_add_ila.tcl`): `ila_x0y1`…`ila_x0y4` in the container (TX C0/C1, RX C0/C1,
  2048 deep).
- **2026-10-14** MTS clock-crossing constraint added to `design.xdc` (D16): false path `waitsysref` → `waitforsysref_d1`
  + `ASYNC_REG`; build #4 had failed only these two paths (as the original project).
- **2026-10-14** Build #5 (with ILAs): timing met (WNS +0.023 ns, WHS +0.010 ns), 16 GTs X0Y4–X0Y19 and refclk
  pins = golden, DRC warnings only, no methodology critical warnings.
- **2026-10-14** Per user: unused sources removed (D18): `aurora_gty_rst_47dr.bd`, PARAM_RECORDER / phase_calibration
  BDs, standalone IPs, ~40 RTL files; five IPs in their own filesets were first deleted on disk only (project failed to open) — restored from backup and removed with `remove_files`; backup `backup/pre_cleanup_20261014.tgz`.
- **2026-10-14** XSA: `47dr2/z2_47dr2.xsa` (`write_hw_platform -fixed -include_bit`, `scripts/export_xsa.tcl`). Release rebuild
  started 14:23 because the cleanup left the runs out of date.
- **2026-10-14 15:00** Release `PJ22045_1R8T_release_rev0.11_20261014.tar.gz` (45 MB, project root): bitstreams + .ltx, z1/z2 XSA, docs, reports, sources; all runs up to date, 1815 files SHA256-checked after extraction (`scripts/release/make_release.sh`).
- **2026-10-14** Per user: testbenches added to the 47dr2 project. `sim_1` = `tb.v` (end-to-end chain, generic DELAY=512),
  new simset `sim_fifo` = `tb_fifo.v` (FIFO budget, STALL_NS=1000 TXDEP=16); both imported under `47dr2.srcs/<simset>/imports/sim_chain/`,
  SOURCE_SET empty (BD not compiled), RTL referenced from `sources_1/imports/new` + `axis_packetizer.v` remote-referenced from 47dr1;
  runtime `-all` (tb calls $finish at 200 µs). `run.sh`/`run_fifo.sh` packetizer path fixed (file only exists in 47dr1).
  Verified `launch_simulation -simset sim_1`: DAC latency − delay = 1 for all 50498 samples, no drops. Open item: the tb's
  `align_err`/`tuser_mismatch` counters fire on ~every beat (tuser − data_ts = 2 constant) — checker offset, not yet fixed.
- **2026-10-14** Per user: two detailed documents in the format of `docs/DESIGN.docx`: `docs/SIGNAL_TRANSMISSION.md/.docx`
  (every module and IP configuration on the signal path, links, flow control, start-up, errors) and `docs/TIMING_SYNC.md/.docx`
  (time base, SYSREF, stamping, header carry/rebuild, `data_delay`/`data_aligner` design, latency, alignment, failure modes,
  bring-up). IP values read from a read-only dump of all BDs; `scripts/docs/make_docx.py <NAME>` now builds any of the three.
  Findings (not fixed): PL_SYSREF has no input-delay constraint (timer start edge untimed); RTL analysis of `data_delay` guard /
  `data_aligner` epoch corrects DESIGN.md §6.9 rows (z1 reset, z2 reset, delay change).
- **2026-10-14** Docs: all three documents use generated figures (`scripts/docs/make_figs.py` → `docs/fig/`) instead of ASCII diagrams; DESIGN.md rev 0.12 (D19 VU13P reset fix, D20, §6.9 corrected). No change to this project.
- **2026-10-14 17:33** Release `PJ22045_1R8T_release_rev0.12_20261014.tar.gz` (52 MB, 1843 files SHA256-checked): VU13P build #6 (D19), z1/z2 build #5, three documents + figures.
