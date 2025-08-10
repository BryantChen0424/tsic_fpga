`include "bram.v"
`include "uart_terminal_handler.v"

module game_top (
	input clk,
	input RX,
    output TX,
	output LED
);

function integer log2(input integer v); begin
	log2 = 0;
	while(v >> log2) log2 = log2 + 1;
end endfunction


wire u_w_ready;
reg u_w_valid;
reg [7:0] u_w_data;
reg [7:0] u_w_addr;
reg u_w_last;

wire u_r_ready;
reg u_r_valid;
wire [7:0] u_r_data;
reg  [7:0] u_r_addr;
wire u_r_last;

uart_terminal_handler uer (
    .clk(clk),
    .RX(RX),
    .TX(TX),

    .w_ready(u_w_ready),
    .w_valid(u_w_valid),
    .w_data(u_w_data),
    .w_addr(u_w_addr),
    .w_last(u_w_last),
    
    .r_ready(u_r_ready),
    .r_valid(u_r_valid),
    .r_data(u_r_data),
    .r_addr(u_r_addr),
    .r_last(u_r_last)
);

localparam EOF = 8'hFF;

localparam S_WAIT_DEV_RST = 0;
localparam S_W_NEW_GAME  = 1;
localparam S_R_CODE      = 2;
localparam S_W_RANGE     = 4;
localparam S_R_GUESS     = 5;
localparam S_W_HIT_RENEW = 6;

reg [3:0] S = S_WAIT_DEV_RST;
reg [log2(LEN-1)-1:0] wr_cnt;
reg [3:0] code [0:1] = {0, 0};
reg [3:0] guess [0:1] = {0, 0};
reg guess_legal;
reg [7:0] lower [0:1] = {" ", "0"};
reg [7:0] upper [0:1] = {"9", "9"};
reg lower_update;
reg upper_update;
reg hit;

reg u_wfire;
reg u_rfire;
reg u_rdata_resp;

always @(*) begin
    u_wfire = u_w_ready & u_w_valid;
    u_rfire = u_r_ready & u_r_valid;
    guess_legal = guess[1] > 47 && guess[1] < 58 && guess[0] > 47 && guess[0] < 58;
    lower_update = {guess[1], guess[0]} < {lower[1], lower[0]};
    upper_update = {guess[1], guess[0]} > {upper[1], upper[0]};
    hit = {guess[1], guess[0]} == {upper[1], upper[0]};
end

always @(posedge clk) begin
    u_rdata_resp <= u_rfire;
    case (S)
        S_WAIT_DEV_RST: begin
            if (uer_out_ready) begin
                wr_cnt <= 0;
                S <= S_W_NEW_GAME;
            end
        end
        S_W_NEW_GAME: begin
            if (u_w_last) begin
                wr_cnt <= 0;
                S <= S_R_CODE;
            end
            else begin
                wr_cnt <= wr_cnt + 1;
            end
        end
        S_R_CODE: begin
            if (u_rdata_resp) begin
                if (u_r_data == EOF) begin
                    S <= guess_legal ? S_W_RANGE : S_W_NEW_GAME;
                    {code[1], code[0]} <= {guess[1], guess[0]};
                end
                else begin
                    guess[1] <= guess[0];
                    guess[0] <= u_r_data;
                end
            end
            if (u_rfire) begin
                wr_cnt <= wr_cnt + 1;
            end
            if (u_r_last) begin
                wr_cnt <= 0;
            end
        end
        S_W_RANGE: begin
            if (u_w_last) begin
                wr_cnt <= 0;
                S <= S_R_GUESS;
            end
            else begin
                wr_cnt <= wr_cnt + 1;
            end
        end
        S_R_GUESS: begin
            if (u_rdata_resp) begin
                if (u_r_data == EOF) begin
                    if (guess_legal) begin
                        if (lower_update) begin
                            {lower[1], lower[0]} <= {guess[1], guess[2]};
                            S <= S_W_RANGE;
                        end
                        if (upper_update) begin
                            {upper[1], upper[0]} <= {guess[1], guess[2]};
                            S <= S_W_RANGE;
                        end
                        if (hit) begin
                            S <= S_W_HIT_RENEW;
                        end
                    end
                    else begin
                        S <= S_W_RANGE;
                    end
                end
                else begin
                    guess[1] <= guess[0];
                    guess[0] <= u_r_data;
                end
            end
            if (u_rfire) begin
                wr_cnt <= wr_cnt + 1;
            end
            if (u_r_last) begin
                wr_cnt <= 0;
            end
        end
        S_W_HIT_RENEW: begin
            if (u_w_last) begin
                wr_cnt <= 0;
                S <= S_W_NEW_GAME;
            end
            else begin
                wr_cnt <= wr_cnt + 1;
            end
        end
        default: 
    endcase
end

always @(*) begin
    case (S)
        S_W_NEW_GAME: begin
            u_w_addr = {1'b1, wr_cnt};
            case (wr_cnt)
                0 : u_w_data = "E";
                1 : u_w_data = "n";
                2 : u_w_data = "t";
                3 : u_w_data = "e";
                4 : u_w_data = "r";
                5 : u_w_data = " ";
                6 : u_w_data = "a";
                7 : u_w_data = " ";
                8 : u_w_data = "c";
                9 : u_w_data = "o";
                10: u_w_data = "d";
                11: u_w_data = "e";
                12: u_w_data = EOF;
                default: u_w_data = EOF;
            endcase
            u_w_valid = 1;
            u_w_last = wr_cnt == 12;
        end
        S_W_RANGE: begin
            u_w_addr = {1'b1, wr_cnt};
            case (wr_cnt)
                0 : u_w_data = "R";
                1 : u_w_data = "a";
                2 : u_w_data = "n";
                3 : u_w_data = "g";
                4 : u_w_data = "e";
                5 : u_w_data = ":";
                6 : u_w_data = " ";
                7 : u_w_data = lower[1];
                8 : u_w_data = lower[0];
                9 : u_w_data = "~";
                10: u_w_data = upper[1];
                11: u_w_data = upper[0];
                12: u_w_data = EOF;
                default: u_w_data = EOF;
            endcase
            u_w_valid = 1;
            u_w_last = wr_cnt == 12;
        end
        S_W_HIT_RENEW: begin
            u_w_addr = {1'b1, wr_cnt};
            case (wr_cnt)
                0 : u_w_data = "C";
                1 : u_w_data = "r";
                2 : u_w_data = "a";
                3 : u_w_data = "c";
                4 : u_w_data = "k";
                5 : u_w_data = "e";
                6 : u_w_data = "d";
                7 : u_w_data = ":";
                8 : u_w_data = " ";
                9 : u_w_data = guess[1];
                10: u_w_data = guess[0];
                11: u_w_data = "!";
                12: u_w_data = EOF;
                default: u_w_data = EOF;
            endcase
            u_w_valid = 1;
            u_w_last = wr_cnt == 12;
        end
        default: 
    endcase
    case (S)
        S_R_CODE: begin
            u_r_addr = wr_cnt;
            u_r_valid = 1;
        end
        default: 
    endcase
end
    
endmodule