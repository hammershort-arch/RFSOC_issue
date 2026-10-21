`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/03/12 12:37:05
// Design Name: 
// Module Name: adc_dma_ctrl
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module adc_dma_ctrl(
input clk,
input rst_n,
input [31:0] up_s2mm_addr_l,
input [31:0] up_s2mm_addr_h,
input [31:0] up_s2mm_length,
input [8:0] adc_dma_ctrl,
input [7:0] up_s2mm_start_ctrl,
input up_s2mm_start,


//output reg [63:0] s2mm_addr_0,
//output reg [63:0] s2mm_addr_1,
//output reg [63:0] s2mm_addr_2,
//output reg [63:0] s2mm_addr_3,
//output reg [63:0] s2mm_addr_4,
//output reg [63:0] s2mm_addr_5,
//output reg [63:0] s2mm_addr_6,
//output reg [63:0] s2mm_addr_7,

output reg [31:0] s2mm_length_0,
//output reg [31:0] s2mm_length_1,
//output reg [31:0] s2mm_length_2,
//output reg [31:0] s2mm_length_3,
//output reg [31:0] s2mm_length_4,
//output reg [31:0] s2mm_length_5,
//output reg [31:0] s2mm_length_6,
//output reg [31:0] s2mm_length_7,

output s2mm_start,
output [7:0]s2mm_start_ctrl

    );
reg [63:0]s2mm_addr;
reg [31:0]s2mm_length;
reg [63:0] s2mm_addr_0;
reg [63:0] s2mm_addr_1;
reg [63:0] s2mm_addr_2;
reg [63:0] s2mm_addr_3;
reg [63:0] s2mm_addr_4;
reg [63:0] s2mm_addr_5;
reg [63:0] s2mm_addr_6;
reg [63:0] s2mm_addr_7;
reg [31:0] s2mm_length_2;
reg [31:0] s2mm_length_3;
reg [31:0] s2mm_length_4;
reg [31:0] s2mm_length_5;
reg [31:0] s2mm_length_6;
reg [31:0] s2mm_length_7;
reg [31:0] s2mm_length_1;
assign s2mm_start = up_s2mm_start;
assign s2mm_start_ctrl = up_s2mm_start_ctrl;

always @(posedge clk) begin
    if(rst_n == 0)
        s2mm_addr <= 0;
    else begin
        s2mm_addr[31:0] <= up_s2mm_addr_l;
        s2mm_addr[63:32] <= up_s2mm_addr_h;
        s2mm_length <= up_s2mm_length;
    end
end

reg[1:0] set_pulse;
reg[8:0]  adc_dma_ctrl_t;
always @(posedge clk) 
begin
  adc_dma_ctrl_t <= adc_dma_ctrl;
end

always @(posedge clk) 
begin
  if(rst_n == 0)
    set_pulse <= 0;
  else
    set_pulse <= { set_pulse[0] ,adc_dma_ctrl_t[8]};
end

always @(posedge clk) begin
    if (rst_n == 0 )begin
        s2mm_addr_0 <= 'd0;
        s2mm_addr_1 <= 'd0;
        s2mm_addr_2 <= 'd0;
        s2mm_addr_3 <= 'd0;
        s2mm_addr_4 <= 'd0;
        s2mm_addr_5 <= 'd0;
        s2mm_addr_6 <= 'd0;
        s2mm_addr_7 <= 'd0;
        s2mm_length_0 <= 'd512;
        s2mm_length_1 <= 'd512;
        s2mm_length_2 <= 'd512;
        s2mm_length_3 <= 'd512;
        s2mm_length_4 <= 'd512;
        s2mm_length_5 <= 'd512;
        s2mm_length_6 <= 'd512;
        s2mm_length_7 <= 'd512;
    end
    else begin
        if ( set_pulse == 2'b01 ) begin
            case (adc_dma_ctrl_t[7:0])
                8'h00 : begin
                        s2mm_addr_0 <= s2mm_addr;
                        s2mm_length_0 <= s2mm_length;  
                    end
                8'h01 : begin
                        s2mm_addr_1 <= s2mm_addr;
                        s2mm_length_1 <= s2mm_length;  
                    end
                8'h02 : begin
                        s2mm_addr_2 <= s2mm_addr;
                        s2mm_length_2 <= s2mm_length;  
                    end
                8'h03 : begin
                        s2mm_addr_3 <= s2mm_addr;
                        s2mm_length_3 <= s2mm_length;  
                    end
                8'h04 : begin
                        s2mm_addr_4 <= s2mm_addr;
                        s2mm_length_4 <= s2mm_length;  
                    end
                8'h05 : begin
                        s2mm_addr_5 <= s2mm_addr;
                        s2mm_length_5 <= s2mm_length;  
                    end
                8'h06 : begin
                        s2mm_addr_6 <= s2mm_addr;
                        s2mm_length_6 <= s2mm_length;  
                    end
                8'h07 : begin
                        s2mm_addr_7 <= s2mm_addr;
                        s2mm_length_7 <= s2mm_length;  
                    end
            endcase        
        end
    end



end



endmodule
