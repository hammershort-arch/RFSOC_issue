# =============================================================================
# xsdb_shell.tcl — 互動式 xsdb：連到 .41 的 RFSoC_TX，提供 reg map 小指令（2026-10-19）
#   啟動: xsdb -interactive xsdb_shell.tcl [xvc_port]      （預設 2542 = 47DR1；TX 在 47DR2 時用 2550）
#   位址: ch N base = 0xA009_0000 + 0x1000 × (N−1)（RegMap v8）；system_reg_map = 0xA009_8000
#   所有存取都用 PSU (DAP) + -force，不會 halt A53。RFSoC 重開機 / MTS 後回到 PS 預設值。
# 指令:
#   show                    8 通道常用暫存器一覽（tap7 / fir_en / phase / mode_sel / manual / bypass / src）
#   ch <n>                  設定目前通道（預設 1）
#   rd <off>                讀目前通道  例: rd 0x098
#   wr <off> <val>          寫目前通道並讀回  例: wr 0x098 1
#   wr_all <off> <val>      ch1~8 都寫並讀回  例: wr_all 0x09C 1
#   常用 offset: 0x000 fir_enable, 0x004~0x040 fir_tap00~15, 0x04C phase_offset (143×度),
#                0x050 gain_index_mode_sel, 0x054 gain_index_manual (S6.4), 0x098 bypass_axis_iq,
#                0x09C signal_source_select (Debug_008: 0 Aurora / 1 ADC / 2 all_zero)
#   原生 xsdb 指令（mrd -force / mwr -force / targets ...）也都可以直接用
# =============================================================================
set ::TXPORT [expr {[llength $argv] ? [lindex $argv 0] : 2542}]
set ::CH 1
connect -xvc-url TCP:192.168.68.41:$::TXPORT
after 2500
targets -set -nocase -filter {name =~ "PSU"}

source [file join [file dirname [file normalize [info script]]] xsdb_shell_procs.tcl]

puts "\n已連線 XVC 192.168.68.41:$::TXPORT（PSU target）。指令: show / ch <n> / rd <off> / wr <off> <val> / wr_all <off> <val>"
show
