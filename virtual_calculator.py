#!/usr/bin/env python3
"""Virtual calculator runner for MK-61 RTL testbench (emu145-compatible)."""

from __future__ import annotations

import argparse
import csv
import re
import shutil
import subprocess
import sys
from bisect import bisect_left
from pathlib import Path
from typing import Dict, Iterable, List, Sequence, Tuple

ROOT = Path(__file__).resolve().parent
SIM_PATH = ROOT / "sim"
TRACE_PATH = ROOT / "rtl_trace.csv"
TRACE_VHDL_PATH = ROOT / "rtl_trace_vhdl.csv"
TRACE_HLS_PATH = ROOT / "rtl_trace_hls.csv"
VVP_LOG_PATH = ROOT / "logs" / "virtual_vvp.log"
KEY_EVENTS_PATH = ROOT / "logs" / "virtual_keys.txt"
BUTTON_EVENTS_PATH = ROOT / "logs" / "virtual_buttons.txt"
VHDL_RUN_SCRIPT = ROOT / "vhdl" / "run_ghdl.sh"
HLS_RUN_SCRIPT = ROOT / "hls" / "run_hls.sh"

RTL_FILES: Sequence[str] = (
    "rom_mrom_1302.v",
    "rom_mrom_1303.v",
    "rom_mrom_1306.v",
    "rom_urom_1302.v",
    "rom_urom_1303.v",
    "rom_urom_1306.v",
    "rom_srom_1302.v",
    "rom_srom_1303.v",
    "rom_srom_1306.v",
    "rom_wrappers.v",
    "cmem_shift.v",
    "mcu145ik13_core.v",
    "mk61_top.v",
    "tb_mk61.v",
)

LOW_LEVEL_TOKENS = {
    "K1": (1, 0),
    "K2": (0, 1),
    "K12": (1, 1),
    "NONE": (0, 0),
    "_": (0, 0),
    "PAUSE": (0, 0),
}

# Canonical key metadata extracted from emu145:
# - pmkemu/mainwindow.cpp (button scan order and B_row_d mapping)
# - pmkemu/mainwindow.ui + pmkemu/buttons/_Nr.png (visible legends)
EMU145_BUTTON_META = (
    ("B_1_2",  "0",    "10^x",   "NOP"),
    ("B_1_3",  "1",    "e^x",    ""),
    ("B_1_4",  "2",    "lg",     ""),
    ("B_1_5",  "3",    "ln",     ""),
    ("B_1_6",  "4",    "asin",   "|x|"),
    ("B_1_7",  "5",    "acos",   "ZN"),
    ("B_1_8",  "6",    "atan",   ""),
    ("B_1_9",  "7",    "sin",    "[x]"),
    ("B_1_10", "8",    "cos",    "{x}"),
    ("B_1_11", "9",    "tg",     "max"),
    ("B_2_2",  "+",    "pi",     ""),
    ("B_2_3",  "-",    "sqrt",   ""),
    ("B_2_4",  "*",    "x^2",    ""),
    ("B_2_5",  "/",    "1/x",    ""),
    ("B_2_6",  "",     "x^y",    ""),
    ("B_2_7",  ".",    "cycle",  "lambda"),
    ("B_2_8",  "/-/",  "aut",    "V"),
    ("B_2_9",  "VP",   "PRG",    "xor"),
    ("B_2_10", "CX",   "CF",     "INV"),
    ("B_2_11", "V",    "BX",     "SCH"),
    ("B_3_2",  "SP",   "x!=0",   ""),
    ("B_3_3",  "BP",   "L2",     ""),
    ("B_3_4",  "V/O",  "x>=0",   ""),
    ("B_3_5",  "PP",   "L3",     ""),
    ("B_3_6",  "X->P", "L1",     ""),
    ("B_3_7",  "SHG>", "x<0",    ""),
    ("B_3_8",  "P->X", "L0",     ""),
    ("B_3_9",  "<SHG", "x=0",    ""),
    ("B_3_10", "K",    "",       ""),
    ("B_3_11", "F",    "",       ""),
)

