# =============================================================================
# reg_template: 全部暫存器範本 (RegMap v8: system + channel). 每行預設註解 -> 要改哪顆就拿掉 # 並填值
#   沒取消註解的暫存器不會被寫入. 由上往下依序寫入, 寫完立即生效
#   執行: xsdb reg_rt.tcl run <this file>     離線檢查: xsdb reg_rt.tcl sim <this file>
#   預填值 = reset 值; 單位見每行註解
# =============================================================================
# reg_ch 1                                  ;# 通道: 1 ~ 8 = ch1 ~ ch8 (預設 ch1; system 暫存器不受影響)

# --- SYSTEM (system_reg_map, 所有通道共用)
# reg_wr  signal_mode_select             0x0      ;# sys0  0: CW, 1: Pulse; Power Fit input / goal: CW = cw_power_calc + cw_mode_goal_dbfs; Pulse = pulse_avg_amp + goal -(margin + PAPR), auto update
# reg_set power_limit_margin             3        ;# sys1  dB | 0 ~ 7 dB; Power limit = -margin dBFS. CW goal = min(cw_mode_goal_dbfs, -margin); Pulse goal = -(margin + PAPR)
# reg_set cw_mode_goal_dbfs              -6       ;# sys2  dBFS | -64 ~ 0 dB (HW: <= -margin); CW mode Power Fit goal (e.g. 0x7A0 = -6.0 dBFS ~ amplitude 8211)
# reg_set pulse_update_stable_cycle      4        ;# sys3  clk | 0 ~ 15; Pulse auto update: pulse_avg_amp / pulse_papr must stay unchanged M clk after a change before they are latched together and one Power Fit resu
# reg_wr  agc_tx_power_mode              0x0      ;# sys4  0: Linear, 1: Manual; TXAGC target T. Linear: 96.5625 + linear_mode_offset - rx_att_index x 10 + pf - offsets + algo; Manual: dac_output_ref_dbm + goa
# reg_set digital_apply_delay            35       ;# sys5  clk | 0 ~ 255 (< agc_sr_update_period); Digital gain index applied N clk after the Reg1~4 SR start (35 = RCLK)
# reg_set agc_sr_update_period           50       ;# sys6  clk | HW min 50, max 255 (208 ns ~ 1.06 us); Shift register update round (SER transfer ~37 clk + hardware settling); shared by Reg1~4 and Reg5
# reg_set agc_mode_settle_cycle          64       ;# sys7  clk | HW min 1; Wait after Reg5 transfer before AGC switches RX/TX
# reg_set agc_rx_watch_cycle             1000     ;# sys8  clk | HW min 1; RXAGC S_WATCHING time (no signal -> back to 0 dB); set by PRI
# reg_set agc_rx_wait_dsa_cycle          6        ;# sys9  clk | HW min 1; RXAGC S_WAIT_DSA
# reg_set agc_rx_set_dsa_cycle           6        ;# sys10 clk | HW min 1; RXAGC S_SET_DSA
# reg_set agc_rx_wait_cycle              50       ;# sys11 clk | HW min 1; RXAGC S_WAIT (RF settling before flag clear)
# reg_set agc_rx_set_clear_cycle         6        ;# sys12 clk | HW min 6; RXAGC clear_or / clear_ov pulse width
# reg_set agc_rx_wait_clear_cycle        16       ;# sys13 clk | HW min 1; RXAGC S_WAIT_CLEAR
# reg_wr  cw_power_avg_log2              0x8      ;# sys15 0 ~ 12: CW power block average N = 2^k samples (256 = 1 us), Power Fit CW updated every N clk (build 13)
# reg_set agc_tx_att_hysteresis          1        ;# sys16 dB | 0 ~ 15.9375 dB: TXAGC analog step hysteresis H, R range -H ~ 4.9375 + H dB (build 13)

# --- In-band FIR (tap: reg_fir_tap <t> <I> <Q>, I/Q signed 16-bit)
# reg_wr  in_band_fir_enable             0x0      ;# mem0  0: FIR disable (impulse), 1: FIR enable
# reg_fir_tap 0  0      0                      ;# mem1  tap 0: I Q
# reg_fir_tap 1  0      0                      ;# mem2  tap 1: I Q
# reg_fir_tap 2  0      0                      ;# mem3  tap 2: I Q
# reg_fir_tap 3  0      0                      ;# mem4  tap 3: I Q
# reg_fir_tap 4  0      0                      ;# mem5  tap 4: I Q
# reg_fir_tap 5  0      0                      ;# mem6  tap 5: I Q
# reg_fir_tap 6  0      0                      ;# mem7  tap 6: I Q
# reg_fir_tap 7  0      0                      ;# mem8  tap 7: I Q
# reg_fir_tap 8  0      0                      ;# mem9  tap 8: I Q
# reg_fir_tap 9  0      0                      ;# mem10 tap 9: I Q
# reg_fir_tap 10 0      0                      ;# mem11 tap 10: I Q
# reg_fir_tap 11 0      0                      ;# mem12 tap 11: I Q
# reg_fir_tap 12 0      0                      ;# mem13 tap 12: I Q
# reg_fir_tap 13 0      0                      ;# mem14 tap 13: I Q
# reg_fir_tap 14 0      0                      ;# mem15 tap 14: I Q
# reg_fir_tap 15 0      0                      ;# mem16 tap 15: I Q

