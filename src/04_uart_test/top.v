module top (
	input  clk,
	input RX,
    output reg TX
);

localparam MSG_START = 1;

function integer log2(input integer v); begin
	log2 = 0;
	while(v >> log2) log2 = log2 + 1;
end endfunction

localparam WIDTH = 8;
localparam LEN = 256;
localparam TXSTR_BASE = LEN/2;

localparam RST_CNT_MSB = 7;

reg [RST_CNT_MSB:0] rst_cnt;
reg rst;
reg rst_flag;

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
wire [log2(LEN-1):0] cmd_len;
wire msg_valid;
wire [log2(LEN-1):0] msg_len;

wire [log2(LEN-1):0] uch_addr;
wire [WIDTH-1:0] uch_din;
reg [WIDTH-1:0] uch_dout;
wire uch_we;

uart_cmd_handler #(
    .WIDTH(WIDTH),
    .LEN(LEN),
    .TXSTR_BASE(TXSTR_BASE),
    .MSG_START(MSG_START)
) uch (
    .clk(clk),
    .rst(rst),

    .RX(RX),
    .TX(TX),

    .cmd_valid(cmd_valid),
    .cmd_len(cmd_len),
    .msg_valid(msg_valid),
    .msg_len(msg_len),

    .addr(uch_addr),
    .din(uch_din),
    .dout(uch_dout),
    .we(uch_we)
);

wire [log2(LEN-1):0] umc_addr;
wire [WIDTH-1:0] umc_din;
reg [WIDTH-1:0] umc_dout;
wire umc_we;

uart_msg_core #(
    .WIDTH(WIDTH),
    .LEN(LEN - TXSTR_BASE),
    .MSG_START(MSG_START)
) umc (
    .clk(clk),
    .rst(rst),

    .cmd_valid(cmd_valid),
    .cmd_len(cmd_len),
    .msg_valid(msg_valid),
    .msg_len(msg_len),

    .addr(umc_addr),
    .din(umc_din),
    .dout(umc_dout),
    .we(umc_we)
);

localparam S_CMD = 0;
localparam S_MSG = 1;

reg S = S_CMD;

always @(*) begin
    uch_dout = dout;
    umc_dout = dout;
    case (S)
        S_CMD: begin
            addr = uch_addr;
            din = uch_din;
            we = uch_we;
        end
        S_MSG: begin
            addr = umc_addr + TXSTR_BASE;
            din = umc_din;
            we = umc_we;
        end
        default: begin
            addr = 0;
            din = 0;
            we = 0;
        end
    endcase
end

always @(posedge clk) begin
    rst_cnt <= rst_cnt + 1;
    rst <= rst_cnt[RST_CNT_MSB] & (~rst_flag);
    rst_flag <= rst_cnt[RST_CNT_MSB] | rst_flag;
    if (rst) begin
        S <= MSG_START ? S_MSG : S_CMD;
    end
    else begin
        case (S)
            S_CMD: begin
                if (cmd_valid) begin
                    S <= S_MSG;
                end
            end
            S_MSG: begin
                if (msg_valid) begin
                    S <= S_CMD;
                end
            end
            default: begin
                
            end
        endcase
    end
end

endmodule