`timescale 1ns/1ps

// ROM del cartucho accesible directamente por el bus de FemtoRV32.
// Cuatro lecturas de byte por palabra, resultado little-endian.
// Reset activo alto. Sin escrituras al cartucho.
module cart_memory #(
    parameter integer WAIT_CYCLES = 16
) (
    input  wire        clk,
    input  wire        reset,

    input  wire        cs,
    input  wire        rd,
    input  wire [13:0] addr,

    output reg  [31:0] d_out,
    output wire        rbusy,

    input  wire [7:0]  cart_data,
    output wire [15:0] cart_addr,
    output wire        read_enable
);

    localparam [2:0]
        IDLE      = 0,
        ISSUE     = 1,
        WAIT_BUSY = 2,
        WAIT_DONE = 3,
        RESPONSE  = 4;

    reg [2:0] state;
    reg [15:0] saved_addr;

    wire request = cs && rd;
    wire reader_busy;
    wire [31:0] reader_data;

    // Ocupado desde la solicitud inicial, no solo cuando arranca el lector.
    assign rbusy = !reset && (
        (state == IDLE && request) ||
        state == ISSUE ||
        state == WAIT_BUSY ||
        state == WAIT_DONE
    );

    always @(posedge clk) begin
        if (reset) begin
            state      <= IDLE;
            saved_addr <= 0;
            d_out      <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (request) begin
                        saved_addr <= {2'b00, addr[13:2], 2'b00};
                        state <= ISSUE;
                    end
                end

                // Pulso de un ciclo hacia el lector.
                ISSUE:
                    state <= WAIT_BUSY;

                WAIT_BUSY: begin
                    if (reader_busy)
                        state <= WAIT_DONE;
                end

                WAIT_DONE: begin
                    if (!reader_busy) begin
                        // Bytes físicos 37 21 00 00:
                        // lector = 37210000, CPU = 00002137.
                        d_out <= {
                            reader_data[7:0],
                            reader_data[15:8],
                            reader_data[23:16],
                            reader_data[31:24]
                        };
                        state <= RESPONSE;
                    end
                end

                // El resultado ya es válido y rbusy está desactivado.
                // Evita repetir una solicitud sostenida.
                RESPONSE: begin
                    if (!rd)
                        state <= IDLE;
                end

                default:
                    state <= IDLE;
            endcase
        end
    end

    arreglobitscpu #(
        .WAIT_CYCLES(WAIT_CYCLES)
    ) reader (
        .CLK(clk),
        .RST(reset),
        .MEM_RSTRB(state == ISSUE),
        .DIR_MEM_IN(saved_addr),
        .CS(1'b1),
        .DATA_C(cart_data),

        .MEM_RBUSY(reader_busy),
        .DATA_P(reader_data),
        .DIR_MEM_OUT(cart_addr),
        .CS_CART(),
        .RE_CART(read_enable),
        .RE()
    );

endmodule