# Matrix and semantic aliases are resolved to canonical B_<row>_<dnum> tokens.
# Values may contain one or more button tokens; multi-token values are expanded
# left-to-right (e.g. SIN -> F B_1_9).
EMU145_SEMANTIC_ALIASES = {
    # numeric row (main legends)
    "0": "B_1_2",
    "1": "B_1_3",
    "2": "B_1_4",
    "3": "B_1_5",
    "4": "B_1_6",
    "5": "B_1_7",
    "6": "B_1_8",
    "7": "B_1_9",
    "8": "B_1_10",
    "9": "B_1_11",
    "ZERO": "B_1_2",
    "ONE": "B_1_3",
    "TWO": "B_1_4",
    "THREE": "B_1_5",
    "FOUR": "B_1_6",
    "FIVE": "B_1_7",
    "SIX": "B_1_8",
    "SEVEN": "B_1_9",
    "EIGHT": "B_1_10",
    "NINE": "B_1_11",
    # physical main legends (direct)
    "VP": "B_2_9",
    "CX": "B_2_10",
    "V": "B_2_11",
    "SP": "B_3_2",
    "BP": "B_3_3",
    "VO": "B_3_4",
    "V_O": "B_3_4",
    "PP": "B_3_5",
    "X2P": "B_3_6",
    "X_TO_P": "B_3_6",
    "P2X": "B_3_8",
    "P_TO_X": "B_3_8",
    "SHG_FWD": "B_3_7",
    "SHG_RIGHT": "B_3_7",
    "SHG>": "B_3_7",
    "SHG_BACK": "B_3_9",
    "SHG_LEFT": "B_3_9",
    "<SHG": "B_3_9",
    "F": "B_3_11",
    "K": "B_3_10",
    # basic arithmetic/edit (direct)
    "+": "B_2_2",
    "-": "B_2_3",
    "*": "B_2_4",
    "/": "B_2_5",
    ".": "B_2_7",
    ",": "B_2_7",
    "/-/": "B_2_8",
    "PLUS": "B_2_2",
    "ADD": "B_2_2",
    "MINUS": "B_2_3",
    "SUB": "B_2_3",
    "MUL": "B_2_4",
    "MULT": "B_2_4",
    "TIMES": "B_2_4",
    "DIV": "B_2_5",
    "DOT": "B_2_7",
    "COMMA": "B_2_7",
    "CLR": "B_2_10",
    "CLEAR": "B_2_10",
    "ENTER": "B_2_9",
    "PUSH": "B_2_9",
    "RUN": "B_3_2",
    "STOP": "B_3_2",
    "RUNSTOP": "B_3_2",
    # expression-friendly convenience on RPN keyboard
    "=": "B_2_9",
    "EQUAL": "B_2_9",
    "EQUALS": "B_2_9",
    "EQ": "B_2_9",
    # yellow legends (F + key)
    "10^X": "F B_1_2",
    "TEN_POW_X": "F B_1_2",
    "E^X": "F B_1_3",
    "EXP": "F B_1_3",
    "LG": "F B_1_4",
    "LN": "F B_1_5",
    "ASIN": "F B_1_6",
    "ACOS": "F B_1_7",
    "ATAN": "F B_1_8",
    "SIN": "F B_1_9",
    "COS": "F B_1_10",
    "TG": "F B_1_11",
    "TAN": "F B_1_11",
    "PI": "F B_2_2",
    "SQRT": "F B_2_3",
    "X^2": "F B_2_4",
    "X2": "F B_2_4",
    "SQR": "F B_2_4",
    "1/X": "F B_2_5",
    "INVX": "F B_2_5",
    "X^Y": "F B_2_6",
    "POW": "F B_2_6",
    "POWXY": "F B_2_6",
    "CYCLE": "F B_2_7",
    "AUT": "F B_2_8",
    "PRG": "F B_2_9",
    "CF": "F B_2_10",
    "BX": "F B_2_11",
    "X!=0": "F B_3_2",
    "X_NE_0": "F B_3_2",
    "X>=0": "F B_3_4",
    "X_GE_0": "F B_3_4",
    "X<0": "F B_3_7",
    "X_LT_0": "F B_3_7",
    "X=0": "F B_3_9",
    "X_EQ_0": "F B_3_9",
    "L0": "F B_3_8",
    "L1": "F B_3_6",
    "L2": "F B_3_3",
    "L3": "F B_3_5",
    # blue legends (K + key)
    "|X|": "K B_1_6",
    "ABS": "K B_1_6",
    "ZN": "K B_1_7",
    "[X]": "K B_1_9",
    "{X}": "K B_1_10",
    "MAX": "K B_1_11",
    "LAMBDA": "K B_2_7",
    "XOR": "K B_2_9",
    "INV": "K B_2_10",
    "SCH": "K B_2_11",
}

