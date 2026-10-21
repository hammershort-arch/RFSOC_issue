
log_wave -r /
set designtopgroup [add_wave_group "Design Top Signals"]
set cinoutgroup [add_wave_group "C InOuts" -into $designtopgroup]
set DRAM_IN__DRAM_OUT_group [add_wave_group DRAM_IN__DRAM_OUT(axi_master) -into $cinoutgroup]
set rdata_group [add_wave_group "Read Channel" -into $DRAM_IN__DRAM_OUT_group]
set wdata_group [add_wave_group "Write Channel" -into $DRAM_IN__DRAM_OUT_group]
set ctrl_group [add_wave_group "Handshakes" -into $DRAM_IN__DRAM_OUT_group]
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_BUSER -into $wdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_BID -into $wdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_BRESP -into $wdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_BREADY -into $ctrl_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_BVALID -into $ctrl_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_RRESP -into $rdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_RUSER -into $rdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_RID -into $rdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_RLAST -into $ctrl_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_RDATA -into $rdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_RREADY -into $ctrl_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_RVALID -into $ctrl_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_ARUSER -into $rdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_ARREGION -into $rdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_ARQOS -into $rdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_ARPROT -into $rdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_ARCACHE -into $rdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_ARLOCK -into $rdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_ARBURST -into $rdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_ARSIZE -into $rdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_ARLEN -into $rdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_ARID -into $rdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_ARADDR -into $rdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_ARREADY -into $ctrl_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_ARVALID -into $ctrl_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_WUSER -into $wdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_WID -into $wdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_WLAST -into $ctrl_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_WSTRB -into $wdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_WDATA -into $wdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_WREADY -into $ctrl_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_WVALID -into $ctrl_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_AWUSER -into $wdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_AWREGION -into $wdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_AWQOS -into $wdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_AWPROT -into $wdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_AWCACHE -into $wdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_AWLOCK -into $wdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_AWBURST -into $wdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_AWSIZE -into $wdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_AWLEN -into $wdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_AWID -into $wdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_AWADDR -into $wdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_AWREADY -into $ctrl_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/m_axi_gmem_AWVALID -into $ctrl_group -color #ffff00 -radix hex
set DRAM_IN__DRAM_OUT__length__start__return_group [add_wave_group DRAM_IN__DRAM_OUT__length__start__return(axi_slave) -into $cinoutgroup]
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/interrupt -into $DRAM_IN__DRAM_OUT__length__start__return_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/ap_rst_n_cfp_clk -into $DRAM_IN__DRAM_OUT__length__start__return_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/cfp_clk -into $DRAM_IN__DRAM_OUT__length__start__return_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/s_axi_CONFIGBUS_BRESP -into $DRAM_IN__DRAM_OUT__length__start__return_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/s_axi_CONFIGBUS_BREADY -into $DRAM_IN__DRAM_OUT__length__start__return_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/s_axi_CONFIGBUS_BVALID -into $DRAM_IN__DRAM_OUT__length__start__return_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/s_axi_CONFIGBUS_RRESP -into $DRAM_IN__DRAM_OUT__length__start__return_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/s_axi_CONFIGBUS_RDATA -into $DRAM_IN__DRAM_OUT__length__start__return_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/s_axi_CONFIGBUS_RREADY -into $DRAM_IN__DRAM_OUT__length__start__return_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/s_axi_CONFIGBUS_RVALID -into $DRAM_IN__DRAM_OUT__length__start__return_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/s_axi_CONFIGBUS_ARREADY -into $DRAM_IN__DRAM_OUT__length__start__return_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/s_axi_CONFIGBUS_ARVALID -into $DRAM_IN__DRAM_OUT__length__start__return_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/s_axi_CONFIGBUS_ARADDR -into $DRAM_IN__DRAM_OUT__length__start__return_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/s_axi_CONFIGBUS_WSTRB -into $DRAM_IN__DRAM_OUT__length__start__return_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/s_axi_CONFIGBUS_WDATA -into $DRAM_IN__DRAM_OUT__length__start__return_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/s_axi_CONFIGBUS_WREADY -into $DRAM_IN__DRAM_OUT__length__start__return_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/s_axi_CONFIGBUS_WVALID -into $DRAM_IN__DRAM_OUT__length__start__return_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/s_axi_CONFIGBUS_AWREADY -into $DRAM_IN__DRAM_OUT__length__start__return_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/s_axi_CONFIGBUS_AWVALID -into $DRAM_IN__DRAM_OUT__length__start__return_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/s_axi_CONFIGBUS_AWADDR -into $DRAM_IN__DRAM_OUT__length__start__return_group -radix hex
set blocksiggroup [add_wave_group "Block-level IO Handshake(internal)" -into $designtopgroup]
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/ap_done -into $blocksiggroup
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/ap_idle -into $blocksiggroup
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/ap_ready -into $blocksiggroup
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/ap_start -into $blocksiggroup
set resetgroup [add_wave_group "Reset" -into $designtopgroup]
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/ap_rst_n -into $resetgroup
set clockgroup [add_wave_group "Clock" -into $designtopgroup]
add_wave /apatb_diff_sq_acc_top/AESL_inst_diff_sq_acc/ap_clk -into $clockgroup
set testbenchgroup [add_wave_group "Test Bench Signals"]
set tbinternalsiggroup [add_wave_group "Internal Signals" -into $testbenchgroup]
set tb_simstatus_group [add_wave_group "Simulation Status" -into $tbinternalsiggroup]
set tb_portdepth_group [add_wave_group "Port Depth" -into $tbinternalsiggroup]
add_wave /apatb_diff_sq_acc_top/AUTOTB_TRANSACTION_NUM -into $tb_simstatus_group -radix hex
add_wave /apatb_diff_sq_acc_top/ready_cnt -into $tb_simstatus_group -radix hex
add_wave /apatb_diff_sq_acc_top/done_cnt -into $tb_simstatus_group -radix hex
add_wave /apatb_diff_sq_acc_top/LENGTH_gmem -into $tb_portdepth_group -radix hex
add_wave /apatb_diff_sq_acc_top/LENGTH_DRAM_IN -into $tb_portdepth_group -radix hex
add_wave /apatb_diff_sq_acc_top/LENGTH_DRAM_OUT -into $tb_portdepth_group -radix hex
add_wave /apatb_diff_sq_acc_top/LENGTH_length_r -into $tb_portdepth_group -radix hex
add_wave /apatb_diff_sq_acc_top/LENGTH_start -into $tb_portdepth_group -radix hex
set tbcinoutgroup [add_wave_group "C InOuts" -into $testbenchgroup]
set tb_DRAM_IN__DRAM_OUT_group [add_wave_group DRAM_IN__DRAM_OUT(axi_master) -into $tbcinoutgroup]
set rdata_group [add_wave_group "Read Channel" -into $tb_DRAM_IN__DRAM_OUT_group]
set wdata_group [add_wave_group "Write Channel" -into $tb_DRAM_IN__DRAM_OUT_group]
set ctrl_group [add_wave_group "Handshakes" -into $tb_DRAM_IN__DRAM_OUT_group]
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_BUSER -into $wdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_BID -into $wdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_BRESP -into $wdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_BREADY -into $ctrl_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_BVALID -into $ctrl_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_RRESP -into $rdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_RUSER -into $rdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_RID -into $rdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_RLAST -into $ctrl_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_RDATA -into $rdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_RREADY -into $ctrl_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_RVALID -into $ctrl_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_ARUSER -into $rdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_ARREGION -into $rdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_ARQOS -into $rdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_ARPROT -into $rdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_ARCACHE -into $rdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_ARLOCK -into $rdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_ARBURST -into $rdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_ARSIZE -into $rdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_ARLEN -into $rdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_ARID -into $rdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_ARADDR -into $rdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_ARREADY -into $ctrl_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_ARVALID -into $ctrl_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_WUSER -into $wdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_WID -into $wdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_WLAST -into $ctrl_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_WSTRB -into $wdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_WDATA -into $wdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_WREADY -into $ctrl_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_WVALID -into $ctrl_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_AWUSER -into $wdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_AWREGION -into $wdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_AWQOS -into $wdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_AWPROT -into $wdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_AWCACHE -into $wdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_AWLOCK -into $wdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_AWBURST -into $wdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_AWSIZE -into $wdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_AWLEN -into $wdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_AWID -into $wdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_AWADDR -into $wdata_group -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_AWREADY -into $ctrl_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/m_axi_gmem_AWVALID -into $ctrl_group -color #ffff00 -radix hex
set tb_DRAM_IN__DRAM_OUT__length__start__return_group [add_wave_group DRAM_IN__DRAM_OUT__length__start__return(axi_slave) -into $tbcinoutgroup]
add_wave /apatb_diff_sq_acc_top/CONFIGBUS_INTERRUPT -into $tb_DRAM_IN__DRAM_OUT__length__start__return_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_reset_CONFIGBUS -into $tb_DRAM_IN__DRAM_OUT__length__start__return_group -radix hex
add_wave /apatb_diff_sq_acc_top/AESL_clock_CONFIGBUS -into $tb_DRAM_IN__DRAM_OUT__length__start__return_group -radix hex
add_wave /apatb_diff_sq_acc_top/CONFIGBUS_BRESP -into $tb_DRAM_IN__DRAM_OUT__length__start__return_group -radix hex
add_wave /apatb_diff_sq_acc_top/CONFIGBUS_BREADY -into $tb_DRAM_IN__DRAM_OUT__length__start__return_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/CONFIGBUS_BVALID -into $tb_DRAM_IN__DRAM_OUT__length__start__return_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/CONFIGBUS_RRESP -into $tb_DRAM_IN__DRAM_OUT__length__start__return_group -radix hex
add_wave /apatb_diff_sq_acc_top/CONFIGBUS_RDATA -into $tb_DRAM_IN__DRAM_OUT__length__start__return_group -radix hex
add_wave /apatb_diff_sq_acc_top/CONFIGBUS_RREADY -into $tb_DRAM_IN__DRAM_OUT__length__start__return_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/CONFIGBUS_RVALID -into $tb_DRAM_IN__DRAM_OUT__length__start__return_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/CONFIGBUS_ARREADY -into $tb_DRAM_IN__DRAM_OUT__length__start__return_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/CONFIGBUS_ARVALID -into $tb_DRAM_IN__DRAM_OUT__length__start__return_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/CONFIGBUS_ARADDR -into $tb_DRAM_IN__DRAM_OUT__length__start__return_group -radix hex
add_wave /apatb_diff_sq_acc_top/CONFIGBUS_WSTRB -into $tb_DRAM_IN__DRAM_OUT__length__start__return_group -radix hex
add_wave /apatb_diff_sq_acc_top/CONFIGBUS_WDATA -into $tb_DRAM_IN__DRAM_OUT__length__start__return_group -radix hex
add_wave /apatb_diff_sq_acc_top/CONFIGBUS_WREADY -into $tb_DRAM_IN__DRAM_OUT__length__start__return_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/CONFIGBUS_WVALID -into $tb_DRAM_IN__DRAM_OUT__length__start__return_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/CONFIGBUS_AWREADY -into $tb_DRAM_IN__DRAM_OUT__length__start__return_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/CONFIGBUS_AWVALID -into $tb_DRAM_IN__DRAM_OUT__length__start__return_group -color #ffff00 -radix hex
add_wave /apatb_diff_sq_acc_top/CONFIGBUS_AWADDR -into $tb_DRAM_IN__DRAM_OUT__length__start__return_group -radix hex
save_wave_config diff_sq_acc.wcfg
run all
quit

