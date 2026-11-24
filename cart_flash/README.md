# Nota: esto estaba ubicado originalmente en FPGBC_digital_UN/test/min_soc por que es probable que la ejecución de las pruebas no funcione

# Calculadora FPGBC desde cartucho

La CPU FemtoRV32 ejecuta la calculadora ya grabada en el cartucho.
La BRAM solo contiene pila y datos, sin firmware precargado.

Desde esta carpeta:

```sh
make sim_cart_calc
make check_synth
make build_cart_calc
make load_cart_calc
```

`make configure_cart_calc` genera y carga en una sola orden.
Bitstream: `build/gw2ar_eq144_calc/SOC.fs`. Los archivos generados no se
versionan. Las herramientas se buscan en el entorno Pixi o en PATH.
No se reprograma la flash del cartucho.

La imagen de referencia está en `firmware/cart_calc/` desde la raíz del
repositorio. `check_cart_image` comprueba que GB y HEX coincidan, que la
pila inicial sea 0x2000 y que el programa quepa en la ventana ROM.

Mapa CPU: ROM `0x0000..0x0FFF`, RAM `0x1000..0x2FFF`, UART `0x00400000`,
raíz `0x00410000`, binario→BCD `0x00440000`, BCD→binario `0x00460000`.
Multiplicación y división se ejecutan por software en el binario original.
Las FSM conservan DONE y resultado hasta la siguiente operación.

UART: 57600, 8N1, sin control de flujo. Reset activo bajo en pin FPGA 120.
Tras pulsar y soltar reset debe aparecer `Number:`.
Introducir un número y Enter (solo CR), luego `+`, `*`, `/` sin Enter,
y después el segundo número y Enter. `^` calcula la raíz del primer número.
Esperar el eco de cada cifra; no hay FIFO UART.

La simulación usa el binario original, envenena la RAM para comprobar que
no contiene código y verifica las operaciones 2+3, 7*6, 9/3 y raíz de 16.
Incluye pruebas del lector y de DONE persistente. La síntesis no sustituye
la validación eléctrica y temporal en placa.
