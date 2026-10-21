`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/11/2026 03:15:41 PM
// Design Name: 
// Module Name: complex_FIR_module_parallel
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


module complex_FIR_module_parallel #(
    parameter DATA_WIDTH    = 16,
    parameter FIR_COE_WIDTH = 16,
    parameter TAPS          = 16
)(
    input clk,    
    input rst_n,
    input ce,
    input in_valid,
    
    // Complex Data Input (Single Slice)
    input [DATA_WIDTH*TAPS-1:0]     data_in_i,
    input [DATA_WIDTH*TAPS-1:0]     data_in_q,
    
    // Complex Coefficient Input
    input [FIR_COE_WIDTH*TAPS-1:0] fir_coe_i,
    input [FIR_COE_WIDTH*TAPS-1:0] fir_coe_q,
    
    output FIR_output_valid,
    // Multipliers (DATA_WIDTH + FIR_COE_WIDTH) + 1 (Complex Add) + STAGES (Adder Tree)
    output wire signed [(DATA_WIDTH+FIR_COE_WIDTH+1+$clog2(TAPS))-1:0] fir_out_i,
    output wire signed [(DATA_WIDTH+FIR_COE_WIDTH+1+$clog2(TAPS))-1:0] fir_out_q
);

    localparam STAGES = $clog2(TAPS);
    integer j, k;

    // Pipeline Stage 1: Complex Multiplication Components
    // Y_I = I*hI - Q*hQ
    // Y_Q = I*hQ + Q*hI
    reg signed [(DATA_WIDTH+FIR_COE_WIDTH)-1:0] mult_ii [0:TAPS-1];
    reg signed [(DATA_WIDTH+FIR_COE_WIDTH)-1:0] mult_qq [0:TAPS-1];
    reg signed [(DATA_WIDTH+FIR_COE_WIDTH)-1:0] mult_iq [0:TAPS-1];
    reg signed [(DATA_WIDTH+FIR_COE_WIDTH)-1:0] mult_qi [0:TAPS-1];

    // Pipeline Stage 2: Cross Addition/Subtraction
    reg signed [(DATA_WIDTH+FIR_COE_WIDTH):0] cmult_i [0:TAPS-1];
    reg signed [(DATA_WIDTH+FIR_COE_WIDTH):0] cmult_q [0:TAPS-1];

    // Pipeline Stage 3+: Adder Tree
    reg signed [(DATA_WIDTH+FIR_COE_WIDTH+1+STAGES)-1:0] fir_mult_sum_i [0:STAGES][0:TAPS-1];   
    reg signed [(DATA_WIDTH+FIR_COE_WIDTH+1+STAGES)-1:0] fir_mult_sum_q [0:STAGES][0:TAPS-1];   

    // Valid Shift Register
    reg valid_temp [0:STAGES+1]; // +1 for extra complex mult pipeline stage

    assign FIR_output_valid = valid_temp[STAGES+1];	

    genvar i;
    generate 
        // 1. Multipliers Pipeline Stage
        for(i = 0; i < TAPS; i = i + 1) begin : GEN_MULT
            always @(posedge clk) begin
                if(!rst_n) begin
                    mult_ii[i] <= 0;
                    mult_qq[i] <= 0;
                    mult_iq[i] <= 0;
                    mult_qi[i] <= 0;
                end else if(ce) begin
                    mult_ii[i] <= $signed(data_in_i[DATA_WIDTH*i +: DATA_WIDTH]) * $signed(fir_coe_i[FIR_COE_WIDTH*i +: FIR_COE_WIDTH]);
                    mult_qq[i] <= $signed(data_in_q[DATA_WIDTH*i +: DATA_WIDTH]) * $signed(fir_coe_q[FIR_COE_WIDTH*i +: FIR_COE_WIDTH]);
                    mult_iq[i] <= $signed(data_in_i[DATA_WIDTH*i +: DATA_WIDTH]) * $signed(fir_coe_q[FIR_COE_WIDTH*i +: FIR_COE_WIDTH]);
                    mult_qi[i] <= $signed(data_in_q[DATA_WIDTH*i +: DATA_WIDTH]) * $signed(fir_coe_i[FIR_COE_WIDTH*i +: FIR_COE_WIDTH]);
                end
            end
        end

        // 2. Complex Combine Pipeline Stage
        for(i = 0; i < TAPS; i = i + 1) begin : GEN_COMBINE
            always @(posedge clk) begin
                if(!rst_n) begin
                    cmult_i[i] <= 0;
                    cmult_q[i] <= 0;
                end else if(ce) begin
                    cmult_i[i] <= mult_ii[i] - mult_qq[i];
                    cmult_q[i] <= mult_iq[i] + mult_qi[i];
                end
            end
        end

        // 3. Valid Pipeline Alignment
        for(i = 0; i < STAGES + 2; i = i + 1) begin : GEN_VALID
            if(i == 0) begin
                always @(posedge clk) begin
                    if(!rst_n) valid_temp[i] <= 0;
                    else if(ce)      valid_temp[i] <= in_valid;
                end
            end else begin
                always @(posedge clk) begin
                    if(!rst_n) valid_temp[i] <= 0;
                    else if(ce)      valid_temp[i] <= valid_temp[i-1];
                end
            end
        end		
    endgenerate

    // 4. Pipelined Adder Tree for I and Q
    always @(posedge clk) begin
        if(!rst_n) begin
            for(j = 0; j < TAPS; j = j + 1) begin
                for(k = 0; k < STAGES + 1; k = k + 1) begin
                    fir_mult_sum_i[k][j] <= 0;
                    fir_mult_sum_q[k][j] <= 0;
                end
            end
        end else if(ce) begin
            // Input to Adder Tree (Stage 0)
            for(j = 0; j < TAPS; j = j + 1) begin
                fir_mult_sum_i[0][j] <= cmult_i[j];
                fir_mult_sum_q[0][j] <= cmult_q[j];
            end
            
            // Tree Addition Stages
            for(j = 0; j < STAGES; j = j + 1) begin
                for(k = 0; k < ceil_div2(TAPS, j + 1); k = k + 1) begin
                    fir_mult_sum_i[j+1][k] <= fir_mult_sum_i[j][2*k] + fir_mult_sum_i[j][2*k+1];
                    fir_mult_sum_q[j+1][k] <= fir_mult_sum_q[j][2*k] + fir_mult_sum_q[j][2*k+1];
                end
            end
        end
    end

    assign fir_out_i = fir_mult_sum_i[STAGES][0];
    assign fir_out_q = fir_mult_sum_q[STAGES][0];

    function integer ceil_div2;
        input integer value;
        input integer itr;
        integer i, result;
        begin
            result = value;
            for(i = 0; i < itr; i = i + 1) begin
                result = (result + 1) / 2;
            end
            ceil_div2 = result;
        end
    endfunction

endmodule