
`timescale 1 ns / 1 ps

	module axi_lite_interface_v1_0 #
	(
		// Users to add parameters here
        parameter   ADDRESS_WIDTH = 14,
        parameter   AXI_ADDRESS_WIDTH = 16
	)
	(
		// Users to add ports here

		// User ports ends
		// Do not modify the ports beyond this line


		// Ports of Axi Slave Bus Interface S00_AXI
        input                   s_axi_aclk,
        input                   s_axi_aresetn,
        input                   s_axi_awvalid,
        input       [15:0]      s_axi_awaddr,
        output                  s_axi_awready,
        input                   s_axi_wvalid,
        input       [31:0]      s_axi_wdata,
        input       [ 3:0]      s_axi_wstrb,
        output                  s_axi_wready,
        output                  s_axi_bvalid,
        output      [ 1:0]      s_axi_bresp,
        input                   s_axi_bready,
        input                   s_axi_arvalid,
        input       [15:0]      s_axi_araddr,
        output                  s_axi_arready,
        output                  s_axi_rvalid,
        output      [31:0]      s_axi_rdata,
        output      [ 1:0]      s_axi_rresp,
        input                   s_axi_rready,
        input       [ 2:0]      s_axi_awprot,
        input       [ 2:0]      s_axi_arprot,
        
          // pcore interface
      
        output                            up_wreq,
        output  [(ADDRESS_WIDTH-1):0]     up_waddr,
        output  [31:0]                    up_wdata,
        input                             up_wack,
        output                            up_rreq,
        output  [(ADDRESS_WIDTH-1):0]     up_raddr,
        input   [31:0]                    up_rdata,
        input                             up_rack
	);
	
	
	  // signal name changes
  
	
	
	
// Instantiation of Axi Bus Interface S00_AXI
  up_axi i_up_axi (
  .up_rstn (s_axi_aresetn),
  .up_clk (s_axi_aclk),
  .up_axi_awvalid (s_axi_awvalid),
  .up_axi_awaddr (s_axi_awaddr),
  .up_axi_awready (s_axi_awready),
  .up_axi_wvalid (s_axi_wvalid),
  .up_axi_wdata (s_axi_wdata),
  .up_axi_wstrb (s_axi_wstrb),
  .up_axi_wready (s_axi_wready),
  .up_axi_bvalid (s_axi_bvalid),
  .up_axi_bresp (s_axi_bresp),
  .up_axi_bready (s_axi_bready),
  .up_axi_arvalid (s_axi_arvalid),
  .up_axi_araddr (s_axi_araddr),
  .up_axi_arready (s_axi_arready),
  .up_axi_rvalid (s_axi_rvalid),
  .up_axi_rresp (s_axi_rresp),
  .up_axi_rdata (s_axi_rdata),
  .up_axi_rready (s_axi_rready),
  .up_wreq (up_wreq),
  .up_waddr (up_waddr),
  .up_wdata (up_wdata),
  .up_wack (up_wack),
  .up_rreq (up_rreq),
  .up_raddr (up_raddr),
  .up_rdata (up_rdata),
  .up_rack (up_rack));


	// Add user logic here

	// User logic ends

	endmodule
