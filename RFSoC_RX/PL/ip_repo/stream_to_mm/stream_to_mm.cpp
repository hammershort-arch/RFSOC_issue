/************************************************
Copyright (c) 2016, Xilinx, Inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, 
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, 
this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, 
this list of conditions and the following disclaimer in the documentation 
and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors 
may be used to endorse or promote products derived from this software 
without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, 
THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. 
IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, 
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, 
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, 
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.// Copyright (c) 2016 Xilinx, Inc.
************************************************/

#include <stdlib.h>
#include "ap_int.h"
#include <iostream>
#include <hls_stream.h>
#include <ap_axi_sdata.h>
typedef unsigned long int  uint32;
void stream_to_mm(ap_int<256>* DRAM_OUT,uint32 length,ap_int<256>* stream_in)
{
//#pragma HLS INTERFACE ap_bus port=DRAM_IN
//#pragma HLS PIPELINE II=1
#pragma HLS INTERFACE axis register both port=stream_in
#pragma HLS INTERFACE m_axi depth=64 port=DRAM_OUT offset=direct num_read_outstanding=0 num_write_outstanding=32 max_read_burst_length=16 max_write_burst_length=16
//#pragma HLS INTERFACE s_axilite port=return bundle=CONFIGBUS
//#pragma HLS INTERFACE s_axilite port=DRAM_OUT bundle=CONFIGBUS
//#pragma HLS INTERFACE s_axilite port=length bundle=CONFIGBUS clock=cfp_clk
//#pragma HLS INTERFACE s_axilite port=start bundle=CONFIGBUS
//#pragma HLS INTERFACE s_axilite port=return bundle=CONFIGBUS register


memcpy(DRAM_OUT, stream_in, length*sizeof(ap_int<256>));
}



