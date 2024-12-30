module spi_master #(
parameter DATA_WIDTH    = 'd8               ,
parameter LEN_WIDTH     = 'd4               ,
parameter PHASE_CLK     = 'd0               , // not implemented
parameter POLARITY_CLK  = 'd0               ,
parameter DIVIDER_CLK   = 8'd1                // number of clk tacts + 1 in a sclk tact
)(
input                          clk          , // system clock
input                          rst_n        , // asynchronous reset, active low
input                          req          , // request to transfer a data
input                          dir_transfer , // direction of the transfered bits, 0 - form 0 to 7, 1 - from 7 to 0
input [LEN_WIDTH      - 1 : 0] len_data     , // data length
input [DATA_WIDTH     - 1 : 0] data_in      , // requested data
input                          miso         , // master in slave out, 1 bit sent from the slave to the master
output reg                     ack          , // acknowledge that the request is served
output reg                     sclk         , 
output                         mosi         , // master out slave in, 1 bit sent from the master to the slave
output reg                     ss             // slave select 
);
 
localparam FIRST_BIT   = 0;
localparam LAST_BIT    = DATA_WIDTH - 'd1;
localparam SEMIPERIODS = DATA_WIDTH << 1;

//-----------------------INTERNAL WIRES/REGS----------------------
reg [DIVIDER_CLK   : 0] cnt_div;
reg [LEN_WIDTH - 1 : 0] cnt_bits;
reg [DATA_WIDTH- 1 : 0] data_stored;

//---------------------------SPI LOGIC-----------------------------

assign mosi = dir_transfer ? data_stored[LAST_BIT] : data_stored[FIRST_BIT];

always @(posedge clk or negedge rst_n)
	if (~rst_n)	                         sclk <= POLARITY_CLK; else
	if (ack | (~|cnt_div & (|cnt_bits))) sclk <= ~sclk; else
	if (~|cnt_div & (~|cnt_bits))        sclk <= POLARITY_CLK;
	
always @(posedge clk or negedge rst_n)
	if (~rst_n)	                    ss <= 'd0; else
	if (ack)		                    ss <= 'd1; else
	if (~(|cnt_bits) & ~(|cnt_div)) ss <= 'd0; 

//-------------------------COUNTERS LOGIC--------------------------

always @(posedge clk or negedge rst_n)
	if (~rst_n)                              cnt_div <= 'd0; else
	if (ack | (~|cnt_div & (|cnt_bits)))     cnt_div <= DIVIDER_CLK; else
	if (|cnt_div)                            cnt_div <= cnt_div - 'd1; 
														
always @(posedge clk or negedge rst_n)
	if (~rst_n)	                    cnt_bits <= 'd0; else
	if (req & ack)                  cnt_bits <= SEMIPERIODS - 'd1; else
	if (~|cnt_div & (|cnt_bits))    cnt_bits <= cnt_bits - 'd1;
	
//-------------------------REQ-ACK LOGIC----------------------------
	
always @(posedge clk or negedge rst_n)
	if (~rst_n)	                                 ack <= 'd0; else
	if (req & (~|cnt_bits) & (~|cnt_div) & ~ack) ack <= 'd1; else
	if (ack)	                                   ack <= 'd0; 
	
	
always @(posedge clk or negedge rst_n)
	if (ack)		                                data_stored <= data_in; else
	if ((sclk ~^ POLARITY_CLK) & (~|cnt_div)) 
		if (dir_transfer)	                        data_stored <= data_stored << 1; else
											                        data_stored <= data_stored >> 1;
											
endmodule