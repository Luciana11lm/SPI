module fifo #(
parameter DATA_WIDTH = 8,
parameter FIFO_DEPTH = 6
)(
input                           clk       , // system clock
input                           rst_n     , // asynchronous reset, active low
input      [DATA_WIDTH - 1:0] 	data_in   , // data written into fifo
input                    				wr_enable , // one pulse to enable data read from fifo when fifo not empty
input                    				rd_enable , // one pulse to enable data write in fifo when req and ack
output     [DATA_WIDTH - 1:0] 	data_out  , // data read from fifo
output reg                    	empty     , // fifo has no data
output reg                    	full        // fifo stores FIFO_DEPTH data 
);

reg  [DATA_WIDTH         - 1:0] fifo [FIFO_DEPTH - 1 : 0]; // fifo that stores FIFO_DEPTH data of DATA_WIDTH bits
reg  [$clog2(FIFO_DEPTH)    :0] wr_pointer               ; // inidcates the position in fifo where data is written
reg  [$clog2(FIFO_DEPTH)    :0] rd_pointer               ; // inidcates the position in fifo where data is read from
wire [$clog2(FIFO_DEPTH)    :0] wr_pointer_next          ; // inidcates the next position in fifo where data is written
wire [$clog2(FIFO_DEPTH)    :0] rd_pointer_next          ; // inidcates the next position in fifo where data is read from

// changes when a write request is made and fifo isn't full, if it is currently the last position in fifo, then becomes the first(0), else increments
assign wr_pointer_next = (wr_enable & (~full)) ? ((wr_pointer == FIFO_DEPTH-'d1) ? 'd0 : wr_pointer + 'd1) : wr_pointer;

// changes when a read request is made and fifo isn't empty, if it is currently the last position in fifo, then becomes the first(0), else increments
assign rd_pointer_next = (rd_enable & (~empty)) ? ((rd_pointer == FIFO_DEPTH-'d1) ? 'd0 : rd_pointer + 'd1) : rd_pointer;

// sends data as long as it's not empty and has read request
assign data_out = (~empty & rd_enable) ? fifo[rd_pointer] : 'hx; 

always @(posedge clk or negedge rst_n)
	if (~rst_n)	       rd_pointer <= 'd0; else
										 rd_pointer <= rd_pointer_next;
	
always @(posedge clk or negedge rst_n)
	if (~rst_n)	       wr_pointer <= 'd0; else
										 wr_pointer <= wr_pointer_next;
	
// sets when a write operation is made without a read operation and the position that is written is next to the last read one, resets at a read operation
always @(posedge clk or negedge rst_n)
	if (~rst_n)	                                                    full <= 'd0; else
	if (wr_enable & (~rd_enable) & (wr_pointer_next == rd_pointer))	full <= 'd1; else
	if (rd_enable)                                                  full <= 'd0;
	
// sets when a read operation is made without a write operation and the position that is read is next to the last written one, resets at a write operation
always @(posedge clk or negedge rst_n)
	if (~rst_n)	                                                    empty <= 'd1; else
	if (rd_enable & (~wr_enable) & (rd_pointer_next == wr_pointer))	empty <= 'd1; else
	if (wr_enable)                                                  empty <= 'd0;
	
// stores data as long as it's not full and has write request
always @(posedge clk)
	if (wr_enable & (~full))	fifo[wr_pointer] <= data_in;

/*	
always @(posedge clk)
	if (rd_enable & (~empty))	data_out <= fifo[rd_pointer]; else
														data_out <= 'dx;
*/
endmodule