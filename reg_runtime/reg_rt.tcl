# =============================================================================
# reg_rt.tcl  (2026-10-10, RegMap v8; 2026-10-12 build 14: mem38 bypass_axis_iq + RX ch7; 2026-10-14 mem39 signal_source_select)
#   ** Debug_008 版 (2026-10-19, 由 PJ22045_1R8T_release_Rex_rev0.1 RFSoC_TX/reg_runtime 複製): mem39 signal_source_select 1 -> 2 bit (2 / 3 = all_zero) **
#     .41 BMC XVC: TX 在 47DR1 (z1) = xvc:192.168.68.41:2542, 在 47DR2 (z2) = xvc:192.168.68.41:2550
#   ** PJ22045_1R8T 版 (2026-10-14, 由 Calibration_Gain_Control/reg_runtime 複製後修改) **
#     - 位址改成 PJ22045_1R8T design_1 的分配; 通道 ch1 ~ ch8; 沒有 rx_gain_control (RX ch7 暫存器已移除)
#   透過 JTAG (xsdb) 在 runtime 讀寫 system_reg_map + 各通道 addressable_reg_map
#   對應 Calibration_Gain_Control doc/Reg_map/ Reg_map_tx_ch_v0.2 + Reg_map_emu_sys_v0.1
#     system  0xA009_8000 (sys0~16, 所有通道共用, reg_ch 不影響)
#     channel ch1 ~ ch8 0xA009_0000 + 0x1000 x (N-1) (mem0~39 設定, mem64~70 狀態)
#             gain BRAM ch1 ~ ch8 0xA009_A000 + 0x2000 x (N-1) (本腳本不存取)
#
#   用法 (細節見 README.md):
#     互動:  xsdb -interactive reg_rt.tcl shell ?url? ?3?   連線後停在提示字元, 直接打 reg_set ... (單顆測試用)
#              url: TCP:localhost:31000 (既有 hw_server) / xvc:192.168.68.42:2542 (BMC XVC) / 省略 = 本機 USB-JTAG
#            (或 xsdb -> source reg_rt.tcl -> reg_connect ?url?)
#     批次:  xsdb reg_rt.tcl run  my_cfg.tcl        連線後執行設定檔
#            xsdb reg_rt.tcl list                    連線後列出所有暫存器目前值
#            xsdb reg_rt.tcl save my_backup.tcl      連線後把目前值存成設定檔 (v7 的 dump 改名)
#            xsdb reg_rt.tcl status ?1~8|all?        連線後 snapshot 並印出狀態 (= reg_dump)
#            xsdb reg_rt.tcl sim  my_cfg.tcl         不接板子, 只檢查設定檔與換算 (dry-run)
#   環境變數 (可選): REG_HW_URL (預設: 本機 hw_server 自動啟動; 經 BMC XVC: xvc:192.168.68.42:2542 = 47DR1, :2550 = 47DR2;
#                    既有 hw_server: TCP:localhost:31000), REG_TARGET (預設 *APU*)
#
#   指令:
#     reg_connect ?url? ?target_filter?   連 hw_server 並選 target
#     reg_sim                             離線模擬 (記憶體內, 初值 = reset 值)
#     reg_set  <name> <value>             以物理單位寫入 (dB / dBm / clk ...), 自動換算 + 範圍檢查 + 讀回確認
#     reg_get  <name>                     讀回物理值
#     reg_wr   <name> <raw>               直接寫 raw 值 (例 0xD8)
#     reg_rd   <name>                     讀 raw 值
#     reg_pulse <name> <raw>              寫 raw 後再寫 0 (正緣觸發, 例 agc_bypass_sr_update)
#     reg_list ?pattern?                  列出暫存器 (名稱支援 glob, 例 agc_rx_*)
#     reg_info <name>                     顯示位址 / 格式 / 範圍 / 說明
#     reg_run  <file>                     執行設定檔 (內容就是上述指令, 一行一個)
#     reg_save <file>                     把目前所有可寫暫存器 (system + 目前通道) 存成 reg_set 設定檔
#     reg_dump ?1~8|all? ?csv?            snapshot 狀態暫存器 (mem64~70) 並印出物理值; 同時附加到 CSV
#                                         (預設 reg_status_<日期>.csv, RX: reg_rx_status_<日期>.csv) 與 txt (reg_status_<日期時間>.txt)
#     reg_version                         讀 build_version (sys14)
#     reg_ch   <1~8>                      切換通道 (cal_plus_gain_control_ch1 ~ ch8 的 reg map base)
#     reg_fir_tap <t> <I> <Q>             FIR tap t (0~15) 以 I / Q 兩個 signed 16-bit 值寫入 (自動打包)
#     reg_template <file>                 產生全部暫存器的範本 (每行預設註解, 取消註解即生效)
# =============================================================================

