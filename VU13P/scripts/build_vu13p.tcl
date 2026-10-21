# =============================================================================
# build_vu13p.tcl  (Debug_007, 2026-10-17; 由同事 rev0.12 source/scripts/build.tcl 修改)
#   改動: 路徑改成專案相對路徑; 輸出到 ../output_data/<name>.bit / .ltx; 加 report_power;
#         OOC / synth_1 / impl_1 分段計時; 失敗的 run (~/.Xilinx Bus error 等) reset 後重跑, 最多 3 次
#   Usage: cd VU13P; vivado -mode batch -source scripts/build_vu13p.tcl -tclargs <name> [jobs]
# =============================================================================
set name [lindex $argv 0]
set jobs [expr {[llength $argv] > 1 ? [lindex $argv 1] : 8}]
set proj_dir [pwd]
set rpt $proj_dir/reports
file mkdir $rpt
set bd aurora_gty_vu13p_rst
set t0 [clock seconds]
proc stamp {tag} { global t0; puts "TIME $tag [clock format [clock seconds] -format {%H:%M:%S}] (+[expr {[clock seconds] - $t0}] s)" }

open_project [lindex [glob $proj_dir/*.xpr] 0]
# --- refresh top BD + wrapper (同同事 build.tcl)
open_bd_design [get_files $bd.bd]
validate_bd_design
save_bd_design
make_wrapper -files [get_files $bd.bd] -top -force
close_bd_design [current_bd_design]
set w [file normalize $proj_dir/vu13p.gen/sources_1/bd/$bd/hdl/${bd}_wrapper.v]
if {[get_files -quiet $w] eq ""} { add_files -norecurse -fileset sources_1 $w }
set_property top ${bd}_wrapper [get_filesets sources_1]
update_compile_order -fileset sources_1
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]
set_property INCREMENTAL_CHECKPOINT {} [get_runs synth_1]
catch {set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs impl_1]}

generate_target all [get_files $bd.bd]
catch {create_ip_run [get_files $bd.bd]} m
proc ooc_runs {} { return [get_runs -filter {IS_SYNTHESIS && NAME != synth_1}] }
proc bad {r} { set s [get_property STATUS $r]; return [expr {[get_property PROGRESS $r] ne "100%" || [string match "*ERROR*" $s] || [string match "*failed*" $s]}] }
puts "IP_RUNS [llength [ooc_runs]]"

# --- synth_1 (Vivado 會自動帶出 top BD 需要的 OOC run; 不直接 launch ooc_runs, 因為 xpr 內有同事刪除 source 後殘留的空 fileset)
#     OOC 時間事後由各 run 的 runme.log 計算 (reports/run_times.txt)
stamp SYNTH_START
reset_run synth_1
for {set try 0} {$try <= 3} {incr try} {
    launch_runs synth_1 -jobs $jobs
    catch {wait_on_run synth_1}
    if {![bad [get_runs synth_1]]} break
    puts "RETRY synth_1: [get_property STATUS [get_runs synth_1]]"
    foreach r [concat [ooc_runs] [get_runs synth_1]] {
        set st [get_property STATUS $r]
        if {[string match "*ERROR*" $st] || [string match "*failed*" $st]} { puts "RESET_RUN $r ($st)"; reset_run $r }
    }
}
stamp SYNTH_DONE

# --- impl_1 -> bitstream
for {set try 0} {$try <= 3} {incr try} {
    launch_runs impl_1 -to_step write_bitstream -jobs $jobs
    catch {wait_on_run impl_1}
    if {![bad [get_runs impl_1]]} break
    puts "RETRY impl_1: [get_property STATUS [get_runs impl_1]]"; reset_run impl_1
}
stamp IMPL_DONE
puts "BUILD_STATUS synth=\"[get_property STATUS [get_runs synth_1]]\" impl=\"[get_property STATUS [get_runs impl_1]]\""

# --- reports (同同事 build.tcl + power / hier utilization)
open_run impl_1
report_timing_summary -max_paths 20 -file $rpt/timing_summary.rpt
report_utilization                  -file $rpt/utilization.rpt
report_utilization -hierarchical -hierarchical_depth 3 -file $rpt/utilization_hier.rpt
report_power                        -file $rpt/power.rpt
report_drc                          -file $rpt/drc.rpt
report_methodology                  -file $rpt/methodology.rpt
report_clock_interaction            -file $rpt/clock_interaction.rpt
report_cdc -details                 -file $rpt/cdc.rpt
set fh [open $rpt/gt_placement.txt w]
foreach c [lsort [get_cells -hier -filter {REF_NAME == GTYE4_CHANNEL}]] { puts $fh "GT [get_property LOC $c] $c" }
foreach c [lsort [get_cells -hier -filter {REF_NAME == GTYE4_COMMON}]]  { puts $fh "COMMON [get_property LOC $c] $c" }
foreach p [lsort [get_ports -filter {NAME =~ *diff_ref*}]] { puts $fh "REFCLK [get_property PACKAGE_PIN $p] $p" }
close $fh
# SLR of the new / old path cells
set fh [open $rpt/slr_placement.txt w]
foreach pat {*axis_slr_x1y8_to_tx* *axis_slr_x1y4_to_z1* *axis_broadcaster_0* *axis_broadcaster_1* *link_x1y4/* *link_x1y8/*} {
    set cs [get_cells -hier -quiet -filter "IS_PRIMITIVE && NAME =~ $pat"]
    set slrs {}
    foreach c $cs { set s [get_slrs -quiet -of_objects $c]; if {$s ne ""} { dict incr slrs $s } }
    puts $fh "$pat cells=[llength $cs] slr=$slrs"
}
close $fh
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
set whs [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -hold]]
puts "TIMING WNS=$wns WHS=$whs"

set out [file normalize $proj_dir/../output_data]
file mkdir $out
set impl_dir [get_property DIRECTORY [get_runs impl_1]]
foreach f [glob -nocomplain $impl_dir/*.bit $impl_dir/*.ltx] { file copy -force $f $out/${name}[file extension $f] }
puts "OUTPUT [glob $out/*]"
close_project
stamp BUILD_DONE
