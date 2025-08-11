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
module uart_rx_buf #(
	parameter clk_freq = 12000000,
	parameter baud = 115200,
    parameter rbuf_size = 16
) (
	input clk,
	input RX,
    input get,
    output reg [7:0] data,
    output reg empty
);

function integer log2(input integer v); begin
	log2 = 0;
	while(v >> log2) log2 = log2 + 1;
end endfunction

wire rx1_ready;
wire [7:0] rx1_data;
uart_rx #(clk_freq, baud) urx1 (
    .clk(clk),
    .rx(RX),
    .rx_ready(rx1_ready),
    .rx_data(rx1_data)
);

localparam RBUF_ADDR_WIDTH = log2(rbuf_size-1);

reg [7:0] rbuf [0:rbuf_size-1];

reg [RBUF_ADDR_WIDTH:0] _b = 0;
reg [RBUF_ADDR_WIDTH:0] _e = 0;

reg rbuf_empty;

always @(*) begin
    rbuf_empty = _b == _e;
    data = rbuf[_b];
    empty = rbuf_empty;
end

integer i;

always @(posedge clk) begin
    if (!rbuf_empty && get) begin
        _b <= _b + 1;
    end
    else begin
        _b <= _b;
    end

    for (i = 0; i < rbuf_size; i = i + 1) begin
        rbuf[_e] <= rbuf[_e];
    end
    if (rx1_ready) begin
        rbuf[_e] <= rx1_data;
    end

    if (rx1_ready) begin
        _e <= _e + 1;
    end
    else begin
        _e <= _e;
    end
end

endmodule
