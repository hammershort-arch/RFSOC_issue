# =============================================================================
# att_step.tcl  (2026-10-10, RegMap v8 / build 13)
#   Bypass mode 逐檔切換 TX 類比衰減器 (TRM8, 檔位 0~27) 做實驗
#
#   用法 (在 reg_rt.tcl 的 xsdb shell 裡):
#     xsdb% source att_step.tcl          ;# 只要 source 一次
#     xsdb% att_on                       ;# 進入 bypass: TX mode、數位 gain 固定 0 dB、從目前檔位開始
#     xsdb% att_next                     ;# 往下一檔 (衰減變小: 130 -> 125 -> ... -> 5 dB)
#     xsdb% att_prev                     ;# 往上一檔 (衰減變大)
#     xsdb% att_set 17                   ;# 直接指定檔位 (0~27)
#     xsdb% att_db 45                    ;# 指定衰減 dB (取最接近、不超過的檔位)
#     xsdb% att_list                     ;# 列出 0~27 檔位與衰減
#     xsdb% att_off                      ;# 離開 bypass, 恢復進入前的設定 (AGC 接手)
#   每一行都是一個指令, 打一次就切一檔; 每次切換都會印出目前檔位 / 衰減
#
#   檔位: 0 = 130 dB ... 17 = 45 dB (每檔 5 dB), 18 = 41 dB ... 27 = 5 dB (每檔 4 dB)
#   注意:
#     - 作用在目前通道 (reg_ch 1 / 3); 切通道後要重新 att_on
#     - bypass 時 RX 衰減為 dummy 0 dB; Reg1~4 只在 att_* 指令送出時更新 (agc_bypass_sr_update 正緣)
#     - att_on 預設把數位 gain 固定在 0 dB (gain_index_mode_sel = 1, manual 0), 只量類比衰減器;
#       要保留 Power Fit 的數位 gain 用 att_on keep_digital
# =============================================================================

namespace eval ::att {
    variable on 0
    variable state 0
    variable saved {}
}

# 檔位 -> 衰減 (dB)
proc ::att::db_of {s} { expr {$s <= 17 ? 130 - 5 * $s : 45 - 4 * ($s - 17)} }

# 寫入檔位並送出 Reg1~4
proc ::att::apply {s} {
    if {![string is integer -strict $s] || $s < 0 || $s > 27} { error "att: state '$s' must be 0~27" }
    if {!$::att::on} { error "att: not in bypass mode, run att_on first" }
    reg_wr    agc_bypass_tx_att_state $s
    reg_pulse agc_bypass_sr_update 0x1          ;# 正緣: 送 Reg1~4 (TX 衰減)
    set ::att::state $s
    puts [format ">>> ch%s TX att state %2d = %3d dB" $::reg::CH $s [::att::db_of $s]]
}

proc att_on {{mode ""}} {
    # 記下進入前的設定, att_off 時恢復
    set ::att::saved [list \
        agc_bypass_agc      [reg_rd agc_bypass_agc] \
        agc_reg5            [reg_rd agc_reg5] \
        gain_index_mode_sel [reg_rd gain_index_mode_sel] \
        gain_index_manual   [reg_rd gain_index_manual]]
    # 從目前 bypass 檔位開始 (第一次為 0 = 130 dB)
    set ::att::state [expr {[reg_rd agc_bypass_tx_att_state] & 0x1F}]
    if {$::att::state > 27} { set ::att::state 0 }
    if {$mode ne "keep_digital"} {
        reg_set gain_index_manual 0
        reg_wr  gain_index_mode_sel 1           ;# 數位 gain 固定 0 dB
    }
    reg_wr  agc_bypass_tx_att_state $::att::state
    reg_wr  agc_bypass_agc 1                    ;# AGC 暫停
    # Reg5: TXRX_SW (bit7) = 0 -> TX, 其餘 bit 維持
    reg_wr  agc_reg5 [expr {[reg_rd agc_reg5] & 0x7F}]
    reg_pulse agc_bypass_sr_update 0x3          ;# 送 Reg1~4 + Reg5
    set ::att::on 1
    puts [format ">>> bypass ON (ch%s, TX mode, digital %s), TX att state %d = %d dB" \
        $::reg::CH [expr {$mode eq "keep_digital" ? "= Power Fit" : "fixed 0 dB"}] $::att::state [::att::db_of $::att::state]]
}

proc att_next {} {
    if {$::att::state >= 27} { puts ">>> already at state 27 (5 dB, minimum attenuation)"; return }
    ::att::apply [expr {$::att::state + 1}]
}

proc att_prev {} {
    if {$::att::state <= 0} { puts ">>> already at state 0 (130 dB, maximum attenuation)"; return }
    ::att::apply [expr {$::att::state - 1}]
}

proc att_set {s} { ::att::apply $s }

proc att_db {db} {
    # 不超過 db 的最大衰減檔位
    set best 27
    for {set s 27} {$s >= 0} {incr s -1} { if {[::att::db_of $s] <= $db} { set best $s } }
    ::att::apply $best
}

proc att_list {} {
    for {set s 0} {$s <= 27} {incr s} {
        puts [format "  state %2d = %3d dB%s" $s [::att::db_of $s] [expr {$::att::on && $s == $::att::state ? "   <- current" : ""}]]
    }
}

proc att_off {} {
    if {$::att::saved eq ""} { puts ">>> nothing to restore"; return }
    array set sv $::att::saved
    reg_wr gain_index_manual   $sv(gain_index_manual)
    reg_wr gain_index_mode_sel $sv(gain_index_mode_sel)
    reg_wr agc_reg5            $sv(agc_reg5)
    reg_wr agc_bypass_agc      $sv(agc_bypass_agc)  ;# 0 -> AGC 接手並依結果重寫衰減器
    set ::att::on 0
    puts ">>> bypass OFF, restored: bypass_agc $sv(agc_bypass_agc), agc_reg5 $sv(agc_reg5), gain_index_mode_sel $sv(gain_index_mode_sel), gain_index_manual $sv(gain_index_manual)"
}

puts "att_step.tcl loaded: att_on ?keep_digital? / att_next / att_prev / att_set <0~27> / att_db <dB> / att_list / att_off"
