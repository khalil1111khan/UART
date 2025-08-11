module uart_top_dynamic(
    input wire clk,
    input wire rst,
    input wire rx,
    input wire [31:0] baud_rate,
    output wire [7:0] rx_data,
    output wire rx_ready,
    output wire tx,
    output reg [7:0] led_output
);
    wire tx_busy;
    reg tx_start_int;

    // Instantiate UART transmitter
    uart_tx_dynamic tx_inst (
        .clk(clk),
        .rst(rst),
        .tx_start(tx_start_int),
        .baud_rate(baud_rate),
        .tx_data(rx_data),
        .Tx(tx),
        .tx_busy(tx_busy)
    );

    // Instantiate UART receiver
    uart_rx_dynamic rx_inst (
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .baud_rate(baud_rate),
        .rx_data(rx_data),
        .rx_ready(rx_ready)
    );

    // Logic to handle received data and trigger transmission
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            led_output <= 8'b0;
            tx_start_int <= 1'b0;
        end else begin
            if (rx_ready) begin
                led_output <= rx_data;  // Update LEDs with received data
                if (!tx_busy) begin
                    tx_start_int <= 1'b1;  // Pulse tx_start_int for one cycle
                end
            end else begin
                tx_start_int <= 1'b0;  // Reset tx_start_int to avoid repeated triggers
            end
        end
    end
endmodule
