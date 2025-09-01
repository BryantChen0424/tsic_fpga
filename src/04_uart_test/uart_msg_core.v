module uart_msg_core #(
    parameter WIDTH = 8,
    parameter LEN = 256
) (
    clk,

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

input cmd_valid = 1;
input [log2(LEN-1):0] cmd_len;
output reg msg_valid;
output reg [log2(LEN-1):0] msg_len;

output reg [log2(LEN-1):0] addr;
output reg [WIDTH-1:0] din;
input [WIDTH-1:0] dout;
output reg we;

localparam S_IDLE = 0;
localparam S_WRITING = 1;

reg [3:0] S = S_IDLE;

reg [log2(LEN-1):0] r_len = 0;
reg [log2(LEN-1):0] w_len = 0;

always @(posedge clk) begin
    case (S)
        S_IDLE: begin
            if (cmd_valid) begin
                r_len <= cmd_len;
                S <= S_WRITING;
            end
            w_len <= 0;
        end
        S_WRITING: begin
            if (msg_valid) begin
                msg_valid <= 0;
                S <= S_IDLE;
            end
            else if (w_len == r_len + 2) begin
                addr <= 0;
                din <= 0;
                we <= 0;

                msg_valid <= 1;
                msg_len <= w_len;
            end
            else if (w_len == r_len + 1) begin
                addr <= w_len;
                din <= "\r";
                we <= 1;

                w_len <= w_len + 1;
            end
            else if (w_len == r_len) begin
                addr <= w_len;
                din <= "\n";
                we <= 1;

                w_len <= w_len + 1;
            end
            else begin
                addr <= w_len;
                din <= w_len + 64;
                we <= 1;

                w_len <= w_len + 1;
            end
        end
        default: begin
            
        end
    endcase
end

endmodule