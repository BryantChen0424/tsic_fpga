module top (
    clk, // input hardware clock (12 MHz)
    LED // all LEDs
    );

    input clk;
    output reg LED;

    reg [23:0] ledcnt = 0;
    always @(*) begin
        LED = ledcnt[23];
    end

    always @ (posedge clk) begin
        ledcnt <= ledcnt + 1;
    end
endmodule
