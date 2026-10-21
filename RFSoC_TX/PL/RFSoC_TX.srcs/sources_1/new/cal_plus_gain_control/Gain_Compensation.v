`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/10/2026 03:21:51 PM
// Design Name: 
// Module Name: Gain_Compensation
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Revision 0.02 - (2026-10-08) gain 視為 unsigned fixed_32_21 (1.0 = 0x0020_0000, 最大 2048x = +66.2 dB);
//                 輸出 round-half-even + 飽和 (±SAT_LEVEL, 預設 16384 = S16.14 的 1.0); latency 維持 4 拍
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Gain_Compensation(
	input 				clk,
	input				rst_n,
	input				in_valid,
	input [11:0]	    gain_offset_index,
	input [159:0]	 	s_axis_tdata,
	input 				s_axis_tvalid,
	output reg  		s_axis_tready,

	
	output				bram_clk,
	output reg [31:0]	bram_addr,
	output [31:0]		bram_wrdata,
	input  [31:0]		bram_rddata,
	output				bram_en,
	output				bram_rst,
	output [3:0]        bram_we,
	
	output reg [159:0]  m_axis_tdata,
	output reg			m_axis_tvalid,
	input				m_axis_tready	
);
	
	parameter MEM_BASE  = 32'h0;
	parameter SAT_LEVEL = 16384;     // 輸出飽和 ±SAT_LEVEL (DAC 系統上限, S16.14 的 1.0)
	
	reg signed [31:0] gain;
	reg in_valid_reg0, in_valid_reg1;
	
	reg signed [159:0] data_reg0, data_reg1;
	
	reg s_axis_tvalid_reg0, s_axis_tvalid_reg1, s_axis_tvalid_reg2;
	reg m_axis_tready_reg0, m_axis_tready_reg1, m_axis_tready_reg2;
	
	wire signed [15:0] I16 [0:4];
	wire signed [15:0] Q16 [0:4];
	reg  signed [48:0] I49 [0:4];   // 16 x 33 (unsigned gain 補 0) 乘積
	reg  signed [48:0] Q49 [0:4];
	
	assign bram_clk = clk;
	assign bram_rst = ~rst_n;
	assign bram_wrdata = 32'b0;
	assign bram_en = 1'b1;
	assign bram_we = 4'b0;
	
	always@(posedge clk) begin
		if(!rst_n) 
			gain <= 32'h00200000;
		else
			if(in_valid_reg1)
				gain <= bram_rddata;
			else
				gain <= gain;
	end
	
	always@(posedge clk) begin
		if(!rst_n) begin
			in_valid_reg0 <= 0;
			in_valid_reg1 <= 0;
		end
		else begin
			in_valid_reg0 <= in_valid;
			in_valid_reg1 <= in_valid_reg0;
		end
	end
	
	always@(posedge clk) begin
		if(!rst_n) 
			bram_addr <= MEM_BASE;
		else
			if(in_valid)
				bram_addr <= MEM_BASE + 4 * gain_offset_index;
			else
				bram_addr <= bram_addr;
	end
	
	always@(posedge clk) begin
		if(!rst_n) begin
			data_reg0 <= 0;
			data_reg1 <= 0;
		end
		else begin
			data_reg0 <= s_axis_tdata;
			data_reg1 <= data_reg0;
		end
	end
	
	// round-half-even (bit 21 為 1.0 的位置) + 飽和
	function [15:0] rnd_sat;
		input signed [48:0] p;
		reg   signed [48:0] r;
		reg   signed [27:0] q;
		begin
			r = p + $signed({29'd0, {20{1'b1}}}) + $signed({48'd0, p[21]});   // + (2^20 - 1) + bit21 -> 剛好 0.5 時進位到偶數
			q = r[48:21];
			if (q > SAT_LEVEL)        rnd_sat = SAT_LEVEL;
			else if (q < -SAT_LEVEL)  rnd_sat = -SAT_LEVEL;
			else                      rnd_sat = q[15:0];
		end
	endfunction

	genvar i;
	generate
		for(i = 0; i < 5; i = i + 1) begin
			assign {Q16[i], I16[i]} = data_reg1[i*32 +: 32];
			// 第 3 拍: 乘積 (gain 視為 unsigned)
			always@(posedge clk) begin
				Q49[i] <= Q16[i] * $signed({1'b0, gain});
				I49[i] <= I16[i] * $signed({1'b0, gain});
			end
			// 第 4 拍: 捨入 + 飽和
			always@(posedge clk) begin
				m_axis_tdata[i*32 +: 32] <= {rnd_sat(Q49[i]), rnd_sat(I49[i])};
			end
		end
	endgenerate	
	
	always@(posedge clk) begin
		m_axis_tvalid <= s_axis_tvalid_reg2;
		s_axis_tready <= m_axis_tready_reg2;
	end
	
	always@(posedge clk) begin
		if(!rst_n) begin
			s_axis_tvalid_reg0 <= 0;
			s_axis_tvalid_reg1 <= 0;
			s_axis_tvalid_reg2 <= 0;
		end
		else begin
			s_axis_tvalid_reg0 <= s_axis_tvalid;
			s_axis_tvalid_reg1 <= s_axis_tvalid_reg0;
			s_axis_tvalid_reg2 <= s_axis_tvalid_reg1;
		end
	end
	
	always@(posedge clk) begin
		if(!rst_n) begin
			m_axis_tready_reg0 <= 0;
			m_axis_tready_reg1 <= 0;
			m_axis_tready_reg2 <= 0;
		end
		else begin
			m_axis_tready_reg0 <= m_axis_tready;
			m_axis_tready_reg1 <= m_axis_tready_reg0;
			m_axis_tready_reg2 <= m_axis_tready_reg1;
		end
	end

endmodule
