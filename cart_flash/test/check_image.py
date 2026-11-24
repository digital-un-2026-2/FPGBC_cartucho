#!/usr/bin/env python3
"""Valida la imagen ya grabada; no la modifica ni la incluye en la BRAM."""
from pathlib import Path
import hashlib


def load_image():
    root = Path(__file__).resolve().parents[4]
    image_dir = root / "firmware" / "cart_calc"
    rom = (image_dir / "firmware_mbc5.gb").read_bytes()
    reference = b"".join(int(w, 16).to_bytes(4, "little")
                         for w in (image_dir / "firmware.hex").read_text().split())
    if len(rom) < 0x4000 or not reference or not rom.startswith(reference):
        raise ValueError("firmware_mbc5.gb no coincide con firmware.hex")
    if rom[:8] != bytes.fromhex("3721000037210000"):
        raise ValueError("No es la calculadora esperada con pila inicial 0x2000")
    if len(reference) > 0x4000 or any(reference[0x1000:]):
        raise ValueError("El programa excede la ventana XIP de 4 KiB")
    print("SHA256 cartucho:", hashlib.sha256(rom).hexdigest(), flush=True)
    return rom


if __name__ == "__main__":
    load_image()
    print("PASS imagen: código en 0000..0FFF y pila inicial 2000.")
