`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/07/2026 11:50:42 AM
// Design Name: 
// Module Name: square_root
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

module square_root(
input logic i_clk,
input logic i_rst,
input logic i_valid,
input logic[31:0] i_data,
output logic[15:0] o_out,
output logic o_ready
    );
    
    sqrt_iter_if #(.R_WIDTH(2),  .Q_WIDTH(1))  if0();
    sqrt_iter_if #(.R_WIDTH(4),  .Q_WIDTH(2))  if1();
    sqrt_iter_if #(.R_WIDTH(6),  .Q_WIDTH(3))  if2();
    sqrt_iter_if #(.R_WIDTH(8),  .Q_WIDTH(4))  if3();
    sqrt_iter_if #(.R_WIDTH(10), .Q_WIDTH(5))  if4();
    sqrt_iter_if #(.R_WIDTH(12), .Q_WIDTH(6))  if5();
    sqrt_iter_if #(.R_WIDTH(14), .Q_WIDTH(7))  if6();
    
    sqrt_iter_if #(.R_WIDTH(16), .Q_WIDTH(8))  if7();
    sqrt_iter_if #(.R_WIDTH(18), .Q_WIDTH(9))  if8();
    
    sqrt_iter_if #(.R_WIDTH(20), .Q_WIDTH(10)) if9();  
    sqrt_iter_if #(.R_WIDTH(22), .Q_WIDTH(11)) if10();
    
    sqrt_iter_if #(.R_WIDTH(24), .Q_WIDTH(12)) if11();
    sqrt_iter_if #(.R_WIDTH(26), .Q_WIDTH(13)) if12();
    
    sqrt_iter_if #(.R_WIDTH(28), .Q_WIDTH(14)) if13();
    sqrt_iter_if #(.R_WIDTH(30), .Q_WIDTH(15)) if14();
    sqrt_iter_if #(.R_WIDTH(32), .Q_WIDTH(16)) if15();
    
    logic[31:0] data_q16_16 ;
    assign data_q16_16 = i_data[31:0] ;
    
    
    
    logic [15:0][1:0] pairs; 
    assign pairs = { >> 2 {data_q16_16}};
    
    // 2026-10-10 (timing): step3 加一級 pipeline, step4 之後的 pair 全部多延遲 1 拍;
    //   valid_reg 5 級 + o_ready 1 級 = 總 latency 6 拍 (i_valid -> o_ready) (2026-10-12 註解更新)
    logic [11:0][1:0] pairs_p;
    logic [8:0][1:0]  pairs_d1;
    logic [6:0][1:0]  pairs_d2; 
    logic [4:0][1:0]  pairs_d3;
    logic [2:0][1:0]  pairs_d4;

    always_ff @(posedge i_clk) begin
        pairs_p  <= pairs[11:0];
        pairs_d1 <= pairs_p[8:0]; 
        pairs_d2 <= pairs_d1[6:0];
        pairs_d3 <= pairs_d2[4:0];
        pairs_d4 <= pairs_d3[2:0];
    end
    

always_comb begin
    if (pairs[15] >= 2'd1) begin
        if0.rem = pairs[15] - 2'b01;
        if0.root = 1'b1;
    end 
    else begin
        if0.rem = pairs[15];
        if0.root = 1'b0;
    end
end

    square_iter step1  (.in(if0.stage_in),  .i_pair(pairs[14]), .out(if1.stage_out), .i_clk(i_clk) , .i_rst(i_rst)  );
    square_iter step2  (.in(if1.stage_in),  .i_pair(pairs[13]), .out(if2.stage_out), .i_clk(i_clk) , .i_rst(i_rst)  );
    square_iter#(.ENABLE_PIPE(1)) step3  (.in(if2.stage_in),  .i_pair(pairs[12]), .out(if3.stage_out), .i_clk(i_clk) , .i_rst(i_rst)  );
    square_iter step4  (.in(if3.stage_in),  .i_pair(pairs_p[11]), .out(if4.stage_out), .i_clk(i_clk) , .i_rst(i_rst)  );
    square_iter step5  (.in(if4.stage_in),  .i_pair(pairs_p[10]), .out(if5.stage_out), .i_clk(i_clk) , .i_rst(i_rst)  );
    square_iter#(.ENABLE_PIPE(1)) step6  (.in(if5.stage_in),  .i_pair(pairs_p[9]),  .out(if6.stage_out), .i_clk(i_clk) , .i_rst(i_rst)  );
    
    square_iter step7  (.in(if6.stage_in),  .i_pair(pairs_d1[8]),  .out(if7.stage_out), .i_clk(i_clk) , .i_rst(i_rst)  ); 
    square_iter#(.ENABLE_PIPE(1)) step8  (.in(if7.stage_in),  .i_pair(pairs_d1[7]),  .out(if8.stage_out), .i_clk(i_clk) , .i_rst(i_rst)  );    
    
    square_iter step9  (.in(if8.stage_in),  .i_pair(pairs_d2[6]),  .out(if9.stage_out), .i_clk(i_clk) , .i_rst(i_rst)  );
    square_iter#(.ENABLE_PIPE(1)) step10 (.in(if9.stage_in),  .i_pair(pairs_d2[5]),  .out(if10.stage_out), .i_clk(i_clk) , .i_rst(i_rst)  );
    
    square_iter step11 (.in(if10.stage_in), .i_pair(pairs_d3[4]),  .out(if11.stage_out), .i_clk(i_clk) , .i_rst(i_rst)  );
    square_iter#(.ENABLE_PIPE(1)) step12 (.in(if11.stage_in), .i_pair(pairs_d3[3]),  .out(if12.stage_out), .i_clk(i_clk) , .i_rst(i_rst)  );
    
    
    square_iter step13 (.in(if12.stage_in), .i_pair(pairs_d4[2]),  .out(if13.stage_out), .i_clk(i_clk) , .i_rst(i_rst)  );
    square_iter step14 (.in(if13.stage_in), .i_pair(pairs_d4[1]),  .out(if14.stage_out), .i_clk(i_clk) , .i_rst(i_rst)  );
    square_iter step15 (.in(if14.stage_in), .i_pair(pairs_d4[0]),  .out(if15.stage_out), .i_clk(i_clk) , .i_rst(i_rst)  );

    logic[4:0]valid_reg ;
    
    always_ff@(posedge i_clk)
        if(i_rst)begin
            valid_reg <= 0 ;
            o_ready <= 0 ;
        end
        else begin
            valid_reg <= {valid_reg[3:0], i_valid};
            o_ready <= valid_reg[4];
        end     
        
   always_ff@(posedge i_clk)
        o_out   <= if15.root ; 
   
          
    
    
    
endmodule