namespace eval ::reg {
    variable BASE   0xA0090000
    variable CH     1
    # 各通道 reg map base (PJ22045_1R8T design_1 位址分配, 2026-10-14): ch1 ~ ch8 = 0xA009_0000 + 0x1000 x (N-1)
    variable CH_BASE
    array set CH_BASE {1 0xA0090000 2 0xA0091000 3 0xA0092000 4 0xA0093000 5 0xA0094000 6 0xA0095000 7 0xA0096000 8 0xA0097000}
    # system_reg_map base (PJ22045_1R8T design_1, 2026-10-14)
    variable SYS_BASE 0xA0098000
    # PJ22045_1R8T 沒有 rx_gain_control (RX ch7 暫存器已移除)
    variable RX_BASE ""
    variable SIM    0
    variable MEM
    array set MEM {}
    variable VERIFY 1
    # name -> {mem width type frac unit reset description scope}  (scope: ch / sys / sysro / st / rx / rxst)
    #   type u: unsigned, s: signed (2's comp); frac: 小數位數 (4 = 1/16); unit 只用於顯示
    variable T
    array set T {}
}

proc ::reg::def {mem name width type frac unit reset desc {scope ch}} {
    variable T
    set T($name) [list $mem $width $type $frac $unit $reset $desc $scope]
}
proc ::reg::scope {name} { return [lindex [field $name] 7] }
# 可寫的設定暫存器 (ch / sys / rx)
proc ::reg::is_cfg {name} { return [expr {[scope $name] in {ch sys rx}}] }
# 顯示用標籤 (sysN / memN / rxN)
proc ::reg::label {name} {
    set sc [scope $name]
    return [expr {$sc in {sys sysro} ? "sys" : ($sc in {rx rxst} ? "rx" : "mem")}][lindex [field $name] 0]
}

