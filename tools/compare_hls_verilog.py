#!/usr/bin/env python3
"""Compare display behavior between Verilog and HLS MK-61 traces."""

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
HLS_TRACE_DEFAULT = ROOT / "rtl_trace_hls.csv"

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
        parts = [f"Command failed ({proc.returncode}): {' '.join(cmd)}"]
        if proc.stdout.strip():
            parts.append(f"stdout:\n{proc.stdout.strip()}")
        if proc.stderr.strip():
            parts.append(f"stderr:\n{proc.stderr.strip()}")
        raise CompareError("\n".join(parts))


def build_verilog() -> None:
    run_cmd(["iverilog", "-g2005", "-o", str(SIM_PATH), *RTL_FILES])


def run_verilog(cycles: int, mode: int) -> None:
    run_cmd(["vvp", str(SIM_PATH), f"+cycles={cycles}", f"+mode={mode}"])


def run_hls(cycles: int, mode: int) -> None:
    run_cmd(["./hls/run_hls.sh", "--cycles", str(cycles), "--mode", str(mode)])


def parse_trace(path: Path) -> list[dict[str, int]]:
    if not path.exists():
        raise CompareError(f"trace file not found: {path}")

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
                raise CompareError(f"{path}:{idx}: invalid numeric row: {row}") from exc

    return rows


def sync_frames(rows: Iterable[dict[str, int]]) -> list[tuple[int, int, int]]:
    out: list[tuple[int, int, int]] = []
    for r in rows:
        if r["sync"] != 0:
            out.append((r["cycle"], r["dcycle"], r["seg"]))
    return out


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Compare Verilog and HLS MK-61 display traces")
    p.add_argument("--cycles", type=int, default=20000, help="simulation cycles for both runs")
    p.add_argument("--mode", type=int, default=0, choices=[0, 1, 2], help="0=RAD, 1=DEG, 2=GRD")
    p.add_argument("--skip-run", action="store_true", help="only compare existing traces")
    p.add_argument("--skip-verilog-build", action="store_true", help="skip rebuilding Verilog sim")
    p.add_argument("--verilog-trace", type=Path, default=VERILOG_TRACE_DEFAULT)
    p.add_argument("--hls-trace", type=Path, default=HLS_TRACE_DEFAULT)
    p.add_argument("--max-mismatch-print", type=int, default=10)
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
            print("[*] running HLS simulation")
            run_hls(args.cycles, args.mode)

        v_rows = parse_trace(args.verilog_trace)
        h_rows = parse_trace(args.hls_trace)

        v_frames = sync_frames(v_rows)
        h_frames = sync_frames(h_rows)

        print(f"[INFO] verilog_rows={len(v_rows)} hls_rows={len(h_rows)}")
        print(f"[INFO] verilog_sync_frames={len(v_frames)} hls_sync_frames={len(h_frames)}")

        if len(v_frames) != len(h_frames):
            print("[ERR] sync frame count mismatch", file=sys.stderr)
            return 1

        offsets: list[int] = []
        mismatches: list[str] = []

        for idx, (vf, hf) in enumerate(zip(v_frames, h_frames)):
            v_cycle, v_dcycle, v_seg = vf
            h_cycle, h_dcycle, h_seg = hf
            offsets.append(h_cycle - v_cycle)
            if (v_dcycle != h_dcycle) or (v_seg != h_seg):
                mismatches.append(
                    f"frame#{idx}: verilog(cycle={v_cycle},dcycle={v_dcycle},seg={v_seg}) "
                    f"!= hls(cycle={h_cycle},dcycle={h_dcycle},seg={h_seg})"
                )

        unique_offsets = sorted(set(offsets))
        msg = (
            f"constant {unique_offsets[0]} cycles"
            if len(unique_offsets) == 1
            else f"non-constant {unique_offsets}"
        )
        print(f"[INFO] sync cycle offset (hls-verilog): {msg}")

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
