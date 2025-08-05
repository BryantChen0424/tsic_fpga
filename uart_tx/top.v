`include "uart_tx.v"

/* baudrate: 9600 */
/* Top level module for keypad + UART demo */
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
    output LED;

    /* FTDI I/O */
    output TX;

    parameter period_9600 = 625;
    parameter period_1 = 6000000;
    parameter ASCII_0 = 8'd48;
    parameter ASCII_9 = 8'd57;

    /* 9600 Hz clock generation (from 12 MHz) */
    reg clk_9600 = 0;
    reg [31:0] cntr_9600 = 32'b0;
    /* 1 Hz clock generation (from 12 MHz) */
    reg clk_1 = 0;
    reg [31:0] cntr_1 = 32'b0;

    reg uart_send = 1'b1;

    /* UART registers */
    reg [7:0] uart_txbyte = ASCII_0;
    wire uart_txed;

    /* LED register */
    reg ledval = 0;

    /* UART transmitter module designed for
       8 bits, no parity, 1 stop bit. 
    */
    uart_tx_8n1 transmitter (
        // 9600 baud rate clock
        .clk (clk_9600),
        // byte to be transmitted
        .txbyte (uart_txbyte),
        // trigger a UART transmit on baud clock
        .senddata (uart_send),
        // input: tx is finished
        .txdone (uart_txed),
        // output UART tx pin
        .tx (TX),
    );

    /* Wiring */
    assign LED=ledval;
    
    /* Low speed clock generation */
    always @ (posedge clk) begin
        /* generate 9600 Hz clock */
        cntr_9600 <= cntr_9600 + 1;
        if (cntr_9600 == period_9600) begin
            clk_9600 <= ~clk_9600;
            cntr_9600 <= 32'b0;
        end

        /* generate 1 Hz clock */
        cntr_1 <= cntr_1 + 1;
        if (cntr_1 == period_1) begin
            clk_1 <= ~clk_1;
            cntr_1 <= 32'b0;
        end
    end

    reg [8:0] cnt = 0;

    /* Increment ASCII digit and blink LED */
    always @ (posedge clk_9600) begin
        ledval <= ~ledval;
        if (uart_txed) begin
            if (cnt == 14) begin
                cnt <= 0;
            end else begin
                cnt <= cnt + 1;
            end
        end
    end

    always @(*) begin
        case (cnt)
            8'd0 : uart_txbyte = "H";
            8'd1 : uart_txbyte = "e";
            8'd2 : uart_txbyte = "l";
            8'd3 : uart_txbyte = "l";
            8'd4 : uart_txbyte = "o";
            8'd5 : uart_txbyte = ",";
            8'd6 : uart_txbyte = " ";
            8'd7 : uart_txbyte = "w";
            8'd8 : uart_txbyte = "o";
            8'd9 : uart_txbyte = "r";
            8'd10: uart_txbyte = "l";
            8'd11: uart_txbyte = "d";
            8'd12: uart_txbyte = "!";
            8'd13: uart_txbyte = "\n";
            8'd14: uart_txbyte = "\r";
            default: uart_txbyte = 8'h00;
        endcase
    end


endmodule
