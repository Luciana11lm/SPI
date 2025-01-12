module spi_master #(
parameter DATA_WIDTH    = 'd8               ,
parameter LEN_WIDTH     = 'd5               ,
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
reg  [DIVIDER_CLK          : 0] cnt_div         ;        
reg  [LEN_WIDTH        - 1 : 0] cnt_bits        ;
reg  [DATA_WIDTH       - 1 : 0] data_stored     ;  
reg  [DATA_WIDTH       - 1 : 0] cfg_info        ;   // configuration information =  len_data (4) + phase_clk + polarity_clk + dir_transfer
reg  [DATA_WIDTH       - 1 : 0] divider_clk     ;
wire                            dir_transfer    ;   // direction of the transfered bits, 0 - form 0 to 7, 1 - from 7 to 0
wire                            polarity_clk    ;
wire                            phase_clk       ;
wire [LEN_WIDTH        - 1 : 0] len_data        ;   // data length
wire                            rd_enable       ;		// one pulse to enable data read from fifo when fifo not empty
wire                            wr_enable       ;   // one pulse to enable data write in fifo when req and ack
wire                            empty           ;
wire                            full            ;
wire [DATA_WIDTH       - 1 : 0] data_out        ;
wire [DATA_WIDTH       - 1 : 0] data_fifo       ;
reg                             empty_dly       ;
wire                            start_transfer  ;

assign wr_enable = req & ack & (address > 'd1);
assign rd_enable = (~|cnt_bits) & (~|cnt_div) & (~empty);
assign start_transfer = ~empty & empty_dly;
assign data_fifo = ((address > 'd1) & wr_enable) ? data_in : 'hx;

always @(posedge clk or negedge rst_n)
	if (~rst_n)	empty_dly <= 'd0; else
							empty_dly <= empty;

//---------------------------SPI LOGIC-----------------------------

assign mosi         = (~rd_enable) ? (dir_transfer ? data_stored[LAST_BIT] : data_stored[FIRST_BIT]) : mosi;
assign dir_transfer = cfg_info[0];
assign polarity_clk = cfg_info[1];
assign phase_clk    = cfg_info[2];
assign len_data     = cfg_info[7:3];

always @(posedge clk or negedge rst_n)
	if (~rst_n)	                                      sclk <= polarity_clk; else
	if (~|cnt_div & (~|cnt_bits))                     sclk <= polarity_clk; else
	if (start_transfer | (~|cnt_div & (|cnt_bits)))   sclk <= ~sclk; 

	
always @(posedge clk or negedge rst_n)
	if (~rst_n)	                    ss <= 'd0; else
	if (rd_enable)		              ss <= 'd1; else
	if (~(|cnt_bits) & ~(|cnt_div)) ss <= 'd0; 

//-------------------------COUNTERS LOGIC--------------------------

always @(posedge clk or negedge rst_n)
	if (~rst_n)                                         cnt_div <= 'd0; else
	if (start_transfer | (~|cnt_div & (|cnt_bits)))     cnt_div <= divider_clk; else
	if (|cnt_div)                                       cnt_div <= cnt_div - 'd1; 
														
always @(posedge clk or negedge rst_n)
	if (~rst_n)	                                                 cnt_bits <= 'd0; else
	if (start_transfer | ((~|cnt_bits) & (~|cnt_div) & ~empty))  cnt_bits <= SEMIPERIODS - 'd1; else
	if (~|cnt_div & (|cnt_bits))                                 cnt_bits <= cnt_bits - 'd1;
	
//-------------------------REQ-ACK LOGIC----------------------------
	
always @(posedge clk or negedge rst_n)
	if (~rst_n)	              ack <= 'd0; else
	if (req & (~full) & ~ack) ack <= 'd1; else
	if (ack)	                ack <= 'd0; 
	
	
always @(posedge clk or negedge rst_n)
	if (rd_enable)		                          data_stored <= data_out; else
	if ((sclk ~^ polarity_clk) & (~|cnt_div) & (|cnt_bits)) 
		if (dir_transfer)	                        data_stored <= data_stored << 1; else
											                        data_stored <= data_stored >> 1;
																							
always @(posedge clk or negedge rst_n)
	if (ack & (address == 'd0))               	cfg_info <= data_in;
	
always @(posedge clk or negedge rst_n)
	if (ack & (address == 'd1))               	divider_clk <= data_in;

fifo #(
.DATA_WIDTH (DATA_WIDTH),
.FIFO_DEPTH (6         ) 
)i_fifo(    
.clk        (clk       ),
.rst_n      (rst_n     ),
.data_in    (data_fifo ),
.wr_enable  (wr_enable ),
.rd_enable  (rd_enable ),
.data_out   (data_out  ),
.empty      (empty     ),
.full       (full      )
);
											
endmodule