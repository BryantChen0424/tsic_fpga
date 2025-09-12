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

reg dino_pose_sel = 0;
reg [2:0] Suop = 0;
reg [log2(X_MAX-1):0] ux;
reg [log2(Y_MAX-1):0] uy;
reg [WIDTH-1:0] pix_temp;

localparam GROUND_Y = 0;
localparam GROUND_H = 20;

localparam DINO_X = 20;
localparam DINO_Y = 20;
localparam DINO_W = 16;
localparam DINO_H = 16;

reg dino_mask;
reg ground_mask;

localparam CNT_BITS = 28;
reg [CNT_BITS-1:0] cnt = 0;
localparam INC = (1 << (CNT_BITS - 1)) / 2400000;

always @(*) begin
    dino_mask = (uy >= DINO_Y && uy < (DINO_Y+DINO_H)) && (ux >= DINO_X && ux < (DINO_X+DINO_W));
    ground_mask = uy < (GROUND_Y+GROUND_H);
end

always @(posedge clk) begin
    cnt <= cnt[CNT_BITS-1] ? 0 : cnt + INC;
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
                if (dino_mask) begin
                    addr <= (uy-DINO_Y) * DINO_W + (ux-DINO_X) + dino_pose_sel * (DINO_W*DINO_H) + SRC_BASE;
                end
                else if (ground_mask) begin
                    addr <= uy * X_MAX + ((ux == X_MAX-1) ? 0 : ux + 1);
                end
                Suop <= Suop + 1;
            end
            2: begin
                Suop <= Suop + 1;
            end
            3: begin
                if (dino_mask || ground_mask) begin
                    pix_temp <= dout;
                end
                else begin
                    pix_temp <= 0;
                end
                Suop <= Suop + 1;
            end
            4: begin
                addr <= uy * X_MAX + ux;
                din <= pix_temp;
                we <= 1;
                done <= 1;
                done_color <= {
                    {pix_temp, 1'b0},
                    {pix_temp, 2'b0},
                    {pix_temp, 1'b0}
                };
                // done_color <= 16'hffff;
                
                Suop <= 0;
            end
        endcase
    end
    if (cnt[CNT_BITS-1]) begin
        dino_pose_sel <= ~dino_pose_sel;
    end
end

endmodule