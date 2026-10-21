# =============================================================================
# regmap_def.py  PJ22045_1R8T rev0.12_dev 版 (2026-10-15)
#   由 Calibration_Gain_Control/doc/tools/regmap_def.py (RegMap v8 + mem39, 2026-10-14) 複製; 暫存器定義相同,
#   差別: 本專案沒有 rx_gain_control (RX 定義與 sys6~13 Used by 中的 RX 說明已移除)
#   唯一的暫存器定義來源:
#     - hardware/scripts/gen_reg_maps.py  -> addressable_reg_map.v (channel) / system_reg_map.v
#                                            rx_reg_map.v (rx_gain_control, RX-only AGC)
#     - doc/tools/mk_regmap_v8.py         -> doc/Reg_map/Reg_map_channel_v0.X.xlsx / Reg_map_emu_sys_v0.X.xlsx / Reg_map_rx_v0.X.xlsx
#   改暫存器只改這個檔, 再重新產生 Verilog / Excel (reg_rt.tcl 的 ::reg::def 也照這份更新)
#
#   欄位: idx, name, bits(高位), signed, frac(小數位數, 1/2^frac), reset, access, fmt, rng, desc, effect, used, group
#     access: RW = 讀寫, RO = 唯讀 (硬體輸入), TRIG = 寫 1 觸發 (讀回另有內容)
# =============================================================================

def R(idx, name, msb, reset=0, signed=False, frac=0, access="RW", fmt="", rng="", desc="",
      effect="Real-time", used="", group="", hw_min=None, port=None):
    return dict(idx=idx, name=name, msb=msb, signed=signed, frac=frac, reset=reset, access=access, fmt=fmt,
                rng=rng, desc=desc, effect=effect, used=used, group=group, hw_min=hw_min, port=port)

def dbfs16(db):
    """dB -> S?.4 (1/16 dB) 的整數值"""
    return int(round(db * 16))

# ----------------------------------------------------------------------------- channel (each cal_plus_gain_control_chN)
CAL, GI, AGC, ST = "Calibration", "Gain Index", "AGC_EMU", "Status"
CH_ADDR_WIDTH = 9          # 128 x 32-bit (0x000 ~ 0x1FC)

CHANNEL = [R(0, "fir_enable", 0, fmt="bit", rng="0 / 1", desc="Complex FIR enable", effect="-",
             used="in_band_flatness/sl_fir_enable", group=CAL)]
CHANNEL += [R(1 + t, f"fir_tap{t:02d}", 31, fmt="[15:0] I, [31:16] Q (S0.15 each, 0x7FFF ≈ 1.0)", rng="-",
              desc=f"Complex FIR tap {t:02d} coefficient", effect="-",
              used=f"in_band_flatness/FIR_coef_unpack_0", group=CAL) for t in range(16)]
