`timescale 1ns/1ps

// Calculadora original: código/constantes en cartucho, pila/datos en BRAM.
// ROM 0000..0FFF, RAM 1000..2FFF; el binario inicializa SP=2000.
module SOC #(
    parameter integer CART_WAIT_CYCLES = 16
) (
    input wire clk,
    input wire resetn,
    input wire RXD,
    output wire TXD,
    output wire link_oe,
    input wire [7:0] cart_data,
    output wire [15:0] cart_addr,
    output wire cart_clk,
    output wire cart_wr_n,
    output wire cart_rd_n,
    output wire cart_cs_n,
    output wire cart_ctrl_oe,
    output wire cart_data_dir
);
    wire [31:0] mem_addr, mem_wdata;
    reg [31:0] mem_rdata;
    wire [3:0] mem_wmask;
    wire mem_rstrb;
    wire wr = |mem_wmask;

    wire cart_sel = mem_addr < 32'h00001000;
    wire ram_sel = mem_addr >= 32'h00001000 && mem_addr < 32'h00003000;
    wire uart_sel = mem_addr[31:16] == 16'h0040;
    wire sqrt_sel = mem_addr[31:16] == 16'h0041;
    wire bin2bcd_sel = mem_addr[31:16] == 16'h0044;
    wire bcd2bin_sel = mem_addr[31:16] == 16'h0046;
    wire [31:0] ram_addr = mem_addr - 32'h00001000;

    wire [31:0] cart_dout, ram_dout, uart_dout;
    wire [31:0] sqrt_dout, bin2bcd_dout, bcd2bin_dout;
    wire cart_rbusy, cart_read_enable;

    assign link_oe = 1'b1;
    assign cart_ctrl_oe = resetn;
    assign cart_data_dir = 1'b1;
    assign cart_clk = 1'b0;
    assign cart_wr_n = 1'b1; // Solo lectura: no modificar flash ni MBC5.
    assign cart_cs_n = 1'b1; // /CS del conector selecciona FRAM, no la ROM.
    assign cart_rd_n = !resetn || !cart_read_enable;

    FemtoRV32 #(.RESET_ADDR(32'h00000000)) CPU (
        .clk(clk), .reset(resetn),
        .mem_addr(mem_addr), .mem_rdata(mem_rdata),
        .mem_rstrb(mem_rstrb), .mem_wdata(mem_wdata), .mem_wmask(mem_wmask),
        .mem_rbusy(cart_rbusy), .mem_wbusy(1'b0),
        .interrupt_request(1'b0)
    );

    // Sin firmware inicial: ninguna instrucción se ejecuta desde esta RAM.
    bram RAM (
        .clk(clk), .mem_addr(ram_addr), .mem_rdata(ram_dout),
        .mem_rstrb(ram_sel && mem_rstrb),
        .mem_wdata(mem_wdata), .mem_wmask({4{ram_sel}} & mem_wmask)
    );

    cart_memory #(.WAIT_CYCLES(CART_WAIT_CYCLES)) per_cart (
        .clk(clk), .reset(!resetn), .cs(cart_sel), .rd(mem_rstrb),
        .addr(mem_addr[13:0]), .d_out(cart_dout), .rbusy(cart_rbusy),
        .cart_data(cart_data), .cart_addr(cart_addr),
        .read_enable(cart_read_enable)
    );

    peripheral_uart #(.clk_freq(40_000_000), .baud(57_600)) per_uart (
        .clk(clk), .rst(!resetn), .d_in(mem_wdata), .cs(uart_sel),
        .addr(mem_addr[4:0]), .rd(mem_rstrb), .wr(wr), .d_out(uart_dout),
        .uart_tx(TXD), .uart_rx(RXD), .ledout()
    );

    peripheral_sqrt per_sqrt (
        .clk(clk), .reset(!resetn), .d_in(mem_wdata[15:0]), .cs(sqrt_sel),
        .addr(mem_addr[4:0]), .rd(mem_rstrb), .wr(wr), .d_out(sqrt_dout)
    );

    peripheral_bin2bcd bin2bcd0 (
        .clk(clk), .reset(!resetn), .d_in(mem_wdata[15:0]), .cs(bin2bcd_sel),
        .addr(mem_addr[4:0]), .rd(mem_rstrb), .wr(wr), .d_out(bin2bcd_dout)
    );

    peripheral_bcd2bin bcd2bin0 (
        .clk(clk), .reset(!resetn), .d_in(mem_wdata[19:0]), .cs(bcd2bin_sel),
        .addr(mem_addr[4:0]), .rd(mem_rstrb), .wr(wr), .d_out(bcd2bin_dout)
    );

    always @* begin
        mem_rdata = 0;
        if (cart_sel) mem_rdata = cart_dout;
        else if (ram_sel) mem_rdata = ram_dout;
        else if (uart_sel) mem_rdata = uart_dout;
        else if (sqrt_sel) mem_rdata = sqrt_dout;
        else if (bin2bcd_sel) mem_rdata = bin2bcd_dout;
        else if (bcd2bin_sel) mem_rdata = bcd2bin_dout;
    end
endmodule
