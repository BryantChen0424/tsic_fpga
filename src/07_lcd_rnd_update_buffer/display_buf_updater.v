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
    update_x,
    update_y,
    done,
    done_color,

    addr,
    din,
    dout,
    we,

    rnd,
    rx_ready,
    rx_data
);

localparam SRC_BASE = X_MAX * Y_MAX;

function integer log2(input integer v); begin
	log2 = 0;
	while(v >> log2) log2 = log2 + 1;
end endfunction

input clk;
input rst_n;

input update;
input [log2(X_MAX-1):0] update_x;
input [log2(Y_MAX-1):0] update_y;
output reg done = 0;
output reg [15:0] done_color;

output reg [log2(LEN-1):0] addr;
output reg [WIDTH-1:0] din;
input [WIDTH-1:0] dout;
output reg we = 0;

input [RND_WIDTH-1:0] rnd;
input rx_ready;
input [7:0] rx_data;

reg [15:0] digits_sel;
reg [2:0] Suop = 0;
reg [log2(X_MAX-1):0] ux;
reg [log2(Y_MAX-1):0] uy;
reg [WIDTH-1:0] pix_temp;

// localparam CNT_BITS = 28;
// reg [CNT_BITS-1:0] cnt = 0;
// localparam INC = (1 << (CNT_BITS - 1)) / 12000000;

always @(posedge clk) begin
    // cnt <= cnt[CNT_BITS-1] ? 0 : cnt + INC;
    if (~rst_n) begin
        Suop <= 0;
    end
    else begin
        case (Suop)
            0: begin
                we <= 0;
                done <= 0;
                uy <= update_y;
                ux <= update_x;
                if (update) begin
                    Suop <= 1;
                end
            end
            1: begin
                addr <= uy[6:3] * 20 + ux[7:3] + digits_sel * 200 + SRC_BASE;
                // addr <= uy * 160 + ux;
                Suop <= Suop + 1;
            end
            2: begin
                Suop <= Suop + 1;
            end
            3: begin
                pix_temp <= dout;
                Suop <= Suop + 1;
            end
            4: begin
                addr <= uy * 160 + ux;
                din <= pix_temp;
                we <= 0;
                done <= 1;
                done_color <= {
                    {pix_temp, 1'b0},
                    {pix_temp, 2'b0},
                    {pix_temp, 1'b0}
                };
                Suop <= 0;
            end
        endcase
    end
    if (rx_ready/* || cnt[CNT_BITS-1]*/) begin
        digits_sel <= (rnd * 10) >> 8;
    end
end

endmodule