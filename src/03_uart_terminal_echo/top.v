/*
 *  icebreaker examples - Async uart mirror using pll
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

reg put = 0;
reg [7:0] tx_data = 0;
wire tx_empty;
uart_tx_buf #(clk_freq, baud) txb (
	.clk(clk),
	.TX(TX),
    .put(put),
    .data(tx_data),
    .empty(tx_empty)
);

localparam 
    S_RST       = 4'b0000,
    S_R         = 4'b0001,
    S_T_slash_n = 4'b1001,
    S_T_prompt1 = 4'b1010,
    S_T_prompt2 = 4'b1011,
    S_T_back1   = 4'b1100,
    S_T_back2   = 4'b1101,
    S_T_last    = 4'b1000;



// ctrl signals
reg [3:0] ctrl_S = S_RST;
reg [15:0] rst_cnt = 0;
reg [7:0] line_len = 0;

always @(*) begin
    get = ctrl_S == S_R;
end

always @(posedge clk) begin
    rst_cnt <= rst_cnt + 1;
    case (ctrl_S)
        S_RST: begin
            if (rst_cnt[15]) begin
                put <= 1;
                tx_data <= "$";
                ctrl_S <= S_T_prompt2;
            end
        end
        S_R: begin
            if (~rx_empty) begin
                // processing special cases
                if (rx_data == "\n" || rx_data == "\r") begin
                    tx_data <= "\n";
                    line_len <= 0;
                    ctrl_S <= S_T_slash_n;
                    put <= 1;
                end
                else if (rx_data == 8'h08) begin
                    if (line_len > 0) begin
                        tx_data <= 8'h08;
                        line_len <= line_len - 1;
                        ctrl_S <= S_T_back1;
                        put <= 1;
                    end
                    else begin
                        ctrl_S <= S_R;
                        put <= 0;
                    end
                end
                else if (rx_data == 8'h1B) begin // ignore esc
                    ctrl_S <= S_R;
                    put <= 0;
                end
                else begin
                    tx_data <= rx_data;
                    line_len <= line_len + 1;
                    ctrl_S <= S_T_last;
                    put <= 1;
                end
            end
        end
        S_T_slash_n: begin
            tx_data <= "\r";
            ctrl_S <= S_T_prompt1;
        end
        S_T_prompt1: begin
            tx_data <= "$";
            ctrl_S <= S_T_prompt2;
        end
        S_T_prompt2: begin
            tx_data <= " ";
            ctrl_S <= S_T_last;
        end
        S_T_back1: begin
            tx_data <= " ";
            ctrl_S <= S_T_back2;
        end
        S_T_back2: begin
            tx_data <= 8'h08;
            ctrl_S <= S_T_last;
        end
        S_T_last: begin
            if (tx_empty) begin
                tx_data <= 0;
                ctrl_S <= S_R;
            end
            put <= 0;
        end
        default: begin
            tx_data <= 0;
            ctrl_S <= S_R;
        end
    endcase
end

endmodule
