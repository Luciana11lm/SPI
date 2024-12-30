module spi_top #(
parameter DATA_WIDTH    = 'd8   ,
parameter LEN_WIDTH     = 'd4   
)();

reg                           clk         ;
reg                           rst_n       ;
reg  [DATA_WIDTH     - 1 : 0] data_in     ;
reg  [LEN_WIDTH      - 1 : 0] len_data    ; 
reg                           req         ;
reg                           dir_transfer;
wire                          ack         ;
wire                          sclk        ;
wire                          mosi        ;
wire                          ss          ;

initial begin
	clk <= 'd0;
	forever #5 clk <= ~clk;
end

initial begin
	rst_n <= 'd1;
	#13;
	rst_n <= 'd0;
	#8;
	rst_n <= 'd1;
end

initial begin
	@(negedge rst_n);
	@(posedge rst_n);
	@(posedge clk);
	make_req('h17, 'd8, 2, 'd1);
	make_req('h16, 'd8, 30, 'd1);
	make_req('h15, 'd8, 0, 'd1);
	make_req('h14, 'd8, 0, 'd0);
	make_req('h13, 'd8, 0, 'd0);
	make_req('h12, 'd8, 50, 'd0);
end

task make_req(input [DATA_WIDTH - 1 : 0] data_sent, input [LEN_WIDTH - 1 : 0] len_data_send, input int delay, input direction);
	begin
		repeat(delay) @(posedge clk);
		req <= 'd1;
		data_in <= data_sent;
		len_data <= len_data_send;
		dir_transfer <= direction;
		@(negedge ack);
		req <= 'd0;
		data_in <= 'hx;
		len_data <= 'hx;
	end
endtask

spi_master #(
.DATA_WIDTH    (DATA_WIDTH  ),
.LEN_WIDTH     (LEN_WIDTH   ),
.DIVIDER_CLK   ('d2         ),
.PHASE_CLK     ('d0         ),
.POLARITY_CLK  ('d0         )
)i_spi_master(
.clk           (clk         ), 
.rst_n         (rst_n       ), 
.req           (req         ), 
.dir_transfer  (dir_transfer), 
.len_data      (len_data    ), 
.data_in       (data_in     ), 
.miso          (            ), 
.ack           (ack         ), 
.sclk          (sclk        ), 
.mosi          (mosi        ), 
.ss            (ss          )  
);

endmodule