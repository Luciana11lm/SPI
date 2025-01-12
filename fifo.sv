module fifo #(
parameter DATA_WIDTH = 8,
parameter FIFO_DEPTH = 6
)(
input                           clk       ,
input                           rst_n     ,
input      [DATA_WIDTH - 1:0] 	data_in   ,
input                    				wr_enable ,
input                    				rd_enable ,
output     [DATA_WIDTH - 1:0] 	data_out  ,
output reg                    	empty     ,
output reg                    	full  
);

reg  [DATA_WIDTH         - 1:0] fifo [FIFO_DEPTH - 1 : 0];
reg  [$clog2(FIFO_DEPTH)    :0] wr_pointer               ;
reg  [$clog2(FIFO_DEPTH)    :0] rd_pointer               ;
wire [$clog2(FIFO_DEPTH)    :0] wr_pointer_next          ;
wire [$clog2(FIFO_DEPTH)    :0] rd_pointer_next          ;

assign wr_pointer_next = (wr_enable & (~full)) ? ((wr_pointer == FIFO_DEPTH-'d1) ? 'd0 : wr_pointer + 'd1) : wr_pointer;
assign rd_pointer_next = (rd_enable & (~empty)) ? ((rd_pointer == FIFO_DEPTH-'d1) ? 'd0 : rd_pointer + 'd1) : rd_pointer;
assign data_out = fifo[rd_pointer];

always @(posedge clk or negedge rst_n)
	if (~rst_n)	       rd_pointer <= 'd0; else
										 rd_pointer <= rd_pointer_next;
	
always @(posedge clk or negedge rst_n)
	if (~rst_n)	       wr_pointer <= 'd0; else
										 wr_pointer <= wr_pointer_next;
	
always @(posedge clk or negedge rst_n)
	if (~rst_n)	                                                    full <= 'd0; else
	if (wr_enable & (~rd_enable) & (wr_pointer_next == rd_pointer))	full <= 'd1; else
	if (rd_enable)                                                  full <= 'd0;
	
always @(posedge clk or negedge rst_n)
	if (~rst_n)	                                                    empty <= 'd1; else
	if (rd_enable & (~wr_enable) & (rd_pointer_next == wr_pointer))	empty <= 'd1; else
	if (wr_enable)                                                  empty <= 'd0;
	
always @(posedge clk)
	if (wr_enable & (~full))	fifo[wr_pointer] <= data_in;

/*	
always @(posedge clk)
	if (rd_enable & (~empty))	data_out <= fifo[rd_pointer]; else
														data_out <= 'dx;
	*/
endmodule