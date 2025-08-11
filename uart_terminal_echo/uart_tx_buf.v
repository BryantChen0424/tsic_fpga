/*
 *  icebreaker examples - Async uart mirror using pll
 *
 *  Copyright (C) 2018 Piotr Esden-Tempski <piotr@esden.net>
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */


// without ring buffer overwrite checking
module uart_tx_buf #(
	parameter clk_freq = 12000000,
	parameter baud = 115200,
    parameter rbuf_size = 16
) (
	input  clk,
	output TX,
    input put,
    input [7:0] data,
    output reg empty
);

function integer log2(input integer v); begin
	log2 = 0;
	while(v >> log2) log2 = log2 + 1;
end endfunction

/* instantiate the tx1 module */
reg tx1_start = 0;
reg [7:0] tx1_data = 0;
wire tx1_busy;
uart_tx #(clk_freq, baud) utx1 (
    .clk(clk),
    .tx_start(tx1_start),
    .tx_data(tx1_data),
    .tx(TX),
    .tx_busy(tx1_busy)
);

localparam RBUF_ADDR_WIDTH = log2(rbuf_size-1);

reg [7:0] rbuf [0:rbuf_size-1];

reg [RBUF_ADDR_WIDTH:0] _b = 0;
reg [RBUF_ADDR_WIDTH:0] _e = 0;

reg rbuf_empty;
// reg flag = 0;

always @(*) begin
    rbuf_empty = _b == _e;
    empty = rbuf_empty;
end

integer i;

always @(posedge clk) begin
    if (!tx1_start && !rbuf_empty && !tx1_busy) begin
        tx1_start <= 1;
        tx1_data <= rbuf[_b];
        _b <= _b + 1;
        // flag <= 1;
    end
    else begin
        tx1_start <= 0;
        tx1_data <= 0;
        _b <= _b;
    end

    for (i = 0; i < rbuf_size; i = i + 1) begin
        rbuf[_e] <= rbuf[_e];
    end
    if (put) begin
        rbuf[_e] <= data;
    end

    if (put) begin
        _e <= _e + 1;
    end
    else begin
        _e <= _e;
    end
end

endmodule
