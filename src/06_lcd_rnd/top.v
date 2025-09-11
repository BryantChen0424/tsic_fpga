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

st7735  driver (
    .clk(clk),
    .x(x),
    .y(y),
    .color(color),
    .next_pixel(next_pixel),

    .oled_cs(oled_cs),
    .oled_clk(oled_clk),
    .oled_mosi(oled_mosi),
    .oled_dc(oled_dc),
    .reset(reset)
);

localparam WIDTH = 4;
localparam LEN = 2000;

reg [log2(LEN-1):0] addr;
reg [WIDTH-1:0] din = 0;
wire [WIDTH-1:0] dout;
reg we = 0;

bram #(WIDTH, LEN) mem (
    .clk(clk),
    .addr(addr),
    .din(din),
    .dout(dout),
    .we(we)
);

localparam RND_WIDTH = 8;

reg rndg_en = 1;
reg rndg_load_seed = 1;
reg [RND_WIDTH-1:0] rndg_seed = 0;
wire [RND_WIDTH-1:0] rndg_rnd;

rnd_gen #(RND_WIDTH) rndg (
    .clk(clk),
    .rst_n(reset),
    .en(rndg_en),        
    .load_seed(rndg_load_seed), 
    .seed(rndg_seed),      
    .rnd(rndg_rnd)        
);

reg seed_flag = 0;

reg [15:0] digits_sel = 0;

always @(*) begin
    addr = y[6:3] * 20 + x[7:3] + digits_sel * 200;
end

always @(posedge clk) begin
    if (~reset) begin
        digits_sel <= 0;
        seed_flag <= 0;
    end
    else begin
        
        if (next_pixel) begin
            color <= {
                {dout, 1'b0},
                {dout, 2'b0},
                {dout, 1'b0}
            };
        end

        rndg_seed <= rndg_seed + 1;

        if (rx_ready && ~seed_flag) begin
            digits_sel <= (rndg_seed * 10) >> 8;
            rndg_load_seed <= 1;
        end
        else if (rx_ready && seed_flag) begin
            digits_sel <= (rndg_rnd * 10) >> 8;
        end
        else begin
            rndg_load_seed <= 0;
        end

        seed_flag <= seed_flag | rx_ready;
    end
end

endmodule
