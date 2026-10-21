`timescale 1 ns / 1 ps

module AESL_cdc_unit #(parameter DEPTH = 16, parameter PWIDTH = 4, parameter DWIDTH = 1) (
    input reset_wclk,
    input reset_rclk,
    input write_clock,
    input write_en,
    input [DWIDTH - 1:0] write_data,
    input read_clock,
    output [DWIDTH - 1:0] read_data
        );
    
    reg [DWIDTH - 1:0] mem [0:DEPTH - 1];
    
    reg [PWIDTH:0] write_ptr;
    wire [PWIDTH:0] write_ptr_next;
    reg [PWIDTH:0] write_ptr_rsync_1;
    
    reg [PWIDTH:0] read_ptr;
    wire [PWIDTH:0] read_ptr_next;
    reg [PWIDTH:0] read_ptr_wsync_1;

        wire empty;
        wire full;

        //////////////////////////
        // memory access
        //////////////////////////
    assign read_data = empty ? 0 : mem[read_ptr[PWIDTH - 1:0]];

    always @ (posedge write_clock) 
        begin
        if (write_en && ~full) begin
            mem[write_ptr[PWIDTH - 1:0]] <= write_data;
            end
        end

        //////////////////////////
        // write_ptr
        //////////////////////////
        assign write_ptr_next = (write_en && ~full) ? (write_ptr + 1) : write_ptr;
    always @ (negedge reset_wclk or posedge write_clock) 
        begin
            if (reset_wclk == 0) begin
                write_ptr <= 0;
            end
            else begin
                write_ptr <= write_ptr_next;
            end
        end

        ///////////////////////////////////
        // write_ptr passing to read clock
        ///////////////////////////////////
    always @ (negedge reset_rclk or posedge read_clock) 
        begin
            if (reset_rclk == 0) begin
                write_ptr_rsync_1 <= 0;
            end
            else begin
                write_ptr_rsync_1 <= write_ptr;
            end
        end

        /////////////////////////////////
        // read_ptr: read when not empty
        /////////////////////////////////
        assign read_ptr_next = (~empty) ? (read_ptr + 1) : read_ptr;
    always @ (negedge reset_rclk or posedge read_clock) 
        begin
            if (reset_rclk == 0) begin
                read_ptr <= 0;
            end
            else begin
                read_ptr <= read_ptr_next;
            end
        end

        ///////////////////////////////////
        // read_ptr passing to write clock
        ///////////////////////////////////
    always @ (negedge reset_wclk or posedge write_clock) 
        begin
            if (reset_wclk == 0) begin
                read_ptr_wsync_1 <= 0;
            end
            else begin
                read_ptr_wsync_1 <= read_ptr;
            end
        end

        ///////////////////////////////////
        // empty full generation
        ///////////////////////////////////
    assign empty = (read_ptr == write_ptr_rsync_1);
    assign full = (write_ptr[PWIDTH] == ~read_ptr_wsync_1[PWIDTH]) && (write_ptr[PWIDTH - 1:0] == read_ptr_wsync_1[PWIDTH - 1:0]);
    
    
endmodule
