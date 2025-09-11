module top (
    input  wire clk,
    output wire oled_cs,
    output wire oled_clk,
    output wire oled_mosi,
    output wire oled_dc,
    output wire reset
);

function integer log2(input integer v); begin
	log2 = 0;
	while(v >> log2) log2 = log2 + 1;
end endfunction


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

localparam CNT_BITS = 28;
reg [CNT_BITS-1:0] cnt = 0;
reg [3:0] digits_sel = 0;

localparam INC = (1 << (CNT_BITS - 1)) / 12000000;

always @(*) begin
    addr = y[6:3] * 20 + x[7:3] + digits_sel * 200;
end

always @(posedge clk) begin
    if (~reset) begin
        cnt <= 0;
        digits_sel <= 0;
    end
    else begin
        if (next_pixel) begin
            color <= {
                {dout, 1'b0},
                {dout, 2'b0},
                {dout, 1'b0}
            };
        end

        if (cnt[CNT_BITS-1]) begin
            cnt <= 0;
            if (digits_sel == 9) begin
                digits_sel <= 0;
            end
            else begin
                digits_sel <= digits_sel + 1;
            end
        end
        else begin
            cnt <= cnt + INC;
        end
    end
end

endmodule
