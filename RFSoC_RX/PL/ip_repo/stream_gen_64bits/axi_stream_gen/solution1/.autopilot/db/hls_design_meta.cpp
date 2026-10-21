#include "hls_design_meta.h"
const Port_Property HLS_Design_Meta::port_props[]={
	Port_Property("ap_clk", 1, hls_in, -1, "", "", 1),
	Port_Property("ap_rst_n", 1, hls_in, -1, "", "", 1),
	Port_Property("ap_start", 1, hls_in, -1, "", "", 1),
	Port_Property("ap_done", 1, hls_out, -1, "", "", 1),
	Port_Property("ap_idle", 1, hls_out, -1, "", "", 1),
	Port_Property("ap_ready", 1, hls_out, -1, "", "", 1),
	Port_Property("stream_data_gen_TDATA", 128, hls_out, 0, "axis", "out_data", 1),
	Port_Property("stream_data_gen_TVALID", 1, hls_out, 6, "axis", "out_vld", 1),
	Port_Property("stream_data_gen_TREADY", 1, hls_in, 0, "axis", "out_acc", 1),
	Port_Property("stream_data_gen_TKEEP", 16, hls_out, 1, "axis", "out_data", 1),
	Port_Property("stream_data_gen_TSTRB", 16, hls_out, 2, "axis", "out_data", 1),
	Port_Property("stream_data_gen_TUSER", 1, hls_out, 3, "axis", "out_data", 1),
	Port_Property("stream_data_gen_TLAST", 1, hls_out, 4, "axis", "out_data", 1),
	Port_Property("stream_data_gen_TID", 1, hls_out, 5, "axis", "out_data", 1),
	Port_Property("stream_data_gen_TDEST", 1, hls_out, 6, "axis", "out_data", 1),
	Port_Property("LEN", 32, hls_in, 7, "ap_none", "in_data", 1),
};
const char* HLS_Design_Meta::dut_name = "steam_gen_64";
