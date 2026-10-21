############################################################
## This file is generated automatically by Vivado HLS.
## Please DO NOT edit it.
## Copyright (C) 1986-2018 Xilinx, Inc. All Rights Reserved.
############################################################
open_project diff_sq_acc
set_top mm_to_stream
add_files src/diff_sq_acc.cpp
add_files -tb tb/diff_sq_acc_tb.cpp -cflags "-Wno-unknown-pragmas -Wno-unknown-pragmas -Wno-unknown-pragmas"
open_solution "solution1"
set_part {xczu28dr-ffvg1517-1-e}
create_clock -period 10 -name default
config_compile -no_signed_zeros=0 -unsafe_math_optimizations=0
config_schedule -effort medium -enable_dsp_full_reg=0 -relax_ii_for_timing=0 -verbose=0
config_bind -effort medium
config_export -display_name Bus_master_stream -format ip_catalog -rtl verilog -vivado_phys_opt place -vivado_report_level 0
config_sdx -optimization_level none -target none
config_interface -clock_enable=0 -expose_global=0 -m_axi_addr64 -m_axi_offset off -register_io off -trim_dangling_port=0
set_clock_uncertainty 12.5%
#source "./diff_sq_acc/solution1/directives.tcl"
csim_design
csynth_design
cosim_design -O -trace_level all
export_design -rtl verilog -format ip_catalog -display_name "Bus_master_stream"