# ---------------------------------------------------------------- register table (RegMap v8, 由 doc/tools/regmap_def.py 產生)
#   scope: ch = 每個通道 (reg_ch 切換 base), sys = system_reg_map (所有通道共用), st = 通道狀態 (唯讀, reg_dump 讀取)
#          rx = rx_gain_control_ch7 設定, rxst = RX 狀態 (reg_dump 7)
::reg::def 0  in_band_fir_enable            1  u 0 ""     0      "0: FIR disable (impulse), 1: FIR enable"
for {set t 0} {$t < 16} {incr t} {
    ::reg::def [expr {$t + 1}] in_band_fir_coef_tap_$t 32 u 0 "" 0 "FIR tap $t coef: \[15:0\] I, \[31:16\] Q (raw)"
}
::reg::def 17 coarse_delay_offset            4  u 0 ""     0      "0 ~ 15; Delay_Cal coarse delay"
::reg::def 18 fractional_delay_offset        3  u 0 "/5clk" 0      "0 ~ 4; Delay_Cal fractional delay"
::reg::def 19 phase_offset                   16 u 0 ""     0      "Phase_Cal phase offset (cordic_0~4)"
::reg::def 20 gain_index_mode_sel            1  u 0 ""     0      "0: TXAGC, 1: manual; Gain_Compensation index source: 0 = gain_index_tx (TXAGC digital), 1 = gain_index_manual"
::reg::def 21 gain_index_manual              11 s 4 "dB"   0      "-64 ~ +63.9375 dB; Manual gain index (mode_sel = 1), offsets not added"
::reg::def 22 gain_index_ch_offset           9  s 4 "dB"   0      "-16 ~ +15.9375 dB; Channel magnitude trim (+ = gain), in the TXAGC target (analog first, residual digital)"
::reg::def 23 gain_index_rf_freq_offset      8  s 4 "dB"   0      "-8 ~ +7.9375 dB; RF-frequency magnitude trim (+ = gain), in the TXAGC target"
::reg::def 24 gain_index_temperature_offset  8  s 4 "dB"   0      "-8 ~ +7.9375 dB; Temperature magnitude trim (+ = gain), in the TXAGC target"
::reg::def 25 dac_output_ref_dbm             11 s 4 "dBm"  -25    "HW limit +10 ~ -40 dBm; DAC output measured with goal = goal_ref_dbfs (TXAGC Manual mode reference)"
::reg::def 26 goal_ref_dbfs                  11 s 4 "dBFS" -6     "-64 ~ +63.9375 dB; Goal (dBFS) used when dac_output_ref_dbm was measured; goal_rel_db = goal_dBFS - goal_ref_dbfs"
::reg::def 27 agc_reg5                       8  u 0 ""     128    "\[7\] TXRX_SW: 0 TX, 1 RX; \[6:2\] filter; \[1:0\] PA on = 11; Reg5 byte (595 QA~QH). \[7\] TXRX_SW = AGC mode source; \[6:2\] Filter {Vc2, Vc1, Vc0, "
::reg::def 28 agc_bypass_agc                 1  u 0 ""     0      "0: AGC, 1: bypass; 1: AGC paused; TX attenuator = agc_bypass_tx_att_state, RX = dummy 0 dB, digital comp = 0; SR sent only by agc_bypass_sr_update"
::reg::def 29 agc_bypass_tx_att_state        5  u 0 ""     0      "0 ~ 27 (0 = 130 dB ... 27 = 5 dB); TX analog attenuator state in bypass"
::reg::def 30 agc_bypass_sr_update           2  u 0 ""     0      "write 1 then 0 (0x3 = all 5 registers); Bypass only. \[0\] send Reg1~4, \[1\] send Reg5"
::reg::def 31 agc_manual_tx_att_en           1  u 0 ""     0      "0: formula, 1: manual; TX target attenuation = agc_manual_tx_att_db (other TX inputs ignored)"
::reg::def 32 agc_manual_tx_att_db           8  u 0 "dB"   0      "5 ~ 130; Manual TX target attenuation"
::reg::def 33 agc_target_power               8  s 0 "dBm"  0      "-128 ~ +127 dBm; Manual mode target output power (e.g. 0xD8 = -40 dBm)"
::reg::def 34 agc_linear_mode_offset         12 s 4 "dB"   0      "-128 ~ +127.9375 dB; Linear mode offset"
::reg::def 35 agc_manual_mode_offset         12 s 4 "dB"   0      "-128 ~ +127.9375 dB; Manual mode offset"
::reg::def 36 agc_manual_rx_att_en           1  u 0 ""     0      "0: RXAGC, 1: manual; Use agc_manual_rx_att_state instead of the RXAGC result (RX mode)"
::reg::def 37 agc_manual_rx_att_state        3  u 0 ""     0      "0 ~ 6 (0 ~ 60 dB); Manual RX attenuation state"
::reg::def 38 bypass_axis_iq                 1  u 0 ""     0      "0: normal, 1: bypass; Debug: m_axis_iq = Signal Source Mux output (FIR / calibration / gain control bypassed), normal path keeps running (build 14)"
::reg::def 39 signal_source_select           2  u 0 ""     0      "0: s_axis_iq_in_0 (Aurora), 1: s_axis_iq_in_1 (ADC), 2 / 3: all_zero (Debug_008, 160'd0 tvalid=1); Signal Source Mux: input sent to Power Fit / Calibration (and the mem38 bypass path), unselected inputs dropped"
::reg::def 0  signal_mode_select             1  u 0 ""     0      "0: CW, 1: Pulse; Power Fit input / goal: CW = cw_power_calc + cw_mode_goal_dbfs; Pulse = pulse_avg_amp + goal -(margin + PAPR), auto update" sys
::reg::def 1  power_limit_margin             3  u 0 "dB"   3      "0 ~ 7 dB; Power limit = -margin dBFS. CW goal = min(cw_mode_goal_dbfs, -margin); Pulse goal = -(margin + PAPR)" sys
::reg::def 2  cw_mode_goal_dbfs              11 s 4 "dBFS" -6     "-64 ~ 0 dB (HW: <= -margin); CW mode Power Fit goal (e.g. 0x7A0 = -6.0 dBFS ~ amplitude 8211)" sys
::reg::def 3  pulse_update_stable_cycle      4  u 0 "clk"  4      "0 ~ 15; Pulse auto update: pulse_avg_amp / pulse_papr must stay unchanged M clk after a change before they are latched together and one Power Fit resu" sys
::reg::def 4  agc_tx_power_mode              1  u 0 ""     0      "0: Linear, 1: Manual; TXAGC target T. Linear: 96.5625 + linear_mode_offset - rx_att_index x 10 + pf - offsets + algo; Manual: dac_output_ref_dbm + goa" sys
::reg::def 5  digital_apply_delay            8  u 0 "clk"  35     "0 ~ 255 (< agc_sr_update_period); Digital gain index applied N clk after the Reg1~4 SR start (35 = RCLK)" sys
::reg::def 6  agc_sr_update_period           8  u 0 "clk"  50     "HW min 50, max 255 (208 ns ~ 1.06 us); Shift register update round (SER transfer ~37 clk + hardware settling); shared by Reg1~4 and Reg5" sys
::reg::def 7  agc_mode_settle_cycle          16 u 0 "clk"  64     "HW min 1; Wait after Reg5 transfer before AGC switches RX/TX" sys
::reg::def 8  agc_rx_watch_cycle             32 u 0 "clk"  1000   "HW min 1; RXAGC S_WATCHING time (no signal -> back to 0 dB); set by PRI" sys
::reg::def 9  agc_rx_wait_dsa_cycle          8  u 0 "clk"  6      "HW min 1; RXAGC S_WAIT_DSA" sys
::reg::def 10 agc_rx_set_dsa_cycle           8  u 0 "clk"  6      "HW min 1; RXAGC S_SET_DSA" sys
::reg::def 11 agc_rx_wait_cycle              8  u 0 "clk"  50     "HW min 1; RXAGC S_WAIT (RF settling before flag clear)" sys
::reg::def 12 agc_rx_set_clear_cycle         8  u 0 "clk"  6      "HW min 6; RXAGC clear_or / clear_ov pulse width" sys
::reg::def 13 agc_rx_wait_clear_cycle        8  u 0 "clk"  16     "HW min 1; RXAGC S_WAIT_CLEAR" sys
::reg::def 14 build_version                 32 u 0 ""     0      "Build number (read only, = XSA / output_data index)" sysro
::reg::def 15 cw_power_avg_log2              4  u 0 ""     8      "0 ~ 12: CW power block average N = 2^k samples (256 = 1 us), Power Fit CW updated every N clk (build 13)" sys
::reg::def 16 agc_tx_att_hysteresis          8  u 4 "dB"   1      "0 ~ 15.9375 dB: TXAGC analog step hysteresis H, R range -H ~ 4.9375 + H dB (build 13)" sys
::reg::def 64 status_snapshot                16 u 0 ""     0      "Write 1: latch all st_* registers of this channel on the same clock (clk and adc_clk domains); read back the number of completed snapshots (increments" st
::reg::def 65 st_power_amp                   16 u 0 ""     0      "0 ~ 65535; power_fit_top/power_amp (cw_power_calc output)" st
::reg::def 66 st_gain_index_power_fit        10 s 4 "dB"   0      "-31.9375 ~ +31.9375 dB; Power Fit result pf = goal_dBFS - input_dBFS" st
::reg::def 67 st_goal_db                     12 s 4 "dBFS" 0      "-128 ~ 0 dB; Power Fit goal in dBFS (16384 = 0 dBFS). CW: min(cw_mode_goal_dbfs, -margin); Pulse: -(margin + PAPR)" st
::reg::def 68 st_goal_rel_db                 10 s 4 "dB"   0      "-31.9375 ~ +31.9375 dB; goal_dBFS - goal_ref_dbfs (TXAGC Manual mode)" st
::reg::def 69 st_gain_index_tx               12 s 4 "dB"   0      "-128 ~ +127.9375 dB; TXAGC digital gain index (pf - R) applied to Gain_Compensation (clk domain)" st
::reg::def 70 st_adc_flags                   4  u 0 ""     0      "\[0\] over_threshold1, \[1\] over_threshold2, \[2\] over_range, \[3\] over_voltage; RFDC flags at the snapshot (adc_clk domain, current value only)" st

