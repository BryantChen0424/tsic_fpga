module uart_msg_core #(
    parameter WIDTH = 8,
    parameter LEN = 256,
    parameter MSG_START = 0
) (
    clk,
    rst,

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

input cmd_valid = 1;
input [log2(LEN-1):0] cmd_len;
output reg msg_valid = 0;
output reg [log2(LEN-1):0] msg_len = 0;

output reg [log2(LEN-1):0] addr = 0;
output reg [WIDTH-1:0] din = 0;
input [WIDTH-1:0] dout;
output reg we = 0;

localparam S_IDLE = 0;
localparam S_WRITING = 1;

reg S;

reg [log2(LEN-1):0] r_len = 0;
reg [log2(LEN-1):0] w_len = 0;

localparam SS_reset          = 0;
localparam SS_print_range    = 1;
localparam SS_read_guess     = 2;
localparam SS_guess_validity = 3;
localparam SS_update_range   = 4;

reg [3:0] SS = SS_reset;

reg [3:0] ans[1:0]; // 2 dec digits
reg [3:0] guess[1:0]; // 2 dec digits
reg [3:0] upper[1:0]; // 2 dec digits
reg [3:0] lower[1:0]; // 2 dec digits

always @(posedge clk) begin
    if (rst) begin
        S <= S_IDLE;
        SS <= SS_reset;
    end
    else begin
        case (S)
            S_IDLE: begin
                if (cmd_valid) begin
                    S <= S_WRITING;
                end
                r_len <= cmd_len;
                w_len <= 0;
            end
            S_WRITING: begin
                case (SS)
                    SS_reset: begin
                        lower[1] <= 0;
                        lower[0] <= 0;
                        upper[1] <= 9;
                        upper[0] <= 9;
                        SS <= SS_print_range;
                        w_len <= 0;
                    end
                    SS_print_range: begin
                        if (msg_valid) begin
                            SS <= SS_reset;
                            S <= S_IDLE;
                        end
                        else if (w_len == 7) begin
                            addr <= 0;
                            we <= 0;
                            msg_valid <= 1;
                            msg_len <= w_len;
                        end
                        else begin
                            w_len <= w_len + 1;
                            addr <= w_len;
                            we <= 1;
                            case (w_len)
                                'd0 : din <= lower[1] ? lower[1] + 48 : " ";
                                'd1 : din <= lower[0] + 48;
                                'd2 : din <= "~";
                                'd3 : din <= upper[1] ? upper[1] + 48 : " ";
                                'd4 : din <= upper[0] + 48;
                                'd5 : din <= "\n";
                                'd6 : din <= "\r";
                                default: din <= 0;
                            endcase
                        end
                    end
                    default: begin
                        
                    end
                endcase
            end
            default: begin
                
            end
        endcase
    end
end

endmodule