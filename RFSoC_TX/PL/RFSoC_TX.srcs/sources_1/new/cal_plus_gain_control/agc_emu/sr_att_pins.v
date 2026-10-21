`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: sr_att_pins
// Description: sr_group_ctrl (N_REG = 4) 的向量輸出 -> Reg1~4 各自的 74LVC595 腳位
//              [0] = Reg1, [1] = Reg2, [2] = Reg3, [3] = Reg4
//////////////////////////////////////////////////////////////////////////////////


module sr_att_pins (
    input  wire [3:0] ser,
    input  wire [3:0] srclk,
    input  wire [3:0] rclk,

    output wire       Reg1_SER,  output wire Reg1_SRCLK, output wire Reg1_RCLK,
    output wire       Reg2_SER,  output wire Reg2_SRCLK, output wire Reg2_RCLK,
    output wire       Reg3_SER,  output wire Reg3_SRCLK, output wire Reg3_RCLK,
    output wire       Reg4_SER,  output wire Reg4_SRCLK, output wire Reg4_RCLK
);

    assign {Reg4_SER,   Reg3_SER,   Reg2_SER,   Reg1_SER}   = ser;
    assign {Reg4_SRCLK, Reg3_SRCLK, Reg2_SRCLK, Reg1_SRCLK} = srclk;
    assign {Reg4_RCLK,  Reg3_RCLK,  Reg2_RCLK,  Reg1_RCLK}  = rclk;

endmodule