# 有效範圍外的值: 照寫, 但提示硬體實際行為 (依 RTL): name -> {lo hi 超出時的行為}
array set ::reg::HWLIM {
    fractional_delay_offset {0 4 "Delay_Cal default: no fractional delay (same as 0)"}
    dac_output_ref_dbm      {-40 10 "agc_cdc clamps to -40 / +10 dBm"}
    agc_bypass_tx_att_state {0 27 "txagc decoder default: 130 dB (max attenuation)"}
    agc_manual_tx_att_db    {5 130 "analog clamps to 5 / 130 dB (R residual still applied)"}
    agc_manual_rx_att_state {0 6 "rxagc decoder default: 0 dB"}
    rx_manual_att_state     {0 6 "rxagc decoder default: 0 dB"}
    rx_bypass_att_state     {0 6 "rxagc decoder default: 0 dB"}
    rxagc_stable_cycle      {1 65535 "hardware uses 1"}
    agc_rx_wait_dsa_cycle   {1 255 "hardware uses the minimum"}
    agc_rx_set_dsa_cycle    {1 255 "hardware uses the minimum"}
    agc_rx_wait_cycle       {1 255 "hardware uses the minimum"}
    agc_rx_watch_cycle      {1 4294967295 "hardware uses the minimum"}
    agc_rx_set_clear_cycle  {6 255 "hardware uses 6"}
    agc_rx_wait_clear_cycle {1 255 "hardware uses the minimum"}
    agc_sr_update_period    {50 255 "hardware uses 50"}
    agc_mode_settle_cycle   {1 65535 "hardware uses 1"}
    cw_mode_goal_dbfs       {-64 0 "hardware also limits the CW goal to <= -power_limit_margin dBFS"}
    pulse_update_stable_cycle {0 15 "4-bit"}
    cw_power_avg_log2       {0 12 "hardware uses 12 (N = 4096)"}
}
proc ::reg::hw_limit_note {name value} {
    variable HWLIM
    if {![info exists HWLIM($name)]} return
    lassign $HWLIM($name) lo hi note
    if {$value < $lo || $value > $hi} { puts "  WARNING: $name $value outside valid $lo ~ $hi -> $note" }
}

# ---------------------------------------------------------------- 底層存取
proc ::reg::field {name} {
    variable T
    if {![info exists T($name)]} {
        set near [lsort [array names T *[string range $name 0 5]*]]
        error "unknown register '$name'[expr {[llength $near] ? " (did you mean: [join $near {, }])" : ""}]"
    }
    return $T($name)
}
proc ::reg::addr {name} {
    variable BASE; variable SYS_BASE; variable RX_BASE
    set sc [scope $name]
    set b [expr {$sc in {sys sysro} ? $SYS_BASE : ($sc in {rx rxst} ? $RX_BASE : $BASE)}]
    return [expr {$b + 4 * [lindex [field $name] 0]}]
}
proc ::reg::ro_guard {name} {
    if {[scope $name] eq "sysro" || ([scope $name] in {st rxst} && $name ni {status_snapshot rx_status_snapshot})} {
        error "$name is read-only"
    }
}
proc ::reg::hw_wr {a v} {
    variable SIM; variable MEM
    if {$SIM} { set MEM($a) $v; return }
    mwr -force $a $v
}
proc ::reg::hw_rd {a} {
    variable SIM; variable MEM
    if {$SIM} { return [expr {[info exists MEM($a)] ? $MEM($a) : 0}] }
    return [expr {[lindex [mrd -force -value $a] 0] & 0xFFFFFFFF}]
}

