# xsdb_shell_procs.tcl — 簡化指令（只定義 proc，不連線），給 reg_rt.tcl shell / xsdb_shell.tcl 共用（2026-10-19）
#   show                 8 通道常用暫存器一覽（tap7 / fir_en / phase / mode_sel / manual / bypass / src）
#   ch <n>               切換目前通道（在 reg_rt.tcl 裡會同時 reg_ch n）
#   rd <off>             讀目前通道          例: rd 0x09C
#   wr <off> <val>       寫目前通道並讀回    例: wr 0x098 1
#   wr_all <off> <val>   ch1~8 都寫並讀回    例: wr_all 0x09C 0
#   常用 offset: 0x000 fir_enable, 0x004~0x040 fir_tap00~15, 0x04C phase_offset (143×度), 0x050 gain_index_mode_sel,
#                0x054 gain_index_manual (S6.4), 0x098 bypass_axis_iq, 0x09C signal_source_select (0 Aurora / 1 ADC / 2 all_zero)
#   存取用 mrd/mwr -force（不 halt A53）；RegMap v8：ch N base = 0xA009_0000 + 0x1000 × (N−1)
proc ::sh_base {n} { expr {0xA0090000 + 0x1000*($n-1)} }
proc ::sh_r32 {a} { expr {[lindex [mrd -force -value $a 1] 0] & 0xFFFFFFFF} }
proc ::sh_cur {} { expr {[info exists ::reg::CH] ? $::reg::CH : ([info exists ::CH] ? $::CH : 1)} }
proc ch {n} {
    if {$n < 1 || $n > 8} { error "ch: 1~8" }
    set ::CH $n
    if {[llength [info commands reg_ch]]} { reg_ch $n }
    puts [format "目前通道 ch%d (base 0x%08X)" $n [sh_base $n]]
}
proc rd {off} {
    set n [sh_cur]; set v [sh_r32 [expr {[sh_base $n] + $off}]]
    puts [format "ch%d \[0x%03X\] = 0x%X (%d)" $n $off $v $v]
}
proc wr {off val} {
    set n [sh_cur]; set a [expr {[sh_base $n] + $off}]
    set b [sh_r32 $a]; mwr -force $a $val; set v [sh_r32 $a]
    puts [format "ch%d \[0x%03X\] 0x%X -> 0x%X%s" $n $off $b $v [expr {$v == ($val & 0xFFFFFFFF) ? "" : "   !! 讀回不符"}]]
}
proc wr_all {off val} {
    for {set n 1} {$n <= 8} {incr n} {
        set a [expr {[sh_base $n] + $off}]
        set b [sh_r32 $a]; mwr -force $a $val; set v [sh_r32 $a]
        puts [format "ch%d \[0x%03X\] 0x%X -> 0x%X%s" $n $off $b $v [expr {$v == ($val & 0xFFFFFFFF) ? "" : "   !! 讀回不符"}]]
    }
}
proc show {} {
    puts "ch   tap7        fir_en phase   mode_sel manual bypass src"
    for {set n 1} {$n <= 8} {incr n} {
        set b [sh_base $n]
        puts [format "ch%d  0x%08X  %-6X 0x%04X  %-8X 0x%03X  %-6X %X" $n [sh_r32 [expr {$b+0x20}]] [sh_r32 $b] \
            [sh_r32 [expr {$b+0x4C}]] [sh_r32 [expr {$b+0x50}]] [sh_r32 [expr {$b+0x54}]] [sh_r32 [expr {$b+0x98}]] [sh_r32 [expr {$b+0x9C}]]]
    }
}
