`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/11/2026 03:17:04 PM
// Design Name: 
// Module Name: TOP_complex_FIR_module_parallel
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

module TOP_complex_FIR_module_parallel #(
    parameter DATA_WIDTH    = 16,
    parameter FIR_COE_WIDTH = 16,
    parameter TAPS          = 16,
    parameter NUM_PARALLEL  = 5
)(
    input clk,
    input rst_n,
    
    input wire                                enable,
    
    // AXIS Slave Interface 
    input [DATA_WIDTH*NUM_PARALLEL-1:0]       s_axis_i_tdata,
    input                                     s_axis_i_tvalid,
    output wire                               s_axis_i_tready,
    
    input [DATA_WIDTH*NUM_PARALLEL-1:0]       s_axis_q_tdata,
    input                                     s_axis_q_tvalid,
    output wire                               s_axis_q_tready,
    
    
    // AXIS Master Interface 
    output reg [DATA_WIDTH*NUM_PARALLEL-1:0]  m_axis_i_tdata,
    output reg                                m_axis_i_tvalid,
    input wire                                m_axis_i_tready,
    
     // AXIS Master Interface 
    output reg [DATA_WIDTH*NUM_PARALLEL-1:0]  m_axis_q_tdata,
    output reg                                m_axis_q_tvalid,
    input wire                                m_axis_q_tready,   


    // Coefficient Inputs (From Unpacker)
    input signed [15:0] tap00_i,  input signed [15:0] tap00_q,
    input signed [15:0] tap01_i,  input signed [15:0] tap01_q,
    input signed [15:0] tap02_i,  input signed [15:0] tap02_q,
    input signed [15:0] tap03_i,  input signed [15:0] tap03_q,
    input signed [15:0] tap04_i,  input signed [15:0] tap04_q,
    input signed [15:0] tap05_i,  input signed [15:0] tap05_q,
    input signed [15:0] tap06_i,  input signed [15:0] tap06_q,
    input signed [15:0] tap07_i,  input signed [15:0] tap07_q,
    input signed [15:0] tap08_i,  input signed [15:0] tap08_q,
    input signed [15:0] tap09_i,  input signed [15:0] tap09_q,
    input signed [15:0] tap10_i,  input signed [15:0] tap10_q,
    input signed [15:0] tap11_i,  input signed [15:0] tap11_q,
    input signed [15:0] tap12_i,  input signed [15:0] tap12_q,
    input signed [15:0] tap13_i,  input signed [15:0] tap13_q,
    input signed [15:0] tap14_i,  input signed [15:0] tap14_q,
    input signed [15:0] tap15_i,  input signed [15:0] tap15_q
);

    // AXIS Handshake Signal: 當下游能夠接收 (m_axis_tready) 且上游有資料 (s_axis_tvalid) 時才推進 pipeline
    wire aclken = m_axis_i_tready && m_axis_q_tready;
    assign s_axis_i_tready = aclken;
    assign s_axis_q_tready = aclken;
   
   
   // -----------------------------------------------------------------------------
   // Input Data Path Pipeline Stage (修復 RFADC 到 FIR 之間的長距離佈線 Delay)
   // -----------------------------------------------------------------------------
   reg [DATA_WIDTH*NUM_PARALLEL-1:0] s_axis_i_tdata_r;
   reg [DATA_WIDTH*NUM_PARALLEL-1:0] s_axis_q_tdata_r;
 
    // 2026-10-10 (timing): tvalid 與 tdata 一起暫存一拍 (原本 tvalid 直接推所有 DSP 的 CE, fanout ~350),
    // 本地暫存並允許複製; 也讓 valid 與它對應的資料 (s_axis_*_tdata_r) 對齊
    (* max_fanout = 32 *) reg s_axis_tvalid_r;
    always @(posedge clk) begin
        if (!rst_n) begin
            s_axis_i_tdata_r <= 'd0;
            s_axis_q_tdata_r <= 'd0;
            s_axis_tvalid_r  <= 1'b0;
        end else if (aclken) begin
            s_axis_i_tdata_r <= s_axis_i_tdata;
            s_axis_q_tdata_r <= s_axis_q_tdata;
            s_axis_tvalid_r  <= s_axis_i_tvalid && s_axis_q_tvalid;
        end
    end
    
    reg signed [15:0] tap_i_reg [0:15];
    reg signed [15:0] tap_q_reg [0:15];
   
    always @(posedge clk) begin
        if (!rst_n) begin
            tap_i_reg[0]  <= 16'd0; tap_q_reg[0]  <= 16'd0;
            tap_i_reg[1]  <= 16'd0; tap_q_reg[1]  <= 16'd0;
            tap_i_reg[2]  <= 16'd0; tap_q_reg[2]  <= 16'd0;
            tap_i_reg[3]  <= 16'd0; tap_q_reg[3]  <= 16'd0;
            tap_i_reg[4]  <= 16'd0; tap_q_reg[4]  <= 16'd0;
            tap_i_reg[5]  <= 16'd0; tap_q_reg[5]  <= 16'd0;
            tap_i_reg[6]  <= 16'd0; tap_q_reg[6]  <= 16'd0;
            tap_i_reg[7]  <= 16'd0; tap_q_reg[7]  <= 16'd0;
            tap_i_reg[8]  <= 16'd0; tap_q_reg[8]  <= 16'd0;
            tap_i_reg[9]  <= 16'd0; tap_q_reg[9]  <= 16'd0;
            tap_i_reg[10] <= 16'd0; tap_q_reg[10] <= 16'd0;
            tap_i_reg[11] <= 16'd0; tap_q_reg[11] <= 16'd0;
            tap_i_reg[12] <= 16'd0; tap_q_reg[12] <= 16'd0;
            tap_i_reg[13] <= 16'd0; tap_q_reg[13] <= 16'd0;
            tap_i_reg[14] <= 16'd0; tap_q_reg[14] <= 16'd0;
            tap_i_reg[15] <= 16'd0; tap_q_reg[15] <= 16'd0;
        end else begin
            if (enable) begin
                tap_i_reg[0]  <= tap00_i; tap_q_reg[0]  <= tap00_q;
                tap_i_reg[1]  <= tap01_i; tap_q_reg[1]  <= tap01_q;
                tap_i_reg[2]  <= tap02_i; tap_q_reg[2]  <= tap02_q;
                tap_i_reg[3]  <= tap03_i; tap_q_reg[3]  <= tap03_q;
                tap_i_reg[4]  <= tap04_i; tap_q_reg[4]  <= tap04_q;
                tap_i_reg[5]  <= tap05_i; tap_q_reg[5]  <= tap05_q;
                tap_i_reg[6]  <= tap06_i; tap_q_reg[6]  <= tap06_q;
                tap_i_reg[7]  <= tap07_i; tap_q_reg[7]  <= tap07_q;
                tap_i_reg[8]  <= tap08_i; tap_q_reg[8]  <= tap08_q;
                tap_i_reg[9]  <= tap09_i; tap_q_reg[9]  <= tap09_q;
                tap_i_reg[10] <= tap10_i; tap_q_reg[10] <= tap10_q;
                tap_i_reg[11] <= tap11_i; tap_q_reg[11] <= tap11_q;
                tap_i_reg[12] <= tap12_i; tap_q_reg[12] <= tap12_q;
                tap_i_reg[13] <= tap13_i; tap_q_reg[13] <= tap13_q;
                tap_i_reg[14] <= tap14_i; tap_q_reg[14] <= tap14_q;
                tap_i_reg[15] <= tap15_i; tap_q_reg[15] <= tap15_q;
            end else begin  // Impulse Response
                tap_i_reg[0]  <= 16'd0;    tap_q_reg[0]  <= 16'd0;
                tap_i_reg[1]  <= 16'd0;    tap_q_reg[1]  <= 16'd0;
                tap_i_reg[2]  <= 16'd0;    tap_q_reg[2]  <= 16'd0;
                tap_i_reg[3]  <= 16'd0;    tap_q_reg[3]  <= 16'd0;
                tap_i_reg[4]  <= 16'd0;    tap_q_reg[4]  <= 16'd0;
                tap_i_reg[5]  <= 16'd0;    tap_q_reg[5]  <= 16'd0;
                tap_i_reg[6]  <= 16'd0;    tap_q_reg[6]  <= 16'd0;
                tap_i_reg[7]  <= 16'h7FFF; tap_q_reg[7]  <= 16'd0;
                tap_i_reg[8]  <= 16'd0;    tap_q_reg[8]  <= 16'd0;
                tap_i_reg[9]  <= 16'd0;    tap_q_reg[9]  <= 16'd0;
                tap_i_reg[10] <= 16'd0;    tap_q_reg[10] <= 16'd0;
                tap_i_reg[11] <= 16'd0;    tap_q_reg[11] <= 16'd0;
                tap_i_reg[12] <= 16'd0;    tap_q_reg[12] <= 16'd0;
                tap_i_reg[13] <= 16'd0;    tap_q_reg[13] <= 16'd0;
                tap_i_reg[14] <= 16'd0;    tap_q_reg[14] <= 16'd0;
                tap_i_reg[15] <= 16'd0;    tap_q_reg[15] <= 16'd0;
            end
        end
    end
    
    // 重新打包成內部子模組所需的 Array 格式
    wire [FIR_COE_WIDTH*TAPS-1:0] internal_fir_coe_i;
    wire [FIR_COE_WIDTH*TAPS-1:0] internal_fir_coe_q;
 
    genvar m;
    generate
        for (m = 0; m < TAPS; m = m + 1) begin : GEN_COE_PACK
            assign internal_fir_coe_i[FIR_COE_WIDTH*m +: FIR_COE_WIDTH] = tap_i_reg[m];
            assign internal_fir_coe_q[FIR_COE_WIDTH*m +: FIR_COE_WIDTH] = tap_q_reg[m];
        end
    endgenerate

    // Shift Registers for I and Q
    reg [DATA_WIDTH-1:0] register_array_i [0:TAPS+NUM_PARALLEL-2];
    reg [DATA_WIDTH-1:0] register_array_q [0:TAPS+NUM_PARALLEL-2];

    wire [DATA_WIDTH*TAPS-1:0] fir_din_i [0:NUM_PARALLEL-1];
    wire [DATA_WIDTH*TAPS-1:0] fir_din_q [0:NUM_PARALLEL-1];

    localparam OUT_ACC_WIDTH = DATA_WIDTH + FIR_COE_WIDTH + 1 + $clog2(TAPS);
    
    wire signed [OUT_ACC_WIDTH-1:0] parallel_out_i [0:NUM_PARALLEL-1];
    wire signed [OUT_ACC_WIDTH-1:0] parallel_out_q [0:NUM_PARALLEL-1];

    reg  FIR_input_valid;
    wire [NUM_PARALLEL-1:0] sub_fir_valid;
    wire FIR_output_valid;

    assign FIR_output_valid = sub_fir_valid[0];



    genvar i, j;
    generate
        // 1. Shift Register Data Pipeline for I and Q
        for(i = 0; i < TAPS+NUM_PARALLEL-1; i = i + 1) begin : GEN_SHIFT_REG
            if(i < NUM_PARALLEL) begin
                always @(posedge clk) begin
                    if (!rst_n) begin
                        register_array_i[NUM_PARALLEL-i-1] <= 'd0;
                        register_array_q[NUM_PARALLEL-i-1] <= 'd0;
                    end else if(aclken && s_axis_tvalid_r) begin
                        register_array_i[NUM_PARALLEL-i-1] <= s_axis_i_tdata_r[DATA_WIDTH*i +: DATA_WIDTH];
                        register_array_q[NUM_PARALLEL-i-1] <= s_axis_q_tdata_r[DATA_WIDTH*i +: DATA_WIDTH];
                    end
                end
            end else begin
                always @(posedge clk) begin
                    if (!rst_n) begin
                        register_array_i[i] <= 'd0;
                        register_array_q[i] <= 'd0;
                    end else if(aclken && s_axis_tvalid_r) begin
                        register_array_i[i] <= register_array_i[i-NUM_PARALLEL];
                        register_array_q[i] <= register_array_q[i-NUM_PARALLEL];
                    end
                end
            end
        end

        // 2. Map Shift Register Array to 5 Parallel Inputs
        for(i = 0; i < NUM_PARALLEL; i = i + 1) begin : GEN_MAP_INPUT
            for(j = 0; j < TAPS; j = j + 1) begin
                assign fir_din_i[i][DATA_WIDTH*j +: DATA_WIDTH] = register_array_i[j+NUM_PARALLEL-i-1];
                assign fir_din_q[i][DATA_WIDTH*j +: DATA_WIDTH] = register_array_q[j+NUM_PARALLEL-i-1];
            end
        end

        // 3. Instantiate 5 Parallel Complex FIR Engines
        for(i = 0; i < NUM_PARALLEL; i = i + 1) begin : GEN_FIR_ENGINES
            complex_FIR_module_parallel #(
                .DATA_WIDTH(DATA_WIDTH),
                .FIR_COE_WIDTH(FIR_COE_WIDTH),
                .TAPS(TAPS)
            ) inst_Complex_FIR (
                .clk(clk),
                .rst_n(rst_n),  
                .ce(aclken),   
                .in_valid(FIR_input_valid),
                .data_in_i(fir_din_i[i]),
                .data_in_q(fir_din_q[i]),
                .fir_coe_i(internal_fir_coe_i),
                .fir_coe_q(internal_fir_coe_q),
                .FIR_output_valid(sub_fir_valid[i]),
                .fir_out_i(parallel_out_i[i]),
                .fir_out_q(parallel_out_q[i])
            );
        end
    endgenerate

    // 4. Input Valid Control
    always @(posedge clk) begin
        if(!rst_n) FIR_input_valid <= 0;
        else if(aclken) FIR_input_valid <= s_axis_tvalid_r;
    end

    // 5. Output Rounding (round-half-up: + 2^(SHIFT_BIT-1) 後截斷, tie 朝 +inf; 2026-10-12 註解更正, 不是 convergent) & AXIS Output Stage
    localparam SHIFT_BIT = FIR_COE_WIDTH - 1; // 15-bit fractional offset
    
    integer k;
    reg signed [OUT_ACC_WIDTH-1:0] round_tmp_i [0:NUM_PARALLEL-1];
    reg signed [OUT_ACC_WIDTH-1:0] round_tmp_q [0:NUM_PARALLEL-1];

    always @(posedge clk) begin
        if(!rst_n) begin
            m_axis_i_tdata <= 0;
            m_axis_q_tdata <= 0;
            m_axis_i_tvalid <= 0;
            m_axis_q_tvalid <= 0;
        end else if (aclken) begin
            m_axis_i_tvalid <= FIR_output_valid;
            m_axis_q_tvalid <= FIR_output_valid;
            for(k = 0; k < NUM_PARALLEL; k = k + 1) begin
                round_tmp_i[k] = parallel_out_i[k] + (1 << (SHIFT_BIT - 1));
                round_tmp_q[k] = parallel_out_q[k] + (1 << (SHIFT_BIT - 1));

                m_axis_i_tdata[DATA_WIDTH*k +: DATA_WIDTH] <= round_tmp_i[k][SHIFT_BIT +: DATA_WIDTH];
                m_axis_q_tdata[DATA_WIDTH*k +: DATA_WIDTH] <= round_tmp_q[k][SHIFT_BIT +: DATA_WIDTH];
            end
        end
    end

endmodule