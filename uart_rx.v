module uart_rx_dynamic(
    input wire clk,                  
    input wire rst,                
    input wire rx,
    input wire [31:0] baud_rate,                      // UART receive line (serial data input)
    output reg [7:0] rx_data,           // Received data (parallel output)
    output reg rx_ready                 // Flag indicating when data is ready
);
    
    parameter clk_frq = 100000000;
    //parameter BAUD_RATE = 9600; 
    
    // Baud rate calculation
    //localparam integer BAUD_TICK_COUNT = CLK_FREQ / BAUD_RATE;

    // State Encoding
    localparam IDLE   = 3'b000;
    localparam START  = 3'b001;
    localparam DATA   = 3'b010;
    localparam STOP   = 3'b011;

    // Registers
    reg [2:0] state;                    // Current state of the receiver
    reg [3:0] bit_index;                // Bit index in the received byte
    reg [7:0] shift_reg;                // Shift register for assembling data bits
    reg [15:0] baud_counter;            // Counter for baud tick timing
    reg [31:0] baud_tick_count;
    reg [31:0] prev_baud_rate;
    
    // Baud rate calculation logic (calculate tick count based on baud rate)
//    always @(posedge clk or posedge rst) begin
//        if (rst) begin
//            baud_tick_count <= clk_frq / 9600;  // Default to 9600 baud on reset
//            prev_baud_rate <= 9600;
//        end else if (baud_rate != prev_baud_rate) begin
//            // Update baud tick count when baud rate changes
//            baud_tick_count <= clk_frq / baud_rate;
//            prev_baud_rate <= baud_rate;
//        end
//    end
      always @(posedge clk or posedge rst) begin
            if (rst) begin
                baud_tick_count <= clk_frq / 9600;  // Default baud rate
                prev_baud_rate <= 9600;
            end else if (baud_rate != prev_baud_rate && state == IDLE) begin
                baud_tick_count <= clk_frq / baud_rate;
                prev_baud_rate <= baud_rate;
            end
      end

    
    // State Machine for UART Receiver
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            rx_data <= 8'b0;
            bit_index <= 4'b0;
            rx_ready <= 1'b0;
            shift_reg <= 8'b0;
            baud_counter <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    rx_ready <= 1'b0;        // Clear ready flag
                    baud_counter <= 16'd0;   // Reset baud counter
                    if (rx == 1'b0) begin    // Detect start bit (falling edge)
                        state <= START;
                    end
                end

                START: begin
                    if (baud_counter == baud_tick_count / 2) begin // Sample at middle of start bit
                        if (rx == 1'b0) begin // Confirm it's still start bit
                            state <= DATA;
                            bit_index <= 4'b0;  // Reset bit index
                            baud_counter <= 16'd0;
                        end else begin
                            state <= IDLE;      // False start, return to IDLE
                        end
                    end else begin
                        baud_counter <= baud_counter + 1;
                    end
                end

                DATA: begin
                    if (baud_counter == baud_tick_count - 1) begin
                        baud_counter <= 16'd0;
                        shift_reg <= {rx, shift_reg[7:1]};  // Shift in the received bit
                        if (bit_index == 7) begin
                            state <= STOP;      // Move to stop state after 8 bits
                        end else begin
                            bit_index <= bit_index + 1;
                        end
                    end else begin
                        baud_counter <= baud_counter + 1;
                    end
                end

                STOP: begin
                    if (baud_counter == baud_tick_count - 1) begin
                        baud_counter <= 16'd0;
                        if (rx == 1'b1) begin  // Stop bit detected (high)
                            rx_data <= shift_reg; // Load the received data
                            rx_ready <= 1'b1;     // Set data ready flag
                        end
                        state <= IDLE;          // Return to IDLE
                    end else begin
                        baud_counter <= baud_counter + 1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
