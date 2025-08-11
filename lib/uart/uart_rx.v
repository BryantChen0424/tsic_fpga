/*
 *  icebreaker examples - Async uart rx module
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


module uart_rx #(
	parameter clk_freq = 12000000,
	parameter baud = 115200,
	parameter oversampling = 8
)(
	input clk, // system clock
	input rx, // RX signal
	output reg rx_ready, // catch a whole byte
	output reg [7:0] rx_data, // the byte just be catched
	output reg rx_idle, // high when the packet gap is longer than a bit transimission window
	output reg rx_eop = 0 // asserted for one clock cycle when an end of packet has been detected
);

function integer log2(input integer v); begin
	log2 = 0;
	while(v >> log2) log2 = log2 + 1;
end endfunction

localparam
	IDLE      = 4'b0000,
	BIT_START = 4'b0001,
	BIT0      = 4'b1000,
	BIT1      = 4'b1001,
	BIT2      = 4'b1010,
	BIT3      = 4'b1011,
	BIT4      = 4'b1100,
	BIT5      = 4'b1101,
	BIT6      = 4'b1110,
	BIT7      = 4'b1111,
	BIT_STOP  = 4'b0010;

localparam l2o = log2(oversampling);

reg [3:0] rx_state = IDLE;

reg [l2o-2:0] os_cnt = 0;
reg [l2o+1:0] gap_cnt = 0;

reg [1:0] rx_sync = 2'b11;
reg [1:0] filter_cnt = 2'b11;

reg rx_bit = 1'b1;

reg sample_now;
wire os_tick;

baud_tick_gen #(clk_freq, baud, oversampling) tickgen(.clk(clk), .enable(1'b1), .tick(os_tick));

always @(*) begin
	rx_idle = gap_cnt[l2o+1];
	sample_now = os_tick && (os_cnt == ((oversampling / 2) - 1));
end

always @(posedge clk) begin
	if(os_tick) begin
		// sync rx to the clk domain
		rx_sync <= {rx_sync[0], rx};

		if((rx_sync[1] == 1'b1) && (filter_cnt != 2'b11)) 
			filter_cnt <= filter_cnt + 1'd1;
		if((rx_sync[1] == 1'b0) && (filter_cnt != 2'b00))
			filter_cnt <= filter_cnt - 1'd1;
		
		// filter_cnt acts like a fsm
		if(filter_cnt == 2'b11)
			rx_bit <= 1'b1;
		else if(filter_cnt == 2'b00)
			rx_bit <= 1'b0;

		os_cnt <= (rx_state == IDLE) ? 1'd0 : os_cnt + 1'd1;
	end

	case(rx_state)
		IDLE:      if(~rx_bit) rx_state <= BIT_START;
		BIT_START: if(sample_now) rx_state <= BIT0;
		BIT0:      if(sample_now) rx_state <= BIT1;
		BIT1:      if(sample_now) rx_state <= BIT2;
		BIT2:      if(sample_now) rx_state <= BIT3;
		BIT3:      if(sample_now) rx_state <= BIT4;
		BIT4:      if(sample_now) rx_state <= BIT5;
		BIT5:      if(sample_now) rx_state <= BIT6;
		BIT6:      if(sample_now) rx_state <= BIT7;
		BIT7:      if(sample_now) rx_state <= BIT_STOP;
		BIT_STOP:  if(sample_now) rx_state <= IDLE;
		default:   rx_state <= IDLE;
	endcase

	if(sample_now && rx_state[3]) begin
		rx_data <= {rx_bit, rx_data[7:1]};
	end

	rx_ready <= (sample_now && (rx_state == BIT_STOP) && rx_bit);

	if (rx_state != IDLE) 
		gap_cnt <= 0;
	else if(os_tick & ~gap_cnt[l2o+1])
		gap_cnt <= gap_cnt + 1'd1;

	rx_eop <= os_tick & ~gap_cnt[l2o+1] & &gap_cnt[l2o:0];
end

endmodule

