# xsdb_ch_mode.tcl — RFSoC_TX ch1~8：設定 mem39 signal_source_select 與 mem38 bypass_axis_iq，寫前讀 FIR tap7（預期 0x7FFF）確認讀寫有效
# 用法: xsdb xsdb_ch_mode.tcl <xvc_port> <mem39> <mem38>
#   例: xsdb xsdb_ch_mode.tcl 2542 1 0   （47DR1 = TX；ADC loopback 經 cal_plus_gain_control 完整處理）
#   mem39: 0 = Aurora (s_axis_iq_in_0), 1 = 本板 ADC (s_axis_iq_in_1), 2 = all_zero (Debug_008)；mem38: 0 = 完整處理, 1 = bypass 直接送 DAC
# 用 PSU (DAP) + -force 存取，不會 halt A53。RFSoC 重開機 / MTS 後恢復預設 (0 / 0)
lassign $argv port m39 m38
connect -xvc-url TCP:192.168.68.41:$port
after 2000
targets -set -nocase -filter {name =~ "PSU"}
for {set n 1} {$n <= 8} {incr n} {
  set base [expr {0xA0090000 + 0x1000*($n-1)}]
  set tap7 [lindex [mrd -force -value [expr {$base + 0x20}] 1] 0]
  set b39 [lindex [mrd -force -value [expr {$base + 0x9C}] 1] 0]
  set b38 [lindex [mrd -force -value [expr {$base + 0x98}] 1] 0]
  mwr -force [expr {$base + 0x9C}] $m39
  mwr -force [expr {$base + 0x98}] $m38
  set a39 [lindex [mrd -force -value [expr {$base + 0x9C}] 1] 0]
  set a38 [lindex [mrd -force -value [expr {$base + 0x98}] 1] 0]
  puts [format "ch%d tap7=0x%08X  mem39 signal_source_select: 0x%X -> 0x%X   mem38 bypass_axis_iq: 0x%X -> 0x%X" $n $tap7 $b39 $a39 $b38 $a38]
}
foreach t [targets -target-properties] { if {[dict get $t name] eq "Cortex-A53 #0"} { puts "A53#0 [dict get $t state_reason]" } }
disconnect
