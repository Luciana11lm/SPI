module spi_tb #(
parameter DATA_WIDTH    = 'd8   ,
parameter LEN_WIDTH     = 'd4   
)();

reg                           clk         ;
reg                           rst_n       ;
reg  [DATA_WIDTH     - 1 : 0] data_in     ;
reg                           req         ;
reg  [DATA_WIDTH     - 1 : 0] address     ;
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
	make_req('h40, 'd0, 2);   // configuration request, direction form 0 -> 7, polarity = 0, phase = 0, data length = 8 bits
	make_req('h1, 'd1, 5);    // divider clock value = 2
	make_req('h15, 'd8, 0);   
	make_req('h14, 'd8, 0);
	make_req('h13, 'd8, 0);
	make_req('h12, 'd8, 0);
	make_req('h11, 'd8, 0);
	make_req('h10, 'd8, 0);
	make_req('h09, 'd3, 5);
	make_req('h08, 'd3, 200);
	make_req('h43, 'd0, 200); // request to change polarity and direction
	make_req('h3, 'd1, 5);    // request to change clk divider value = 4
	make_req('h15, 'd8, 0);
	make_req('h22, 'd4, 0);
	make_req('h1a, 'd3, 8);
	make_req('h1b, 'd3, 3);
	make_req('h1c, 'd5, 6);
end

task make_req(input [DATA_WIDTH - 1 : 0] data_sent, input [DATA_WIDTH - 1 : 0] address_sent , input int delay);
	begin
		repeat(delay) @(posedge clk);
		req <= 'd1;
		data_in <= data_sent;
		address <= address_sent;
		@(negedge ack);
		req <= 'd0;
		data_in <= 'hx;
		address <= 'hx;
	end
endtask

spi_master #(
.DATA_WIDTH    (DATA_WIDTH  ),
.LEN_WIDTH     (LEN_WIDTH   ),
)i_spi_master(
.clk           (clk         ), 
.rst_n         (rst_n       ), 
.req           (req         ), 
.data_in       (data_in     ), 
.address       (address     ),
.miso          (            ), 
.ack           (ack         ), 
.sclk          (sclk        ), 
.mosi          (mosi        ), 
.ss            (ss          )  
);

endmodule