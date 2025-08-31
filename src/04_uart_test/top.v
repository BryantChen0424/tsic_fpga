module top (
	input  clk,
	input RX,
    output reg TX
);

function integer log2(input integer v); begin
	log2 = 0;
	while(v >> log2) log2 = log2 + 1;
end endfunction

localparam WIDTH = 8;
localparam LEN = 256;
localparam TXSTR_BASE = LEN/2;

reg [log2(LEN-1):0] addr;
reg [WIDTH-1:0] din;
wire [WIDTH-1:0] dout;
reg we;

bram #(WIDTH, LEN) mem (
    .clk(clk),
    .addr(addr),
    .din(din),
    .dout(dout),
    .we(we)
);

wire cmd_valid;
reg msg_valid = 0;
reg [log2(LEN-1):0] msg_len = 0;

wire [log2(LEN-1):0] uch_addr;
wire [WIDTH-1:0] uch_din;
reg [WIDTH-1:0] uch_dout;
wire uch_we;

uart_cmd_handler #(
    .WIDTH(WIDTH),
    .LEN(LEN),
    .TXSTR_BASE(TXSTR_BASE)
) uch (
    .clk(clk),

    .RX(RX),
    .TX(TX),

    .cmd_valid(cmd_valid),
    .msg_valid(msg_valid),
    .msg_len(msg_len),

    .addr(uch_addr),
    .din(uch_din),
    .dout(uch_dout),
    .we(uch_we)
);

reg [log2(LEN-1):0] w_addr = 0;
reg [WIDTH-1:0] w_din = 0;
wire [WIDTH-1:0] w_dout;
reg w_we = 0;

localparam S_IDLE = 0;
localparam S_WRITING = 1;

reg [3:0] S = S_IDLE;

always @(*) begin
    uch_dout = dout;
    w_dout = dout;
    case (S)
        S_IDLE: begin
            addr = uch_addr;
            din = uch_din;
            we = uch_we;
        end
        S_WRITING: begin
            addr = w_addr;
            din = w_din;
            we = w_we;
        end
        default: begin
            addr = 0;
            din = 0;
            we = 0;
        end
    endcase
end

reg [7:0] tx_line_len = 0;

// always @(*) begin
//     msg_valid = 1;
//     msg_len = 2;
// end

always @(posedge clk) begin
    case (S)
        S_IDLE: begin
            if (cmd_valid) begin
                S <= S_WRITING;
            end
            tx_line_len <= 0;
        end
        S_WRITING: begin
            if (msg_valid) begin
                msg_valid <= 0;
                S <= S_IDLE;
            end
            else if (tx_line_len == 30) begin
                w_addr <= TXSTR_BASE;
                w_din <= 0;
                w_we <= 0;

                msg_valid <= 1;
                msg_len <= tx_line_len;
            end
            else if (tx_line_len == 29) begin
                w_addr <= tx_line_len + TXSTR_BASE;
                w_din <= "\r";
                w_we <= 1;

                tx_line_len <= tx_line_len + 1;
            end
            else if (tx_line_len == 28) begin
                w_addr <= tx_line_len + TXSTR_BASE;
                w_din <= "\n";
                w_we <= 1;

                tx_line_len <= tx_line_len + 1;
            end
            else begin
                w_addr <= tx_line_len + TXSTR_BASE;
                w_din <= tx_line_len + 64;
                w_we <= 1;

                tx_line_len <= tx_line_len + 1;
            end
        end
        default: begin
            
        end
    endcase
end

endmodule