# 物理值 <-> raw
proc ::reg::to_raw {name value} {
    lassign [field $name] mem width type frac
    if {![string is double -strict $value]} { error "$name: '$value' is not a number" }
    set scaled [expr {$value * (1 << $frac)}]
    set raw [expr {round($scaled)}]
    if {abs($scaled - $raw) > 1e-9} {
        puts "  note: $name $value rounded to [expr {double($raw) / (1 << $frac)}] (step [expr {1.0 / (1 << $frac)}])"
    }
    if {$type eq "s"} {
        set lo [expr {-(1 << ($width - 1))}]; set hi [expr {(1 << ($width - 1)) - 1}]
    } else {
        set lo 0; set hi [expr {(1 << $width) - 1}]
    }
    if {$raw < $lo || $raw > $hi} {
        error "$name: $value out of range ([fmt_phys $name $lo] ~ [fmt_phys $name $hi])"
    }
    return [expr {$raw & ((1 << $width) - 1)}]
}
proc ::reg::to_phys {name raw} {
    lassign [field $name] mem width type frac
    set v [expr {$raw & ((1 << $width) - 1)}]
    if {$type eq "s" && ($v >> ($width - 1))} { set v [expr {$v - (1 << $width)}] }
    return [expr {$frac ? double($v) / (1 << $frac) : $v}]
}
proc ::reg::fmt_phys {name raw} {
    lassign [field $name] mem width type frac unit
    set p [to_phys $name $raw]
    if {$frac} { set p [format %.4f $p] ; set p [string trimright [string trimright $p 0] .] }
    return [string trim "$p $unit"]
}
proc ::reg::check_raw {name raw} {
    lassign [field $name] mem width
    if {![string is wideinteger -strict $raw]} { error "$name: '$raw' is not an integer" }
    if {$raw < 0 || $raw > ((1 << $width) - 1)} {
        error "$name: raw [format 0x%X $raw] exceeds [expr {$width}] bits (max [format 0x%X [expr {(1 << $width) - 1}]])"
    }
}
proc ::reg::write_verify {name raw} {
    variable VERIFY
    set a [addr $name]
    hw_wr $a $raw
    if {$VERIFY} {
        set rb [hw_rd $a]
        if {$rb != $raw} { error "$name: readback [format 0x%08X $rb] != written [format 0x%08X $raw] (addr [format 0x%08X $a])" }
    }
}

