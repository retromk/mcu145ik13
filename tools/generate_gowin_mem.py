#!/usr/bin/env python3
"""Generate .mem images for Gowin BRAM-backed ROM mode from Verilog case tables."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "rom_data"

MROM_UROM_RE = re.compile(
    r"\b\d+'d(?P<addr>\d+)\s*:\s*dout\s*=\s*32'h(?P<word>[0-9a-fA-F_]+)\s*;"
)
SROM_RE = re.compile(
    r"\b7'd(?P<addr>\d+)\s*:\s*begin\s*\{col0,col1,col2,col3,col4,col5,col6,col7,col8\}\s*=\s*"
    r"\{(?P<vals>[^}]+)\}\s*;\s*end"
)
HEX8_RE = re.compile(r"8'h([0-9a-fA-F_]+)")


def normalize_hex(raw: str, width_nibbles: int) -> str:
    return f"{int(raw.replace('_', ''), 16):0{width_nibbles}x}"


def write_lines(path: Path, lines: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="ascii")


def gen_u32_mem(src: Path, depth: int, out_name: str) -> None:
    words = ["00000000"] * depth
    text = src.read_text(encoding="ascii")
    for m in MROM_UROM_RE.finditer(text):
        addr = int(m.group("addr"), 10)
        if 0 <= addr < depth:
            words[addr] = normalize_hex(m.group("word"), 8)
    write_lines(OUT_DIR / out_name, words)


def gen_s72_mem(src: Path, out_name: str) -> None:
    depth = 128
    words = ["0" * 18] * depth
    text = src.read_text(encoding="ascii")
    for m in SROM_RE.finditer(text):
        addr = int(m.group("addr"), 10)
        vals = HEX8_RE.findall(m.group("vals"))
        if len(vals) != 9 or not (0 <= addr < depth):
            continue
        byte_vals = [normalize_hex(v, 2) for v in vals]
        words[addr] = "".join(byte_vals)
    write_lines(OUT_DIR / out_name, words)


def main() -> int:
    gen_u32_mem(ROOT / "rom_mrom_1302.v", 256, "mrom_1302.mem")
    gen_u32_mem(ROOT / "rom_mrom_1303.v", 256, "mrom_1303.mem")
    gen_u32_mem(ROOT / "rom_mrom_1306.v", 256, "mrom_1306.mem")
    gen_u32_mem(ROOT / "rom_urom_1302.v", 128, "urom_1302.mem")
    gen_u32_mem(ROOT / "rom_urom_1303.v", 128, "urom_1303.mem")
    gen_u32_mem(ROOT / "rom_urom_1306.v", 128, "urom_1306.mem")
    gen_s72_mem(ROOT / "rom_srom_1302.v", "srom_1302.mem")
    gen_s72_mem(ROOT / "rom_srom_1303.v", "srom_1303.mem")
    gen_s72_mem(ROOT / "rom_srom_1306.v", "srom_1306.mem")
    print(f"[OK] generated Gowin ROM mem files in {OUT_DIR}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
