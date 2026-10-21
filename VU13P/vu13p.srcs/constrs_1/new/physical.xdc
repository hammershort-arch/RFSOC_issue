set_property PACKAGE_PIN BA15 [get_ports {sys_clk_p[0]}]
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports {sys_clk_p[0]}]
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports {sys_clk_n[0]}]
create_clock -period 10.000 -name sys_clk [get_ports {sys_clk_p[0]}]
#
set_property PACKAGE_PIN AU16 [get_ports {pma_rst_clk_p[0]}]
set_property PACKAGE_PIN AV16 [get_ports {pma_rst_clk_n[0]}]
set_property IOSTANDARD LVDS [get_ports {pma_rst_clk_p[0]}]
set_property IOSTANDARD LVDS [get_ports {pma_rst_clk_n[0]}]
set_false_path -from [get_ports {pma_rst_clk_p[0]}]
#
set_property PACKAGE_PIN AD10 [get_ports gt_x1y8_diff_ref_clk_n]
set_property PACKAGE_PIN AD11 [get_ports gt_x1y8_diff_ref_clk_p]
create_clock -period 6.400 -name gt_x1y8_refclk [get_ports gt_x1y8_diff_ref_clk_p]
#
# z1 (47dr1) link: quads 229/230/231 refclk0 (pins per golden ibert_13pTo47DR1)
set_property PACKAGE_PIN Y10 [get_ports gt_x1y9_diff_ref_clk_n]
set_property PACKAGE_PIN Y11 [get_ports gt_x1y9_diff_ref_clk_p]
create_clock -period 6.400 -name gt_x1y9_refclk [get_ports gt_x1y9_diff_ref_clk_p]
set_property PACKAGE_PIN T10 [get_ports gt_x1y10_diff_ref_clk_n]
set_property PACKAGE_PIN T11 [get_ports gt_x1y10_diff_ref_clk_p]
create_clock -period 6.400 -name gt_x1y10_refclk [get_ports gt_x1y10_diff_ref_clk_p]
set_property PACKAGE_PIN M10 [get_ports gt_x1y11_diff_ref_clk_n]
set_property PACKAGE_PIN M11 [get_ports gt_x1y11_diff_ref_clk_p]
create_clock -period 6.400 -name gt_x1y11_refclk [get_ports gt_x1y11_diff_ref_clk_p]
#
#
set_property PACKAGE_PIN AW8 [get_ports gt_x1y4_diff_ref_clk_n]
set_property PACKAGE_PIN AW9 [get_ports gt_x1y4_diff_ref_clk_p]
create_clock -period 6.400 -name gt_x1y4_refclk [get_ports gt_x1y4_diff_ref_clk_p]
#
# z2 (47dr2) link: quads 225/226/227 refclk0 (pins per golden ibert_13pTo47DR2)
set_property PACKAGE_PIN AT10 [get_ports gt_x1y5_diff_ref_clk_n]
set_property PACKAGE_PIN AT11 [get_ports gt_x1y5_diff_ref_clk_p]
create_clock -period 6.400 -name gt_x1y5_refclk [get_ports gt_x1y5_diff_ref_clk_p]
set_property PACKAGE_PIN AM10 [get_ports gt_x1y6_diff_ref_clk_n]
set_property PACKAGE_PIN AM11 [get_ports gt_x1y6_diff_ref_clk_p]
create_clock -period 6.400 -name gt_x1y6_refclk [get_ports gt_x1y6_diff_ref_clk_p]
set_property PACKAGE_PIN AH10 [get_ports gt_x1y7_diff_ref_clk_n]
set_property PACKAGE_PIN AH11 [get_ports gt_x1y7_diff_ref_clk_p]
create_clock -period 6.400 -name gt_x1y7_refclk [get_ports gt_x1y7_diff_ref_clk_p]
#
#
set_property PACKAGE_PIN R36 [get_ports gt_x0y11_diff_ref_clk_p]
set_property PACKAGE_PIN R37 [get_ports gt_x0y11_diff_ref_clk_n]
create_clock -name gt_x0y11_refclk -period 6.4 [get_ports gt_x0y11_diff_ref_clk_p]
#
set_property PACKAGE_PIN L36 [get_ports gt_x0y13_diff_ref_clk_p]
set_property PACKAGE_PIN L37 [get_ports gt_x0y13_diff_ref_clk_n]
create_clock -name gt_x0y13_refclk -period 6.4 [get_ports gt_x0y13_diff_ref_clk_p]
#
#


#x1y4
set_clock_groups -asynchronous -group [get_clocks -filter {NAME =~ *sys_clk*}] -group [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ *aurora_x1y4* && REF_PIN_NAME == txoutclk_out[0]}]]
#x1y5
set_clock_groups -asynchronous -group [get_clocks -filter {NAME =~ *sys_clk*}] -group [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ *aurora_x1y5* && REF_PIN_NAME == txoutclk_out[0]}]]
#x1y6
set_clock_groups -asynchronous -group [get_clocks -filter {NAME =~ *sys_clk*}] -group [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ *aurora_x1y6* && REF_PIN_NAME == txoutclk_out[0]}]]
#x1y7
set_clock_groups -asynchronous -group [get_clocks -filter {NAME =~ *sys_clk*}] -group [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ *aurora_x1y7* && REF_PIN_NAME == txoutclk_out[0]}]]
#x1y8
set_clock_groups -asynchronous -group [get_clocks -filter {NAME =~ *sys_clk*}] -group [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ *aurora_x1y8* && REF_PIN_NAME == txoutclk_out[0]}]]
#x1y9
set_clock_groups -asynchronous -group [get_clocks -filter {NAME =~ *sys_clk*}] -group [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ *aurora_x1y9_* && REF_PIN_NAME == txoutclk_out[0]}]]
#x1y10
set_clock_groups -asynchronous -group [get_clocks -filter {NAME =~ *sys_clk*}] -group [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ *aurora_x1y10_* && REF_PIN_NAME == txoutclk_out[0]}]]
#x1y11
set_clock_groups -asynchronous -group [get_clocks -filter {NAME =~ *sys_clk*}] -group [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ *aurora_x1y11_* && REF_PIN_NAME == txoutclk_out[0]}]]
#x0y11 (13P<->13P link)
set_clock_groups -asynchronous -group [get_clocks -filter {NAME =~ *sys_clk*}] -group [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ *aurora_x0y11* && REF_PIN_NAME == txoutclk_out[0]}]]
#x0y13
set_clock_groups -asynchronous -group [get_clocks -filter {NAME =~ *sys_clk*}] -group [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ *aurora_x0y13* && REF_PIN_NAME == txoutclk_out[0]}]]