PRESETS: Dict[str, Dict[str, object]] = {
    "boot_probe": {
        "description": "Single key probe after init",
        "keys": "1",
        "timing": {"cycles": 320000, "start": 100000, "gap": 90000, "frames": 6},
    },
    "scan_row1": {
        "description": "Sweep row 1 (D2..D11)",
        "keys": "B_1_2 B_1_3 B_1_4 B_1_5 B_1_6 B_1_7 B_1_8 B_1_9 B_1_10 B_1_11",
        "timing": {"cycles": 1150000, "start": 100000, "gap": 90000, "frames": 8},
    },
    "scan_all": {
        "description": "Sweep all 30 matrix buttons",
        "keys": "B_1_2 B_1_3 B_1_4 B_1_5 B_1_6 B_1_7 B_1_8 B_1_9 B_1_10 B_1_11 "
                "B_2_2 B_2_3 B_2_4 B_2_5 B_2_6 B_2_7 B_2_8 B_2_9 B_2_10 B_2_11 "
                "B_3_2 B_3_3 B_3_4 B_3_5 B_3_6 B_3_7 B_3_8 B_3_9 B_3_10 B_3_11",
        "timing": {"cycles": 3000000, "start": 100000, "gap": 90000, "frames": 8},
    },
    "calc_1_2_plus_3_eq": {
        "description": "Arithmetic demo: 12 + 3 -> 15 (legacy preset name)",
        "keys": "1 2 V + 3 +",
        "timing": {"cycles": 760000, "start": 100000, "gap": 90000, "frames": 6},
    },
    "calc_1_enter_2_plus": {
        "description": "Arithmetic demo: 1 + 2 -> 3",
        "keys": "1 V + 2 +",
        "timing": {"cycles": 760000, "start": 100000, "gap": 90000, "frames": 6},
    },
    "calc_12_enter_3_plus": {
        "description": "Arithmetic demo: 12 + 3 -> 15 (stable timing/profile)",
        "keys": "1 2 V + 3 +",
        "timing": {"cycles": 760000, "start": 100000, "gap": 90000, "frames": 6},
    },
    "func_sin_1": {
        "description": "Function demo: SIN(0) -> 0",
        "keys": "0 SIN",
        "timing": {"cycles": 560000, "start": 100000, "gap": 90000, "frames": 6},
    },
}

EMU_SEGMENTS = "0123456789-LCrE "
MODE_MAP = {"rad": 0, "deg": 1, "grd": 2}

DEFAULT_CYCLES = 320000
DEFAULT_START = 100000
DEFAULT_HOLD = 16
DEFAULT_GAP = 12000
DEFAULT_FRAMES = 5


class CommandError(RuntimeError):
    pass


def run_cmd(cmd: Sequence[str], *, cwd: Path = ROOT, tee_to: Path | None = None) -> subprocess.CompletedProcess[str]:
    proc = subprocess.run(
        list(cmd),
        cwd=cwd,
        text=True,
        capture_output=True,
        check=False,
    )
    if tee_to is not None:
        tee_to.parent.mkdir(parents=True, exist_ok=True)
        tee_to.write_text(proc.stdout + proc.stderr, encoding="utf-8")
    if proc.returncode != 0:
        raise CommandError(
            f"Command failed ({proc.returncode}): {' '.join(cmd)}\n"
            f"stdout:\n{proc.stdout}\n"
            f"stderr:\n{proc.stderr}"
        )
    return proc


