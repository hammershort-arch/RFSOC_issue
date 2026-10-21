# VU13P — design notes

Project: `vu13p.xpr` · Vivado 2025.2 · part `xcvu13p-fhgb2104-2-i` · top `aurora_gty_vu13p_rst_wrapper`
Source: copied from `~/Desktop/PJ22045_EV1/13P_integrated_2` (original untouched).
GT pinout reference (read-only): `~/Desktop/board_test_item/test_item_13p/project/ibert_13pTo47DR1_ex`, `ibert_13pTo47DR2_ex`.

## Role in the system (1R8T)

```
z1 (47dr1) ADC ch00 ──2-lane──► VU13P X1Y8 core1 ──► axis_broadcaster_0 (1→8) ──► 8× 2-lane ──► z2 (47dr2) → 8 DACs
```

- **RX from z1**: 8 cores on quads 228–231 (mirror of z1's 8 cores) so every z1 lane pair has a partner.
  Only X1Y8 core1 (lanes X1Y34-35) carries data (z1 ADC ch00, from z1 X0Y1 core1 / X0Y6-7):
  `link_x1y8` → `M_AXIS_X1Y8_C1` → `axis_slr_x1y8_to_tx`  (core1 again since 2026-10-14) (axis_register_slice, Multi_SLR_Crossing, 1 crossing,
  +1 pipeline each side) → axis_broadcaster_0 — quad 228 and quads 224–227 are in different SLRs.
- **TX to z2**: 8 cores on quads 224–227, each fed by one broadcaster output.
- 13P↔13P link (`aurora_gty_vu13ptovu13p`, Quad_X0Y11 / X0Y13) kept unchanged; its RX is no longer the broadcaster source.

## Aurora 64B66B cores (all 2-lane, 25.625 Gbps, 156.25 MHz MGTREFCLK0 of own quad)

Container BD: `aurora_gty_vu13pto47dr.bd` (instance `aurora_gty_vu13pto47_0` in top BD `aurora_gty_vu13p_rst.bd`).
Every quad N = 4..11 has the **same two blocks** at container top level:

- `hier_x1yN` — 2 Aurora cores (core0 owns the QPLL/user clock, core1 shares it) + status VIOs + reset helpers.
- `link_x1yN` — identical copy of the original X1Y4 plumbing:
  - TX: `S_AXIS_X1YN_C0` → tx_fifo_c0 (axis_aclk → user_clk) → tx_slice_c0 → core0;
        `S_AXIS_X1YN_C1` → tx_fifo_c1 → tx_slice_c1 → core1
  - RX: core0 → rx_slice_c0 → rx_fifo_c0 (user_clk → axis_aclk) → `M_AXIS_X1YN_C0`;
        core1 → rx_slice_c1 → rx_fifo_c1 → `M_AXIS_X1YN_C1`
  - resets: user_rst_sync_c0/c1 (core channel-up rstn → user_clk), axis_rst_sync_c0/c1 (→ axis_aclk)
- `system_ila_0` (debug) monitors X1Y4 only: core0 RX, core0 TX, core1 TX at the hier_x1y4 boundary.

| Quad | Bank | core0 lanes | core1 lanes | Peer | Use |
|---|---|---|---|---|---|
| X1Y4 | 224 | X1Y16-17 | X1Y18-19 | z2 X0Y1 | TX: broadcaster M00 → `S_AXIS_X1Y4_C0`, M01 → `S_AXIS_X1Y4_C1` |
| X1Y5 | 225 | X1Y20-21 | X1Y22-23 | z2 X0Y2 | TX: M02 / M03 |
| X1Y6 | 226 | X1Y24-25 | X1Y26-27 | z2 X0Y3 | TX: M04 / M05 |
| X1Y7 | 227 | X1Y28-29 | X1Y30-31 | z2 X0Y4 | TX: M06 / M07 |
| X1Y8 | 228 | X1Y32-33 | X1Y34-35 | z1 X0Y1 | RX: **core1** `M_AXIS_X1Y8_C1` → axis_broadcaster_0 |
| X1Y9 | 229 | X1Y36-37 | X1Y38-39 | z1 X0Y2 | link only |
| X1Y10 | 230 | X1Y40-41 | X1Y42-43 | z1 X0Y3 | link only |
| X1Y11 | 231 | X1Y44-45 | X1Y46-47 | z1 X0Y4 | link only |

Unused container AXIS ports (TX inputs of X1Y8–X1Y11, RX outputs other than `M_AXIS_X1Y8_C1`) are left open
(inputs tied to 0 by IPI).

## Refclk pins (`constrs_1/new/physical.xdc`, from golden IBERT)

| Port | Quad | P / N | Golden |
|---|---|---|---|
| gt_x1y4_diff_ref | 224 | AW9 / AW8 | 13pTo47DR2 q0 |
| gt_x1y5_diff_ref | 225 | AT11 / AT10 | 13pTo47DR2 q1 |
| gt_x1y6_diff_ref | 226 | AM11 / AM10 | 13pTo47DR2 q2 |
| gt_x1y7_diff_ref | 227 | AH11 / AH10 | 13pTo47DR2 q3 |
| gt_x1y8_diff_ref | 228 | AD11 / AD10 | 13pTo47DR1 q0 |
| gt_x1y9_diff_ref | 229 | Y11 / Y10 | 13pTo47DR1 q1 |
| gt_x1y10_diff_ref | 230 | T11 / T10 | 13pTo47DR1 q2 |
| gt_x1y11_diff_ref | 231 | M11 / M10 | 13pTo47DR1 q3 |

All 6.4 ns `create_clock`; each `aurora_x1yN` TX out clock is async to `sys_clk`. GT serial pins are placed by the
Aurora IP location (no PACKAGE_PIN needed). `pblock_1` (X1Y4 GT region) kept from the original.

## Clocks / resets (unchanged from original)
- `sys_clk` 100 MHz (BA15) → `init_clk`; `clk_wiz_0` 400 MHz → `s_axis_aclk` (broadcaster / FIFOs).
- `pma_rst` (AU16/AV16 LVDS) → `hier_rst/ini_system` → `pma_init` of all cores.

## Scripts (in `../scripts`, run with `vivado -mode batch -source ...` from this dir)
- `mod_vu13p.tcl` — pass 1: x1y8 RX-only, 3 TX quad copies (X1Y5-7), broadcaster 1→8.
- `mod2_vu13p_a.tcl` — pass 2a: hier_x1y8 rebuilt with 2 cores + hier_x1y9..x1y11 (mirror of z1).
- `mod2_vu13p_b.tcl` — pass 2b: top-level ports, wrapper, top.
- `mod5_vu13p.tcl` — broadcaster source x1y8 core1 (superseded by pass 7).
- `mod7_vu13p.tcl` / `mod7b_vu13p.tcl` / `mod7c_vu13p.tcl` — uniform `link_x1yN` for all quads, broadcaster ←
  `M_AXIS_X1Y8_C1`, ILA re-pointed.
- `mod9_vu13p.tcl` — SLR-crossing register slice in front of the broadcaster.
- `run_build.sh vu13p [jobs]` → `build.tcl` — clears stale container cache, synth → impl → bitstream, reports in `reports/`.

Gotcha: a BD container parent does not refresh when the child only *adds* ports — delete
`vu13p.gen/sources_1/bd/aurora_gty_vu13p_rst/bd/aurora_gty_vu13pto47dr_inst_0` before reopening the top BD.

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
- Lane-level wiring 13P↔47DR assumed straight (X1Y32-33 ↔ z1 X0Y4-5, etc.); golden IBERT only confirms quad pairing.
- Unused cores' TX AXIS inputs are left unconnected (tvalid = 0); RX outputs of x1y4..x1y7 / x1y9..x1y11 unused.
- Build #3 bitstream predates the 2026-10-14 naming pass; rebuild needed.

## History
- **2026-10-13** Project created from 13P_integrated_2 (srcs + xpr only); `project_1.gen` refs renamed to `vu13p.gen`.
- **2026-10-13** Pass 1 (`mod_vu13p.tcl`): removed x1y8 core1 + its TX/RX plumbing; copied hier_x1y4 TX chain to X1Y5/6/7
  (`tx_q5..7`); broadcaster_0 NUM_MI 2→8 fed from `M_AXIS_x1y8`; removed broadcaster_1; XDC refclk 225–227 added.
  BD validated, wrapper regenerated.
- **2026-10-13** Another Claude session re-ran `mod_vu13p.tcl` (21:04) and generated into a stray `project_1.gen`;
  BD structure verified intact, stray dir removed, refs repointed to `vu13p.gen`.
- **2026-10-13** Pass 2 (`mod2_vu13p_a/b.tcl`): per user, z1 now uses 8 cores → hier_x1y8 rebuilt with 2 cores,
  added hier_x1y9/x1y10/x1y11 (quads 229–231); XDC refclk 229–231 + clock groups. Broadcaster source unchanged
  (x1y8 core0). BD validated, wrapper regenerated, top = `aurora_gty_vu13p_rst_wrapper`.
- **2026-10-13** Per user (option b): broadcaster source moved from x1y8 core0 to **x1y8 core1** to match z1, where ADC1
  is on X0Y1 core1 (`S_AXIS_X0Y1`). axis_register_slice_6 now takes `hier_x1y8/USER_DATA_M_AXIS_RX1`; its reset and
  axis_data_fifo_7's reset moved from `arstn` to `arstn1` (`mod5_vu13p.tcl`, top refreshed with `mod2_vu13p_b.tcl`).
  BD validated, wrapper regenerated.
- **2026-10-13** Per user: all links made identical to X1Y4 (`mod7_vu13p.tcl`): X1Y4's FIFO/register-slice/CDC plumbing
  grouped as `link_x1y4` and copied to `link_x1y5`..`link_x1y11` (old tx_q5–7 groups and x1y8 slice/FIFO removed);
  new container ports `S_AXIS_x1y8..11[_1]`, `M_AXIS_x1y5..11[_1]`. Broadcaster now fed from `M_AXIS_x1y8_1`
  (`mod7b_vu13p.tcl`). Grouping created monitor-only boundary pins that caused ILA width-mismatch CRITICAL
  WARNINGs → removed from all links and `system_ila_0` re-pointed to the hier_x1y4 core interfaces
  (`mod7c_vu13p.tcl`). BD validated with no critical warnings.
- **2026-10-13** Build #1/#2 (`run_build.sh`): IP OOC runs crashed with SIGBUS at Vivado start (parallel runs racing on
  `~/.Xilinx`) → `XILINX_LOCAL_USER_DATA=no` added to `run_build.sh`.
