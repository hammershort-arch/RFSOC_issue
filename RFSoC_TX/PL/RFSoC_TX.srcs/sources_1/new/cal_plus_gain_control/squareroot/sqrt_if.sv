interface sqrt_if(input logic clk, input logic rst);
    logic valid;
    logic[31:0] data;
    logic[16:0] out;
    logic ready;
    
    // Clocking Block
    // drv_cb，Driver 
    clocking drv_cb @(posedge clk);
        default input #1ns output #1ns;
        output data;
        output valid;
        input  ready;
        input  out;   
    endclocking

    // Monitor
    clocking mon_cb @(posedge clk);
        default input #1ns output #1ns;
        input data, valid, ready, out;
    endclocking
    

endinterface

interface sqrt_iter_if #(
    parameter int R_WIDTH = 2, 
    parameter int Q_WIDTH = 1
);
    logic [R_WIDTH-1:0] rem;
    logic [Q_WIDTH-1:0] root;

    modport stage_in  (input  rem, input  root);
    modport stage_out (output rem, output root);
    
endinterface