def compile_sim() -> None:
    cmd = ["iverilog", "-g2005", "-o", str(SIM_PATH), *RTL_FILES]
    run_cmd(cmd)


def split_tokens(raw: str) -> List[str]:
    return [t.strip() for t in re.split(r"[\s,;]+", raw) if t.strip()]


def split_alias_tokens(raw: str) -> List[str]:
    return [t.strip() for t in re.split(r"[\s,;+]+", raw) if t.strip()]


def parse_low_level_token(token: str) -> Tuple[int, int] | None:
    return LOW_LEVEL_TOKENS.get(token.upper())


def parse_button_token(token: str) -> Tuple[int, int] | None:
    t = token.strip().upper()
    m = re.fullmatch(r"(?:B_)?([1-3])_([2-9]|1[01])", t)
    if m:
        return int(m.group(1)), int(m.group(2))
    m = re.fullmatch(r"R([1-3])D([2-9]|1[01])", t)
    if m:
        return int(m.group(1)), int(m.group(2))
    m = re.fullmatch(r"([1-3]):([2-9]|1[01])", t)
    if m:
        return int(m.group(1)), int(m.group(2))
    return None


def build_default_aliases() -> Dict[str, str]:
    aliases: Dict[str, str] = {}

    for row in range(1, 4):
        for dnum in range(2, 12):
            col = dnum - 2
            idx = (row - 1) * 10 + col
            canonical = f"B_{row}_{dnum}"
            for alias in (
                canonical,
                f"R{row}D{dnum}",
                f"{row}:{dnum}",
                f"KEY_{row}_{dnum}",
                f"POS{idx:02d}",
                f"K{idx:02d}",
            ):
                aliases[alias.upper()] = canonical

    for alias, target in EMU145_SEMANTIC_ALIASES.items():
        aliases[alias.upper()] = target.upper()

    return aliases


def parse_alias_spec(spec: str, known_aliases: Dict[str, str]) -> Tuple[str, str]:
    if "=" not in spec:
        raise ValueError(f"Invalid alias '{spec}': expected NAME=TOKEN or NAME=TOKEN1+TOKEN2")
    left, right = spec.split("=", 1)
    name = left.strip().upper()
    if not name:
        raise ValueError(f"Invalid alias '{spec}': empty alias name")

    parts = [p.upper() for p in split_alias_tokens(right.strip())]
    if not parts:
        raise ValueError(f"Invalid alias '{spec}': empty alias target")

    for tok in parts:
        if parse_button_token(tok) is not None:
            continue
        if parse_low_level_token(tok) is not None:
            continue
        if tok in known_aliases:
            continue
        raise ValueError(f"Invalid alias target token '{tok}' in '{spec}'")

    return name, " ".join(parts)


def load_aliases_file(path: Path, aliases: Dict[str, str]) -> None:
    if not path.exists():
        raise FileNotFoundError(f"Alias file not found: {path}")

    with path.open("r", encoding="utf-8") as f:
        for lineno, line in enumerate(f, start=1):
            body = line.split("#", 1)[0].strip()
            if not body:
                continue
            try:
                key, value = parse_alias_spec(body, aliases)
            except ValueError as exc:
                raise ValueError(f"{path}:{lineno}: {exc}") from exc
            aliases[key] = value


def resolve_aliases(tokens: Sequence[str], aliases: Dict[str, str]) -> List[str]:
    def expand_token(token: str, stack: Tuple[str, ...]) -> List[str]:
        key = token.strip().upper()
        if not key:
            return []

        mapped = aliases.get(key)
        if mapped is None:
            return [key]

        parts = [p.upper() for p in split_alias_tokens(mapped)]
        if not parts:
            return []
        if len(parts) == 1 and parts[0] == key:
            return [key]

        if key in stack:
            chain = " -> ".join(stack + (key,))
            raise ValueError(f"Alias recursion detected: {chain}")

        out: List[str] = []
        for part in parts:
            if part in aliases:
                out.extend(expand_token(part, stack + (key,)))
            else:
                out.append(part)
        return out

    resolved: List[str] = []
    for token in tokens:
        resolved.extend(expand_token(token, ()))
    return resolved


