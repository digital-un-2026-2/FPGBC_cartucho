#!/usr/bin/env python3
"""Ejecuta el binario original del cartucho, no un firmware recompilado."""
import argparse
from pathlib import Path
import subprocess
from check_image import load_image

p = argparse.ArgumentParser(description=__doc__)
p.add_argument("--iverilog", required=True)
p.add_argument("--vvp", required=True)
p.add_argument("sources", nargs="+")
args = p.parse_args()
here = Path(__file__).resolve().parent
build = here.parent / "build" / "sim"
build.mkdir(parents=True, exist_ok=True)
rom = load_image()
(build / "cart_rom.hex").write_text(
    "".join(f"{v:02x}\n" for v in rom[:0x4000]))
for top in ("tb_cart_memory", "tb_math_done"):
    subprocess.run([args.iverilog, "-g2012", "-s", top,
                    "-o", str(build / f"{top}.out"), *args.sources,
                    str(here / f"{top}.v")], check=True)
    subprocess.run([args.vvp, str(build / f"{top}.out")], check=True)
subprocess.run([args.iverilog, "-g2012", "-s", "tb_cart_calc",
                "-o", str(build / "simulation.out"), *args.sources,
                str(here / "tb_cart_calc.v")], check=True)
subprocess.run([args.vvp, str(build / "simulation.out"),
                f"+ROM_HEX={build / 'cart_rom.hex'}"],
               cwd=here.parent, check=True)