# --- Calibration / Gain index
# reg_wr  coarse_delay_offset            0x0      ;# mem17 0 ~ 15; Delay_Cal coarse delay
# reg_set fractional_delay_offset        0        ;# mem18 /5clk | 0 ~ 4; Delay_Cal fractional delay
# reg_wr  phase_offset                   0x0      ;# mem19 Phase_Cal phase offset (cordic_0~4)
# reg_wr  gain_index_mode_sel            0x0      ;# mem20 0: TXAGC, 1: manual; Gain_Compensation index source: 0 = gain_index_tx (TXAGC digital), 1 = gain_index_manual
# reg_set gain_index_manual              0        ;# mem21 dB | -64 ~ +63.9375 dB; Manual gain index (mode_sel = 1), offsets not added

# --- Gain index offset / TXAGC 參考
# reg_set gain_index_ch_offset           0        ;# mem22 dB | -16 ~ +15.9375 dB; Channel magnitude trim (+ = gain), in the TXAGC target (analog first, residual digital)
# reg_set gain_index_rf_freq_offset      0        ;# mem23 dB | -8 ~ +7.9375 dB; RF-frequency magnitude trim (+ = gain), in the TXAGC target
# reg_set gain_index_temperature_offset  0        ;# mem24 dB | -8 ~ +7.9375 dB; Temperature magnitude trim (+ = gain), in the TXAGC target
# reg_set dac_output_ref_dbm             -25      ;# mem25 dBm | HW limit +10 ~ -40 dBm; DAC output measured with goal = goal_ref_dbfs (TXAGC Manual mode reference)
# reg_set goal_ref_dbfs                  -6       ;# mem26 dBFS | -64 ~ +63.9375 dB; Goal (dBFS) used when dac_output_ref_dbm was measured; goal_rel_db = goal_dBFS - goal_ref_dbfs

# --- AGC_EMU
# reg_wr  agc_reg5                       0x80     ;# mem27 [7] TXRX_SW: 0 TX, 1 RX; [6:2] filter; [1:0] PA on = 11; Reg5 byte (595 QA~QH). [7] TXRX_SW = AGC mode source; [6:2] Filter {Vc2, Vc1, Vc0, 
# reg_wr  agc_bypass_agc                 0x0      ;# mem28 0: AGC, 1: bypass; 1: AGC paused; TX attenuator = agc_bypass_tx_att_state, RX = dummy 0 dB, digital comp = 0; SR sent only by agc_bypass_sr_update
# reg_wr  agc_bypass_tx_att_state        0x0      ;# mem29 0 ~ 27 (0 = 130 dB ... 27 = 5 dB); TX analog attenuator state in bypass
# reg_pulse agc_bypass_sr_update           0x3     ;# mem30 write 1 then 0 (0x3 = all 5 registers); Bypass only. [0] send Reg1~4, [1] send Reg5
# reg_wr  agc_manual_tx_att_en           0x0      ;# mem31 0: formula, 1: manual; TX target attenuation = agc_manual_tx_att_db (other TX inputs ignored)
# reg_set agc_manual_tx_att_db           0        ;# mem32 dB | 5 ~ 130; Manual TX target attenuation
# reg_set agc_target_power               0        ;# mem33 dBm | -128 ~ +127 dBm; Manual mode target output power (e.g. 0xD8 = -40 dBm)
# reg_set agc_linear_mode_offset         0        ;# mem34 dB | -128 ~ +127.9375 dB; Linear mode offset
# reg_set agc_manual_mode_offset         0        ;# mem35 dB | -128 ~ +127.9375 dB; Manual mode offset
# reg_wr  agc_manual_rx_att_en           0x0      ;# mem36 0: RXAGC, 1: manual; Use agc_manual_rx_att_state instead of the RXAGC result (RX mode)
# reg_wr  agc_manual_rx_att_state        0x0      ;# mem37 0 ~ 6 (0 ~ 60 dB); Manual RX attenuation state

# --- Debug
# reg_wr  bypass_axis_iq                 0x0      ;# mem38 0: normal, 1: bypass; Debug: m_axis_iq = Signal Source Mux output (FIR / calibration / gain control bypassed), normal path keeps running (build 14)

# --- Signal Source Mux
# reg_wr  signal_source_select           0x0      ;# mem39 0: s_axis_iq_in_0 (Aurora), 1: s_axis_iq_in_1 (ADC), 2 / 3: all_zero (Debug_008, 160'd0 tvalid=1); Signal Source Mux: input sent to Power Fit / Calibration (and the mem38 bypass path), unselected inputs dropped