- **2026-10-14** Build #2 impl result: (a) DRC UCIO-1 — refclk pins of X1Y5/X1Y6/X1Y7 missing from `physical.xdc`
  (lost when the other session restored its 20:40 backup) → re-added AT11/AM11/AH11 (+ clock groups); stray `]` on the
  `pma_rst_clk_p` false-path line fixed. (b) Timing WNS −0.116 ns (104 endpoints) on 400 MHz inter-SLR paths
  link_x1y8 RX FIFO → TX FIFOs of 224–227 → added `axis_slr_x1y8_to_tx` (`mod9_vu13p.tcl`).
- **2026-10-14** Build #3 (01:17–01:40, design with broadcaster ← `M_AXIS_x1y8_1`): synth/impl/bitstream complete,
  `vu13p.runs/impl_1/aurora_gty_vu13p_rst_wrapper.bit`. Timing met: WNS +0.026 ns, WHS +0.010 ns, 0 failing endpoints.
  GT placement checked (`reports/gt_placement.txt`): hier_x1y4..x1y11 on GTYE4_CHANNEL_X1Y16..X1Y47 / COMMON X1Y4..X1Y11,
  13P↔13P on X0Y44-47 / X0Y52-55; all refclk pins equal the golden table above. DRC: only warnings (PDCN-1569 ×3,
  RTSTAT-10 ×1). Methodology: TIMING-4/TIMING-27 critical warnings on `clk_wiz_0/inst/clk_in1` (clk_wiz OOC clock
  redefinition under `sys_clk`, inherited from the original project), LUTAR-1 ×95 warnings.
