set_property -dict {PACKAGE_PIN E8 IOSTANDARD LVCMOS33}   [get_ports {ps_8io_tri_io[0]}]
set_property -dict {PACKAGE_PIN E9 IOSTANDARD LVCMOS33}   [get_ports {ps_8io_tri_io[1]}]
set_property -dict {PACKAGE_PIN E6 IOSTANDARD LVCMOS33}   [get_ports {ps_8io_tri_io[2]}]
set_property -dict {PACKAGE_PIN F6 IOSTANDARD LVCMOS33}   [get_ports {ps_8io_tri_io[3]}]
set_property -dict {PACKAGE_PIN AP5 IOSTANDARD LVCMOS18}  [get_ports {ps_8io_tri_io[4]}]
set_property -dict {PACKAGE_PIN AP6 IOSTANDARD LVCMOS18}  [get_ports {ps_8io_tri_io[5]}]
set_property -dict {PACKAGE_PIN AR6 IOSTANDARD LVCMOS18}  [get_ports {ps_8io_tri_io[6]}]
set_property -dict {PACKAGE_PIN AR7 IOSTANDARD LVCMOS18}  [get_ports {ps_8io_tri_io[7]}]
set_property -dict {PACKAGE_PIN C10 IOSTANDARD LVCMOS33}  [get_ports storage_ena_dbg]
set_property -dict {PACKAGE_PIN A9 IOSTANDARD LVCMOS33}   [get_ports trans_check_0]

set_property -dict {PACKAGE_PIN AG14 IOSTANDARD LVCMOS18} [get_ports sync_reg_adc0]
set_property -dict {PACKAGE_PIN AJ13 IOSTANDARD LVCMOS18} [get_ports sync_reg_dac0]

#set_property LOC HPIOBDIFFINBUF_X0Y36 [get_cells {design_1_wrapper_i/design_1_i/util_ds_buf_0/U0/USE_IBUFDS.GEN_IBUFDS[0].IBUFDS_I}]
set_property PACKAGE_PIN AP8 [get_ports FPGA_clk_p_0]
set_property PACKAGE_PIN AR8 [get_ports FPGA_clk_n_0]

set_property PACKAGE_PIN AP9 [get_ports PL_SYSREF_clk_p[0]]
set_property PACKAGE_PIN AR9 [get_ports PL_SYSREF_clk_n[0]]

set_property IOSTANDARD LVDS [get_ports PL_SYSREF_clk_n[0]]
set_property IOSTANDARD LVDS [get_ports PL_SYSREF_clk_p[0]]

set_property DIFF_TERM_ADV TERM_100 [get_ports PL_SYSREF_clk_n[0]]
set_property DIFF_TERM_ADV TERM_100 [get_ports PL_SYSREF_clk_p[0]]

set_property IOSTANDARD LVDS [get_ports FPGA_clk_p_0]
set_property IOSTANDARD LVDS [get_ports FPGA_clk_n_0]
create_clock -period 3.90625 -name FPGA_clk -waveform {0.000 1.953} [get_ports FPGA_clk_p_0]

set_property PACKAGE_PIN AF17 [get_ports PMA_RST_clk_p[0]]
set_property PACKAGE_PIN AF16 [get_ports PMA_RST_clk_n[0]]

set_property IOSTANDARD LVDS [get_ports PMA_RST_clk_p[0]]
set_property IOSTANDARD LVDS [get_ports PMA_RST_clk_n[0]]


set_max_delay -datapath_only -from [get_pins -hierarchical -filter {NAME =~ "*user_sysref_adc*/C"}] -to [get_pins -hierarchical -filter {NAME =~ "*i_mts_sysref_count_adc/sysref_fbrc_ff*/D"}] 3.90625
set_max_delay -datapath_only -from [get_pins -hierarchical -filter {NAME =~ "*user_sysref_adc*/C"}] -to [get_pins -hierarchical -filter {NAME =~ "*i_mts_sysref_count_adc/sysref_freq_done_ff*/D"}] 3.90625
set_max_delay -datapath_only -from [get_pins -hierarchical -filter {NAME =~ "*user_sysref_adc*/C"}] -to [get_pins -hierarchical -filter {NAME =~ "*i_mts_sysref_count_adc/sysref_freq_strt_ff*/D"}] 3.90625
set_max_delay -datapath_only -from [get_pins -hierarchical -filter {NAME =~ "*user_sysref_adc*/C"}] -to [get_pins -hierarchical -filter {NAME =~ "*i_rf_conv_mt_mrk_counter_adc*/mrk_cntr_ff*/CE"}] 3.90625
set_max_delay -datapath_only -from [get_pins -hierarchical -filter {NAME =~ "*user_sysref_adc*/C"}] -to [get_pins -hierarchical -filter {NAME =~ "*i_rf_conv_mt_mrk_counter_adc*/mrk_cntr_started_ff*/D"}] 3.90625
set_max_delay -datapath_only -from [get_pins -hierarchical -filter {NAME =~ "*user_sysref_adc*/C"}] -to [get_pins -hierarchical -filter {NAME =~ "*i_rf_conv_mt_mrk_counter_adc*/sysref_sync_dly_ff*/D"}] 3.90625
set_max_delay -datapath_only -from [get_pins -hierarchical -filter {NAME =~ "*user_sysref_dac*/C"}] -to [get_pins -hierarchical -filter {NAME =~ "*i_mts_sysref_count_dac/sysref_fbrc_ff*/D"}] 3.90625
set_max_delay -datapath_only -from [get_pins -hierarchical -filter {NAME =~ "*user_sysref_dac*/C"}] -to [get_pins -hierarchical -filter {NAME =~ "*i_mts_sysref_count_dac/sysref_freq_done_ff*/D"}] 3.90625
set_max_delay -datapath_only -from [get_pins -hierarchical -filter {NAME =~ "*user_sysref_dac*/C"}] -to [get_pins -hierarchical -filter {NAME =~ "*i_mts_sysref_count_dac/sysref_freq_strt_ff*/D"}] 3.90625
set_max_delay -datapath_only -from [get_pins -hierarchical -filter {NAME =~ "*user_sysref_dac*/C"}] -to [get_pins -hierarchical -filter {NAME =~ "*sysref_dac_ff*/D"}] 3.90625
set_max_delay -datapath_only -from [get_pins -hierarchical -filter {NAME =~ "*user_sysref_adc*/C"}] -to [get_cells -hierarchical -filter {IS_SEQUENTIAL == TRUE && NAME =~ "*ila_core_inst*"}] 3.90625

set_input_delay -clock [get_clocks FPGA_clk] -min -add_delay 3.90625 [get_ports PL_SYSREF_clk_p[0]]
set_input_delay -clock [get_clocks FPGA_clk] -max -add_delay 3.93625 [get_ports PL_SYSREF_clk_p[0]]
