# =============================================================================
# cal_plus_gain_control.xdc  (2026-10-14, 由 Calibration_Gain_Control 整合)
# Reg map (S_AXI_ACLK / pl_clk0) -> 資料路徑 clk, 所有通道 (cal_plus_gain_control_ch1..ch8)
# 設定暫存器由 PS 寫入, 屬於準靜態值 (FIR 係數 mem0~16 直接進 clk domain; 其他經 cal_cdc / agc_cdc).
# source 專案寫法為 -to [get_clocks FPGA_clk]; 這裡改用 cal_cdc_0 目的端暫存器的時脈,
# 不依賴 container clk 之後接到哪個 clock.
# =============================================================================
set_false_path -from [get_cells -hierarchical -filter {NAME =~ */addressable_reg_map/inst/cfg_r*_reg* && IS_SEQUENTIAL}] \
               -to   [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ */cal_cdc_0/inst/cfg_sync_d_reg*/C}]]
