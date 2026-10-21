set moduleName steam_gen_64
set isTaskLevelControl 1
set isCombinational 0
set isDatapathOnly 0
set isPipelined 0
set pipeline_type none
set FunctionProtocol ap_ctrl_hs
set isOneStateSeq 0
set ProfileFlag 0
set StallSigGenFlag 0
set isEnableWaveformDebug 1
set C_modelName {steam_gen_64}
set C_modelType { void 0 }
set C_modelArgList {
	{ stream_data_gen_V_data_V int 128 regular {axi_s 1 volatile  { stream_data_gen Data } }  }
	{ stream_data_gen_V_keep_V int 16 regular {axi_s 1 volatile  { stream_data_gen Keep } }  }
	{ stream_data_gen_V_strb_V int 16 regular {axi_s 1 volatile  { stream_data_gen Strb } }  }
	{ stream_data_gen_V_user_V int 1 regular {axi_s 1 volatile  { stream_data_gen User } }  }
	{ stream_data_gen_V_last_V int 1 regular {axi_s 1 volatile  { stream_data_gen Last } }  }
	{ stream_data_gen_V_id_V int 1 regular {axi_s 1 volatile  { stream_data_gen ID } }  }
	{ stream_data_gen_V_dest_V int 1 regular {axi_s 1 volatile  { stream_data_gen Dest } }  }
	{ LEN int 32 regular  }
}
set C_modelArgMapList {[ 
	{ "Name" : "stream_data_gen_V_data_V", "interface" : "axis", "bitwidth" : 128, "direction" : "WRITEONLY", "bitSlice":[{"low":0,"up":127,"cElement": [{"cName": "stream_data_gen.V.data.V","cData": "int128","bit_use": { "low": 0,"up": 127},"cArray": [{"low" : 0,"up" : 0,"step" : 1}]}]}]} , 
 	{ "Name" : "stream_data_gen_V_keep_V", "interface" : "axis", "bitwidth" : 16, "direction" : "WRITEONLY", "bitSlice":[{"low":0,"up":15,"cElement": [{"cName": "stream_data_gen.V.keep.V","cData": "uint16","bit_use": { "low": 0,"up": 15},"cArray": [{"low" : 0,"up" : 0,"step" : 1}]}]}]} , 
 	{ "Name" : "stream_data_gen_V_strb_V", "interface" : "axis", "bitwidth" : 16, "direction" : "WRITEONLY", "bitSlice":[{"low":0,"up":15,"cElement": [{"cName": "stream_data_gen.V.strb.V","cData": "uint16","bit_use": { "low": 0,"up": 15},"cArray": [{"low" : 0,"up" : 0,"step" : 1}]}]}]} , 
 	{ "Name" : "stream_data_gen_V_user_V", "interface" : "axis", "bitwidth" : 1, "direction" : "WRITEONLY", "bitSlice":[{"low":0,"up":0,"cElement": [{"cName": "stream_data_gen.V.user.V","cData": "uint1","bit_use": { "low": 0,"up": 0},"cArray": [{"low" : 0,"up" : 0,"step" : 1}]}]}]} , 
 	{ "Name" : "stream_data_gen_V_last_V", "interface" : "axis", "bitwidth" : 1, "direction" : "WRITEONLY", "bitSlice":[{"low":0,"up":0,"cElement": [{"cName": "stream_data_gen.V.last.V","cData": "uint1","bit_use": { "low": 0,"up": 0},"cArray": [{"low" : 0,"up" : 0,"step" : 1}]}]}]} , 
 	{ "Name" : "stream_data_gen_V_id_V", "interface" : "axis", "bitwidth" : 1, "direction" : "WRITEONLY", "bitSlice":[{"low":0,"up":0,"cElement": [{"cName": "stream_data_gen.V.id.V","cData": "uint1","bit_use": { "low": 0,"up": 0},"cArray": [{"low" : 0,"up" : 0,"step" : 1}]}]}]} , 
 	{ "Name" : "stream_data_gen_V_dest_V", "interface" : "axis", "bitwidth" : 1, "direction" : "WRITEONLY", "bitSlice":[{"low":0,"up":0,"cElement": [{"cName": "stream_data_gen.V.dest.V","cData": "uint1","bit_use": { "low": 0,"up": 0},"cArray": [{"low" : 0,"up" : 0,"step" : 1}]}]}]} , 
 	{ "Name" : "LEN", "interface" : "wire", "bitwidth" : 32, "direction" : "READONLY", "bitSlice":[{"low":0,"up":31,"cElement": [{"cName": "LEN","cData": "int","bit_use": { "low": 0,"up": 31},"cArray": [{"low" : 0,"up" : 0,"step" : 0}]}]}]} ]}