# ---------------------------------------------------------------- 使用者指令
proc reg_connect {{url ""} {filter ""}} {
    if {$url eq ""}    { set url    [expr {[info exists ::env(REG_HW_URL)] ? $::env(REG_HW_URL) : ""}] }
    if {$filter eq ""} { set filter [expr {[info exists ::env(REG_TARGET)] ? $::env(REG_TARGET) : "*APU*"}] }
    set ::reg::SIM 0
    if {$url eq ""} {
        # 本機 USB-JTAG (例 JTAG-HS3): connect 會自動啟動本機 hw_server
        set url "local hw_server"
        connect
    } elseif {[string match -nocase "xvc:*" $url]} {
        # 經 BMC 的 XVC server (網路 JTAG), 例 xvc:192.168.68.42:2542 (47DR1) / :2550 (47DR2)
        connect -xvc-url TCP:[string range $url 4 end]
    } else {
        # 既有 hw_server, 例 TCP:localhost:31000
        connect -url $url
    }
    targets -set -nocase -filter "name =~ \"$filter\""
    puts "connected: $url (target filter $filter), channel ch$::reg::CH (base [format 0x%08X $::reg::BASE])"
    puts [targets]
    # 連線確認: build_version, agc_reg5 (reset 0x80), power_limit_margin (system, reset 3)
    puts "check: build_version = [reg_version], agc_reg5 = [reg_rd agc_reg5], power_limit_margin = [reg_rd power_limit_margin]"
}
proc reg_sim {} {
    set ::reg::SIM 1
    array unset ::reg::MEM
    foreach {ch base} [array get ::reg::CH_BASE] {
        if {$base eq ""} continue
        foreach n [array names ::reg::T] {
            if {[::reg::scope $n] ne "ch"} continue
            set ::reg::MEM([expr {$base + 4 * [lindex $::reg::T($n) 0]}]) [::reg::to_raw $n [lindex $::reg::T($n) 5]]
        }
    }
    foreach n [array names ::reg::T] {
        if {[::reg::scope $n] in {sys rx}} { set ::reg::MEM([::reg::addr $n]) [::reg::to_raw $n [lindex $::reg::T($n) 5]] }
    }
    set ::reg::MEM([::reg::addr build_version]) 0
    puts "SIM mode: no hardware access, registers start at reset values"
}
proc reg_set {name value} {
    ::reg::ro_guard $name
    set raw [::reg::to_raw $name $value]
    ::reg::hw_limit_note $name [::reg::to_phys $name $raw]
    ::reg::write_verify $name $raw
    puts [format "  %-30s <- %-12s (raw 0x%X @ 0x%08X)" $name [::reg::fmt_phys $name $raw] $raw [::reg::addr $name]]
}
proc reg_ch {ch} {
    if {![info exists ::reg::CH_BASE($ch)]} { error "reg_ch: unknown channel '$ch' (1 ~ 8)" }
    if {$::reg::CH_BASE($ch) eq ""} { error "reg_ch: ch$ch base address not assigned yet (update ::reg::CH_BASE in reg_rt.tcl)" }
    set ::reg::CH $ch
    set ::reg::BASE $::reg::CH_BASE($ch)
    puts "channel ch$ch, reg map base [format 0x%08X $::reg::BASE]"
}
proc reg_fir_tap {t i q} {
    if {![string is integer -strict $t] || $t < 0 || $t > 15} { error "reg_fir_tap: tap '$t' must be 0~15" }
    foreach {n v} [list I $i Q $q] {
        if {![string is integer -strict $v] || $v < -32768 || $v > 32767} { error "reg_fir_tap $t: $n '$v' must be an integer -32768 ~ 32767" }
    }
    set raw [expr {(($q & 0xFFFF) << 16) | ($i & 0xFFFF)}]
    ::reg::write_verify in_band_fir_coef_tap_$t $raw
    puts [format "  %-30s <- I %6d, Q %6d (raw 0x%08X)" in_band_fir_coef_tap_$t $i $q $raw]
}
proc reg_template {file} {
    set fh [open $file w]
    puts $fh "# ============================================================================="
    puts $fh "# reg_template: 全部暫存器範本 (RegMap v8: system + channel). 每行預設註解 -> 要改哪顆就拿掉 # 並填值"
    puts $fh "#   沒取消註解的暫存器不會被寫入. 由上往下依序寫入, 寫完立即生效"
    puts $fh "#   執行: xsdb reg_rt.tcl run <this file>     離線檢查: xsdb reg_rt.tcl sim <this file>"
    puts $fh "#   預填值 = reset 值; 單位見每行註解"
    puts $fh "# ============================================================================="
    puts $fh "# reg_ch 1                                  ;# 通道: 1 ~ 8 = ch1 ~ ch8 (預設 ch1; system 暫存器不受影響)"
    set last ""
    foreach n [::reg::sorted [array names ::reg::T]] {
        lassign $::reg::T($n) mem width type frac unit reset desc scope
        if {![::reg::is_cfg $n]} continue
        set grp [expr {$scope eq "sys" ? "SYSTEM (system_reg_map, 所有通道共用)" : $scope eq "rx" ? "RX ch7 (rx_gain_control_ch7, RX-only AGC)" : ($mem == 39 ? "Signal Source Mux" : $mem == 38 ? "Debug" : $mem <= 16 ? "In-band FIR (tap: reg_fir_tap <t> <I> <Q>, I/Q signed 16-bit)" : ($mem <= 21 ? "Calibration / Gain index" : ($mem <= 26 ? "Gain index offset / TXAGC 參考" : "AGC_EMU")))}]
        set mlabel [::reg::label $n]
        if {$grp ne $last} { puts $fh "\n# --- $grp"; set last $grp }
        if {[string match in_band_fir_coef_tap_* $n]} {
            set t [string range $n 21 end]
            puts $fh [format "# reg_fir_tap %-2s %-6s %-6s                 ;# %-5s tap %s: I Q" $t 0 0 $mlabel $t]
        } elseif {$n in {agc_bypass_sr_update rx_bypass_sr_update}} {
            puts $fh [format "# reg_pulse %-30s 0x3     ;# %-5s %s" $n $mlabel $desc]
        } elseif {$frac == 0 && $type eq "u" && $unit eq ""} {
            puts $fh [format "# reg_wr  %-30s 0x%-6X ;# %-5s %s" $n [::reg::to_raw $n $reset] $mlabel $desc]
        } else {
            puts $fh [format "# reg_set %-30s %-8s ;# %-5s %s" $n $reset $mlabel "[string trim "$unit"] | $desc"]
        }
    }
    close $fh
    puts "saved: $file"
}
proc reg_get {name} { return [::reg::to_phys $name [::reg::hw_rd [::reg::addr $name]]] }
proc reg_wr {name raw} {
    ::reg::ro_guard $name
    ::reg::check_raw $name $raw
    ::reg::hw_limit_note $name [::reg::to_phys $name $raw]
    ::reg::write_verify $name $raw
    puts [format "  %-30s <- raw 0x%X (%s)" $name $raw [::reg::fmt_phys $name $raw]]
}
proc reg_rd {name} { return [format 0x%X [::reg::hw_rd [::reg::addr $name]]] }
proc reg_pulse {name raw} {
    ::reg::ro_guard $name
    ::reg::check_raw $name $raw
    ::reg::hw_wr [::reg::addr $name] $raw
    ::reg::hw_wr [::reg::addr $name] 0
    puts [format "  %-30s <- pulse 0x%X -> 0" $name $raw]
}
# 排序: system 在前, 再 channel 設定 / 狀態, 最後 RX ch7
proc ::reg::sort_key {n} {
    set sc [lindex $::reg::T($n) 7]
    return [expr {($sc in {sys sysro} ? 0 : ($sc in {rx rxst} ? 2000 : 1000)) + [lindex $::reg::T($n) 0]}]
}
proc ::reg::sorted {names} {
    return [lsort -command {apply {{a b} { expr {[::reg::sort_key $a] - [::reg::sort_key $b]} }}} $names]
}
proc reg_list {{pattern *}} {
    puts [format "%-6s %-10s %-30s %-10s %s" reg addr name raw value]
    foreach n [::reg::sorted [array names ::reg::T $pattern]] {
        set raw [::reg::hw_rd [::reg::addr $n]]
        set sc [::reg::scope $n]
        puts [format "%-6s 0x%08X %-30s 0x%-8X %s%s" [::reg::label $n] [::reg::addr $n] $n $raw [::reg::fmt_phys $n $raw] \
            [expr {$sc in {st rxst} ? "  (last snapshot)" : ""}]]
    }
}
proc reg_version {} { return [::reg::hw_rd [::reg::addr build_version]] }
proc reg_info {name} {
    lassign [::reg::field $name] mem width type frac unit reset desc
    set fmt [expr {$type eq "s" ? "S" : "U"}][expr {$width - $frac - ($type eq "s")}].$frac
    set lab [::reg::label $name]
    puts "$name: $lab ([::reg::scope $name]) @ [format 0x%08X [::reg::addr $name]], $width bit $fmt $unit, reset $reset\n  $desc"
}
proc reg_run {file} {
    set fh [open $file r]; set n 0
    while {[gets $fh line] >= 0} {
        incr n
        set line [string trim $line]
        if {$line eq "" || [string index $line 0] eq "#"} continue
        if {[catch {uplevel #0 $line} err]} { close $fh; error "$file:$n: $err" }
    }
    close $fh
    puts "done: $file"
}
proc reg_save {file} {
    set fh [open $file w]
    puts $fh "# reg_save [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]  build [reg_version], ch$::reg::CH  (reg_run this file to restore)"
    puts $fh "reg_ch $::reg::CH"
    foreach n [::reg::sorted [array names ::reg::T]] {
        if {$n in {agc_bypass_sr_update rx_bypass_sr_update} || ![::reg::is_cfg $n]} continue
        set raw [::reg::hw_rd [::reg::addr $n]]
        lassign $::reg::T($n) mem width type frac
        if {$frac == 0 && $type eq "u"} {
            puts $fh [format "reg_wr  %-30s 0x%X" $n $raw]
        } else {
            puts $fh [format "reg_set %-30s %s" $n [::reg::to_phys $n $raw]]
        }
    }
    close $fh
    puts "saved: $file"
}

# ---------------------------------------------------------------- 狀態 snapshot (mem64~70; RX ch7: rx16~20)
proc ::reg::snapshot {base {off 0x100}} {
    set a [expr {$base + $off}]
    set c0 [expr {[hw_rd $a] & 0xFFFF}]
    hw_wr $a 1
    if {$::reg::SIM} { set ::reg::MEM($a) [expr {($c0 + 1) & 0xFFFF}]; return [expr {($c0 + 1) & 0xFFFF}] }
    for {set i 0} {$i < 20} {incr i} {
        set c [expr {[hw_rd $a] & 0xFFFF}]
        if {$c != $c0} { return $c }
    }
    error "status snapshot timeout (count stays $c0 @ [format 0x%08X $a])"
}
proc reg_dump {{chs ""} {csv ""}} {
    if {$chs eq "" } { set chs $::reg::CH }
    if {$chs eq "all"} { set chs [lsort -integer [array names ::reg::CH_BASE]] }
    set ts   [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]
    set tsf  [clock format [clock seconds] -format {%Y%m%d_%H%M%S}]
    if {$csv eq ""} { set csv "reg_status_[clock format [clock seconds] -format %Y%m%d].csv" }
    set st {st_power_amp st_gain_index_power_fit st_goal_db st_goal_rel_db st_gain_index_tx}
    set cfg {signal_mode_select power_limit_margin cw_mode_goal_dbfs agc_tx_power_mode}
    set new [expr {![file exists $csv]}]
    set fc [open $csv a]
    if {$new} { puts $fc "time,build,ch,snapshot,[join $st ,],over_threshold1,over_threshold2,over_range,over_voltage,[join $cfg ,],goal_ref_dbfs,dac_output_ref_dbm,agc_target_power" }
    set txt "reg_status_$tsf.txt"
    set ft [open $txt w]
    set ver [reg_version]
    set saved $::reg::BASE
    foreach ch $chs {
        if {![info exists ::reg::CH_BASE($ch)]} { close $fc; close $ft; error "reg_dump: unknown channel '$ch' (1 ~ 8 / all)" }
        set ::reg::BASE $::reg::CH_BASE($ch)
        set cnt [::reg::snapshot $::reg::BASE]
        set vals {}; set out {}
        lappend out [format "=== ch%s status  snapshot #%d  %s  build %d ===" $ch $cnt $ts $ver]
        foreach n $st {
            set raw [hw_rd_n $n]
            lappend vals [::reg::to_phys $n $raw]
            lappend out [format "  %-26s %s" $n [::reg::fmt_phys $n $raw]]
        }
        set fl [hw_rd_n st_adc_flags]
        set fb [list [expr {$fl & 1}] [expr {($fl >> 1) & 1}] [expr {($fl >> 2) & 1}] [expr {($fl >> 3) & 1}]]
        lappend out [format "  %-26s ot1 %d  ot2 %d  or %d  ov %d" adc_flags {*}$fb]
        set cv {}
        foreach n [concat $cfg goal_ref_dbfs dac_output_ref_dbm agc_target_power] {
            set raw [hw_rd_n $n]; lappend cv [::reg::to_phys $n $raw]
        }
        lappend out [format "  settings: mode %s, margin %s dB, cw_goal %s dBFS, tx_power_mode %s, goal_ref %s dBFS, dac_ref %s dBm, target %s dBm" \
            [expr {[lindex $cv 0] ? "Pulse" : "CW"}] [lindex $cv 1] [lindex $cv 2] [expr {[lindex $cv 3] ? "Manual" : "Linear"}] \
            [lindex $cv 4] [lindex $cv 5] [lindex $cv 6]]
        foreach l $out { puts $l; puts $ft $l }
        puts $fc "$ts,$ver,$ch,$cnt,[join $vals ,],[join $fb ,],[join $cv ,]"
    }
    set ::reg::BASE $saved
    close $fc; close $ft
    puts "saved: $txt, appended: $csv"
}
proc hw_rd_n {name} { return [::reg::hw_rd [::reg::addr $name]] }
proc ::reg::dump_rx {ts ver csv} {
    set cnt [snapshot $::reg::RX_BASE 0x40]
    set st  [hw_rd_n st_rx_att_state]
    set fl  [hw_rd_n st_rx_adc_flags]
    set fb  [list [expr {$fl & 1}] [expr {($fl >> 1) & 1}] [expr {($fl >> 2) & 1}] [expr {($fl >> 3) & 1}]]
    set stb [hw_rd_n st_rxagc_stable]
    set en  [hw_rd_n st_rx_agc_enable]
    set cv {}
    foreach n {rx_manual_att_en rx_manual_att_state rx_bypass_agc rx_reg5 rxagc_stable_cycle} { lappend cv [hw_rd_n $n] }
    set out {}
    lappend out [format "=== rx ch7 status  snapshot #%d  %s  build %d ===" $cnt $ts $ver]
    lappend out [format "  %-26s %d (%d dB)" st_rx_att_state $st [expr {10 * $st}]]
    lappend out [format "  %-26s ot1 %d  ot2 %d  or %d  ov %d" adc_flags {*}$fb]
    lappend out [format "  %-26s %d" st_rxagc_stable $stb]
    lappend out [format "  %-26s %d" st_rx_agc_enable $en]
    lappend out [format "  settings: manual_en %d, manual_state %d, bypass %d, reg5 0x%02X, stable_cycle %d" {*}$cv]
    set new [expr {![file exists $csv]}]
    set fc [open $csv a]
    if {$new} { puts $fc "time,build,snapshot,st_rx_att_state,over_threshold1,over_threshold2,over_range,over_voltage,st_rxagc_stable,st_rx_agc_enable,rx_manual_att_en,rx_manual_att_state,rx_bypass_agc,rx_reg5,rxagc_stable_cycle" }
    puts $fc "$ts,$ver,$cnt,$st,[join $fb ,],$stb,$en,[join $cv ,]"
    close $fc
    return $out
}

# ---------------------------------------------------------------- 批次模式
if {[info exists argv] && [llength $argv] > 0 && [info script] ne "" && [file tail [info script]] eq "reg_rt.tcl"} {
    set cmd [lindex $argv 0]; set arg [lindex $argv 1]
    set stay 0
    if {[catch {
        switch -- $cmd {
            shell {
                # 搭配 xsdb -interactive: 連線後停在 xsdb 提示字元, 直接打 reg_* 指令
                #   xsdb -interactive reg_rt.tcl shell TCP:localhost:31000      既有 hw_server (例 Vivado 開的)
                #   xsdb -interactive reg_rt.tcl shell xvc:192.168.68.42:2542   經 BMC XVC (47DR1; 47DR2 = 2550)
                #   xsdb -interactive reg_rt.tcl shell                          本機 USB-JTAG (HS3)
                #   ... shell <url> 3                                           從 ch3 開始 (1 ~ 8)
                #   xsdb -interactive reg_rt.tcl shell sim                      離線模擬
                #   連線失敗時留在提示字元, 可再打 reg_connect <url> 重試
                set stay 1
                set url ""; set ch ""
                foreach a [lrange $argv 1 end] {
                    if {$a eq "sim"} { set url sim } elseif {$a in {1 2 3 4 5 6 7 8}} { set ch $a } else { set url $a }
                }
                if {$url eq "sim"} {
                    reg_sim
                } elseif {[catch {reg_connect $url} cerr]} {
                    puts "ERROR: connect failed: $cerr"
                    puts "  retry: reg_connect TCP:<host>:<port>  (existing hw_server, e.g. TCP:localhost:31000)"
                    puts "         reg_connect xvc:<ip>:<port>    (BMC XVC, 47DR1 2542 / 47DR2 2550)"
                    puts "         reg_connect                    (local USB-JTAG, e.g. JTAG-HS3)"
                }
                if {$ch ne ""} { reg_ch $ch }
                puts "ready: reg_set / reg_get / reg_wr / reg_rd / reg_fir_tap / reg_ch / reg_list / reg_dump / reg_save / reg_run <file> ... (exit to quit)"
                # Debug_008: 一併載入簡化指令 show / ch / rd / wr / wr_all（tools/xsdb_shell_procs.tcl）
                set _p [file join [file dirname [file normalize [info script]]] tools xsdb_shell_procs.tcl]
                if {[file exists $_p]} { source $_p; puts "also: show / ch <n> / rd <off> / wr <off> <val> / wr_all <off> <val>" }
            }
            run  { reg_connect; reg_run $arg }
            list { reg_connect; reg_list [expr {$arg eq "" ? "*" : $arg}] }
            save { reg_connect; reg_save $arg }
            dump { puts "NOTE: v8: 'dump' (save settings) is now 'save'; 'status' = reg_dump"; reg_connect; reg_save $arg }
            status { reg_connect; reg_dump [expr {$arg eq "" ? 1 : $arg}] }
            sim  { reg_sim; if {$arg ne ""} { reg_run $arg }; reg_list }
            template { reg_template [expr {$arg eq "" ? "reg_template.tcl" : $arg}] }
            default { error "unknown command '$cmd' (shell / run / list / save / status / sim / template)" }
        }
    } err]} { puts "ERROR: $err"; exit 1 }
    if {!$stay} { exit 0 }
}
