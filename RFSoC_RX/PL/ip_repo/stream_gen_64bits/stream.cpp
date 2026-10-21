// HLS example of vector add using AXI streams for data, and AXI lite for control interface

#include <iostream>
#include <hls_stream.h>
#include <ap_axi_sdata.h>

using namespace std;

typedef ap_axis <128,1,1,1> AXI_T;
typedef hls::stream<AXI_T> STREAM_T;

void steam_gen_64(STREAM_T &stream_data_gen, int LEN){
//#pragma HLS INTERFACE s_axilite port=LEN bundle=ctrl
#pragma HLS INTERFACE axis port=stream_data_gen
//#pragma HLS INTERFACE s_axilite port=return bundle=ctrl

    AXI_T tmpC;
    tmpC.data = 0;

    steam_gen_label0:for(int i=0; i<LEN; i++){

        tmpC.data = tmpC.data + 1;
		
        if(i == LEN-1){
			tmpC.last = 1;	
		}else{
			tmpC.last = 0;
		}
		tmpC.strb = 0xffff;
		tmpC.keep = 0xffff;
		stream_data_gen << tmpC;
    }

}
