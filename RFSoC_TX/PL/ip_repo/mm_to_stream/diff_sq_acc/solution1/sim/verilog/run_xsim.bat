
call D:/Xilinx/Vivado/2017.3/bin/xelab xil_defaultlib.apatb_diff_sq_acc_top -prj diff_sq_acc.prj -L smartconnect_v1_0 -L axi_protocol_checker_v1_1_12 -L axi_protocol_checker_v1_1_13 -L axis_protocol_checker_v1_1_11 -L axis_protocol_checker_v1_1_12 -L xil_defaultlib --initfile "D:/Xilinx/Vivado/2017.3/data/xsim/ip/xsim_ip.ini" --lib "ieee_proposed=./ieee_proposed" -s diff_sq_acc -debug wave
call D:/Xilinx/Vivado/2017.3/bin/xsim --noieeewarnings diff_sq_acc -tclbatch diff_sq_acc.tcl

