module uart_tx_dynamic(
    input clk,
    input rst,
    input tx_start,
    input wire [31:0] baud_rate,
    input [7:0] tx_data,
    output reg Tx,
    output reg tx_busy    // Signal to indicate transmission in progress
);
    // Parameters for Baud Rate and Clock Frequency
    parameter clk_frq = 100000000;    // 100 MHz clock frequency
   // parameter baud_rate = 9600;       //  Baud rate
   // parameter baud_tik = clk_frq / baud_rate;

    // State Encoding
    localparam IDLE  = 3'b000;
    localparam START = 3'b001;
    localparam DATA  = 3'b010;
    localparam STOP  = 3'b011;

    // Registers
    reg [2:0] state;               // Current state of the transmitter
    reg [15:0] baud_count;         // Baud rate counter
    reg [3:0] bit_index;           // Bit position counter
    reg [7:0] shift_reg;           // Shift register for data bits
    reg [31:0] baud_tick_count;
    reg [31:0] prev_baud_rate;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            baud_tick_count <= clk_frq / 9600;  // Default baud rate
            prev_baud_rate <= 9600;
        end else if (baud_rate != prev_baud_rate && state == IDLE) begin
            baud_tick_count <= clk_frq / baud_rate;
            prev_baud_rate <= baud_rate;
        end
    end

    
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
    
    // State Machine for UART Transmitter
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            baud_count <= 16'b0;
            bit_index <= 4'b0;
            shift_reg <= 8'b0;
            Tx <= 1'b1;            // Idle line is high
            tx_busy <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    Tx <= 1'b1;     // Keep line high in IDLE
                    tx_busy <= 1'b0;
                    if (tx_start) begin
                        shift_reg <= tx_data;   // Load data to transmit
                        baud_count <= 16'b0;    // Reset baud counter
                        bit_index <= 4'b0;
                        tx_busy <= 1'b1;
                        state <= START;         
                    end
                end

                START: begin
                    Tx <= 1'b0;     // Send start bit (0)
                    if (baud_count < baud_tick_count - 1) begin
                        baud_count <= baud_count + 1;
                    end else begin
                        baud_count <= 0;
                        state <= DATA;          
                    end
                end

                DATA: begin
                    Tx <= shift_reg[0];         // Send LSB of shift register
                    if (baud_count < baud_tick_count - 1) begin
                        baud_count <= baud_count + 1;
                    end else begin
                        baud_count <= 0;
                        shift_reg <= shift_reg >> 1;  // Shift data right
                        bit_index <= bit_index + 1;
                        if (bit_index == 7) begin
                            state <= STOP;       // Move to STOP state after 8 bits
                        end
                    end
                end

                STOP: begin
                    Tx <= 1'b1;                 // Send stop bit (1)
                    if (baud_count < baud_tick_count - 1) begin
                        baud_count <= baud_count + 1;
                    end else begin
                        baud_count <= 0;
                        state <= IDLE;          // Return to IDLE state
                        tx_busy <= 1'b0;        // Transmission complete
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
