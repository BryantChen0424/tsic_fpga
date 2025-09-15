// ============================================================
// Synthesizable Galois LFSR (right-shift, LSB feedback)
// - WIDTH:  8/16/32... (must match a proper TAPS polynomial)
// - TAPS:   Galois mask (XORed when LSB is 1)
// - Seed must be non-zero; seed==0 will be forced to 1
// - One new value per cycle when en=1
// ============================================================
module rnd_gen #(
    parameter integer WIDTH = 8,
    // For WIDTH=16: primitive polynomial x^16 + x^14 + x^13 + x^11 + 1
    // parameter TAPS  = 32'h0000_B400
    parameter TAPS = 8'hB8
    // parameter TAPS = 16'hB400
    // parameter TAPS = 32'h8020_0003
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 en,         // step when 1
    input  wire                 lock_seed,  // load new seed when 1
    output reg  [WIDTH-1:0]     rnd         // current LFSR state (pseudo-random)
);
    reg [WIDTH-1:0] s;
    reg [WIDTH-1:0] seed = 0;
    reg [WIDTH-1:0] seed_nz;

    // Force a non-zero seed
    always @(*) begin
        seed_nz = (seed == {WIDTH{1'b0}}) ? {{(WIDTH-1){1'b0}}, 1'b1} : seed;
        rnd = s;
    end

    always @(posedge clk) begin
        seed <= seed + 1;
        if (!rst_n) begin
            s <= seed_nz;
        end else if (lock_seed) begin
            s <= seed_nz;
        end else if (en) begin
            // Right shift by 1; if LSB==1, XOR with TAPS
            // Note: TAPS width must be >= WIDTH; low WIDTH bits are used
            s <= (s[0]) ? ((s >> 1) ^ TAPS[WIDTH-1:0]) : (s >> 1);
        end
    end
endmodule
