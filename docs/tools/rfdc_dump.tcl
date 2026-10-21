# rfdc_dump.tcl (2026-10-16): 以唯讀方式讀出 RFSoC_TX / RFSoC_RX 的 RFDC 設定 (給 mk_doc_rfdc.py 產生文件用)
#   Usage: vivado -mode batch -source docs/tools/rfdc_dump.tcl -log rfdc_dump.log ; 再把 log 中 TX / RX 各行存成 rfdc_params_TX.txt / _RX.txt
set R [file normalize [file dirname [info script]]/../..]
foreach {tag x} [list TX $R/RFSoC_TX/hardware/RFSoC_TX.xpr RX $R/RFSoC_RX/hardware/RFSoC_RX.xpr] {
  open_project -read_only $x
  open_bd_design [get_files design_1.bd]
  set c [get_bd_cells /usp_rf_data_converter_1]
  foreach p [lsort [list_property $c CONFIG.*]] {
    if {[regexp {CONFIG\.(ADC|DAC)([0-3]_|_)} $p] || [regexp {MTS|Sysref|Clock|PLL|Refclk|Outclk|Fabric} $p]} {
      set v [get_property $p $c]
      if {$v ne "" && $v ne "0" && $v ne "false" || [regexp {Enable|NCO|Mixer|Decimation|Interpolation|Data_Type|Data_Width|Sampling|Refclk|Outclk|Fabric|Nyquist|Invsinc|Clock|Dist|Sysref|Multi} $p]} { puts "P $tag $p=$v" }
    }
  }
  foreach pin {m0_axis_aclk s0_axis_aclk m1_axis_aclk s1_axis_aclk m2_axis_aclk s2_axis_aclk m3_axis_aclk s3_axis_aclk s_axi_aclk} {
    set p [get_bd_pins -quiet $c/$pin]; if {$p ne ""} { puts "CLK $tag $pin <- [get_bd_nets -quiet -of_objects $p] FREQ=[get_property CONFIG.FREQ_HZ $p]" }
  }
  foreach ip [lsort [get_bd_intf_pins -of_objects $c -filter {NAME =~ m*_axis || NAME =~ s*_axis}]] {
    set n [get_bd_intf_nets -quiet -of_objects $ip]
    set peers {}; if {$n ne ""} { foreach q [get_bd_intf_pins -of_objects $n] { if {$q ne $ip} { lappend peers $q } } }
    puts "AXIS $tag [get_property NAME $ip] -> $peers"
  }
  foreach pn [lsort [get_bd_pins -of_objects $c -filter {NAME =~ clk_adc* || NAME =~ clk_dac*}]] {
    set n [get_bd_nets -quiet -of_objects $pn]; set peers {}; if {$n ne ""} { foreach q [get_bd_pins -of_objects $n] { if {$q ne $pn} { lappend peers $q } } }
    puts "OCLK $tag [get_property NAME $pn] FREQ=[get_property CONFIG.FREQ_HZ $pn] -> $peers"
  }
  close_project
}
