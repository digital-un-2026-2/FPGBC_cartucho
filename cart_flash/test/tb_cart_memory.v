`timescale 1ns/1ps
module tb_cart_memory;
  reg clk=0, reset=1, cs=0, rd=0;
  reg [13:0] addr=0;
  wire [31:0] result;
  wire busy, re;
  wire [15:0] address;
  wire [7:0] data, delayed_data;
  wire read_valid;
  integer loads=0;
  cart_memory #(.WAIT_CYCLES(16)) dut (
    .clk(clk), .reset(reset), .cs(cs), .rd(rd), .addr(addr),
    .d_out(result), .rbusy(busy), .cart_data(data),
    .cart_addr(address), .read_enable(re)
  );
  always #12.5 clk=~clk;
  assign #300 delayed_data=address[7:0];
  assign #300 read_valid=re;
  assign data=re && read_valid ? delayed_data : 8'hxx;
  always @(negedge clk) if(!reset && dut.reader.LD_REG) loads=loads+1;

  task read_word;
    input [13:0] a;
    input [31:0] expected;
    begin
      @(negedge clk); #1; cs=1; rd=1; addr=a;
      #1; if(busy!==1) $fatal(1,"BUSY no cubre solicitud inicial");
      @(negedge clk); #1; rd=0; cs=0; addr=14'h0300;
      while(busy) begin @(negedge clk); #1; end
      if(result!==expected) $fatal(1,"Dato/alineacion/endian: %h != %h",result,expected);
      repeat(2) @(negedge clk);
    end
  endtask

  initial begin
    repeat(4) @(negedge clk);
    #1; reset=0;
    read_word(14'h0000,32'h03020100);
    read_word(14'h0007,32'h07060504);
    read_word(14'h3ffc,32'hfffefdfc);
    if(loads!=12) $fatal(1,"No hay cuatro capturas por solicitud");

    // Un strobe sostenido no debe repetir la operación.
    @(negedge clk); #1; cs=1; rd=1; addr=14'h0008;
    #1; if(busy!==1) $fatal(1,"BUSY inicial");
    while(busy) begin @(negedge clk); #1; end
    repeat(300) @(negedge clk);
    #1;
    if(result!==32'h0b0a0908 || loads!=16 || busy!==0)
      $fatal(1,"Solicitud sostenida se repite");
    rd=0; cs=0;
    repeat(3) @(negedge clk);

    // Reset aborta una lectura y permite una posterior.
    #1; cs=1; rd=1; addr=14'h0010;
    repeat(5) @(negedge clk);
    #1; reset=1; cs=0; rd=0;
    repeat(4) @(negedge clk);
    #1;
    if(busy!==0 || result!==0 || re!==0) $fatal(1,"Reset incompleto");
    reset=0;
    read_word(14'h0010,32'h13121110);
    $display("PASS cart_memory: BUSY inmediato, solicitud pulsada/sostenida, dirección guardada, endian, borde y reset.");
    $finish;
  end
  initial begin #100000; $fatal(1,"Timeout cart_memory"); end
endmodule
