module top (
    input  wire clk,

    input RX,
    output TX,

    output wire oled_cs,
    output wire oled_clk,
    output wire oled_mosi,
    output wire oled_dc,
    output wire reset
);

localparam X_MAX = 160;
localparam Y_MAX = 80;

localparam CLK_FREQ = 12000000;
localparam BAUD = 115200;

function integer log2(input integer v); begin
	log2 = 0;
	while(v >> log2) log2 = log2 + 1;
end endfunction

wire rx_ready;
wire [7:0] rx_data;

uart_rx #(CLK_FREQ, BAUD) urx (
    .clk(clk),
    .rx(RX),
    .rx_ready(rx_ready),
    .rx_data(rx_data)
);

reg tx_start;
reg [7:0] tx_data;
wire tx_busy;

uart_tx #(CLK_FREQ, BAUD) utx (
    .clk(clk),
    .tx_start(tx_start),
    .tx_data(tx_data),
    .tx(TX),
    .tx_busy(tx_busy)
);

uart_echo_unit #(CLK_FREQ, BAUD) ueu (
    .clk(clk),

    .rx_data(rx_data),
    .rx_ready(rx_ready),

    .tx_start(tx_start),
    .tx_data(tx_data),
    .tx_busy(tx_busy),

    .en(1),
    .idle()
);

reg [15:0] color;
wire [7:0] x;
wire [6:0] y;
wire next_pixel;
reg color_done = 0;

st7735  driver (
    .clk(clk),
    .x(x),
    .y(y),
    .color(color),
    .next_pixel(next_pixel),
    .color_done(color_done),

    .oled_cs(oled_cs),
    .oled_clk(oled_clk),
    .oled_mosi(oled_mosi),
    .oled_dc(oled_dc),
    .reset(reset)
);

localparam SCREEN_SIZE = X_MAX * Y_MAX;
localparam WIDTH = 1;
localparam LEN = SCREEN_SIZE + 3200;

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

localparam RND_WIDTH = 8;

reg rndg_en = 1;
reg rndg_lock_seed = 0;
wire [RND_WIDTH-1:0] rndg_rnd;

rnd_gen #(RND_WIDTH) rndg (
    .clk(clk),
    .rst_n(reset),
    .en(rndg_en),        
    .lock_seed(rndg_lock_seed),    
    .rnd(rndg_rnd)        
);

reg pre_next_pixel;

localparam S_DISPLAY    = 0;
localparam S_UPDATE    = 1;

reg S = S_DISPLAY;

reg u_update;
wire u_done;

wire [log2(LEN-1):0] u_addr;
wire [WIDTH-1:0] u_din;
reg [WIDTH-1:0] u_dout;
wire u_we;
reg [7:0] u_x;
reg [6:0] u_y;
wire [15:0] u_color;

display_buf_updater #(LEN, WIDTH, X_MAX, Y_MAX, RND_WIDTH) dbu (
    .clk(clk),
    .rst_n(reset),

    .update(u_update),
    .update_x(u_x),
    .update_y(u_y),
    .done(u_done),
    .done_color(u_color),

    .addr(u_addr),
    .din(u_din),
    .dout(u_dout),
    .we(u_we),

    .rnd(rndg_rnd),
    .rx_ready(rx_ready),
    .rx_data(rx_data)
);

always @(*) begin
    u_dout = dout;
    addr = u_addr;
    din = u_din;
    we = u_we;
end

always @(posedge clk) begin
    pre_next_pixel <= next_pixel;
    if (~reset) begin
        seed_flag <= 0;
        S <= S_DISPLAY;
        u_update <= 0;
    end
    else begin
        case (S)
            S_DISPLAY: begin
                color_done <= 0;
                if (~pre_next_pixel && next_pixel) begin
                    u_x <= x;
                    u_y <= y;
                    if (x < X_MAX && y < Y_MAX) begin
                        u_update <= 1;
                        S <= S_UPDATE;
                    end
                    else begin
                        color_done <= 1;
                    end
                end
            end
            S_UPDATE: begin
                u_update <= 0;
                color <= u_color;
                if (u_done) begin
                    color_done <= 1;
                    S <= S_DISPLAY;
                end
            end
        endcase
        if (rx_data && ~seed_flag) begin
            seed_flag <= 1;
            rndg_lock_seed <= 1;
        end
        else begin
            rndg_lock_seed <= 0;
        end
    end
end

endmodule

