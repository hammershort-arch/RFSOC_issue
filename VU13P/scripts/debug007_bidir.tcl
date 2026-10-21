# =============================================================================
# debug007_bidir.tcl  (Debug_007, 2026-10-17)
#   VU13P 雙向資料路徑: 原本只有 z1 -> VU13P -> z2, 加上 z2 -> VU13P -> z1
#
#   原路徑 (不動):
#     M_AXIS_X1Y8_C1 (z1 X0Y1 core1) -> axis_slr_x1y8_to_tx -> axis_broadcaster_0 (1->8)
#       -> S_AXIS_X1Y4_C0 .. S_AXIS_X1Y7_C1 (quad 224-227 -> z2)            ila_bcast 監看
#   新路徑 (本腳本加入, 鏡像原路徑):
#     M_AXIS_X1Y4_C1 (z2 X0Y1 core1) -> axis_slr_x1y4_to_z1 -> axis_broadcaster_1 (1->8)
#       -> S_AXIS_X1Y8_C0 .. S_AXIS_X1Y11_C1 (quad 228-231 -> z1)            ila_bcast_1 監看
#
#   兩組 broadcaster 都是 HAS_TREADY=0, 不需要方向選擇: 哪一顆放 RFSoC_RX, 那一側的 core1 才有資料;
#   放 RFSoC_TX 的那顆不送 Aurora 資料 (container S_AXIS 未接, tvalid=0), 另一組 broadcaster 就閒置.
#   config / clock (clk_wiz_0 400 MHz) / reset (util_vector_logic_0/Res) 全部和原路徑相同.
#   Usage: cd VU13P; vivado -mode batch -source scripts/debug007_bidir.tcl
# =============================================================================
set xpr [lindex [glob [pwd]/*.xpr] 0]
open_project $xpr
open_bd_design [get_files aurora_gty_vu13p_rst.bd]
set A aurora_gty_vu13pto47_0
set clk [get_bd_pins clk_wiz_0/clk_out1]
set rstn [get_bd_pins util_vector_logic_0/Res]

# --- SLR crossing (quad 224 SLR -> quad 228-231 SLR), 同 axis_slr_x1y8_to_tx
set rs [create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice:1.1 axis_slr_x1y4_to_z1]
set_property -dict [list CONFIG.REG_CONFIG 15 CONFIG.NUM_SLR_CROSSINGS 1 \
                         CONFIG.PIPELINES_MASTER 1 CONFIG.PIPELINES_SLAVE 1] $rs

# --- broadcaster 1 -> 8, 同 axis_broadcaster_0
set bc [create_bd_cell -type ip -vlnv xilinx.com:ip:axis_broadcaster:1.1 axis_broadcaster_1]
set_property -dict [list CONFIG.NUM_MI 8 CONFIG.HAS_TREADY 0 CONFIG.HAS_TKEEP 1 CONFIG.HAS_TLAST 1 \
                         CONFIG.HAS_TSTRB 0 CONFIG.S_TDATA_NUM_BYTES 16 CONFIG.M_TDATA_NUM_BYTES 16 \
                         CONFIG.S_TUSER_WIDTH 0 CONFIG.M_TUSER_WIDTH 0] $bc

# --- ILA, 同 ila_bcast (9 slots AXIS, 1024 deep)
set ila [create_bd_cell -type ip -vlnv xilinx.com:ip:system_ila:1.1 ila_bcast_1]
set_property -dict [list CONFIG.C_MON_TYPE INTERFACE CONFIG.C_NUM_MONITOR_SLOTS 9 CONFIG.C_DATA_DEPTH 1024] $ila
for {set i 0} {$i < 9} {incr i} {
    set_property CONFIG.C_SLOT_${i}_INTF_TYPE xilinx.com:interface:axis_rtl:1.0 $ila
}

# --- data path
connect_bd_intf_net [get_bd_intf_pins $A/M_AXIS_X1Y4_C1] [get_bd_intf_pins $rs/S_AXIS]
connect_bd_intf_net [get_bd_intf_pins $rs/M_AXIS]        [get_bd_intf_pins $bc/S_AXIS]
connect_bd_intf_net [get_bd_intf_pins $rs/M_AXIS]        [get_bd_intf_pins $ila/SLOT_0_AXIS]
set i 0
foreach q {8 9 10 11} {
    foreach c {0 1} {
        set m [format M%02d_AXIS $i]
        connect_bd_intf_net [get_bd_intf_pins $bc/$m] [get_bd_intf_pins $A/S_AXIS_X1Y${q}_C${c}]
        connect_bd_intf_net [get_bd_intf_pins $bc/$m] [get_bd_intf_pins $ila/SLOT_[expr {$i + 1}]_AXIS]
        incr i
    }
}
connect_bd_net $clk  [get_bd_pins $rs/aclk] [get_bd_pins $bc/aclk] [get_bd_pins $ila/clk]
connect_bd_net $rstn [get_bd_pins $rs/aresetn] [get_bd_pins $bc/aresetn]

# --- checks
foreach c [get_bd_cells {axis_slr_x1y4_to_z1 axis_broadcaster_1 ila_bcast_1 axis_slr_x1y8_to_tx axis_broadcaster_0 ila_bcast}] {
    puts "CFG $c"
    foreach p [list_property -regexp $c {CONFIG\.(REG_CONFIG|NUM_SLR_CROSSINGS|PIPELINES_.*|NUM_MI|HAS_TREADY|C_NUM_MONITOR_SLOTS|C_DATA_DEPTH)$}] {
        puts "  $p = [get_property $p $c]"
    }
}
foreach p [lsort [get_bd_intf_pins -of_objects [get_bd_cells $A] -filter {NAME =~ S_AXIS_* || NAME =~ M_AXIS_*}]] {
    set n [get_bd_intf_nets -quiet -of_objects $p]
    if {$n ne ""} { puts "CONN $p <-> [lsort [get_bd_intf_pins -of_objects $n]]" }
}
regenerate_bd_layout
validate_bd_design
save_bd_design
make_wrapper -files [get_files aurora_gty_vu13p_rst.bd] -top -force
close_bd_design [current_bd_design]
close_project
puts "DEBUG007_DONE"
