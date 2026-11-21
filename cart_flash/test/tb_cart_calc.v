`timescale 1ns/1ps
module tb_cart_calc;
  reg clk=0, resetn=0, rx=1;
  wire tx, link_oe;
  wire [15:0] address;
  wire rd_n, wr_n, cs_n, ctrl_oe, data_dir, cart_clk;
  wire [7:0] data, delayed_data;
  wire read_valid;
  reg [7:0] rom [0:16383];
  string rom_file;
  string output_text="";
  event uart_byte;
  integer fetches=0, stack_writes=0;
  localparam BIT_TIME=25*(40000000/57600/16)*16;

  SOC dut (
    .clk(clk), .resetn(resetn), .RXD(rx), .TXD(tx), .link_oe(link_oe),
    .cart_data(data), .cart_addr(address), .cart_clk(cart_clk),
    .cart_wr_n(wr_n), .cart_rd_n(rd_n), .cart_cs_n(cs_n),
    .cart_ctrl_oe(ctrl_oe), .cart_data_dir(data_dir)
  );
  always #12.5 clk=~clk;
  assign #300 delayed_data=rom[address];
  assign #300 read_valid=!rd_n && ctrl_oe && data_dir;
  assign data=(!rd_n && read_valid) ? delayed_data : 8'hxx;

  always @(negedge clk) if(resetn) begin
    if(dut.CPU.state==4'b0001) begin
      fetches=fetches+1;
      if(!dut.cart_sel || dut.ram_sel || dut.mem_addr>=32'h1000)
        $fatal(1,"Fetch fuera de ROM: %h",dut.mem_addr);
    end
    if(dut.ram_sel && |dut.mem_wmask) begin
      stack_writes=stack_writes+1;
      if(dut.mem_addr<32'h1000 || dut.mem_addr>=32'h3000)
        $fatal(1,"Escritura RAM fuera de rango");
    end
    if(dut.cart_sel && |dut.mem_wmask)
      $fatal(1,"Intento de escritura de CPU en ROM");
    if(wr_n!==1 || cs_n!==1 || ctrl_oe!==1 || data_dir!==1)
      $fatal(1,"Controles de cartucho incorrectos");
  end

  task receive_byte;
    output [7:0] value;
    integer b;
    begin
      @(negedge tx);
      #(BIT_TIME/2);
      if(tx!==0) $fatal(1,"UART start");
      for(b=0;b<8;b=b+1) begin #(BIT_TIME); value[b]=tx; end
      #(BIT_TIME);
      if(tx!==1) $fatal(1,"UART stop");
    end
  endtask
  reg [7:0] received;
  initial forever begin
    receive_byte(received);
    output_text={output_text,received};
    $write("%c",received);
    -> uart_byte;
  end
  task wait_suffix;
    input string text;
    begin
      while(output_text.len()<text.len() ||
            output_text.substr(output_text.len()-text.len(),
                               output_text.len()-1)!=text)
        @(uart_byte);
    end
  endtask
  task send_byte;
    input [7:0] value;
    integer b;
    begin
      rx=0; #(BIT_TIME);
      for(b=0;b<8;b=b+1) begin rx=value[b]; #(BIT_TIME); end
      rx=1; #(BIT_TIME*2);
    end
  endtask
  task enter_digit;
    input [7:0] digit;
    begin
      send_byte(digit);
      wait_suffix($sformatf("%c",digit));
    end
  endtask
  task operation;
    input [7:0] first, op, second;
    input string expected;
    begin
      wait_suffix("Number: ");
      enter_digit(first);
      send_byte(8'h0d);
      wait_suffix("Operator ");
      send_byte(op);
      wait_suffix("Number: ");
      enter_digit(second);
      send_byte(8'h0d);
      wait_suffix(expected);
    end
  endtask
  initial begin
    if(!$value$plusargs("ROM_HEX=%s",rom_file)) $fatal(1,"ROM_HEX");
    $readmemh(rom_file,rom);
    // La RAM se envenena: ningún código o dato inicial del cartucho en BRAM.
    for(integer i=0;i<2048;i=i+1) dut.RAM.MEM[i]=32'hdeadbeef;
    repeat(8) @(negedge clk);
    #1; resetn=1;
    operation("2","+","3","\012\01500005\012\015");
    $display("PASS calculadora: 2 + 3 = 5");
    operation("7","*","6","\012\01500042\012\015");
    $display("PASS calculadora: 7 * 6 = 42");
    operation("9","/","3","\012\01500003\012\015");
    $display("PASS calculadora: 9 / 3 = 3");
    wait_suffix("Number: ");
    enter_digit("1"); enter_digit("6");
    send_byte(8'h0d);
    wait_suffix("Operator ");
    send_byte("^");
    wait_suffix("\012\01500004\012\015");
    if(fetches<100 || stack_writes<10) $fatal(1,"No se comprobó ejecución y pila");
    $display("PASS calculadora: sqrt(16) = 4");
    $display("PASS XIP: binario original, fetch desde cartucho, pila en RAM y UART TX/RX.");
    $finish;
  end
  initial begin
    #300000000;
    $fatal(1,"Timeout calculadora: PC=%h state=%h busy=%b",
           dut.CPU.PC,dut.CPU.state,dut.cart_rbusy);
  end
endmodule
