module display_buf_updater #(
    parameter LEN = 12800,
    parameter WIDTH = 8,
    parameter X_MAX = 160,
    parameter Y_MAX = 80,
    parameter RND_WIDTH = 8
) (
    clk,
    rst_n,

    update,
    done,

    addr,
    din,
    dout,
    we,

    rnd
);

localparam SRC_BASE = X_MAX * Y_MAX;

function integer log2(input integer v); begin
	log2 = 0;
	while(v >> log2) log2 = log2 + 1;
end endfunction

input clk;
input rst_n;

input update;
output reg done = 0;

output reg [log2(LEN-1):0] addr;
output reg [WIDTH-1:0] din;
input [WIDTH-1:0] dout;
output reg we = 0;

input [RND_WIDTH-1:0] rnd;

reg [15:0] digits_sel;
reg [2:0] Suop = 0;
reg [7:0] ux;
reg [6:0] uy;
reg [WIDTH-1:0] pix_temp;

always @(posedge clk) begin
    if (~rst_n) begin
        Suop <= 0;
    end
    else if (update) begin
        uy <= 0;
        ux <= 0;
        Suop <= 0;
        digits_sel <= (rnd * 10) >> 8;
    end
    else begin
        done <= 0;
        case (Suop)
            0: begin
                if (uy == Y_MAX) begin
                    uy <= 0;
                    ux <= 0;
                    done <= 1;
                end
                else begin
                    addr <= uy[6:3] * 20 + ux[7:3] + digits_sel * 200 + SRC_BASE;
                    we <= 0;
                    Suop <= Suop + 1;
                end
            end
            1: begin
                Suop <= Suop + 1;
            end
            2: begin
                pix_temp <= dout;
                Suop <= Suop + 1;
            end
            3: begin
                addr <= uy * 160 + ux;
                din <= pix_temp;
                we <= 1;
                ux <= (ux == X_MAX - 1) ? 0 : ux + 1;
                uy <= (ux == X_MAX - 1) ? uy + 1: uy;
                Suop <= 0;
            end
        endcase
    end
end

endmodule