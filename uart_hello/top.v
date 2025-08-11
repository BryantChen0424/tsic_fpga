`include "uart_tx.v"

module top (
    // input hardware clock (12 MHz)
    clk,
    // all LEDs
    LED,
    // UART lines
    TX, 
    );

    /* Clock input */
    input clk;

    /* LED outputs */
    output reg LED;

    /* FTDI I/O */
    output TX;

    /* UART registers */
    reg [7:0] tx_data;
    reg tx_start = 0;
    wire tx_busy;
    uart_tx  #(12000000, 115200) transmitter (
        // 9600 baud rate clock
        .clk (clk),
        // trigger a UART transmit on baud clock
        .tx_start (tx_start),
        // byte to be transmitted
        .tx_data (tx_data),
        // output UART tx pin
        .tx (TX),
        // input: tx is finished
        .tx_busy (tx_busy),
    );

    reg [24:0] ledcnt = 0;
    always @(*) begin
        LED = ledcnt[24];
    end

    always @ (posedge clk) begin
        ledcnt <= ledcnt + 1;
    end

    localparam S_REQ  = 0; // request a tx
    localparam S_RESP = 1; // wait transmitter goes to busy
    localparam S_DONE = 2; // wait tx finishes

    reg [1:0] S;
    reg [8*15-1:0] msg = "Hello, world!\n\r";

    always @(*) begin
        tx_data = msg[8*15-1:8*14];
    end

    always @(posedge clk) begin
        case (S)
            S_REQ: begin
                tx_start <= 1;
                S <= S_RESP;
            end
            S_RESP: begin
                tx_start <= 0;
                if (tx_busy) begin
                    msg <= (msg << 8) + tx_data;
                    S <= S_DONE;
                end
            end
            S_DONE: begin
                if (~tx_busy) begin
                    S <= S_REQ;
                end
            end
            default: begin
                S <= S_REQ;
                msg <= "Hello, world!\n\r";
            end
        endcase
    end



endmodule
