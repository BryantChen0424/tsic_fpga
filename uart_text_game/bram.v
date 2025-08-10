module bram #(
    parameter WIDTH = 8,
    parameter LEN = 256
)(
    clk,
    addr,
    din,
    dout,
    we
);

function integer log2(input integer v); begin
	log2 = 0;
	while(v >> log2) log2 = log2 + 1;
end endfunction

input clk;
input [log2(LEN-1):0] addr;
input [WIDTH-1:0] din;
output reg [WIDTH-1:0] dout;
input we;

reg [7:0] mem [0:LEN-1]; // 16 KB

always @(posedge clk) begin
    if (we)
        mem[addr] <= din;
    dout <= mem[addr];
end

endmodule