def select_input_tokens(args: argparse.Namespace) -> Tuple[str, List[str]]:
    if args.expr:
        return "expr", split_tokens(args.expr)
    if args.keys:
        return "keys", split_tokens(args.keys)
    if args.preset:
        return f"preset:{args.preset}", split_tokens(PRESETS[args.preset]["keys"])
    return "preset:boot_probe", split_tokens(PRESETS["boot_probe"]["keys"])


def detect_input_mode(tokens: Sequence[str]) -> str:
    if not tokens:
        return "buttons"

    low_level_ok = all(parse_low_level_token(t) is not None for t in tokens)
    buttons_ok = all((parse_button_token(t) is not None) or (parse_low_level_token(t) == (0, 0)) for t in tokens)

    if low_level_ok and not buttons_ok:
        return "keys"
    if buttons_ok and not low_level_ok:
        return "buttons"
    if low_level_ok and buttons_ok:
        return "buttons"

    raise ValueError(
        "Unsupported key token(s). Use low-level tokens (K1,K2,K12,NONE) "
        "or matrix tokens/aliases (B_1_2 / R1D2 / 1:2 / K00 / semantic aliases)."
    )


def build_key_events(
    tokens: Iterable[str], *, start_cycle: int, hold_cycles: int, gap_cycles: int
) -> List[Tuple[int, int, int]]:
    events: List[Tuple[int, int, int]] = []
    cycle = max(start_cycle, 0)
    current = (0, 0)

    for token in tokens:
        target = parse_low_level_token(token.upper())
        if target is None:
            raise ValueError(f"Invalid low-level token: {token}")

        if target == (0, 0):
            if current != (0, 0):
                events.append((cycle, 0, 0))
                current = (0, 0)
            cycle += gap_cycles
            continue

        if current != target:
            events.append((cycle, target[0], target[1]))
            current = target

        cycle += hold_cycles
        if current != (0, 0):
            events.append((cycle, 0, 0))
            current = (0, 0)

        cycle += gap_cycles

    events.sort(key=lambda x: x[0])
    return events


def build_button_events(tokens: Iterable[str], *, start_cycle: int, gap_cycles: int) -> List[Tuple[int, int, int]]:
    events: List[Tuple[int, int, int]] = []
    cycle = max(start_cycle, 0)

    for token in tokens:
        t = token.upper()
        if parse_low_level_token(t) == (0, 0):
            cycle += gap_cycles
            continue

        parsed = parse_button_token(t)
        if parsed is None:
            raise ValueError(f"Invalid button token: {token}")

        row, dnum = parsed
        col = dnum - 2  # emu145 keypad(): low byte is 0..9 mapped to D2..D11
        events.append((cycle, row, col))
        cycle += gap_cycles

    events.sort(key=lambda x: x[0])
    return events


def write_key_events(events: Sequence[Tuple[int, int, int]], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="ascii") as f:
        for cycle, k1, k2 in events:
            f.write(f"{cycle} {k1} {k2}\n")


def write_button_events(events: Sequence[Tuple[int, int, int]], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="ascii") as f:
        for cycle, row, col in events:
            f.write(f"{cycle} {row} {col}\n")


def _trace_path_for_engine(engine: str) -> Path:
    if engine == "verilog":
        return TRACE_PATH
    if engine == "vhdl":
        return TRACE_VHDL_PATH
    if engine == "hls":
        return TRACE_HLS_PATH
    raise ValueError(f"Unsupported engine: {engine}")