- **2026-10-14 09:5x** User edited the top BD in the Vivado GUI (journal `~/Desktop/vivado.jou`): broadcaster input
  `axis_slr_x1y8_to_tx/S_AXIS` moved from `M_AXIS_x1y8_1` (core1, X1Y34-35) to **`M_AXIS_x1y8` (core0, X1Y32-33)**.
  BD validates clean. ⚠ Not consistent with z1, which still sends ADC ch00 on X0Y1 **core1** (`S_AXIS_X0Y1`, lanes
  X0Y6-7) — awaiting user decision (move z1 to core0, or revert here). Build #3 bitstream predates this edit.
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
- **2026-10-14** Per user: broadcaster source back to **X1Y8 core1** (`mod10_vu13p.tcl`), matching z1 X0Y1 core1. Validated.
- **2026-10-14** Per user ("naming is chaos … wire, hier, pin, port"): full naming pass (see *Naming convention*):
  both containers (`aurora_gty_vu13pto47dr`: 377 renames + 522 wires; `aurora_gty_vu13ptovu13p`: 42 + 69 wires —
  its `S_AXIS_x0y13` actually fed core1) and the top BD (port reconnect, GT ports, 36 wires). Container port `i_pma_rst`
  → `ini_pma_rst` (same as 47DR). Old links e.g. `M_AXIS1`=TX core0, `src_arst1`=core0, every `hier_x1yN/gt_x1y8_diff_ref`
  were misleading. Checks: every container port name equals its traced quad/core (80/80); net/endpoint counts identical
  before/after; validate clean; all XDC ports present in the regenerated wrapper. Backup: `backup/pre_naming_20261014.tgz`.
