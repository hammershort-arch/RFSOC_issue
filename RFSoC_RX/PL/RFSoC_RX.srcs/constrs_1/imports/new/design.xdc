set_property PACKAGE_PIN AN10 [get_ports fpga_clk_100mhz_clk_p[0]]
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports fpga_clk_100mhz_clk_p[0]]
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports fpga_clk_100mhz_clk_p[0]]
create_clock -name sys_clk -period 10 [get_ports fpga_clk_100mhz_clk_p[0]]
#
#
#
#
#
#
set_property PACKAGE_PIN AA33 [get_ports gt_x0y1_diff_ref_clk_p]
set_property PACKAGE_PIN AA34 [get_ports gt_x0y1_diff_ref_clk_n]
create_clock -name gt_x0y1_refclk -period 6.4 [get_ports gt_x0y1_diff_ref_clk_p]
#
#
set_property PACKAGE_PIN W33 [get_ports gt_x0y2_diff_ref_clk_p]
set_property PACKAGE_PIN W34 [get_ports gt_x0y2_diff_ref_clk_n]
create_clock -name gt_x0y2_refclk -period 6.4 [get_ports gt_x0y2_diff_ref_clk_p]
#
# quads 130/131 refclk0 (pins per golden ibert_47dr1To13p)
set_property PACKAGE_PIN U33 [get_ports gt_x0y3_diff_ref_clk_p]
set_property PACKAGE_PIN U34 [get_ports gt_x0y3_diff_ref_clk_n]
create_clock -name gt_x0y3_refclk -period 6.4 [get_ports gt_x0y3_diff_ref_clk_p]
set_property PACKAGE_PIN P31 [get_ports gt_x0y4_diff_ref_clk_p]
set_property PACKAGE_PIN P32 [get_ports gt_x0y4_diff_ref_clk_n]
create_clock -name gt_x0y4_refclk -period 6.4 [get_ports gt_x0y4_diff_ref_clk_p]
#
#

#
#x0y1
set_clock_groups -asynchronous \
    -group [get_clocks -filter {NAME =~ *sys_clk*}] \
    -group [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ *aurora_x0y1* && REF_PIN_NAME == txoutclk_out[0]}]]

#x0y2
set_clock_groups -asynchronous \
    -group [get_clocks -filter {NAME =~ *sys_clk*}] \
    -group [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ *aurora_x0y2* && REF_PIN_NAME == txoutclk_out[0]}]]

#x0y3
set_clock_groups -asynchronous \
    -group [get_clocks -filter {NAME =~ *sys_clk*}] \
    -group [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ *aurora_x0y3* && REF_PIN_NAME == txoutclk_out[0]}]]

#x0y4
set_clock_groups -asynchronous \
    -group [get_clocks -filter {NAME =~ *sys_clk*}] \
    -group [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ *aurora_x0y4* && REF_PIN_NAME == txoutclk_out[0]}]]

# MTS debug (hier_mts, inherited from 47DR_integrated_3): the 'waitsysref' flag (FPGA_clk) is re-sampled by a
# 4-flop synchroniser in sync_out_latch (RFADC0_CLK 30 MHz / RFDAC0_CLK 240 MHz). The clocks are unrelated, so
# Vivado's 0.03 ns requirement is meaningless (failed by -1.4/-2.0 ns, also in the original project).
set_false_path -from [get_cells -hierarchical -filter {NAME =~ *hier_mts/sysref_trig_det_*/inst/waitsysref_reg}] \
               -to   [get_cells -hierarchical -filter {NAME =~ *hier_mts/sync_out_latch_*/inst/waitforsysref_d1_reg}]
set_property ASYNC_REG TRUE [get_cells -hierarchical -filter {NAME =~ *hier_mts/sync_out_latch_*/inst/waitforsysref_d1_reg || NAME =~ *hier_mts/sync_out_latch_*/inst/waitforsysref_d2_reg}]
