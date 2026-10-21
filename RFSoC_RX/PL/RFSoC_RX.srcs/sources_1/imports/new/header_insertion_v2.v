`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/24/2026 02:45:45 PM
// Design Name: 
// Module Name: header_insertion_v2
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


module header_insertion_v2(
	// AXI4-S output signals
	m_axis_tdata,
	m_axis_tready,
	m_axis_tvalid,
	m_axis_tkeep,
	m_axis_tlast,
	aclk,
	aresetn,
		
		
	// Signal Interface
	s_axis_tdata,
	s_axis_tvalid,
	s_axis_tready,
	s_axis_tlast,
	s_axis_tuser,
	
	buff_rem,
	in_words,
	out_words
);
	parameter	WORD_WIDTH	= 	32;
    parameter	DIN_WORDS	= 	5;
    parameter 	DOUT_WORDS 	= 	4; 
	parameter	IP_WIDTH	= 	16;
	parameter	TYPE_WIDTH  = 	8;
	parameter	TIME_WIDTH   = 	40;
	parameter	USER_WIDTH	=	IP_WIDTH + TYPE_WIDTH + TIME_WIDTH;
	parameter   BUFF_DEPTH  = 4;
    
    input aclk;
    input aresetn;
    
    input			[WORD_WIDTH*DIN_WORDS-1:0] 		s_axis_tdata;
	input											s_axis_tvalid;
	output											s_axis_tready;
	input											s_axis_tlast;
	input			[USER_WIDTH-1:0]				s_axis_tuser;
	
	output			[WORD_WIDTH*DOUT_WORDS-1:0]		m_axis_tdata;
	output	reg										m_axis_tvalid;
	input											m_axis_tready;
	output	reg										m_axis_tlast;
	output	reg		[WORD_WIDTH*DOUT_WORDS/8-1:0]	m_axis_tkeep;
	
	output          [$clog2(BUFF_DEPTH*DIN_WORDS+1)-1:0]   	buff_rem;
	
	
	//wire						sof, eof;
	reg 						sof;
	reg                         tlast_r;
	
	wire	[TIME_WIDTH-1:0]	timestamp;
	wire	[IP_WIDTH-1:0]		ip;
	wire	[TYPE_WIDTH-1:0]	data_type;
	
	output wire 	[$clog2(DIN_WORDS+USER_WIDTH/WORD_WIDTH+1)-1:0]		in_words;
	output wire 	[$clog2(DOUT_WORDS+1)-1:0]							out_words;
	wire    [$clog2(BUFF_DEPTH*DIN_WORDS+1)-1:0]   						next_words;
	
	wire    [BUFF_DEPTH*WORD_WIDTH*DIN_WORDS-1:0]	data_stream_in;
	wire    [BUFF_DEPTH*WORD_WIDTH*DIN_WORDS-1:0]	data_lsfr_w1;
	wire    [BUFF_DEPTH*WORD_WIDTH*DIN_WORDS-1:0]	data_lsfr_w2;
	wire    [WORD_WIDTH*DOUT_WORDS-1:0]     data_stream_out;
	
	reg	    [BUFF_DEPTH*WORD_WIDTH*DIN_WORDS-1:0]	data_lsfr_r;
	reg	    [$clog2(BUFF_DEPTH*DIN_WORDS+1)-1:0]   	data_rem;
	
	//assign	{sof, eof, ip, data_type, timestamp} = s_axis_tuser;
	assign	{ip, data_type, timestamp} = s_axis_tuser;

    assign	s_axis_tready = (data_rem <= (BUFF_DEPTH-1)*DIN_WORDS ) & ~m_axis_tlast;
		
	assign	in_words = (s_axis_tvalid && s_axis_tready) ? sof ? (USER_WIDTH/WORD_WIDTH+DIN_WORDS) : DIN_WORDS : 0;
	assign 	out_words = ~m_axis_tlast ? (data_rem + in_words >= DOUT_WORDS)  ? DOUT_WORDS : 0: 0;
	assign  next_words = data_rem + in_words - out_words;
		
	assign	data_stream_in = (s_axis_tvalid && s_axis_tready) ? {s_axis_tdata, {WORD_WIDTH*(BUFF_DEPTH*DIN_WORDS-DIN_WORDS){1'b0}}} : {WORD_WIDTH*(BUFF_DEPTH*DIN_WORDS){1'b0}};
							
	assign	data_lsfr_w1 = data_lsfr_r << (WORD_WIDTH*DOUT_WORDS) | data_stream_in >> (data_rem * WORD_WIDTH);
	assign	data_lsfr_w2 = data_lsfr_r | data_stream_in >> ((data_rem + DOUT_WORDS) * WORD_WIDTH);
	
	assign 	m_axis_tdata = data_lsfr_r [WORD_WIDTH*BUFF_DEPTH*DIN_WORDS-1:WORD_WIDTH*BUFF_DEPTH*DIN_WORDS - DOUT_WORDS*WORD_WIDTH];
	//assign 	data_stream_out = data_lsfr_r [WORD_WIDTH*(BUFF_DEPTH*DOUT_WORDS)-1:WORD_WIDTH*((BUFF_DEPTH-1)*DOUT_WORDS)];

	/*genvar i;
	 generate
	   for(i = 0; i < DOUT_WORDS; i=i+1) begin
	       assign m_axis_tdata[i*WORD_WIDTH+:WORD_WIDTH] = data_stream_out[(DOUT_WORDS-i)*WORD_WIDTH - 1 -: WORD_WIDTH];
	   end
	 endgenerate*/
	
	always@(posedge aclk) begin
		if(!aresetn)
			data_lsfr_r <= 0;
		else begin
			if(sof && s_axis_tvalid && s_axis_tready)
			    if(out_words != 0 && m_axis_tready)
				    data_lsfr_r <= data_lsfr_w1 >> USER_WIDTH | {s_axis_tuser, {(WORD_WIDTH*(BUFF_DEPTH*DIN_WORDS)-USER_WIDTH){1'b0}}};
				else
				    data_lsfr_r <= data_lsfr_w2 >> USER_WIDTH | {s_axis_tuser, {(WORD_WIDTH*(BUFF_DEPTH*DIN_WORDS)-USER_WIDTH){1'b0}}};
			else if(s_axis_tvalid && s_axis_tready)
			    if(out_words != 0 && m_axis_tready)
			        data_lsfr_r <= data_lsfr_w1;
			    else
			        data_lsfr_r <= data_lsfr_w2;				
			else if(out_words != 0 && m_axis_tready)
				data_lsfr_r <= data_lsfr_r << (WORD_WIDTH*DOUT_WORDS);			
			else	
				data_lsfr_r <= data_lsfr_r;
		end
	end
	
	assign buff_rem = data_rem;
		
	always@(posedge aclk) begin
		if(!aresetn)
			data_rem <= 0;
		else begin
		    if(s_axis_tvalid && s_axis_tready) 
		        if(out_words != 0 && m_axis_tready)
		    	     data_rem <= data_rem + in_words - DOUT_WORDS;
		    	else
		    	     data_rem <= data_rem + in_words;
		    else if(out_words != 0 && m_axis_tready)
				data_rem <= data_rem - DOUT_WORDS; 
			else	
				data_rem <= data_rem;
		end
	end
	
	always @(posedge aclk) begin
        if (!aresetn)
            m_axis_tvalid <= 1'b0;
        else if (m_axis_tvalid && !m_axis_tready)
            m_axis_tvalid <= 1'b1;          // hold
        else if (out_words != 0)
            m_axis_tvalid <= 1'b1;
        else
            m_axis_tvalid <= 1'b0;
    end 
	
	always@(posedge aclk) begin
		if(!aresetn)
			m_axis_tkeep <= 0;
		else begin
			if(out_words != 0 && m_axis_tready)
				m_axis_tkeep <= ~ ({WORD_WIDTH*DOUT_WORDS/8{1'b1}} >> (out_words * WORD_WIDTH / 8));
			else
				m_axis_tkeep <= m_axis_tkeep;
		end
	end
	
	always@(posedge aclk) begin
		if(!aresetn)
			m_axis_tlast <= 0;
		else 
		    if (m_axis_tlast && ~(m_axis_tvalid && m_axis_tready))
                m_axis_tlast <= m_axis_tlast;          
            else
			    //m_axis_tlast <= s_axis_tvalid & s_axis_tready & eof;
			    m_axis_tlast <= s_axis_tvalid & s_axis_tready & s_axis_tlast;
	end
	
	always@(posedge aclk) begin
		if(!aresetn)
			tlast_r <= 0;
		else 
		    tlast_r <= s_axis_tvalid & s_axis_tready & s_axis_tlast;
	end
		
	always@(posedge aclk) begin
		if(!aresetn)
			sof <= 1;
		else 
		    if (s_axis_tlast && s_axis_tready && s_axis_tvalid)
                sof <= 1;          
            else if (s_axis_tready && s_axis_tvalid)
			    sof <= 0;
			else
			    sof <= sof;
	end
endmodule
