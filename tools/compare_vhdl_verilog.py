#!/usr/bin/env python3
"""Compare display behavior between Verilog and VHDL MK-61 RTL traces."""

from __future__ import annotations

import argparse
import csv
import subprocess
import sys
from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parent.parent
SIM_PATH = ROOT / "sim"
VERILOG_TRACE_DEFAULT = ROOT / "rtl_trace.csv"
VHDL_TRACE_DEFAULT = ROOT / "rtl_trace_vhdl.csv"

RTL_FILES = [
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
]


class CompareError(RuntimeError):
    pass


def parse_int(raw: str) -> int:
    s = raw.strip().lower()
    if s.startswith("0x"):
        return int(s, 16)
    return int(s, 10)


def run_cmd(cmd: list[str]) -> None:
    proc = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True, check=False)
    if proc.returncode != 0:
        details = []
        if proc.stdout.strip():
            details.append(f"stdout:\n{proc.stdout.strip()}")
        if proc.stderr.strip():
            details.append(f"stderr:\n{proc.stderr.strip()}")
        joined = "\n".join(details)
        raise CompareError(f"Command failed ({proc.returncode}): {' '.join(cmd)}\n{joined}")


def build_verilog() -> None:
    run_cmd(["iverilog", "-g2005", "-o", str(SIM_PATH), *RTL_FILES])


def run_verilog(cycles: int, mode: int) -> None:
    run_cmd(["vvp", str(SIM_PATH), f"+cycles={cycles}", f"+mode={mode}"])


def run_vhdl(cycles: int, mode: int) -> None:
    run_cmd(["./vhdl/run_ghdl.sh", "--cycles", str(cycles), "--mode", str(mode)])


def parse_trace(path: Path) -> list[dict[str, int]]:
    if not path.exists():
        raise CompareError(f"Trace file not found: {path}")

    rows: list[dict[str, int]] = []
    with path.open("r", encoding="ascii", newline="") as fd:
        reader = csv.DictReader(fd)
        required = {"cycle", "dcycle", "sync", "seg"}
        if reader.fieldnames is None or not required.issubset(set(reader.fieldnames)):
            raise CompareError(f"{path}: missing required columns {sorted(required)}")

        for idx, row in enumerate(reader, start=2):
            try:
                rows.append(
                    {
                        "cycle": parse_int(row["cycle"]),
                        "dcycle": parse_int(row["dcycle"]),
                        "sync": parse_int(row["sync"]),
                        "seg": parse_int(row["seg"]),
                    }
                )
            except Exception as exc:  # noqa: BLE001
                raise CompareError(f"{path}:{idx}: invalid numeric data: {row}") from exc

    return rows


def sync_frames(rows: Iterable[dict[str, int]]) -> list[tuple[int, int, int]]:
    out: list[tuple[int, int, int]] = []
    for r in rows:
        if r["sync"] != 0:
            out.append((r["cycle"], r["dcycle"], r["seg"]))
    return out


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Compare Verilog and VHDL MK-61 display traces")
    p.add_argument("--cycles", type=int, default=20000, help="Simulation cycles for both runs")
    p.add_argument("--mode", type=int, default=0, choices=[0, 1, 2], help="0=RAD, 1=DEG, 2=GRD")
    p.add_argument("--skip-run", action="store_true", help="Only compare existing trace files")
    p.add_argument("--skip-verilog-build", action="store_true", help="Do not rebuild Verilog sim binary")
    p.add_argument(
        "--verilog-trace",
        type=Path,
        default=VERILOG_TRACE_DEFAULT,
        help=f"Path to Verilog trace (default: {VERILOG_TRACE_DEFAULT})",
    )
    p.add_argument(
        "--vhdl-trace",
        type=Path,
        default=VHDL_TRACE_DEFAULT,
        help=f"Path to VHDL trace (default: {VHDL_TRACE_DEFAULT})",
    )
    p.add_argument(
        "--strict-offset",
        action="store_true",
        help="Fail if sync-frame cycle offset is not constant",
    )
    p.add_argument("--max-mismatch-print", type=int, default=10, help="How many mismatches to print")
    return p.parse_args()


def main() -> int:
    args = parse_args()

    if args.cycles < 1:
        print("[ERR] --cycles must be > 0", file=sys.stderr)
        return 2

    try:
        if not args.skip_run:
            if not args.skip_verilog_build:
                print("[*] building Verilog testbench")
                build_verilog()
            print("[*] running Verilog simulation")
            run_verilog(args.cycles, args.mode)
            print("[*] running VHDL simulation")
            run_vhdl(args.cycles, args.mode)

        verilog_rows = parse_trace(args.verilog_trace)
        vhdl_rows = parse_trace(args.vhdl_trace)

        v_frames = sync_frames(verilog_rows)
        h_frames = sync_frames(vhdl_rows)

        print(f"[INFO] verilog_rows={len(verilog_rows)} vhdl_rows={len(vhdl_rows)}")
        print(f"[INFO] verilog_sync_frames={len(v_frames)} vhdl_sync_frames={len(h_frames)}")

        if len(v_frames) != len(h_frames):
            print("[ERR] sync frame count mismatch", file=sys.stderr)
            return 1

        mismatches: list[str] = []
        offsets: list[int] = []

        for idx, (vf, hf) in enumerate(zip(v_frames, h_frames)):
            v_cycle, v_dcycle, v_seg = vf
            h_cycle, h_dcycle, h_seg = hf
            offsets.append(h_cycle - v_cycle)
            if v_dcycle != h_dcycle or v_seg != h_seg:
                mismatches.append(
                    f"frame#{idx}: verilog(cycle={v_cycle},dcycle={v_dcycle},seg={v_seg}) "
                    f"!= vhdl(cycle={h_cycle},dcycle={h_dcycle},seg={h_seg})"
                )

        unique_offsets = sorted(set(offsets))
        offset_msg = (
            f"constant {unique_offsets[0]} cycles"
            if len(unique_offsets) == 1
            else f"non-constant {unique_offsets}"
        )
        print(f"[INFO] sync cycle offset (vhdl-verilog): {offset_msg}")

        if args.strict_offset and len(unique_offsets) != 1:
            print("[ERR] offset is not constant", file=sys.stderr)
            return 1

        if mismatches:
            print(f"[ERR] frame payload mismatches: {len(mismatches)}", file=sys.stderr)
            for line in mismatches[: args.max_mismatch_print]:
                print(f"  {line}", file=sys.stderr)
            return 1

        print("[OK] sync-frame payloads are identical")
        return 0
    except CompareError as exc:
        print(f"[ERR] {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
