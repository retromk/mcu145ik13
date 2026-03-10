#!/usr/bin/env python3
"""Generate pure-VHDL IK13 ROM entities from existing Verilog ROM tables."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VHDL = ROOT / "vhdl"
CHIPS = (1302, 1303, 1306)


def parse_mrom(path: Path) -> tuple[dict[int, str], str]:
    text = path.read_text(encoding="ascii")
    data: dict[int, str] = {}
    default = "00000000"
    for m in re.finditer(r"\b8'd(\d+)\s*:\s*dout\s*=\s*32'h([0-9A-Fa-f]{8})", text):
        data[int(m.group(1))] = m.group(2).upper()
    dm = re.search(r"default\s*:\s*dout\s*=\s*32'h([0-9A-Fa-f]{8})", text)
    if dm:
        default = dm.group(1).upper()
    return data, default


def parse_urom(path: Path) -> tuple[dict[int, str], str]:
    text = path.read_text(encoding="ascii")
    data: dict[int, str] = {}
    default = "00000000"
    for m in re.finditer(r"\b7'd(\d+)\s*:\s*dout\s*=\s*32'h([0-9A-Fa-f]{8})", text):
        data[int(m.group(1))] = m.group(2).upper()
    dm = re.search(r"default\s*:\s*dout\s*=\s*32'h([0-9A-Fa-f]{8})", text)
    if dm:
        default = dm.group(1).upper()
    return data, default


def parse_srom(path: Path) -> tuple[dict[int, list[str]], list[str]]:
    text = path.read_text(encoding="ascii")
    data: dict[int, list[str]] = {}
    default = ["00"] * 9
    pat = re.compile(
        r"\b7'd(\d+)\s*:\s*begin\s*\{col0,col1,col2,col3,col4,col5,col6,col7,col8\}\s*=\s*\{([^}]*)\};\s*end",
        re.IGNORECASE,
    )
    for m in pat.finditer(text):
        addr = int(m.group(1))
        vals = re.findall(r"8'h([0-9A-Fa-f]{2})", m.group(2))
        if len(vals) != 9:
            raise RuntimeError(f"{path}: addr {addr}: expected 9 bytes, got {len(vals)}")
        data[addr] = [v.upper() for v in vals]
    dm = re.search(
        r"default\s*:\s*begin\s*\{col0,col1,col2,col3,col4,col5,col6,col7,col8\}\s*=\s*\{([^}]*)\};\s*end",
        text,
        re.IGNORECASE,
    )
    if dm:
        vals = re.findall(r"8'h([0-9A-Fa-f]{2})", dm.group(1))
        if len(vals) == 9:
            default = [v.upper() for v in vals]
    return data, default


def generate() -> None:
    mrom: dict[int, tuple[dict[int, str], str]] = {}
    urom: dict[int, tuple[dict[int, str], str]] = {}
    srom: dict[int, tuple[dict[int, list[str]], list[str]]] = {}

    for chip in CHIPS:
        mrom[chip] = parse_mrom(ROOT / f"rom_mrom_{chip}.v")
        urom[chip] = parse_urom(ROOT / f"rom_urom_{chip}.v")
        srom[chip] = parse_srom(ROOT / f"rom_srom_{chip}.v")

    VHDL.mkdir(parents=True, exist_ok=True)

    lines: list[str] = []
    lines += [
        "library ieee;",
        "use ieee.std_logic_1164.all;",
        "use ieee.numeric_std.all;",
        "",
        "entity ik13_mrom is",
        "  generic (",
        "    CHIP : integer := 1302",
        "  );",
        "  port (",
        "    addr : in  std_logic_vector(7 downto 0);",
        "    dout : out std_logic_vector(31 downto 0)",
        "  );",
        "end entity ik13_mrom;",
        "",
        "architecture rtl of ik13_mrom is",
        "  function slv_to_nat01(slv : std_logic_vector) return integer is",
        "    variable u : unsigned(slv'range);",
        "  begin",
        "    for i in slv'range loop",
        "      if slv(i) = '1' then",
        "        u(i) := '1';",
        "      else",
        "        u(i) := '0';",
        "      end if;",
        "    end loop;",
        "    return to_integer(u);",
        "  end function;",
        "begin",
        "  process (all)",
        "    variable a : integer;",
        "  begin",
        "    a := slv_to_nat01(addr);",
        "    dout <= x\"00000000\";",
    ]
    for chip in CHIPS:
        data, default = mrom[chip]
        cond = "if" if chip == CHIPS[0] else "elsif"
        lines += [f"    {cond} CHIP = {chip} then", "      case a is"]
        for addr in sorted(data):
            lines.append(f"        when {addr:3d} => dout <= x\"{data[addr]}\";")
        lines += [f"        when others => dout <= x\"{default}\";", "      end case;"]
    lines += [
        "    else",
        "      dout <= x\"00000000\";",
        "    end if;",
        "  end process;",
        "end architecture rtl;",
    ]
    (VHDL / "ik13_mrom.vhd").write_text("\n".join(lines) + "\n", encoding="ascii")

    lines = []
    lines += [
        "library ieee;",
        "use ieee.std_logic_1164.all;",
        "use ieee.numeric_std.all;",
        "",
        "entity ik13_urom is",
        "  generic (",
        "    CHIP : integer := 1302",
        "  );",
        "  port (",
        "    addr : in  std_logic_vector(6 downto 0);",
        "    dout : out std_logic_vector(31 downto 0)",
        "  );",
        "end entity ik13_urom;",
        "",
        "architecture rtl of ik13_urom is",
        "  function slv_to_nat01(slv : std_logic_vector) return integer is",
        "    variable u : unsigned(slv'range);",
        "  begin",
        "    for i in slv'range loop",
        "      if slv(i) = '1' then",
        "        u(i) := '1';",
        "      else",
        "        u(i) := '0';",
        "      end if;",
        "    end loop;",
        "    return to_integer(u);",
        "  end function;",
        "begin",
        "  process (all)",
        "    variable a : integer;",
        "  begin",
        "    a := slv_to_nat01(addr);",
        "    dout <= x\"00000000\";",
    ]
    for chip in CHIPS:
        data, default = urom[chip]
        cond = "if" if chip == CHIPS[0] else "elsif"
        lines += [f"    {cond} CHIP = {chip} then", "      case a is"]
        for addr in sorted(data):
            lines.append(f"        when {addr:3d} => dout <= x\"{data[addr]}\";")
        lines += [f"        when others => dout <= x\"{default}\";", "      end case;"]
    lines += [
        "    else",
        "      dout <= x\"00000000\";",
        "    end if;",
        "  end process;",
        "end architecture rtl;",
    ]
    (VHDL / "ik13_urom.vhd").write_text("\n".join(lines) + "\n", encoding="ascii")

    lines = []
    lines += [
        "library ieee;",
        "use ieee.std_logic_1164.all;",
        "use ieee.numeric_std.all;",
        "",
        "entity ik13_srom is",
        "  generic (",
        "    CHIP : integer := 1302",
        "  );",
        "  port (",
        "    addr : in  std_logic_vector(6 downto 0);",
        "    col0 : out std_logic_vector(7 downto 0);",
        "    col1 : out std_logic_vector(7 downto 0);",
        "    col2 : out std_logic_vector(7 downto 0);",
        "    col3 : out std_logic_vector(7 downto 0);",
        "    col4 : out std_logic_vector(7 downto 0);",
        "    col5 : out std_logic_vector(7 downto 0);",
        "    col6 : out std_logic_vector(7 downto 0);",
        "    col7 : out std_logic_vector(7 downto 0);",
        "    col8 : out std_logic_vector(7 downto 0)",
        "  );",
        "end entity ik13_srom;",
        "",
        "architecture rtl of ik13_srom is",
        "  function slv_to_nat01(slv : std_logic_vector) return integer is",
        "    variable u : unsigned(slv'range);",
        "  begin",
        "    for i in slv'range loop",
        "      if slv(i) = '1' then",
        "        u(i) := '1';",
        "      else",
        "        u(i) := '0';",
        "      end if;",
        "    end loop;",
        "    return to_integer(u);",
        "  end function;",
        "begin",
        "  process (all)",
        "    variable a : integer;",
        "  begin",
        "    a := slv_to_nat01(addr);",
        "    col0 <= x\"00\"; col1 <= x\"00\"; col2 <= x\"00\"; col3 <= x\"00\"; col4 <= x\"00\";",
        "    col5 <= x\"00\"; col6 <= x\"00\"; col7 <= x\"00\"; col8 <= x\"00\";",
    ]
    for chip in CHIPS:
        data, default = srom[chip]
        cond = "if" if chip == CHIPS[0] else "elsif"
        lines += [f"    {cond} CHIP = {chip} then", "      case a is"]
        for addr in sorted(data):
            vals = data[addr]
            lines.append(
                f"        when {addr:3d} => col0 <= x\"{vals[0]}\"; col1 <= x\"{vals[1]}\"; col2 <= x\"{vals[2]}\"; col3 <= x\"{vals[3]}\"; "
                f"col4 <= x\"{vals[4]}\"; col5 <= x\"{vals[5]}\"; col6 <= x\"{vals[6]}\"; col7 <= x\"{vals[7]}\"; col8 <= x\"{vals[8]}\";"
            )
        d = default
        lines += [
            f"        when others => col0 <= x\"{d[0]}\"; col1 <= x\"{d[1]}\"; col2 <= x\"{d[2]}\"; col3 <= x\"{d[3]}\"; "
            f"col4 <= x\"{d[4]}\"; col5 <= x\"{d[5]}\"; col6 <= x\"{d[6]}\"; col7 <= x\"{d[7]}\"; col8 <= x\"{d[8]}\";",
            "      end case;",
        ]
    lines += [
        "    else",
        "      col0 <= x\"00\"; col1 <= x\"00\"; col2 <= x\"00\"; col3 <= x\"00\"; col4 <= x\"00\";",
        "      col5 <= x\"00\"; col6 <= x\"00\"; col7 <= x\"00\"; col8 <= x\"00\";",
        "    end if;",
        "  end process;",
        "end architecture rtl;",
    ]
    (VHDL / "ik13_srom.vhd").write_text("\n".join(lines) + "\n", encoding="ascii")


def main() -> int:
    generate()
    print("Generated VHDL ROMs:")
    print(f"  {VHDL / 'ik13_mrom.vhd'}")
    print(f"  {VHDL / 'ik13_urom.vhd'}")
    print(f"  {VHDL / 'ik13_srom.vhd'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