def run_sim(
    *,
    cycles: int,
    mode_name: str,
    input_mode: str,
    events_file: Path,
    engine: str,
    no_build: bool,
) -> None:
    mode_name_l = mode_name.lower()
    if mode_name_l not in MODE_MAP:
        raise ValueError(f"Unknown mode: {mode_name}. Use rad/deg/grd")

    mode_id = MODE_MAP[mode_name_l]
    sim_cycles = max(cycles, 1)
    eng = engine.lower()

    if eng == "verilog":
        cmd = [
            "vvp",
            str(SIM_PATH),
            f"+cycles={sim_cycles}",
            f"+mode={mode_id}",
        ]
        if input_mode == "keys":
            cmd.append(f"+keys={events_file}")
        elif input_mode == "buttons":
            cmd.append(f"+buttons={events_file}")
        else:
            raise ValueError(f"Unsupported input mode: {input_mode}")
        run_cmd(cmd, tee_to=VVP_LOG_PATH)
    elif eng == "vhdl":
        cmd = [
            str(VHDL_RUN_SCRIPT),
            "--cycles",
            str(sim_cycles),
            "--mode",
            str(mode_id),
            "--use-external-events",
        ]
        if no_build:
            cmd.append("--no-build")
        run_cmd(cmd, tee_to=VVP_LOG_PATH)
    elif eng == "hls":
        cmd = [
            str(HLS_RUN_SCRIPT),
            "--cycles",
            str(sim_cycles),
            "--mode",
            str(mode_id),
            "--use-external-events",
        ]
        if no_build:
            cmd.append("--no-build")
        run_cmd(cmd, tee_to=VVP_LOG_PATH)
    else:
        raise ValueError(f"Unsupported engine: {engine}. Use verilog/vhdl/hls")

    src_trace = _trace_path_for_engine(eng)
    if not src_trace.exists():
        raise FileNotFoundError(f"Trace file not found after {eng} run: {src_trace}")
    if src_trace != TRACE_PATH:
        shutil.copy2(src_trace, TRACE_PATH)


