`timescale 1ns/1ps
// FSM Moore: conserva estados y operaciones del diagrama corregido.
// WAIT_CYCLES=1 reproduce el dibujo; valores mayores alargan solo esperas.
// El procesador retira MEM_RSTRB/CS al finalizar; no hay espera extra.
module control_fsm #(
  parameter integer WAIT_CYCLES = 1
) (
  input wire CLK, RST, MEM_RSTRB, CS, Z_BYTE,
  output reg LD_REG, SH_REG, RST_DP, INC_COUNT,
  output reg MEM_RBUSY, CS_CART, RE_CART
);
  localparam [3:0] INIT=0, START=1, MEM=2, WAIT1=3, WAIT2=4,
    READ3=5, WAIT4=6, LOAD=7, ADD=8, COMP=9, SHIFT=10, MEM_BUSY0=11,
    RE0=12;
  reg [3:0] state, next_state;
  localparam WAIT_WIDTH = WAIT_CYCLES > 1 ? $clog2(WAIT_CYCLES) : 1;
  reg [WAIT_WIDTH-1:0] wait_count;
  wire wait_done = wait_count == WAIT_CYCLES - 1;
  always @(posedge CLK) begin
    if(RST) begin
      state <= INIT;
      wait_count <= 0;
    end else begin
      state <= next_state;
      if ((state == WAIT1 || state == WAIT2 || state == WAIT4) && !wait_done)
        wait_count <= wait_count + 1'b1;
      else
        wait_count <= 0;
    end
  end
  always @* begin
    LD_REG=0; SH_REG=0; RST_DP=0; INC_COUNT=0;
    MEM_RBUSY=0; CS_CART=0;
    // Una sola asignación: RE permanece continuo al contar dentro de WAIT4.
    RE_CART=(state == READ3 || state == WAIT4 || state == LOAD);
    next_state=INIT;
    case(state)
      INIT: begin
        if(MEM_RSTRB && CS) next_state=START;
        else next_state=INIT;
      end
      START: begin MEM_RBUSY=1; RST_DP=1; next_state=MEM; end
      MEM: begin MEM_RBUSY=1; next_state=WAIT1; end
      WAIT1: begin MEM_RBUSY=1; next_state=wait_done ? WAIT2 : WAIT1; end
      WAIT2: begin MEM_RBUSY=1; next_state=wait_done ? READ3 : WAIT2; end
      READ3: begin MEM_RBUSY=1; next_state=WAIT4; end
      WAIT4: begin MEM_RBUSY=1; next_state=wait_done ? LOAD : WAIT4; end
      LOAD: begin MEM_RBUSY=1; LD_REG=1; next_state=ADD; end
      ADD: begin MEM_RBUSY=1; INC_COUNT=1; next_state=COMP; end
      COMP: begin
        MEM_RBUSY=1;
        if(Z_BYTE) next_state=MEM_BUSY0;
        else next_state=SHIFT;
      end
      SHIFT: begin MEM_RBUSY=1; SH_REG=1; next_state=RE0; end
      RE0: begin MEM_RBUSY=1; next_state=MEM; end
      MEM_BUSY0: next_state=INIT;
      default: next_state=INIT;
    endcase
  end
endmodule