CHANNEL += [
 R(17, "coarse_delay_offset", 3, fmt="unsigned, cycles", rng="0 ~ 15", desc="Delay_Cal coarse delay",
   effect="Real-time (CDC)", used="cal_cdc_0 -> calibration/Delay_Cal_0", group=CAL),
 R(18, "fractional_delay_offset", 2, fmt="unsigned, samples", rng="0 ~ 4", desc="Delay_Cal fractional delay",
   effect="Real-time (CDC)", used="cal_cdc_0 -> calibration/Delay_Cal_0", group=CAL),
 R(19, "phase_offset", 15, fmt="CORDIC phase", rng="-", desc="Phase_Cal phase offset (cordic_0~4)",
   effect="Real-time (CDC)", used="cal_cdc_0 -> calibration/cordic_0~4", group=CAL),
 R(20, "gain_index_mode_sel", 0, fmt="bit", rng="0: TXAGC, 1: manual",
   desc="Gain_Compensation index source: 0 = gain_index_tx (TXAGC digital), 1 = gain_index_manual",
   effect="Real-time (CDC)", used="cal_cdc_0 -> gain_index_mux_0", group=GI),
 R(21, "gain_index_manual", 10, signed=True, frac=4, fmt="S6.4, 1/16 dB", rng="-64 ~ +63.9375 dB",
   desc="Manual gain index (mode_sel = 1), offsets not added", effect="Real-time (CDC)",
   used="cal_cdc_0 -> gain_index_mux_0", group=GI),
 R(22, "gain_index_ch_offset", 8, signed=True, frac=4, fmt="S4.4, 1/16 dB", rng="-16 ~ +15.9375 dB",
   desc="Channel magnitude trim (+ = gain), in the TXAGC target (analog first, residual digital)",
   used="agc_emu/agc_cdc_0 -> txagc_0", group=GI),
 R(23, "gain_index_rf_freq_offset", 7, signed=True, frac=4, fmt="S3.4, 1/16 dB", rng="-8 ~ +7.9375 dB",
   desc="RF-frequency magnitude trim (+ = gain), in the TXAGC target", used="agc_emu/agc_cdc_0 -> txagc_0", group=GI),
 R(24, "gain_index_temperature_offset", 7, signed=True, frac=4, fmt="S3.4, 1/16 dB", rng="-8 ~ +7.9375 dB",
   desc="Temperature magnitude trim (+ = gain), in the TXAGC target", used="agc_emu/agc_cdc_0 -> txagc_0", group=GI),
 R(25, "dac_output_ref_dbm", 10, reset=0x670, signed=True, frac=4, fmt="S6.4 dBm", rng="HW limit +10 ~ -40 dBm",
   desc="DAC output measured with goal = goal_ref_dbfs (TXAGC Manual mode reference)",
   used="agc_emu/agc_cdc_0 -> txagc_0", group=GI),
 R(26, "goal_ref_dbfs", 10, reset=dbfs16(-6.0) & 0x7FF, signed=True, frac=4, fmt="S6.4 dBFS (16384 = 0 dBFS)",
   rng="-64 ~ +63.9375 dB", desc="Goal (dBFS) used when dac_output_ref_dbm was measured; goal_rel_db = goal_dBFS - goal_ref_dbfs",
   effect="Real-time (CDC)", used="cal_cdc_0 -> power_fit_top/power_fit_db_0", group=GI),
 R(27, "agc_reg5", 7, reset=0x80, fmt="bits", rng="[7] TXRX_SW: 0 TX, 1 RX; [6:2] filter; [1:0] PA on = 11",
   desc="Reg5 byte (595 QA~QH). [7] TXRX_SW = AGC mode source; [6:2] Filter {Vc2, Vc1, Vc0, Vc3, Vc4}; [1] PA_VC_D, [0] PA_VC_G",
   effect="Real-time (bypass: agc_bypass_sr_update[1])", used="agc_emu/agc_cdc_0 -> agc_mode_ctrl_0 / sr_src_mux_0", group=AGC),
 R(28, "agc_bypass_agc", 0, fmt="bit", rng="0: AGC, 1: bypass",
   desc="1: AGC paused; TX attenuator = agc_bypass_tx_att_state, RX = dummy 0 dB, digital comp = 0; SR sent only by agc_bypass_sr_update",
   used="agc_emu/agc_cdc_0", group=AGC),
 R(29, "agc_bypass_tx_att_state", 4, fmt="unsigned state", rng="0 ~ 27 (0 = 130 dB ... 27 = 5 dB)",
   desc="TX analog attenuator state in bypass", effect="Bypass trigger", used="agc_emu/agc_cdc_0 -> txagc_0", group=AGC),
 R(30, "agc_bypass_sr_update", 1, fmt="bits, rising edge", rng="write 1 then 0 (0x3 = all 5 registers)",
   desc="Bypass only. [0] send Reg1~4, [1] send Reg5", effect="-", used="agc_emu/agc_cdc_0 -> sr_src_mux_0", group=AGC),
 R(31, "agc_manual_tx_att_en", 0, fmt="bit", rng="0: formula, 1: manual",
   desc="TX target attenuation = agc_manual_tx_att_db (other TX inputs ignored)", used="agc_emu/agc_cdc_0 -> txagc_0", group=AGC),
 R(32, "agc_manual_tx_att_db", 7, fmt="unsigned, 1 dB", rng="5 ~ 130", desc="Manual TX target attenuation",
   used="agc_emu/agc_cdc_0 -> txagc_0", group=AGC),
 R(33, "agc_target_power", 7, signed=True, fmt="signed, 1 dBm", rng="-128 ~ +127 dBm",
   desc="Manual mode target output power (e.g. 0xD8 = -40 dBm)", used="agc_emu/agc_cdc_0 -> txagc_0", group=AGC),
 R(34, "agc_linear_mode_offset", 11, signed=True, frac=4, fmt="signed, 1/16 dB", rng="-128 ~ +127.9375 dB",
   desc="Linear mode offset", used="agc_emu/agc_cdc_0 -> txagc_0", group=AGC),
 R(35, "agc_manual_mode_offset", 11, signed=True, frac=4, fmt="signed, 1/16 dB", rng="-128 ~ +127.9375 dB",
   desc="Manual mode offset", used="agc_emu/agc_cdc_0 -> txagc_0", group=AGC),
 R(36, "agc_manual_rx_att_en", 0, fmt="bit", rng="0: RXAGC, 1: manual",
   desc="Use agc_manual_rx_att_state instead of the RXAGC result (RX mode)", used="agc_emu/agc_cdc_0 -> rxagc_0", group=AGC),
 R(37, "agc_manual_rx_att_state", 2, fmt="unsigned state", rng="0 ~ 6 (0 ~ 60 dB)", desc="Manual RX attenuation state",
   used="agc_emu/agc_cdc_0 -> rxagc_0", group=AGC),
 R(38, "bypass_axis_iq", 0, fmt="bit", rng="0: normal, 1: bypass",
   desc="Debug: 1 = m_axis_iq = Signal Source Mux output (mem39 selected input; FIR / calibration / gain control bypassed, input sent directly to the DAC); "
   "the normal path keeps running (AGC / Power Fit still computed)", effect="Real-time (CDC)",
   used="cal_cdc_0 -> axis_iq_bypass_0", group=CAL),
 R(39, "signal_source_select", 1, fmt="unsigned", rng="0: s_axis_iq_in_0, 1: s_axis_iq_in_1, 2 / 3: all_zero",
   desc="Signal Source Mux: input stream sent to Power Fit / Calibration (and to the mem38 bypass path); "
   "the unselected inputs are dropped (tready = 1). Debug_008: 2 / 3 = all_zero (160'd0, tvalid = 1)", effect="Real-time (CDC)",
   used="cal_cdc_0 -> axis_iq_source_mux_0", group=CAL),
]
CH_RESERVED = (40, 63)     # 保留給之後的設定參數, 讀回 0

