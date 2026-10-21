# =============================================================================
# fir_ch1_example.tcl : 只改 ch1 的 In-band FIR (17 顆: enable + tap 0~15)
#   執行: xsdb reg_rt.tcl run fir_ch1_example.tcl    離線檢查: xsdb reg_rt.tcl sim fir_ch1_example.tcl
#   reg_fir_tap <t> <I> <Q> : I / Q 為 signed 16-bit 整數 (-32768 ~ 32767), 腳本自動打包 [15:0] I, [31:16] Q
#   其他暫存器不會被寫入
# =============================================================================
reg_ch 1

# 改係數期間先關 FIR (輸出走 impulse response), 避免新舊係數混用
reg_wr  in_band_fir_enable 0

#           tap     I       Q
reg_fir_tap 0      -65        0
reg_fir_tap 1      194       -1
reg_fir_tap 2     -457        3
reg_fir_tap 3      896       -7
reg_fir_tap 4    -1665       18
reg_fir_tap 5     2966      -46
reg_fir_tap 6    -5896      154
reg_fir_tap 7    18543    -1513      ;# 範例: 中心 tap (請換成實際係數)
reg_fir_tap 8    18543     1513
reg_fir_tap 9    -5896     -154
reg_fir_tap 10    2966       46
reg_fir_tap 11   -1665      -18
reg_fir_tap 12     896        7
reg_fir_tap 13    -457       -3
reg_fir_tap 14     194        1
reg_fir_tap 15     -65        0

# 係數寫完再開 FIR
reg_wr  in_band_fir_enable 1
