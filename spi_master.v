module spi_master #(
parameter DATA_WIDTH    = 'd8               ,
parameter LEN_WIDTH     = 'd5               ,
parameter FIFO_DEPTH    = 'd6               ,
parameter DIVIDER_CLK   = 8'd2                // number of clk tacts + 1 in a sclk tact
)(
input                          clk          , // system clock
input                          rst_n        , // asynchronous reset, active low
input                          req          , // request to transfer a data
input [DATA_WIDTH     - 1 : 0] data_in      , // requested data
input [DATA_WIDTH     - 1 : 0] address      , // address of the requested data 0 - configuration information, 1 - clk divider, other - fifo
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
reg  [DATA_WIDTH - 1 : 0] data_stored [FIFO_DEPTH - 1 : 0];
reg                             empty           ; 
reg                             full            ;
reg  [$clog2(FIFO_DEPTH) - 1:0] wr_pointer      ;
reg  [$clog2(FIFO_DEPTH) - 1:0] rd_pointer      ;
wire [$clog2(FIFO_DEPTH) - 1:0] wr_pointer_next ;
wire [$clog2(FIFO_DEPTH) - 1:0] rd_pointer_next ;
reg  [DIVIDER_CLK          : 0] cnt_div         ;        
reg  [LEN_WIDTH        - 1 : 0] cnt_bits        ;
reg  [DATA_WIDTH       - 1 : 0] cfg_info        ;   // configuration information =  len_data (4) + phase_clk + polarity_clk + dir_transfer
reg  [DATA_WIDTH       - 1 : 0] divider_clk     ;
wire                            dir_transfer    ;   // direction of the transfered bits, 0 - form 0 to 7, 1 - from 7 to 0
wire                            polarity_clk    ;
wire                            phase_clk       ;
wire [LEN_WIDTH        - 1 : 0] len_data        ;   // data length
wire                            rd_enable       ;
wire                            start_transfer  ;
reg                             empty_dly       ;

//---------------------------FIFO LOGIC-----------------------------
assign wr_pointer_next = (req & ack & (~full) & (address > 'd1)) ? ((wr_pointer == FIFO_DEPTH-'d1) ? 'd0 : wr_pointer + 'd1) : wr_pointer;
assign rd_pointer_next = (((~|cnt_bits) & (|cnt_div)) | start_transfer) ? ((rd_pointer == FIFO_DEPTH-'d1) ? 'd0 : rd_pointer + 'd1) : rd_pointer_next;
assign rd_enable = (~|cnt_bits) & (~|cnt_div);
assign start_transfer = ~empty & empty_dly;

always @(posedge clk or negedge rst_n)
	if (~rst_n)	                       rd_pointer <= 'd0; else
	if ((~|cnt_bits) & (|cnt_div))		 rd_pointer <= rd_pointer_next;
	
always @(posedge clk or negedge rst_n)
	if (~rst_n)	       wr_pointer <= 'd0; else
										 wr_pointer <= wr_pointer_next;
	
always @(posedge clk or negedge rst_n)
	if (~rst_n)	                                                    full <= 'd0; else
	if (req & ack & (~rd_enable) & (wr_pointer_next == rd_pointer))	full <= 'd1; else
	if ((~|cnt_bits) & (~|cnt_div))                                 full <= 'd0;
	
always @(posedge clk or negedge rst_n)
	if (~rst_n)	                                              empty <= 'd1; else
	if (rd_enable & (~req) & (rd_pointer_next == wr_pointer))	empty <= 'd1; else
	if (req & ack & (address > 'd1))                          empty <= 'd0;
	
always @(posedge clk or negedge rst_n)
	empty_dly <= empty;

//---------------------------SPI LOGIC-----------------------------

assign mosi = (~rd_enable) ? (dir_transfer ? data_stored[rd_pointer][LAST_BIT] : data_stored[rd_pointer][FIRST_BIT]) : mosi;
assign dir_transfer = cfg_info[0];
assign polarity_clk = cfg_info[1];
assign phase_clk = cfg_info[2];
assign len_data = cfg_info[7:3];

always @(posedge clk)
	if (start_transfer | ((~|cnt_div & (|cnt_bits))))  sclk <= ~sclk; else
	if (~|cnt_div & (~|cnt_bits))                      sclk <= polarity_clk;
	
always @(posedge clk or negedge rst_n)
	if (~rst_n)	                    ss <= 'd0; else
	if (ack)		                    ss <= 'd1; else
	if (~(|cnt_bits) & ~(|cnt_div)) ss <= 'd0; 

//-------------------------COUNTERS LOGIC--------------------------

always @(posedge clk or negedge rst_n)
	if (~rst_n)                                      cnt_div <= 'd0; else
	if (start_transfer | (~|cnt_div & (|cnt_bits)))  cnt_div <= divider_clk; else
	if (rd_enable & ~empty)                          cnt_div <= divider_clk; else
	if (|cnt_div)                                    cnt_div <= cnt_div - 'd1; 
														
always @(posedge clk or negedge rst_n)
	if (~rst_n)	                                      cnt_bits <= 'd0; else
	if (start_transfer | (~(|cnt_bits) & ~(|cnt_div) & ~empty))    cnt_bits <= SEMIPERIODS - 'd1; else
	if (~|cnt_div & (|cnt_bits))                      cnt_bits <= cnt_bits - 'd1;
	
//-------------------------REQ-ACK LOGIC----------------------------
	
always @(posedge clk or negedge rst_n)
	if (~rst_n)	              ack <= 'd0; else
	if (req & (~full) & ~ack) ack <= 'd1; else
	if (ack)	                ack <= 'd0; 
	
	
always @(posedge clk or negedge rst_n)
	if (ack & (address > 'd1))		              data_stored[wr_pointer] <= data_in; else
	if ((sclk ~^ polarity_clk) & (~|cnt_div) & (|cnt_bits)) 
		if (dir_transfer)	                        data_stored[rd_pointer] <= data_stored[rd_pointer] << 1; else
											                        data_stored[rd_pointer] <= data_stored[rd_pointer] >> 1;
																							
always @(posedge clk or negedge rst_n)
	if (ack & (address == 'd0))               	cfg_info <= data_in;
	
always @(posedge clk or negedge rst_n)
	if (ack & (address == 'd1))               	divider_clk <= data_in;

											
endmodule