CH_STATUS = [
 R(64, "status_snapshot", 15, access="TRIG", fmt="W: bit0 = 1 trigger; R: [15:0] completed snapshot count",
   rng="-", desc="Write 1: latch all st_* registers of this channel on the same clock (clk and adc_clk domains); "
   "read back the number of completed snapshots (increments when both domains are latched)",
   effect="-", used="status_snapshot_0", group=ST, port="snapshot"),
 R(65, "st_power_amp", 15, access="RO", fmt="unsigned amplitude", rng="0 ~ 65535",
   desc="power_fit_top/power_amp (cw_power_calc output)", effect="-", used="power_fit_top/power_amp", group=ST),
 R(66, "st_gain_index_power_fit", 9, signed=True, frac=4, access="RO", fmt="S5.4, 1/16 dB (sign-extended)",
   rng="-31.9375 ~ +31.9375 dB", desc="Power Fit result pf = goal_dBFS - input_dBFS", effect="-",
   used="power_fit_top/gain_index_power_fit", group=ST),
 R(67, "st_goal_db", 11, signed=True, frac=4, access="RO", fmt="S7.4 dBFS (sign-extended)", rng="-128 ~ 0 dB",
   desc="Power Fit goal in dBFS (16384 = 0 dBFS). CW: min(cw_mode_goal_dbfs, -margin); Pulse: -(margin + PAPR)",
   effect="-", used="power_fit_top/goal_db", group=ST),
 R(68, "st_goal_rel_db", 9, signed=True, frac=4, access="RO", fmt="S5.4, 1/16 dB (sign-extended)",
   rng="-31.9375 ~ +31.9375 dB", desc="goal_dBFS - goal_ref_dbfs (TXAGC Manual mode)", effect="-",
   used="power_fit_top/goal_rel_db", group=ST),
 R(69, "st_gain_index_tx", 11, signed=True, frac=4, access="RO", fmt="S7.4, 1/16 dB (sign-extended)",
   rng="-128 ~ +127.9375 dB", desc="TXAGC digital gain index (pf - R) applied to Gain_Compensation (clk domain)",
   effect="-", used="agc_emu/gain_index_tx", group=ST),
 R(70, "st_adc_flags", 3, access="RO", fmt="bits",
   rng="[0] over_threshold1, [1] over_threshold2, [2] over_range, [3] over_voltage",
   desc="RFDC flags at the snapshot (adc_clk domain, current value only)", effect="-",
   used="over_threshold1/2, over_range, over_voltage", group=ST),
]

