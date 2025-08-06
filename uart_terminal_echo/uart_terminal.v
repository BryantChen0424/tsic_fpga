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

`include "uart_rx_buf.v"
`include "uart_tx_buf.v"

module top (
	input  clk,
	input RX,
    output TX,
	output LED
);

function integer log2(input integer v); begin
	log2 = 0;
	while(v >> log2) log2 = log2 + 1;
end endfunction

/* local parameters */
localparam clk_freq = 12_000_000; // 12MHz
localparam baud = 115200;

reg get;
wire [7:0] rx_data;
wire rx_empty;
uart_rx_buf #(clk_freq, baud) rxb (
	.clk(clk),
	.RX(RX),
    .get(get),
    .data(rx_data),
    .empty(rx_empty)
);

reg put;
reg [7:0] tx_data;
wire tx_empty;
uart_tx_buf #(clk_freq, baud) txb (
	.clk(clk),
	.TX(TX),
    .put(put),
    .data(tx_data),
    .empty(tx_empty)
);

localparam 
    S_RESET = 0,
    S_R = 1,
    S_T = 2;

reg [31:0] rst_cnt;


// ctrl signals
reg [1:0] ctrl_S = S_R;
reg [7:0] data = 0;

always @(*) begin
    get = 1;
    put = ctrl_S == S_T;
    tx_data = data;
end

always @(posedge clk) begin
    case (ctrl_S)
        // S_RESET: begin
        //     if (rst_cnt > 12000000) begin
        //         ctrl_S <= S_R;
        //     end
        //     else begin
        //         ctrl_S <= S_RESET;
        //     end
        // end
        S_R: begin
            if (get && ~rx_empty) begin
                data <= rx_data;
                ctrl_S <= S_T;
            end
        end
        S_T: begin
            ctrl_S <= S_R;
        end
        default: begin
            data <= 0;
            ctrl_S <= S_R;
        end
    endcase
end

endmodule
