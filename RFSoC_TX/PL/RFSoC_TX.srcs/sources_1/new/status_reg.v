// ***************************************************************************
// ***************************************************************************
// Copyright 2014 - 2017 (c) Analog Devices, Inc. All rights reserved.
//
// In this HDL repository, there are many different and unique modules, consisting
// of various HDL (Verilog or VHDL) components. The individual modules are
// developed independently, and may be accompanied by separate and unique license
// terms.
//
// The user should read each of these license terms, and understand the
// freedoms and responsibilities that he or she has by using this source/core.
//
// This core is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE.
//
// Redistribution and use of source or resulting binaries, with or without modification
// of this file, are permitted under one of the following two license terms:
//
//   1. The GNU General Public License version 2 as published by the
//      Free Software Foundation, which can be found in the top level directory
//      of this repository (LICENSE_GPL2), and also online at:
//      <https://www.gnu.org/licenses/old-licenses/gpl-2.0.html>
//
// OR
//
//   2. An ADI specific BSD license, which can be found in the top level directory
//      of this repository (LICENSE_ADIBSD), and also on-line at:
//      https://github.com/analogdevicesinc/hdl/blob/master/LICENSE_ADIBSD
//      This will allow to generate bit files and not release the source code,
//      as long as it attaches to an ADI device.
//
// ***************************************************************************
// ***************************************************************************

`timescale 1ns/100ps

module status_reg #(

  parameter   ID = 0) (


   output [5:0]led,
//   output      lmkA_sync,
//  output  reg             pcie_card_system_control,
//  output  reg [31:0]      control_reg,
//  output  reg [31:0]      down_stream_length, 
//  output  reg             down_stream_index,
//  output        [63:0]      down_stream_address,
//  input       [63:0]      up_dma_address,
//  input       [31:0]      up_dma_length,
  
//  input       data_valid,
//  input        intr_update,

  // bus interface

  input                   up_rstn,
  input                   up_clk,
  input                   up_wreq,
  input       [13:0]      up_waddr,
  input       [31:0]      up_wdata,
  output  reg             up_wack,
  input                   up_rreq,
  input       [13:0]      up_raddr,
  output  reg [31:0]      up_rdata,
  output reg [17:0]       up_dma_ctrl,
  output reg [31:0]       up_mm2s_addr_h,
  output reg [31:0]       up_mm2s_addr_l,
  output reg [31:0]       up_mm2s_length,
  output reg [31:0]       up_s2mm_addr_h,
  output reg [31:0]       up_s2mm_addr_l,
  output reg [31:0]       up_s2mm_length,
  output reg [7:0]        up_mm2s_start_ctrl,
  output reg              up_mm2s_start,
  output reg [7:0]        up_s2mm_start_ctrl,
  output reg              up_s2mm_start,
  
  output    reg                     jsj_probe_out0,
  output    reg  [7:0]           jsj_o_jsj_atte_test,
  output    reg  [15:0]        jsj_o_jsj_freq_test,
  output    reg   [1:0]          jsj_ad_value,
  output    reg                     jsj_probe_out4,

  output    reg             ctrl_wr_data_num,
  
  output  reg             up_rack);

  localparam  PCORE_VERSION = 32'hEE70501;

  // internal registers

  reg             up_resetn = 'd0;
  reg     [3:0]   intr_status_reg = 'd0;
  reg             clr_interrupt = 'd0;
   reg            pcie_card_system_rst_i = 'd0;
   reg     [31:0] trigger_cntA = 'd0;
   reg     [31:0] trigger_cntB = 'd0;
   reg     [63:0] data_cnt = 'd0;
   reg     [15:0] control_reg;
   reg       [31:0]      down_stream_address_l;
   reg       [31:0]      down_stream_address_h;

  // internal signals

  wire            up_wreq_s;
  wire            up_rreq_s;




      
assign led = control_reg[5:0];
//assign lmkA_sync = control_reg[6];


  // decode block select

//  assign up_wreq_s = (up_waddr[13:8] == 6'h00) ? up_wreq : 1'b0;
//  assign up_rreq_s = (up_raddr[13:8] == 6'h00) ? up_rreq : 1'b0;

  assign up_wreq_s = up_wreq ;
  assign up_rreq_s =  up_rreq;


  // processor write interface

  always @(negedge up_rstn or posedge up_clk) begin
    if (up_rstn == 0) begin
      up_dma_ctrl <= 18'h0;
      up_mm2s_addr_h  <= 'd0;
      up_mm2s_addr_l <= 'd0;
      up_mm2s_length <= 'd0;
      up_s2mm_addr_h <= 'd0;
      up_s2mm_addr_l <= 'd0;
      up_s2mm_length <= 'd0;
      up_mm2s_start_ctrl <= 'd0;
      up_mm2s_start <= 'd0;
      up_s2mm_start_ctrl <= 'd0;
      up_s2mm_start <= 'd0;
      control_reg <= 'hffff;
    end else begin
      up_wack <= up_wreq_s;
      if ((up_wreq_s == 1'b1)) begin
        case (up_waddr[7:0])
            8'h01: up_dma_ctrl[17:9] <= up_wdata[8:0];
            8'h02: up_dma_ctrl[8:0] <= up_wdata[8:0];
            8'h03: up_mm2s_addr_l <= up_wdata;
            8'h04: up_mm2s_addr_h <= up_wdata;
            8'h05: up_mm2s_length <= up_wdata;
            8'h06: up_s2mm_addr_l <= up_wdata;
            8'h07: up_s2mm_addr_h <= up_wdata;
            8'h08: up_s2mm_length <= up_wdata;
            8'h09: up_mm2s_start_ctrl <= up_wdata[7:0];
            8'h0A: up_s2mm_start_ctrl <= up_wdata[7:0];
            8'h10: up_mm2s_start <= up_wdata[0];
            8'h20: up_s2mm_start <= up_wdata[0];
            8'h40:control_reg <= up_wdata;
            8'h51:begin 
              jsj_o_jsj_atte_test[7:0] <= up_wdata[7:0]; 
              jsj_probe_out0 <= 1'b1; 
             end
            8'h52:begin
              jsj_o_jsj_freq_test[15:0] <=  up_wdata[15:0];
              jsj_probe_out4   <=  1'b1;
             end
            8'h53:jsj_ad_value[1:0] <=  up_wdata[1:0];

            8'h63:ctrl_wr_data_num <= up_wdata;

            default: control_reg <= 'hffff;
         endcase
       end
       else begin
        jsj_probe_out0 <= 1'b0; 
        jsj_probe_out4 <= 1'b0;
       end
    end
  end


  // processor read interface

  always @(negedge up_rstn or posedge up_clk) begin
    if (up_rstn == 0) begin
      up_rack <= 'd0;
      up_rdata <= 'd0;
    end else begin
      up_rack <= up_rreq_s;
      if (up_rreq_s == 1'b1) begin
        case (up_raddr[7:0])
          8'h00: up_rdata <= PCORE_VERSION;
          8'h01: up_rdata <= ID;
          8'h40: up_rdata <= control_reg;
          8'h51: up_rdata <= jsj_o_jsj_atte_test[7:0];
          8'h52: up_rdata <= jsj_o_jsj_freq_test[15:0];
          8'h53: up_rdata <= jsj_ad_value[1:0];
          8'h63: up_rdata <= ctrl_wr_data_num;
          default: up_rdata <= 0;
        endcase
      end else begin
        up_rdata <= 32'd0;
      end
    end
  end








endmodule

// ***************************************************************************
// ***************************************************************************