# RTL Port declarations: 
set portNum 16
set portList { 
	{ ap_clk sc_in sc_logic 1 clock -1 } 
	{ ap_rst_n sc_in sc_logic 1 reset -1 active_low_sync } 
	{ ap_start sc_in sc_logic 1 start -1 } 
	{ ap_done sc_out sc_logic 1 predone -1 } 
	{ ap_idle sc_out sc_logic 1 done -1 } 
	{ ap_ready sc_out sc_logic 1 ready -1 } 
	{ stream_data_gen_TDATA sc_out sc_lv 128 signal 0 } 
	{ stream_data_gen_TVALID sc_out sc_logic 1 outvld 6 } 
	{ stream_data_gen_TREADY sc_in sc_logic 1 outacc 0 } 
	{ stream_data_gen_TKEEP sc_out sc_lv 16 signal 1 } 
	{ stream_data_gen_TSTRB sc_out sc_lv 16 signal 2 } 
	{ stream_data_gen_TUSER sc_out sc_lv 1 signal 3 } 
	{ stream_data_gen_TLAST sc_out sc_lv 1 signal 4 } 
	{ stream_data_gen_TID sc_out sc_lv 1 signal 5 } 
	{ stream_data_gen_TDEST sc_out sc_lv 1 signal 6 } 
	{ LEN sc_in sc_lv 32 signal 7 } 
}
set NewPortList {[ 
	{ "name": "ap_clk", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "clock", "bundle":{"name": "ap_clk", "role": "default" }} , 
 	{ "name": "ap_rst_n", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "reset", "bundle":{"name": "ap_rst_n", "role": "default" }} , 
 	{ "name": "ap_start", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "start", "bundle":{"name": "ap_start", "role": "default" }} , 
 	{ "name": "ap_done", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "predone", "bundle":{"name": "ap_done", "role": "default" }} , 
 	{ "name": "ap_idle", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "done", "bundle":{"name": "ap_idle", "role": "default" }} , 
 	{ "name": "ap_ready", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "ready", "bundle":{"name": "ap_ready", "role": "default" }} , 
 	{ "name": "stream_data_gen_TDATA", "direction": "out", "datatype": "sc_lv", "bitwidth":128, "type": "signal", "bundle":{"name": "stream_data_gen_V_data_V", "role": "default" }} , 
 	{ "name": "stream_data_gen_TVALID", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "outvld", "bundle":{"name": "stream_data_gen_V_dest_V", "role": "default" }} , 
 	{ "name": "stream_data_gen_TREADY", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "outacc", "bundle":{"name": "stream_data_gen_V_data_V", "role": "default" }} , 
 	{ "name": "stream_data_gen_TKEEP", "direction": "out", "datatype": "sc_lv", "bitwidth":16, "type": "signal", "bundle":{"name": "stream_data_gen_V_keep_V", "role": "default" }} , 
 	{ "name": "stream_data_gen_TSTRB", "direction": "out", "datatype": "sc_lv", "bitwidth":16, "type": "signal", "bundle":{"name": "stream_data_gen_V_strb_V", "role": "default" }} , 
 	{ "name": "stream_data_gen_TUSER", "direction": "out", "datatype": "sc_lv", "bitwidth":1, "type": "signal", "bundle":{"name": "stream_data_gen_V_user_V", "role": "default" }} , 
 	{ "name": "stream_data_gen_TLAST", "direction": "out", "datatype": "sc_lv", "bitwidth":1, "type": "signal", "bundle":{"name": "stream_data_gen_V_last_V", "role": "default" }} , 
 	{ "name": "stream_data_gen_TID", "direction": "out", "datatype": "sc_lv", "bitwidth":1, "type": "signal", "bundle":{"name": "stream_data_gen_V_id_V", "role": "default" }} , 
 	{ "name": "stream_data_gen_TDEST", "direction": "out", "datatype": "sc_lv", "bitwidth":1, "type": "signal", "bundle":{"name": "stream_data_gen_V_dest_V", "role": "default" }} , 
 	{ "name": "LEN", "direction": "in", "datatype": "sc_lv", "bitwidth":32, "type": "signal", "bundle":{"name": "LEN", "role": "default" }}  ]}

