# Arranque de la prueba en hardware del controlador FRAM.
#
# Se enlaza en la dirección 0 (antes de calculator.S):
#   1. Copia toda la BRAM (4 KB, tamaño de bram.v) a la FRAM del cartucho.
#   2. Verifica la copia palabra por palabra.
#   3. Salta a FRAM_BASE + calculator_inicio, es decir, a la copia de
#      calculator.S en la FRAM: desde ahí el procesador busca las
#      instrucciones en la FRAM.
#
# calculator_inicio lo define el linker script (fram_boot.ld) justo antes de
# calculator.o (.text), porque la etiqueta "calculator" no es global.

.equ FRAM_BASE, 0x480000      # FRAM: 0x00480000 - 0x0049FFFF
.equ BRAM_SIZE, 0x1000        # bram.v: 1024 palabras de 32 bits

.section .text
.globl fram_boot

fram_boot:
    li   sp, 0x1000
    la   a0, msg_copia
    call putstring

    # ---- Copia BRAM -> FRAM ----
    li   t0, 0
    li   t1, FRAM_BASE
    li   t2, BRAM_SIZE
copia:
    lw   t3, 0(t0)
    sw   t3, 0(t1)
    addi t0, t0, 4
    addi t1, t1, 4
    bltu t0, t2, copia

    # ---- Verificación (sin llamadas entre la copia y la verificación,
    #      para que la pila de la BRAM no cambie) ----
    li   t0, 0
    li   t1, FRAM_BASE
verifica:
    lw   t3, 0(t0)
    lw   t4, 0(t1)
    bne  t3, t4, error_copia
    addi t0, t0, 4
    addi t1, t1, 4
    bltu t0, t2, verifica

    la   a0, msg_salto
    call putstring

    # ---- Salto a calculator en la FRAM ----
    la   t0, calculator_inicio   # dirección en la BRAM
    li   t1, FRAM_BASE
    add  t0, t0, t1
    jr   t0

error_copia:
    la   a0, msg_error
    call putstring
fin_error:
    j    fin_error

.section .data
msg_copia:
    .asciz "\n\rBRAM -> FRAM: copiando 4 KB..."
msg_salto:
    .asciz " OK\n\rEjecutando calculator desde la FRAM\n\r"
msg_error:
    .asciz " ERROR: la copia no coincide\n\r"
