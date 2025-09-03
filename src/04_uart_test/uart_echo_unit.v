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

module uart_echo_unit #(
    parameter clk_freq = 12_000_000, // 12MHz
    parameter baud = 115200,
    parameter rbuf_size = 4
)(
	input  clk,
	
    input [7:0] rx_data,
    input rx_ready,

    output reg tx_start = 0,
    output reg [7:0] tx_data = 0,
    input tx_busy,

    input en,
    output reg idle
);

function integer log2(input integer v); begin
	log2 = 0;
	while(v >> log2) log2 = log2 + 1;
end endfunction

/* local parameters */

reg get;
reg [7:0] rbuf_data;
reg rx_empty;
////////////////////////////////////////////

localparam RBUF_ADDR_WIDTH = log2(rbuf_size-1);

reg [7:0] rbuf [0:rbuf_size-1];

reg [RBUF_ADDR_WIDTH:0] _b = 0;
reg [RBUF_ADDR_WIDTH:0] _e = 0;

always @(*) begin
    rx_empty = _b == _e;
    rbuf_data = rbuf[_b];
end

integer i;

always @(posedge clk) begin
    if (!rx_empty && get) begin
        _b <= _b + 1;
    end
    else begin
        _b <= _b;
    end

    for (i = 0; i < rbuf_size; i = i + 1) begin
        rbuf[_e] <= rbuf[_e];
    end
    if (rx_ready) begin
        rbuf[_e] <= rx_data;
    end

    if (rx_ready) begin
        _e <= _e + 1;
    end
    else begin
        _e <= _e;
    end
end

/////////////////////////////////////////

localparam
    S_RST       = 0,
    S_IDLE      = 1,
    S_R         = 2,
    S_T_slash_n = 3,
    S_T_prompt1 = 4,
    S_T_prompt2 = 5,
    S_T_back1   = 6,
    S_T_back2   = 7,
    S_T_last    = 8;

// ctrl signals
reg [3:0] ctrl_S = S_R;
reg [7:0] line_len = 0;

always @(*) begin
    get = (ctrl_S == S_R) && en;
end

always @(posedge clk) begin
    if (en) begin
        case (ctrl_S)
            // S_IDLE: begin
            //     tx_start <= 0;
            //     if (get_a_cmd) begin
            //         ctrl_S <= S_R;
            //     end
            // end
            S_R: begin
                if (tx_start) begin
                    tx_start <= 0;
                end
                else if (~tx_busy && ~rx_empty) begin
                    // processing special cases
                    if (rbuf_data == "\n" || rbuf_data == "\r") begin
                        tx_start <= 1;
                        tx_data <= "\n";
                        line_len <= 0;
                        ctrl_S <= S_T_slash_n;
                    end
                    else if (rbuf_data == 8'h08) begin
                        if (line_len > 0) begin
                            tx_start <= 1;
                            tx_data <= 8'h08;
                            line_len <= line_len - 1;
                            ctrl_S <= S_T_back1;
                        end
                        else begin
                            ctrl_S <= S_R;
                        end
                    end
                    else if (rbuf_data == 8'h1B) begin // ignore esc
                        ctrl_S <= S_R;
                    end
                    else begin
                        tx_start <= 1;
                        tx_data <= rbuf_data;
                        line_len <= line_len + 1;
                        ctrl_S <= S_T_last;
                    end
                end
            end
            S_T_slash_n: begin
                if (tx_start) begin
                    tx_start <= 0;
                end
                else if (~tx_busy) begin
                    tx_start <= 1;
                    tx_data <= "\r";
                    ctrl_S <= S_R;
                end
            end
            S_T_back1: begin
                if (tx_start) begin
                    tx_start <= 0;
                end
                else if (~tx_busy) begin
                    tx_start <= 1;
                    tx_data <= " ";
                    ctrl_S <= S_T_back2;
                end
            end
            S_T_back2: begin
                if (tx_start) begin
                    tx_start <= 0;
                end
                else if (~tx_busy) begin
                    tx_start <= 1;
                    tx_data <= 8'h08;
                    ctrl_S <= S_T_last;
                end
            end
            S_T_last: begin
                if (tx_start) begin
                    tx_start <= 0;
                end
                else if (~tx_busy) begin
                    ctrl_S <= S_R;
                end
            end
            default: begin
                tx_data <= 0;
                ctrl_S <= S_R;
            end
        endcase
    end
end

always @(*) begin
    idle = rx_empty && ctrl_S == S_R;
end

endmodule