def parse_frames(trace_path: Path) -> List[Tuple[int, List[int]]]:
    if not trace_path.exists():
        raise FileNotFoundError(f"Trace file not found: {trace_path}")

    frames: List[Tuple[int, List[int]]] = []
    display = [0x0F] * 12
    display[7] = 0x80

    # tb_mk61 can emit wide debug fields (e.g. chain state), enlarge csv parser limit.
    csv.field_size_limit(sys.maxsize)

    with trace_path.open("r", encoding="ascii", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            cycle = int(row["cycle"])
            dcycle = int(row["dcycle"])
            sync = int(row["sync"])
            seg_s = row["seg"].strip().lower()
            seg = int(seg_s, 16) if seg_s.startswith("0x") else int(seg_s, 10)

            if 2 <= dcycle <= 13:
                display[dcycle - 2] = seg

            if sync == 1:
                frames.append((cycle, list(display)))

    return frames


def decode_segment(seg: int) -> str:
    idx = seg & 0x0F
    if 0 <= idx < len(EMU_SEGMENTS):
        ch = EMU_SEGMENTS[idx]
    else:
        ch = "?"
    return f"{ch}." if (seg & 0x80) else f"{ch}"


def render_frame_emu145(display: Sequence[int]) -> str:
    out: List[str] = []
    for i in range(9):
        out.append(decode_segment(display[8 - i]))
    for i in range(3):
        out.append(decode_segment(display[11 - i]))
    return " ".join(out)


def print_frames(frames: Sequence[Tuple[int, List[int]]], tail_count: int) -> None:
    if not frames:
        print("No sync frames captured. Increase --cycles.")
        return

    tail = list(frames[-max(1, tail_count):])
    print(f"Frames captured: {len(frames)}")
    print("Last frames (emu145 display order):")
    for cycle, display in tail:
        print(f"  cycle={cycle:>6}  {render_frame_emu145(display)}")


def print_button_event_effects(
    button_events: Sequence[Tuple[int, int, int]], frames: Sequence[Tuple[int, List[int]]], *, lookahead_frames: int = 80
) -> None:
    if not button_events or not frames:
        return

    frame_cycles = [c for c, _ in frames]
    rendered = [(c, render_frame_emu145(d)) for c, d in frames]

    print("Button event effects (base -> first changed frame):")
    for ev_cycle, row, col in button_events:
        idx = bisect_left(frame_cycles, ev_cycle)
        if idx == 0:
            base_cycle, base_text = rendered[0]
        else:
            base_cycle, base_text = rendered[idx - 1]

        end_idx = min(len(rendered), idx + max(1, lookahead_frames))
        change = None
        for j in range(idx, end_idx):
            if rendered[j][1] != base_text:
                change = rendered[j]
                break

        key_name = f"B_{row}_{col + 2}"
        if change is None:
            print(f"  {key_name:7s} at {ev_cycle:>7}: base@{base_cycle:>7} '{base_text}' -> no change")
        else:
            ch_cycle, ch_text = change
            print(f"  {key_name:7s} at {ev_cycle:>7}: base@{base_cycle:>7} '{base_text}' -> {ch_cycle:>7} '{ch_text}'")


def print_presets() -> None:
    print("Available presets:")
    for name in sorted(PRESETS):
        desc = str(PRESETS[name]["description"])
        keys = str(PRESETS[name]["keys"])
        timing = PRESETS[name].get("timing")
        print(f"  {name:20s}  {desc}")
        print(f"    keys: {keys}")
        if isinstance(timing, dict):
            parts: List[str] = []
            for field in ("cycles", "start", "gap", "frames"):
                if field in timing:
                    parts.append(f"{field}={timing[field]}")
            if parts:
                print(f"    timing: {' '.join(parts)}")


def apply_preset_timing(args: argparse.Namespace) -> Dict[str, int]:
    if not args.preset:
        return {}
    if args.preset_timing == "off":
        return {}

    preset = PRESETS.get(args.preset, {})
    timing = preset.get("timing")
    if not isinstance(timing, dict):
        return {}

    default_values = {
        "cycles": DEFAULT_CYCLES,
        "start": DEFAULT_START,
        "gap": DEFAULT_GAP,
        "frames": DEFAULT_FRAMES,
    }
    force = args.preset_timing == "on"
    changed: Dict[str, int] = {}
    for field in ("cycles", "start", "gap", "frames"):
        if field not in timing:
            continue
        target = int(timing[field])
        if force or int(getattr(args, field)) == int(default_values[field]):
            setattr(args, field, target)
            changed[field] = target
    return changed


def print_key_help() -> None:
    print("Canonical matrix keys from emu145 (pmkemu/mainwindow.ui + buttons/_Nr.png):")
    print("  format: B_row_dnum  (row=1..3, dnum=2..11)")
    print("  alternate forms: R1D2, 1:2, KEY_1_2, POS00, K00 .. POS29, K29")
    print()
    print("Key legend table:")
    print("  canonical  main   yellow   blue")
    for canonical, main, yellow, blue in EMU145_BUTTON_META:
        main_s = main if main else "-"
        yellow_s = yellow if yellow else "-"
        blue_s = blue if blue else "-"
        print(f"  {canonical:8s}  {main_s:6s} {yellow_s:8s} {blue_s}")
    print()
    print("Default semantic aliases (emu145 legends; may expand to multi-key sequences):")
    for alias in sorted(EMU145_SEMANTIC_ALIASES):
        print(f"  {alias:10s} -> {EMU145_SEMANTIC_ALIASES[alias]}")
    print()
    print("Override examples:")
    print("  --alias ENTER=B_2_9 --alias PLUS=B_2_2")
    print("  --alias SIN=F+B_1_9 --alias PRG=F+B_2_9")
    print("  --aliases-file mk61_aliases.example.txt")


def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Run RTL virtual calculator emulating fixelsan/emu145 behavior")
    p.add_argument("--keys", default="", help="Input sequence (tokens separated by spaces/commas)")
    p.add_argument("--expr", default="", help="Semantic tokens, e.g. '1 2 ENTER 3 +' or 'SIN 1'")
    p.add_argument("--preset", choices=tuple(sorted(PRESETS.keys())), help="Built-in key sequence preset")
    p.add_argument("--alias", action="append", default=[], help="Alias override NAME=TOKEN or NAME=T1+T2 (repeatable)")
    p.add_argument("--aliases-file", default="", help="Path to alias file (lines: NAME=TOKEN or NAME=T1+T2)")
    p.add_argument("--list-keys", action="store_true", help="Print alias and matrix key help")
    p.add_argument("--list-presets", action="store_true", help="Print built-in presets")
    p.add_argument("--report-events", action="store_true", help="Print per-button event display effects")
    p.add_argument(
        "--preset-timing",
        choices=("auto", "on", "off"),
        default="auto",
        help="Apply preset timing profile: auto (only default args), on (force), off (disable)",
    )
    p.add_argument("--cycles", type=int, default=DEFAULT_CYCLES, help=f"Simulation cycles (default {DEFAULT_CYCLES})")
    p.add_argument("--start", type=int, default=DEFAULT_START, help=f"Cycle offset for first key event (default {DEFAULT_START})")
    p.add_argument("--hold", type=int, default=DEFAULT_HOLD, help=f"Hold cycles (only low-level mode, default {DEFAULT_HOLD})")
    p.add_argument("--gap", type=int, default=DEFAULT_GAP, help=f"Gap cycles between events (default {DEFAULT_GAP})")
    p.add_argument("--frames", type=int, default=DEFAULT_FRAMES, help=f"How many last sync frames to print (default {DEFAULT_FRAMES})")
    p.add_argument("--mode", choices=("rad", "deg", "grd"), default="rad", help="Calculator angle mode")
    p.add_argument("--engine", choices=("verilog", "vhdl", "hls"), default="verilog", help="Simulation engine")
    p.add_argument("--no-build", action="store_true", help="Skip build stage when engine supports it")
    return p


def main(argv: Sequence[str]) -> int:
    args = build_arg_parser().parse_args(argv)

    try:
        aliases = build_default_aliases()

        if args.aliases_file:
            load_aliases_file(Path(args.aliases_file), aliases)

        for raw_spec in args.alias:
            name, target = parse_alias_spec(raw_spec, aliases)
            aliases[name] = target

        if args.list_presets:
            print_presets()
            return 0

        if args.list_keys:
            print_key_help()
            return 0

        preset_timing_changes = apply_preset_timing(args)

        source, raw_tokens = select_input_tokens(args)
        tokens = resolve_aliases(raw_tokens, aliases)
        input_mode = detect_input_mode(tokens)

        if input_mode == "keys":
            events = build_key_events(
                tokens,
                start_cycle=max(0, args.start),
                hold_cycles=max(1, args.hold),
                gap_cycles=max(0, args.gap),
            )
            write_key_events(events, KEY_EVENTS_PATH)
            events_path = KEY_EVENTS_PATH
        else:
            events = build_button_events(
                tokens,
                start_cycle=max(0, args.start),
                gap_cycles=max(1, args.gap),
            )
            write_button_events(events, BUTTON_EVENTS_PATH)
            events_path = BUTTON_EVENTS_PATH

        if args.engine == "verilog" and not args.no_build:
            compile_sim()

        if input_mode == "buttons" and args.start < 50000:
            print("Note: early button start can be ignored during MCU init; consider --start 100000.")

        run_sim(
            cycles=max(1, args.cycles),
            mode_name=args.mode,
            input_mode=input_mode,
            events_file=events_path,
            engine=args.engine,
            no_build=bool(args.no_build),
        )

        frames = parse_frames(TRACE_PATH)

        print(f"Input source: {source}")
        print(f"Input mode: {input_mode}")
        print(f"Raw tokens: {' '.join(raw_tokens) if raw_tokens else '(none)'}")
        print(f"Resolved tokens: {' '.join(tokens) if tokens else '(none)'}")
        if preset_timing_changes:
            timing_str = " ".join(f"{k}={v}" for k, v in preset_timing_changes.items())
            print(f"Preset timing applied: {timing_str}")
        print(f"Events: {len(events)}")
        print(f"Events file: {events_path}")
        print(f"Engine: {args.engine}")
        print(f"Run log: {VVP_LOG_PATH}")
        print_frames(frames, tail_count=max(1, args.frames))
        if args.report_events and input_mode == "buttons":
            print_button_event_effects(events, frames)
        return 0
    except (ValueError, FileNotFoundError, CommandError) as exc:
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
