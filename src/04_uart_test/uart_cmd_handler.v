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

module uart_cmd_handler #(
    parameter WIDTH = 8,
    parameter LEN = 256,
    parameter RXSTR_BASE = 0,
    parameter TXSTR_BASE = 128,
    parameter CLK_FREQ = 12000000,
    parameter BAUD = 115200,
    parameter MSG_START = 0
)(
	clk,
    rst,
	RX,
    TX,

    cmd_valid,
    cmd_len,
    msg_valid,
    msg_len,

    addr,
    din,
    dout,
    we
);

function integer log2(input integer v); begin
	log2 = 0;
	while(v >> log2) log2 = log2 + 1;
end endfunction

input clk;
input rst;

input RX;
output reg TX;

output reg cmd_valid = 1;
output reg [log2(LEN-1):0] cmd_len = 0;
input msg_valid;
input [log2(LEN-1):0] msg_len;

output reg [log2(LEN-1):0] addr;
output reg [WIDTH-1:0] din;
input [WIDTH-1:0] dout;
output reg we;

wire rx_ready;
wire [7:0] rx_data;

uart_rx #(CLK_FREQ, BAUD) urx (
    .clk(clk),
    .rx(RX),
    .rx_ready(rx_ready),
    .rx_data(rx_data)
);

reg tx_start;
reg [7:0] tx_data;
wire tx_busy;

uart_tx #(CLK_FREQ, BAUD) utx (
    .clk(clk),
    .tx_start(tx_start),
    .tx_data(tx_data),
    .tx(TX),
    .tx_busy(tx_busy)
);

reg echo_rx_ready;
reg [7:0] echo_rx_data;

wire echo_tx_start;
wire [7:0] echo_tx_data;
reg echo_tx_busy;

reg echo_en = 0;
wire echo_idle;

uart_echo_unit #(CLK_FREQ, BAUD) ueu (
    .clk(clk),

    .rx_data(echo_rx_data),
    .rx_ready(echo_rx_ready),

    .tx_start(echo_tx_start),
    .tx_data(echo_tx_data),
    .tx_busy(echo_tx_busy),

    .en(echo_en),
    .idle(echo_idle)
);

////////////////

localparam S_rst = 0;
localparam S_prompt = 1;
localparam S_Rp  = 2;
localparam S_R   = 3;
localparam S_Rf  = 4;
localparam S_NL  = 5;
localparam S_T   = 6;

reg [3:0] S = S_rst;

localparam PROMPT_LEN = 2;
reg [8*PROMPT_LEN-1:0] prompt_str = "$ ";
reg [7:0] prompt_head;

reg [log2(LEN-1):0] rx_line_len = 0;
reg [log2(LEN-1):0] tx_line_len = 0;

reg resp_tx_start = 0;
reg [7:0] resp_tx_data = 0;
reg resp_tx_busy;

reg self_tx_start = 0;
reg [7:0] self_tx_data = 0;
reg self_tx_busy;

reg nl2tx_flag = 0;
reg tx_flag = 0;

////////////////

always @(*) begin
    echo_tx_busy = tx_busy;
    resp_tx_busy = tx_busy;
    self_tx_busy = tx_busy;

    echo_rx_data = rx_data;
    echo_rx_ready = rx_ready;

    case (S)
        S_rst: begin
            tx_start = 0;
            tx_data = 0;
        end
        S_prompt: begin
            tx_start = self_tx_start;
            tx_data = self_tx_data;
        end
        S_Rp: begin
            tx_start = 0;
            tx_data = 0;
        end
        S_R: begin
            tx_start = echo_tx_start;
            tx_data = echo_tx_data;
        end
        S_Rf: begin
            tx_start = echo_tx_start;
            tx_data = echo_tx_data;
        end
        S_NL: begin
            tx_start = 0;
            tx_data = 0;
        end
        S_T: begin
            tx_start = resp_tx_start;
            tx_data = resp_tx_data;
        end
        default: begin
            tx_start = 0;
            tx_data = 0;
        end
    endcase

    prompt_head = prompt_str[8*PROMPT_LEN-1:8*(PROMPT_LEN-1)];
end

////////////////

reg [log2(LEN-1):0] str_cnt = 0;

always @(posedge clk) begin
    if (rst) begin
        S <= MSG_START ? S_Rf : S_prompt;
    end
    else begin
        case (S)
            S_prompt: begin
                if (~tx_flag) begin
                    self_tx_start <= 1;
                    self_tx_data <= prompt_head;
                    tx_flag <= 1;

                    str_cnt <= str_cnt + 1;
                    prompt_str <= (prompt_str << 8) | prompt_head;
                end
                else begin
                    if (self_tx_start) begin
                        self_tx_start <= 0;
                        self_tx_data <= 0;
                    end
                    else if (~self_tx_busy) begin
                        tx_flag <= 0;
                        if (str_cnt == PROMPT_LEN) begin
                            str_cnt <= 0;
                            echo_en <= 1;

                            S <= S_Rp;
                        end
                    end
                end
            end
            S_Rp: begin
                S <= S_R;
            end
            S_R: begin
                if (rx_ready) begin
                    if (echo_rx_data == 8'h08) begin
                        rx_line_len <= rx_line_len - 1;
                    end
                    else begin
                        addr <= rx_line_len;
                        din <= echo_rx_data;
                        we <= 1;
                        rx_line_len <= rx_line_len + 1;
                    end
                end
                else begin
                    din <= 0;
                    we <= 0;
                end

                if (din == "\r" || din == "\n") begin
                    S <= S_Rf;
                end
            end
            S_Rf: begin
                cmd_len <= rx_line_len - 1;
                if (echo_idle && ~echo_tx_busy && ~echo_tx_start) begin
                    echo_en <= 0;
                    cmd_valid <= 1;

                    rx_line_len <= 0;
                    S <= S_NL;
                end
            end
            S_NL: begin
                cmd_valid <= 0;
                cmd_len <= 0;
                addr <= TXSTR_BASE;
                tx_line_len <= msg_len;
                nl2tx_flag <= 0;
                tx_flag <= 0;
                if (msg_valid) begin
                    din <= 0;
                    we <= 0;

                    S <= S_T;
                end
            end
            S_T: begin
                if (~nl2tx_flag) begin /// ok
                    nl2tx_flag <= 1;
                    tx_flag <= 0;
                end
                else begin
                    if (~tx_flag) begin
                        addr <= addr + 1;
                        resp_tx_start <= 1;
                        resp_tx_data <= dout;
                        tx_flag <= 1;
                    end
                    else begin
                        if (resp_tx_start) begin
                            resp_tx_start <= 0;
                            resp_tx_data <= 0;
                        end
                        else if (~resp_tx_busy) begin
                            tx_flag <= 0;
                            if (addr == tx_line_len + TXSTR_BASE) begin
                                S <= S_prompt;
                            end
                        end
                    end
                end
                // 
            end
            default: begin
                
            end
        endcase
    end
    
end

endmodule