set RtlHierarchyInfo {[
	{"ID" : "0", "Level" : "0", "Path" : "`AUTOTB_DUT_INST", "Parent" : "",
		"CDFG" : "steam_gen_64",
		"Protocol" : "ap_ctrl_hs",
		"ControlExist" : "1", "ap_start" : "1", "ap_ready" : "1", "ap_done" : "1", "ap_continue" : "0", "ap_idle" : "1",
		"Pipeline" : "None", "UnalignedPipeline" : "0", "RewindPipeline" : "0", "ProcessNetwork" : "0",
		"II" : "0",
		"VariableLatency" : "1", "ExactLatency" : "-1", "EstimateLatencyMin" : "-1", "EstimateLatencyMax" : "-1",
		"Combinational" : "0",
		"Datapath" : "0",
		"ClockEnable" : "0",
		"HasSubDataflow" : "0",
		"InDataflowNetwork" : "0",
		"HasNonBlockingOperation" : "0",
		"Port" : [
			{"Name" : "stream_data_gen_V_data_V", "Type" : "Axis", "Direction" : "O",
				"BlockSignal" : [
					{"Name" : "stream_data_gen_TDATA_blk_n", "Type" : "RtlSignal"}]},
			{"Name" : "stream_data_gen_V_keep_V", "Type" : "Axis", "Direction" : "O"},
			{"Name" : "stream_data_gen_V_strb_V", "Type" : "Axis", "Direction" : "O"},
			{"Name" : "stream_data_gen_V_user_V", "Type" : "Axis", "Direction" : "O"},
			{"Name" : "stream_data_gen_V_last_V", "Type" : "Axis", "Direction" : "O"},
			{"Name" : "stream_data_gen_V_id_V", "Type" : "Axis", "Direction" : "O"},
			{"Name" : "stream_data_gen_V_dest_V", "Type" : "Axis", "Direction" : "O"},
			{"Name" : "LEN", "Type" : "None", "Direction" : "I"}]}]}


set ArgLastReadFirstWriteLatency {
	steam_gen_64 {
		stream_data_gen_V_data_V {Type O LastRead -1 FirstWrite 1}
		stream_data_gen_V_keep_V {Type O LastRead -1 FirstWrite 1}
		stream_data_gen_V_strb_V {Type O LastRead -1 FirstWrite 1}
		stream_data_gen_V_user_V {Type O LastRead -1 FirstWrite 1}
		stream_data_gen_V_last_V {Type O LastRead -1 FirstWrite 1}
		stream_data_gen_V_id_V {Type O LastRead -1 FirstWrite 1}
		stream_data_gen_V_dest_V {Type O LastRead -1 FirstWrite 1}
		LEN {Type I LastRead 0 FirstWrite -1}}}

set hasDtUnsupportedChannel 0

set PerformanceInfo {[
	{"Name" : "Latency", "Min" : "-1", "Max" : "-1"}
	, {"Name" : "Interval", "Min" : "0", "Max" : "0"}
]}

set PipelineEnableSignalInfo {[
]}

set Spec2ImplPortList { 
	stream_data_gen_V_data_V { axis {  { stream_data_gen_TDATA out_data 1 128 }  { stream_data_gen_TREADY out_acc 0 1 } } }
	stream_data_gen_V_keep_V { axis {  { stream_data_gen_TKEEP out_data 1 16 } } }
	stream_data_gen_V_strb_V { axis {  { stream_data_gen_TSTRB out_data 1 16 } } }
	stream_data_gen_V_user_V { axis {  { stream_data_gen_TUSER out_data 1 1 } } }
	stream_data_gen_V_last_V { axis {  { stream_data_gen_TLAST out_data 1 1 } } }
	stream_data_gen_V_id_V { axis {  { stream_data_gen_TID out_data 1 1 } } }
	stream_data_gen_V_dest_V { axis {  { stream_data_gen_TVALID out_vld 1 1 }  { stream_data_gen_TDEST out_data 1 1 } } }
	LEN { ap_none {  { LEN in_data 0 32 } } }
}

set busDeadlockParameterList { 
}

# RTL port scheduling information:
set fifoSchedulingInfoList { 
}

# RTL bus port read request latency information:
set busReadReqLatencyList { 
}

# RTL bus port write response latency information:
set busWriteResLatencyList { 
}

# RTL array port load latency information:
set memoryLoadLatencyList { 
}
