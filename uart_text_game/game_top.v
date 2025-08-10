`include "bram.v"
`include "uart_terminal_handler.v"

module game_top (
	input clk,
	input RX,
    output TX,
	output LED
);

function integer log2(input integer v); begin
	log2 = 0;
	while(v >> log2) log2 = log2 + 1;
end endfunction

localparam WIDTH = 8;
localparam LEN = 256;

wire [log2(LEN-1):0] bram_addr;
wire [WIDTH-1:0] bram_din;
wire [WIDTH-1:0] bram_dout;
wire bram_we;

bram #(WIDTH, LEN) iomsg (
    .clk(clk),
    .addr(bram_addr),
    .din(bram_din),
    .dout(bram_dout),
    .we(bram_we)
);

uart_terminal_handler uther (
    .clk(clk),
    .RX(RX),
    .TX(TX),

    .bram_addr(bram_addr),
    .bram_din(bram_din),
    .bram_dout(bram_dout),
    .bram_we(bram_we),

    .in_burst_done(),
    .out_burst_start()
);

localparam S_O_NEW_GAME_ = 0;
localparam S_I_CODE      = 1;
localparam S_O_CODE      = 1;
    
endmodule