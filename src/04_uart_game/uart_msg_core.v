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

    rw_mode,

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

input cmd_valid;
input [log2(LEN-1):0] cmd_len;
output reg msg_valid = 0;
output reg [log2(LEN-1):0] msg_len = 0;

output reg rw_mode;

output reg [log2(LEN-1):0] addr = 0;
output reg [WIDTH-1:0] din = 0;
input [WIDTH-1:0] dout;
output reg we = 0;

localparam S_IDLE = 0;
localparam S_WRITING = 1;

reg S;

// reg [log2(LEN-1):0] r_len = 0;
// reg [log2(LEN-1):0] w_len = 0;

reg [log2(LEN-1):0] r_len = 0;
reg [log2(LEN-1):0] w_len = 0;

localparam SS_reset              = 1;
localparam SS_print_range        = 2;
localparam SS_read_guess_len     = 3;
localparam SS_read_guess         = 4;
localparam SS_update_range       = 5;

reg [3:0] SS = SS_reset;

reg [3:0] ans[1:0]; // 2 dec digits
reg [3:0] guess[1:0]; // 2 dec digits
reg [3:0] upper[1:0]; // 2 dec digits
reg [3:0] lower[1:0]; // 2 dec digits

reg [7:0] ans_concat;
reg [7:0] guess_concat;
reg [7:0] upper_concat;
reg [7:0] lower_concat;

reg read_flag = 0;
reg read_idx = 1;

reg ans_gen_flag = 0;

reg [7:0] info_str[0:7];

always @(*) begin
    if (SS == SS_print_range) begin
        rw_mode = 1;
    end
    else begin
        rw_mode = 0;
    end

    ans_concat   = {  ans[1],   ans[0]};
    guess_concat = {guess[1], guess[0]};
    upper_concat = {upper[1], upper[0]};
    lower_concat = {lower[1], lower[0]};
end

always @(posedge clk) begin
    if (rst) begin
        ans[1] <= 0;
        ans[0] <= 0;
        ans_gen_flag <= 0;
        S <= S_IDLE;
        SS <= SS_reset;
    end
    else begin
        if (ans_gen_flag) begin
            ans[1] <= ans[0] == 9 ? (ans[1] == 9 ? 0 : ans[1] + 1) : ans[1];
            ans[0] <= ans[0] == 9 ? 0 : ans[0] + 1;
        end
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
                        info_str[0] <= "n";
                        info_str[1] <= "e";
                        info_str[2] <= "w";
                        info_str[3] <= " ";
                        info_str[4] <= "g";
                        info_str[5] <= "a";
                        info_str[6] <= "m";
                        info_str[7] <= "e";

                        lower[1] <= 0;
                        lower[0] <= 0;
                        upper[1] <= 9;
                        upper[0] <= 9;
                        
                        SS <= SS_print_range;
                        w_len <= 0;

                        ans_gen_flag <= 1;
                    end
                    SS_print_range: begin
                        if (msg_valid) begin
                            msg_valid <= 0;
                            SS <= SS_read_guess_len;
                            S <= S_IDLE;
                        end
                        else if (w_len == 16) begin
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
                                'd0 : din <= info_str[0];
                                'd1 : din <= info_str[1];
                                'd2 : din <= info_str[2];
                                'd3 : din <= info_str[3];
                                'd4 : din <= info_str[4];
                                'd5 : din <= info_str[5];
                                'd6 : din <= info_str[6];
                                'd7 : din <= info_str[7];
                                'd8 : din <= " ";
                                'd9 : din <= lower[1] ? lower[1] + 48 : " ";
                                'd10: din <= lower[0] + 48;
                                'd11: din <= "~";
                                'd12: din <= upper[1] ? upper[1] + 48 : " ";
                                'd13: din <= upper[0] + 48;
                                'd14: din <= "\n";
                                'd15: din <= "\r";
                                default: din <= 0;
                            endcase
                        end
                    end
                    SS_read_guess_len: begin
                        ans_gen_flag <= 0;
                        read_flag <= 0;
                        addr <= 0;
                        if (r_len == 2 || r_len == 1) begin
                            SS <= SS_read_guess;
                        end
                        else begin
                            info_str[0] <= "i";
                            info_str[1] <= "l";
                            info_str[2] <= "l";
                            info_str[3] <= "e";
                            info_str[4] <= "g";
                            info_str[5] <= "a";
                            info_str[6] <= "l";
                            info_str[7] <= " ";
                            SS <= SS_print_range;
                        end
                    end
                    SS_read_guess: begin
                        if (~read_flag) begin
                            addr <= 1;
                            read_flag <= 1;
                            if (r_len == 1) begin
                                guess[1] <= 0;
                                read_idx <= 0;
                            end
                            else begin
                                read_idx <= 1;
                            end
                        end
                        else begin
                            if (dout < 48 || dout > 57) begin
                                info_str[0] <= "i";
                                info_str[1] <= "l";
                                info_str[2] <= "l";
                                info_str[3] <= "e";
                                info_str[4] <= "g";
                                info_str[5] <= "a";
                                info_str[6] <= "l";
                                info_str[7] <= " ";
                                SS <= SS_print_range;
                            end
                            else begin
                                if (read_idx == 1) begin
                                    guess[1] <= dout[3:0];
                                    read_idx <= 0;
                                end
                                else begin
                                    guess[0] <= dout[3:0];
                                    SS <= SS_update_range;
                                end
                            end
                            
                        end
                    end
                    SS_update_range: begin
                        if (guess_concat > ans_concat) begin
                            if (guess_concat < upper_concat) begin
                                info_str[0] <= "r";
                                info_str[1] <= "a";
                                info_str[2] <= "n";
                                info_str[3] <= "g";
                                info_str[4] <= "e";
                                info_str[5] <= " ";
                                info_str[6] <= " ";
                                info_str[7] <= " ";
                                upper[1] <= guess[1];
                                upper[0] <= guess[0];
                            end
                            else begin
                                info_str[0] <= "i";
                                info_str[1] <= "l";
                                info_str[2] <= "l";
                                info_str[3] <= "e";
                                info_str[4] <= "g";
                                info_str[5] <= "a";
                                info_str[6] <= "l";
                                info_str[7] <= " ";
                            end
                            SS <= SS_print_range;
                        end
                        else if (guess_concat < ans_concat) begin
                            if (guess_concat > lower_concat) begin
                                info_str[0] <= "r";
                                info_str[1] <= "a";
                                info_str[2] <= "n";
                                info_str[3] <= "g";
                                info_str[4] <= "e";
                                info_str[5] <= " ";
                                info_str[6] <= " ";
                                info_str[7] <= " ";
                                lower[1] <= guess[1];
                                lower[0] <= guess[0];
                            end
                            else begin
                                info_str[0] <= "i";
                                info_str[1] <= "l";
                                info_str[2] <= "l";
                                info_str[3] <= "e";
                                info_str[4] <= "g";
                                info_str[5] <= "a";
                                info_str[6] <= "l";
                                info_str[7] <= " ";
                            end
                            SS <= SS_print_range;
                        end
                        else begin
                            SS <= SS_reset;
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