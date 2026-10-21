# xsdb_reg_wr.tcl — RFSoC_TX（RegMap v8）ch<lo>~<hi> 寫一個暫存器並讀回；同時印 fir_en / mode_sel / manual / bypass / src
# 用法: xsdb xsdb_reg_wr.tcl <xvc_port> <offset> <value> [lo] [hi]
#   例: xsdb xsdb_reg_wr.tcl 2542 0x050 0      （ch1~8 gain_index_mode_sel = 0 → TXAGC）
# 用 PSU (DAP) + -force，不 halt A53。2026-10-19
lassign $argv port off val lo hi
if {$lo eq ""} { set lo 1 }; if {$hi eq ""} { set hi 8 }
connect -xvc-url TCP:192.168.68.41:$port
after 2500
targets -set -nocase -filter {name =~ "PSU"}
set err 0
for {set n $lo} {$n <= $hi} {incr n} {
  set base [expr {0xA0090000 + 0x1000*($n-1)}]
  set tap7 [lindex [mrd -force -value [expr {$base + 0x20}] 1] 0]
  set b [lindex [mrd -force -value [expr {$base + $off}] 1] 0]
  mwr -force [expr {$base + $off}] $val
  set a [lindex [mrd -force -value [expr {$base + $off}] 1] 0]
  if {$a != $val} { incr err }
  set rd {}; foreach o {0x000 0x050 0x054 0x098 0x09C} { lappend rd [format 0x%X [lindex [mrd -force -value [expr {$base + $o}] 1] 0]] }
  puts [format "ch%d tap7=0x%08X  [0x%03X] 0x%X -> 0x%X   fir_en/mode_sel/manual/bypass/src = %s" $n $tap7 $off $b $a [join $rd /]]
}
foreach t [targets -target-properties] { if {[dict get $t name] eq "Cortex-A53 #0"} { puts "A53#0 [dict get $t state_reason]" } }
puts "ERRORS $err"
disconnect
