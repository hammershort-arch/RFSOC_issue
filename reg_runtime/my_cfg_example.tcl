# =============================================================================
# my_cfg_example.tcl : runtime 設定範例 (xsdb reg_rt.tcl run my_cfg_example.tcl), RegMap v8
#   一行一個指令, # 開頭為註解; 由上往下依序寫入 (每筆約 ms 等級, 寫完立即生效)
#   reg_set  = 物理單位 (dB / dBFS / dBm / clk), reg_wr = raw 值, reg_pulse = 寫入後清 0
#   [sys] = system_reg_map, 所有通道共用 (不受 reg_ch 影響); 其餘為目前通道
# =============================================================================

reg_ch 1                                    ;# 通道: 1 ~ 8 = ch1 ~ ch8

# --- TX Manual mode: DAC 參考 (goal -6 dBFS 時量到 -25 dBm), 目標 -40 dBm
reg_set goal_ref_dbfs             -6
reg_set dac_output_ref_dbm        -25
reg_set agc_manual_mode_offset    0
reg_set agc_target_power          -40
reg_set agc_tx_power_mode         1         ;# [sys] 最後才切 mode (所有通道)

# --- gain index offset (加進 TXAGC 目標, 類比優先)
reg_set gain_index_ch_offset      0.5
reg_set gain_index_rf_freq_offset -3.5
reg_set gain_index_temperature_offset 0

# --- Power Fit [sys]
reg_set power_limit_margin        3
reg_set cw_mode_goal_dbfs         -6        ;# CW goal (dBFS, HW <= -margin)
reg_set pulse_update_stable_cycle 4         ;# Pulse: avg / PAPR 連續 4 clk 不變才鎖存
reg_set signal_mode_select        0         ;# 0: CW, 1: Pulse

# --- 類比 / 數位同步 (上板調整) [sys]
reg_set digital_apply_delay       35

# --- 狀態 snapshot (印出並存成 CSV / txt)
# reg_dump all
