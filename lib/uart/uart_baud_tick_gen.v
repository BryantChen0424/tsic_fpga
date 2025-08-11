/*
 *  icebreaker examples - Async uart baud tick generator module
 *
 *  Copyright (C) 2018 Piotr Esden-Tempski <piotr@esden.net>
 *
 *  Modified work
 *  Copyright (C) 2025 Bryant Chen <bryant90424@gmail.com>
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

/***
 * This module generates a bit baud tick multiplied by the oversampling parameter.
 */
module baud_tick_gen #(
	parameter clk_freq     = 12000000,
	parameter baud         = 115200,
	parameter oversampling = 1
) (
	input clk,
	input enable,
	output reg tick
);

function integer log2(input integer v); begin
	log2=0;
	while(v >> log2)
		log2 = log2 + 1; 
end endfunction

localparam acc_width = log2(clk_freq / baud) + 8;
localparam shiftlimiter = log2((baud * oversampling) >> (31 - acc_width));
localparam inc = ((baud * oversampling << (acc_width - shiftlimiter)) + (clk_freq >> (shiftlimiter + 1))) / (clk_freq >> shiftlimiter);

// To find the inc that makes acc overflow at the freq of (baud * oversampling)

reg [acc_width:0] acc = 0;

always @(*) begin
	tick = acc[acc_width];
end

always @(posedge clk) begin
				// This will garantee that acc will wrap to zero just after its overflow
				//   |
	if (enable) //   V
		acc <= acc[acc_width-1:0] + inc[acc_width:0];
	else
		acc <= inc[acc_width:0];
end

endmodule

