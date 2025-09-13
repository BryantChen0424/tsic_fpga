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

localparam SCREEN_SIZE = X_MAX * Y_MAX;

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

localparam GROUND_BASE = SCREEN_SIZE;
localparam GROUND_Y = 0;
localparam GROUND_H = 20;

localparam DINO_BASE = SCREEN_SIZE + X_MAX*GROUND_H;
localparam DINO_X = 5;
localparam DINO_Y = 20;
localparam DINO_W = 16;
localparam DINO_H = 16;

reg init_flag = 0;

reg dino_mask;
reg ground_mask;

localparam CNT_BITS = 24;
localparam MS_INC = (1 << (CNT_BITS - 1)) / 12000;
localparam MSS_BITS = 12;
reg [CNT_BITS-1:0] ms_cnt = 0;
reg ms_tick;
reg [MSS_BITS-1:0] mss = 0;

// reg [CNT_BITS-1:0] dino_inc = (1 << (CNT_BITS - 1)) / 1200000;
reg dino_tick;
// reg [CNT_BITS-1:0] dino_cnt = 0;
// reg [CNT_BITS-1:0] dino_steps = 0;

localparam GROUND_SPEED_MAX = 15;
localparam FLOAT_BITS = 3;
localparam GROUND_SPEED_BITS = log2(GROUND_SPEED_MAX) + FLOAT_BITS;
reg [GROUND_SPEED_BITS:0] ground_speed = 4 << FLOAT_BITS;
reg [GROUND_SPEED_BITS:0] ground_speed_cut_f;

reg [5:0] dino_dy;
reg jump_flag = 0;
reg [2:0] jump_tref;
reg [2:0] jump_t0 = 0;
reg [2:0] dys_idx;

always @(*) begin
    dino_mask = (uy >= (DINO_Y+dino_dy) && uy < (DINO_Y+dino_dy+DINO_H)) && (ux >= DINO_X && ux < (DINO_X+DINO_W));
    ground_mask = uy < (GROUND_Y+GROUND_H);

    ms_tick = ms_cnt[CNT_BITS-1];

    // dino_tick = dino_cnt[CNT_BITS-1];
    dino_tick = &mss[7:2] && ~|mss[1:0] && ms_tick;
    ground_speed_cut_f = ground_speed >> FLOAT_BITS;

    jump_tref = mss[9:7];
    dys_idx = jump_tref - jump_t0;

    if (jump_flag) begin
        case (dys_idx)
            0: dino_dy = 14;
            1: dino_dy = 24;
            2: dino_dy = 30;
            3: dino_dy = 32;
            4: dino_dy = 30;
            5: dino_dy = 24;
            6: dino_dy = 14;
            7: dino_dy = 0;
        endcase
    end
    else begin
        dino_dy = 0;
    end
    
end

always @(posedge clk) begin
    if (~rst_n) begin
        Suop <= 0;
    end
    else begin
        // time logic
        ms_cnt <= ms_tick ? 0 : ms_cnt + MS_INC;
        mss <= ms_tick ? mss + 1 : mss;
        // dino_cnt <= dino_tick ? 0 : dino_cnt + dino_inc;
        // dino_steps <= dino_tick ? dino_steps + 1 : dino_steps;
        if (&mss && ms_tick) begin
            // dino_inc     <= (dino_inc     < 671) ? dino_inc + (dino_inc >> FLOAT_BITS) : 671;
            ground_speed <= (ground_speed < GROUND_SPEED_MAX << FLOAT_BITS ) ? ground_speed + (ground_speed >> FLOAT_BITS) : GROUND_SPEED_MAX << FLOAT_BITS;
        end
        // update logic
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
                    addr <= (uy-(DINO_Y+dino_dy)) * DINO_W + (ux-DINO_X) + dino_pose_sel * (DINO_W*DINO_H) + DINO_BASE;
                end
                else if (ground_mask) begin
                    if (init_flag) begin
                        if (ux >= X_MAX - ground_speed_cut_f) begin
                            addr <= uy * X_MAX + ux + ground_speed_cut_f - X_MAX;
                        end
                        else begin
                            addr <= uy * X_MAX + ux + ground_speed_cut_f;
                        end
                    end
                    else begin
                        addr <= uy * X_MAX + ux + GROUND_BASE;
                    end
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
                // done_color <= {
                //     {pix_temp, 1'b0},
                //     {pix_temp, 2'b0},
                //     {pix_temp, 1'b0}
                // };
                done_color <= {16{pix_temp}};
                
                Suop <= 0;
            end
        endcase
    end
    if (dino_tick) begin
        dino_pose_sel <= ~dino_pose_sel;
    end
    if ((uy == Y_MAX - 1) && (ux == X_MAX - 1)) begin
        init_flag <= 1;
    end

    if (rx_ready && ~jump_flag) begin
        jump_flag <= 1;
        jump_t0 <= jump_tref;
    end
    
    if (jump_flag && dys_idx == 7 && (uy == Y_MAX - 1) && (ux == X_MAX - 1)) begin
        jump_flag <= 0;
    end
end

endmodule