# ----------------------------------------------------------------------------- system (design_1, shared by all channels)
PF, AG, SYS = "Power Fit", "AGC_EMU", "System"
SYS_ADDR_WIDTH = 8         # 64 x 32-bit (0x00 ~ 0xFC)

SYSTEM = [
 R(0, "signal_mode_select", 0, fmt="bit", rng="0: CW, 1: Pulse",
   desc="Power Fit input / goal: CW = cw_power_calc + cw_mode_goal_dbfs; Pulse = pulse_avg_amp + goal -(margin + PAPR), auto update",
   effect="Real-time (CDC)", used="chN/cal_cdc_0 -> power_fit_top/power_fit_db_0", group=PF),
 R(1, "power_limit_margin", 2, reset=3, fmt="U3.0 dB", rng="0 ~ 7 dB",
   desc="Power limit = -margin dBFS. CW goal = min(cw_mode_goal_dbfs, -margin); Pulse goal = -(margin + PAPR)",
   effect="Real-time (CDC)", used="chN/cal_cdc_0 -> power_fit_top/power_fit_db_0", group=PF),
 R(2, "cw_mode_goal_dbfs", 10, reset=dbfs16(-6.0) & 0x7FF, signed=True, frac=4, fmt="S6.4 dBFS (16384 = 0 dBFS)",
   rng="-64 ~ 0 dB (HW: <= -margin)", desc="CW mode Power Fit goal (e.g. 0x7A0 = -6.0 dBFS ~ amplitude 8211)",
   effect="Real-time (CDC)", used="chN/cal_cdc_0 -> power_fit_top/power_fit_db_0", group=PF),
 R(3, "pulse_update_stable_cycle", 3, reset=4, fmt="unsigned, clk (3.906 ns)", rng="0 ~ 15",
   desc="Pulse auto update: pulse_avg_amp / pulse_papr must stay unchanged M clk after a change before they are latched "
   "together and one Power Fit result (pf + goal_rel) is sent",
   effect="Real-time (CDC)", used="chN/cal_cdc_0 -> power_fit_top/power_fit_db_0", group=PF),
 R(4, "agc_tx_power_mode", 0, fmt="bit", rng="0: Linear, 1: Manual",
   desc="TXAGC target T. Linear: 96.5625 + linear_mode_offset - rx_att_index x 10 + pf - offsets + algo; "
   "Manual: dac_output_ref_dbm + goal_rel_db + 50 - target_power + manual_mode_offset - offsets + algo (dB)",
   used="chN/agc_emu/agc_cdc_0 -> txagc_0", group=AG),
 R(5, "digital_apply_delay", 7, reset=35, fmt="unsigned, adc_clk (4.167 ns)", rng="0 ~ 255 (< agc_sr_update_period)",
   desc="Digital gain index applied N clk after the Reg1~4 SR start (35 = RCLK)", effect="Next analog step",
   used="chN/agc_emu/agc_cdc_0 -> gain_apply_sync_0", group=AG),
 R(6, "agc_sr_update_period", 7, reset=50, fmt="unsigned, adc_clk", rng="HW min 50, max 255 (208 ns ~ 1.06 us)", hw_min=50,
   desc="Shift register update round (SER transfer ~37 clk + hardware settling); shared by Reg1~4 and Reg5", effect="Next round",
   used="chN/agc_emu/agc_cdc_0 -> sr_att_group / sr_reg5_group", group=AG),
 R(7, "agc_mode_settle_cycle", 15, reset=64, fmt="unsigned, adc_clk", rng="HW min 1", hw_min=1,
   desc="Wait after Reg5 transfer before AGC switches RX/TX", used="chN/agc_emu/agc_cdc_0 -> agc_mode_ctrl_0", group=AG),
 R(8, "agc_rx_watch_cycle", 31, reset=1000, fmt="unsigned, adc_clk", rng="HW min 1", hw_min=1,
   desc="RXAGC S_WATCHING time (no signal -> back to 0 dB); set by PRI", used="chN/agc_emu/agc_cdc_0 -> rxagc_0", group=AG),
 R(9, "agc_rx_wait_dsa_cycle", 7, reset=6, fmt="unsigned, adc_clk", rng="HW min 1", hw_min=1,
   desc="RXAGC S_WAIT_DSA", used="chN/agc_emu/agc_cdc_0 -> rxagc_0", group=AG),
 R(10, "agc_rx_set_dsa_cycle", 7, reset=6, fmt="unsigned, adc_clk", rng="HW min 1", hw_min=1,
   desc="RXAGC S_SET_DSA", used="chN/agc_emu/agc_cdc_0 -> rxagc_0", group=AG),
 R(11, "agc_rx_wait_cycle", 7, reset=50, fmt="unsigned, adc_clk", rng="HW min 1", hw_min=1,
   desc="RXAGC S_WAIT (RF settling before flag clear)", used="chN/agc_emu/agc_cdc_0 -> rxagc_0", group=AG),
 R(12, "agc_rx_set_clear_cycle", 7, reset=6, fmt="unsigned, adc_clk", rng="HW min 6", hw_min=6,
   desc="RXAGC clear_or / clear_ov pulse width", used="chN/agc_emu/agc_cdc_0 -> rxagc_0", group=AG),
 R(13, "agc_rx_wait_clear_cycle", 7, reset=16, fmt="unsigned, adc_clk", rng="HW min 1", hw_min=1,
   desc="RXAGC S_WAIT_CLEAR", used="chN/agc_emu/agc_cdc_0 -> rxagc_0", group=AG),
 R(15, "cw_power_avg_log2", 3, reset=8, fmt="log2(N), CW samples (clk)", rng="0 ~ 12 (N = 1 ~ 4096, >12 -> 12)",
   desc="CW power block average: cw_amp averaged over N = 2^k samples, Power Fit (CW) updated once every N clk (2026-10-10, build 13)",
   effect="Next block", used="chN/cal_cdc_0 -> power_fit_top/power_fit_db_0", group=PF),
 R(16, "agc_tx_att_hysteresis", 7, reset=16, frac=4, fmt="U4.4 dB (1/16 dB)", rng="0 ~ 15.9375 dB (0 = no hysteresis)",
   desc="TXAGC analog step hysteresis H: keep the current analog step while T stays within [A - H, A_next + H); R range -H ~ 4.9375 + H dB (build 13)",
   used="chN/agc_emu/agc_cdc_0 -> txagc_0", group=AG),
 R(14, "build_version", 31, access="RO", fmt="unsigned", rng="-",
   desc="Build number (XSA / output_data index, e.g. 12), set by build_full_xsa.tcl", effect="-",
   used="system_reg_map parameter BUILD_VERSION", group=SYS),
]
