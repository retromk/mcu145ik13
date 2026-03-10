#!/usr/bin/env python3
"""Generate HLS C++ ROM tables from Verilog ROM files."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "hls" / "rom_tables.hpp"
CHIPS = (1302, 1303, 1306)


def parse_mrom(path: Path) -> dict[int, int]:
    text = path.read_text(encoding="ascii")
    out: dict[int, int] = {}
    for m in re.finditer(r"\b8'd(\d+)\s*:\s*dout\s*=\s*32'h([0-9A-Fa-f]{8})", text):
        out[int(m.group(1))] = int(m.group(2), 16)
    return out


def parse_urom(path: Path) -> dict[int, int]:
    text = path.read_text(encoding="ascii")
    out: dict[int, int] = {}
    for m in re.finditer(r"\b7'd(\d+)\s*:\s*dout\s*=\s*32'h([0-9A-Fa-f]{8})", text):
        out[int(m.group(1))] = int(m.group(2), 16)
    return out


def parse_srom(path: Path) -> dict[int, list[int]]:
    text = path.read_text(encoding="ascii")
    out: dict[int, list[int]] = {}
    pat = re.compile(
        r"\b7'd(\d+)\s*:\s*begin\s*\{col0,col1,col2,col3,col4,col5,col6,col7,col8\}\s*=\s*\{([^}]*)\};\s*end",
        re.IGNORECASE,
    )
    for m in pat.finditer(text):
        addr = int(m.group(1))
        vals = re.findall(r"8'h([0-9A-Fa-f]{2})", m.group(2))
        if len(vals) != 9:
            raise RuntimeError(f"{path}: addr {addr}: expected 9 bytes, got {len(vals)}")
        out[addr] = [int(v, 16) for v in vals]
    return out


def fmt_u32(v: int) -> str:
    return f"0x{v:08X}u"


def fmt_u8(v: int) -> str:
    return f"0x{v:02X}u"


def emit_u32_table(name: str, rows: list[list[int]], width: int) -> list[str]:
    lines: list[str] = [f"static constexpr uint32_t {name}[{len(rows)}][{width}] = {{"]
    for r, row in enumerate(rows):
        vals = ", ".join(fmt_u32(v) for v in row)
        comma = "," if r + 1 < len(rows) else ""
        lines.append(f"  {{{vals}}}{comma}")
    lines.append("};")
    return lines


def emit_u8_3d_table(name: str, rows: list[list[list[int]]], w1: int, w2: int) -> list[str]:
    lines: list[str] = [f"static constexpr uint8_t {name}[{len(rows)}][{w1}][{w2}] = {{"]
    for c, chip in enumerate(rows):
        lines.append("  {")
        for a, addr in enumerate(chip):
            vals = ", ".join(fmt_u8(v) for v in addr)
            comma = "," if a + 1 < len(chip) else ""
            lines.append(f"    {{{vals}}}{comma}")
        comma_chip = "," if c + 1 < len(rows) else ""
        lines.append(f"  }}{comma_chip}")
    lines.append("};")
    return lines


def generate() -> None:
    mrom_rows: list[list[int]] = []
    urom_rows: list[list[int]] = []
    srom_rows: list[list[list[int]]] = []

    for chip in CHIPS:
        mrom_map = parse_mrom(ROOT / f"rom_mrom_{chip}.v")
        urom_map = parse_urom(ROOT / f"rom_urom_{chip}.v")
        srom_map = parse_srom(ROOT / f"rom_srom_{chip}.v")

        mrom_row = [0] * 256
        for addr, v in mrom_map.items():
            mrom_row[addr] = v
        mrom_rows.append(mrom_row)

        urom_row = [0] * 128
        for addr, v in urom_map.items():
            urom_row[addr] = v
        urom_rows.append(urom_row)

        srom_chip = [[0] * 9 for _ in range(128)]
        for addr, cols in srom_map.items():
            srom_chip[addr] = cols
        srom_rows.append(srom_chip)

    lines: list[str] = []
    lines += [
        "#pragma once",
        "",
        "#include <cstdint>",
        "",
        "namespace mk61hls {",
        "",
        "inline constexpr int CHIP_COUNT = 3;",
        "inline constexpr int MROM_DEPTH = 256;",
        "inline constexpr int UROM_DEPTH = 128;",
        "inline constexpr int SROM_DEPTH = 128;",
        "inline constexpr int SROM_COLS = 9;",
        "",
    ]

    lines += emit_u32_table("MROM_TABLE", mrom_rows, 256)
    lines += [""]
    lines += emit_u32_table("UROM_TABLE", urom_rows, 128)
    lines += [""]
    lines += emit_u8_3d_table("SROM_TABLE", srom_rows, 128, 9)
    lines += [""]
    lines += [
        "inline constexpr int chip_to_index(int chip) {",
        "  return (chip == 1302) ? 0 : (chip == 1303) ? 1 : (chip == 1306) ? 2 : 0;",
        "}",
        "",
        "inline uint32_t mrom_lookup(int chip, uint8_t addr) {",
        "  return MROM_TABLE[chip_to_index(chip)][addr];",
        "}",
        "",
        "inline uint32_t urom_lookup(int chip, uint8_t addr) {",
        "  return UROM_TABLE[chip_to_index(chip)][addr & 0x7Fu];",
        "}",
        "",
        "inline uint8_t srom_lookup(int chip, uint8_t addr, uint8_t col) {",
        "  return SROM_TABLE[chip_to_index(chip)][addr & 0x7Fu][col % SROM_COLS];",
        "}",
        "",
        "inline uint32_t boot_command_for_chip(int chip) {",
        "  return mrom_lookup(chip, 0);",
        "}",
        "",
        "} // namespace mk61hls",
    ]

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines) + "\n", encoding="ascii")


def main() -> int:
    generate()
    print(f"Generated: {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