- **2026-10-14** Per user: FIFO depths of every link read from Vivado (`scripts/check/fifo_report.tcl`): z1 TX
  cdc/out 16/16, VU13P rx/tx 512/512, z2 in/cdc 512/512, z2 hold 1024. FIFO-budget simulation with header/framing
  overhead and Aurora pause model (`scripts/sim_chain/run_fifo.sh`): link load ≈ 82.6 %, no loss in normal operation
  or with a 1 µs VU13P TX stall (peak 321/512); a 3 µs stall overflows the VU13P TX FIFO. System design document
  `docs/DESIGN.md` (rev 0.9) and deck `docs/pj22045_1r8t_design.pptx` written in the format of
  `~/Downloads/serdes_selecio_axis/docs`.
- **2026-10-14** Per user: `docs/DESIGN.md` rev 0.10 — §6 *Time base and timers (whole system)* added; DESIGN.docx / deck regenerated.
- **2026-10-14 12:41** Per user: build #4 started (synth → impl → bitstream, `run_build.sh vu13p 8`, log `scripts/build_vu13p.log`) on the renamed rev 0.10 designs; results pending.
- **2026-10-14** Per user: debug ILAs (`mod12_add_ila.tcl`): `ila_x1y4`…`ila_x1y11` in the container (TX C0/C1, RX C0/C1,
  2048 deep, replaces the X1Y4-only `system_ila_0`) and `ila_bcast` at the top (broadcaster input + M00…M07).
- **2026-10-14 14:10** Build #5: bitstream + `.ltx`, **WNS +0.025 ns, WHS +0.010 ns**, 40 GTs and all refclk pins =
  golden, DRC warnings only, methodology only TIMING-4/27 (inherited `clk_wiz`). LUT 3.3 %, FF 4.7 %, BRAM 18.4 %.
- **2026-10-14** Per user: sources not used by the top removed (D18): `aurora.bd`, 14 RTL files (`slr_register*`,
  `data_pg`, `header_*`, `axi_monitor`, `axis_adapter`, `data_mhk/shk/valider/viewer`, `work_persentage`). Backup
  `backup/pre_cleanup_20261014.tgz`. Top and BD validation unchanged; runs stay up to date.
- **2026-10-14 15:00** Release `PJ22045_1R8T_release_rev0.11_20261014.tar.gz` (45 MB, project root): bitstreams + .ltx, z1/z2 XSA, docs, reports, sources; all runs up to date, 1815 files SHA256-checked after extraction (`scripts/release/make_release.sh`).
- **2026-10-14** Per user: two detailed documents in the format of `docs/DESIGN.docx`: `docs/SIGNAL_TRANSMISSION.md/.docx`
  (every module and IP configuration on the signal path, links, flow control, start-up, errors) and `docs/TIMING_SYNC.md/.docx`
  (time base, SYSREF, stamping, header carry/rebuild, `data_delay`/`data_aligner` design, latency, alignment, failure modes,
  bring-up). IP values read from a read-only dump of all BDs; `scripts/docs/make_docx.py <NAME>` now builds any of the three.
  Findings (not fixed): PL_SYSREF has no input-delay constraint (timer start edge untimed); RTL analysis of `data_delay` guard /
  `data_aligner` epoch corrects DESIGN.md §6.9 rows (z1 reset, z2 reset, delay change).
- **2026-10-14** DEFECT found (not fixed, awaiting user): in all eight `aurora_gty_vu13pto47dr/hier_x1yN`, `aurora_rstn_1/channel_up`
  is driven by core 0 `lane_up` (net `aurora_x1yN_0_lane_up`) instead of `aurora_x1yN_1/channel_up`. Inherited from EV1 `hier_x1y4`
  and copied to all quads by the rev 0.5 "all links identical" pass (D9) — now also on X1Y8 C1 (ADC stream). Fix = rewire 8 nets + rebuild.
- **2026-10-14 17:22** Per user ("fix 1 and rebuild"): D19 applied (`scripts/mod13_vu13p_rstn.tcl`, backup
  `backup/pre_rstn_fix_20261014.tgz`): all eight `hier_x1yN/aurora_rstn_1/channel_up` now on `aurora_x1yN_1_channel_up`;
  BD validated; built container copy checked 8/8. Build #6: WNS +0.011 ns, WHS +0.010 ns, 0 failing endpoints,
  GT/refclk placement identical to rev 0.11 (golden). Bitstream + .ltx in `vu13p.runs/impl_1/`. The rev 0.11 release
  tarball still holds the old VU13P bitstream. PL_SYSREF constraint not added (D20, user).
- **2026-10-14 17:33** Release `PJ22045_1R8T_release_rev0.12_20261014.tar.gz` (52 MB, 1843 files SHA256-checked): VU13P build #6 (D19), z1/z2 build #5, three documents + figures.
