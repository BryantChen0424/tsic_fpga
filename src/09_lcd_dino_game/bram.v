module bram #(
    parameter WIDTH = 8,
    parameter LEN = 12800
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

reg [WIDTH-1:0] mem [0:LEN-1];

integer i;

initial begin
    for (i = 0; i < 12800; i = i + 1) begin
        mem[i] <= 1;
    end
    $readmemb("bram.mem", mem);
end

always @(posedge clk) begin
    if (we)
        mem[addr] <= din;
    dout <= mem[addr];
end

endmodule