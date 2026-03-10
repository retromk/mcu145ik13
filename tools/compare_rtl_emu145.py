#!/usr/bin/env python3
"""Differential runner: compare RTL testbench behavior vs emu145 core model."""

from __future__ import annotations

import argparse
import csv
import json
import shutil
import subprocess
import sys
from bisect import bisect_left
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Tuple

ROOT = Path(__file__).resolve().parent.parent
LOG_DIR = ROOT / "logs" / "compare"
RTL_TRACE = ROOT / "rtl_trace.csv"
VBTN = ROOT / "logs" / "virtual_buttons.txt"
REF_BIN = ROOT / "tools" / "emu145_ref_runner"

EMU_SEGMENTS = "0123456789-LCrE "


@dataclass
class Frame:
    cycle: int
    text: str
    display: Tuple[int, ...]


@dataclass
class ButtonEvent:
    cycle: int
    row: int
    col: int


@dataclass
class Scenario:
    name: str
    description: str
    vc_args: List[str]
    mode: str
    cycles_top: int


SCENARIOS: Dict[str, Scenario] = {
    "boot_probe": Scenario(
        name="boot_probe",
        description="Single key after init",
        vc_args=["--preset", "boot_probe", "--cycles", "260000", "--start", "100000", "--gap", "12000"],
        mode="rad",
        cycles_top=260000,
    ),
    "scan_row1": Scenario(
        name="scan_row1",
        description="All row1 keys",
        vc_args=["--preset", "scan_row1", "--cycles", "520000", "--start", "100000", "--gap", "20000"],
        mode="rad",
        cycles_top=520000,
    ),
    "scan_all": Scenario(
        name="scan_all",
        description="All 30 keys",
        vc_args=["--preset", "scan_all", "--cycles", "900000", "--start", "100000", "--gap", "20000"],
        mode="rad",
        cycles_top=900000,
    ),
    "calc_rpn": Scenario(
        name="calc_rpn",
        description="RPN 1 ENTER 2 +",
        vc_args=["--preset", "calc_1_enter_2_plus", "--cycles", "700000", "--start", "260000", "--gap", "30000"],
        mode="rad",
        cycles_top=700000,
    ),
    "func_sin": Scenario(
        name="func_sin",
        description="Function macro 1 SIN",
        vc_args=["--expr", "1 SIN", "--cycles", "700000", "--start", "260000", "--gap", "30000"],
        mode="rad",
        cycles_top=700000,
    ),
    "sp_cx_calc": Scenario(
        name="sp_cx_calc",
        description="SP CX 1 ENTER 2 +",
        vc_args=["--expr", "SP CX 1 ENTER 2 +", "--cycles", "900000", "--start", "260000", "--gap", "30000"],
        mode="rad",
        cycles_top=900000,
    ),
}


def run_cmd(cmd: Sequence[str], *, log_path: Optional[Path] = None) -> None:
    proc = subprocess.run(list(cmd), cwd=ROOT, text=True, capture_output=True, check=False)
    if log_path is not None:
        log_path.parent.mkdir(parents=True, exist_ok=True)
        log_path.write_text(proc.stdout + proc.stderr, encoding="utf-8")
    if proc.returncode != 0:
        raise RuntimeError(
            f"Command failed ({proc.returncode}): {' '.join(cmd)}\n"
            f"stdout:\n{proc.stdout}\n"
            f"stderr:\n{proc.stderr}"
        )


def decode_segment(seg: int) -> str:
    idx = seg & 0x0F
    if 0 <= idx < len(EMU_SEGMENTS):
        ch = EMU_SEGMENTS[idx]
    else:
        ch = "?"
    return f"{ch}." if (seg & 0x80) else ch


def render_frame(display: Sequence[int]) -> str:
    out: List[str] = []
    for i in range(9):
        out.append(decode_segment(display[8 - i]))
    for i in range(3):
        out.append(decode_segment(display[11 - i]))
    return " ".join(out)


def parse_rtl_frames(path: Path) -> List[Frame]:
    frames: List[Frame] = []
    display = [0x0F] * 12
    display[7] = 0x80

    with path.open("r", encoding="ascii", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            cyc = int(row["cycle"])
            dcycle = int(row["dcycle"])
            sync = int(row["sync"])
            seg = int(row["seg"], 16)
            command = int(row["command"], 16)
            strobe = (command & 0x00FC0000) == 0

            if 2 <= dcycle <= 13:
                display[dcycle - 2] = seg
            if sync == 1:
                if strobe:
                    snap = tuple(display)
                else:
                    snap = tuple([0x0F] * 12)
                frames.append(Frame(cycle=cyc, text=render_frame(snap), display=snap))
    return frames


def parse_emu_frames(path: Path) -> List[Frame]:
    frames: List[Frame] = []
    with path.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            cyc = int(row["top_cycle"])
            disp_str = row["display"].strip()
            vals = [int(tok, 16) for tok in disp_str.split()]
            snap = tuple(vals)
            text = row["text"].strip('"') if row.get("text") else render_frame(snap)
            frames.append(Frame(cycle=cyc, text=text, display=snap))
    return frames


def load_button_events(path: Path) -> List[ButtonEvent]:
    events: List[ButtonEvent] = []
    with path.open("r", encoding="ascii") as f:
        for line in f:
            body = line.strip()
            if not body:
                continue
            cyc_s, row_s, col_s = body.split()
            events.append(ButtonEvent(cycle=int(cyc_s), row=int(row_s), col=int(col_s)))
    return events


def best_offset(rtl_frames: Sequence[Frame], emu_frames: Sequence[Frame], *, max_abs: int = 120, probe: int = 600) -> int:
    best = 0
    best_score = -1.0

    rlen = len(rtl_frames)
    elen = len(emu_frames)
    if rlen == 0 or elen == 0:
        return 0

    nprobe = min(probe, rlen, elen)
    for off in range(-max_abs, max_abs + 1):
        matches = 0
        total = 0
        for i in range(nprobe):
            ri = i
            ei = i + off
            if 0 <= ei < elen:
                total += 1
                if rtl_frames[ri].display == emu_frames[ei].display:
                    matches += 1
        if total == 0:
            continue
        score = matches / total
        if score > best_score:
            best_score = score
            best = off

    return best


def compare_frames(rtl_frames: Sequence[Frame], emu_frames: Sequence[Frame], offset: int) -> Dict[str, object]:
    mismatches: List[Tuple[int, int, int, str, str]] = []
    total = 0
    match = 0

    for ri, rf in enumerate(rtl_frames):
        ei = ri + offset
        if not (0 <= ei < len(emu_frames)):
            continue
        ef = emu_frames[ei]
        total += 1
        if rf.display == ef.display:
            match += 1
        elif len(mismatches) < 20:
            mismatches.append((ri, rf.cycle, ef.cycle, rf.text, ef.text))

    ratio = (match / total) if total else 0.0
    return {
        "total": total,
        "match": match,
        "ratio": ratio,
        "mismatches": mismatches,
    }


def event_effects(events: Sequence[ButtonEvent], frames: Sequence[Frame], *, lookahead: int = 120) -> List[Dict[str, object]]:
    if not frames:
        return []
    cyc = [f.cycle for f in frames]

    out: List[Dict[str, object]] = []
    for ev in events:
        idx = bisect_left(cyc, ev.cycle)
        if idx <= 0:
            base = frames[0]
        else:
            base = frames[idx - 1]

        found: Optional[Frame] = None
        for j in range(idx, min(len(frames), idx + max(1, lookahead))):
            if frames[j].text != base.text:
                found = frames[j]
                break

        out.append(
            {
                "key": f"B_{ev.row}_{ev.col + 2}",
                "event_cycle": ev.cycle,
                "base_cycle": base.cycle,
                "base_text": base.text,
                "base_display": list(base.display),
                "change_cycle": (None if found is None else found.cycle),
                "change_text": (None if found is None else found.text),
                "change_display": (None if found is None else list(found.display)),
            }
        )
    return out


def compare_event_effects(rtl_eff: Sequence[Dict[str, object]], emu_eff: Sequence[Dict[str, object]]) -> Dict[str, object]:
    total = min(len(rtl_eff), len(emu_eff))
    same = 0
    diffs: List[Tuple[int, str, object, object]] = []

    for i in range(total):
        r = rtl_eff[i]
        e = emu_eff[i]
        if r["key"] != e["key"]:
            if len(diffs) < 20:
                diffs.append((i, "key", r["key"], e["key"]))
            continue

        rch = r["change_display"]
        ech = e["change_display"]
        if rch == ech:
            same += 1
        elif len(diffs) < 20:
            diffs.append((i, r["key"], rch, ech))

    ratio = (same / total) if total else 0.0
    return {
        "total": total,
        "same": same,
        "ratio": ratio,
        "diffs": diffs,
    }


def scenario_cmd(s: Scenario, *, no_build: bool) -> List[str]:
    cmd = ["./virtual_calculator.py", *s.vc_args, "--mode", s.mode, "--frames", "6"]
    if no_build:
        cmd.append("--no-build")
    return cmd


def write_summary_md(path: Path, rows: Sequence[Dict[str, object]]) -> None:
    lines: List[str] = []
    lines.append("# RTL vs emu145 comparison")
    lines.append("")
    lines.append("| scenario | frames rtl | frames emu | offset | frame match | event match |")
    lines.append("|---|---:|---:|---:|---:|---:|")

    for r in rows:
        lines.append(
            "| {name} | {rfc} | {efc} | {off} | {fr:.2%} | {er:.2%} |".format(
                name=r["name"],
                rfc=r["rtl_frames"],
                efc=r["emu_frames"],
                off=r["offset"],
                fr=r["frame_ratio"],
                er=r["event_ratio"],
            )
        )

    lines.append("")
    lines.append("## Mismatch samples")
    lines.append("")
    for r in rows:
        lines.append(f"### {r['name']}")
        fmm = r["frame_mismatches"]
        emm = r["event_diffs"]
        if not fmm and not emm:
            lines.append("- no mismatches in sampled comparisons")
            lines.append("")
            continue

        for item in fmm[:5]:
            ri, rc, ec, rt, et = item
            lines.append(f"- frame idx {ri}: rtl@{rc}='{rt}' vs emu@{ec}='{et}'")
        for item in emm[:5]:
            idx, key, rv, ev = item
            lines.append(f"- event idx {idx} ({key}): rtl change={rv} vs emu change={ev}")
        lines.append("")

    path.write_text("\n".join(lines), encoding="utf-8")


def main(argv: Sequence[str]) -> int:
    p = argparse.ArgumentParser(description="Compare current RTL behavior with emu145 core model")
    p.add_argument(
        "--scenarios",
        default=",".join(SCENARIOS.keys()),
        help="Comma-separated list of scenario ids",
    )
    p.add_argument("--skip-build", action="store_true", help="Skip build_and_check pre-step")
    p.add_argument("--strict", action="store_true", help="Exit non-zero when mismatches are found")
    args = p.parse_args(argv)

    scenario_ids = [x.strip() for x in args.scenarios.split(",") if x.strip()]
    unknown = [x for x in scenario_ids if x not in SCENARIOS]
    if unknown:
        print(f"Unknown scenarios: {', '.join(unknown)}", file=sys.stderr)
        return 2

    LOG_DIR.mkdir(parents=True, exist_ok=True)

    if not REF_BIN.exists():
        print(f"Missing reference binary: {REF_BIN}", file=sys.stderr)
        print("Build it first: clang++ ... -o tools/emu145_ref_runner", file=sys.stderr)
        return 2

    if not args.skip_build:
        run_cmd(["./build_and_check.sh"], log_path=LOG_DIR / "build_and_check.log")

    rows: List[Dict[str, object]] = []

    for sid in scenario_ids:
        s = SCENARIOS[sid]
        print(f"[compare] scenario={sid}")

        vc_log = LOG_DIR / f"{sid}_virtual.log"
        cmd = scenario_cmd(s, no_build=True)
        run_cmd(cmd, log_path=vc_log)

        if not RTL_TRACE.exists():
            raise RuntimeError("rtl_trace.csv missing after virtual_calculator run")
        if not VBTN.exists():
            raise RuntimeError("logs/virtual_buttons.txt missing after virtual_calculator run")

        rtl_copy = LOG_DIR / f"{sid}_rtl_trace.csv"
        btn_copy = LOG_DIR / f"{sid}_buttons_top.txt"
        shutil.copy2(RTL_TRACE, rtl_copy)
        shutil.copy2(VBTN, btn_copy)

        ref_trace = LOG_DIR / f"{sid}_emu_trace.csv"
        ref_frames = LOG_DIR / f"{sid}_emu_frames.csv"
        ref_log = LOG_DIR / f"{sid}_emu.log"
        run_cmd(
            [
                str(REF_BIN),
                "--cycles-top",
                str(s.cycles_top),
                "--phase-div",
                "5",
                "--mode",
                s.mode,
                "--buttons",
                str(btn_copy),
                "--trace",
                str(ref_trace),
                "--frames",
                str(ref_frames),
            ],
            log_path=ref_log,
        )

        rtl_frames = parse_rtl_frames(rtl_copy)
        emu_frames = parse_emu_frames(ref_frames)
        events = load_button_events(btn_copy)

        off = best_offset(rtl_frames, emu_frames)
        frame_cmp = compare_frames(rtl_frames, emu_frames, off)

        rtl_eff = event_effects(events, rtl_frames)
        emu_eff = event_effects(events, emu_frames)
        eff_cmp = compare_event_effects(rtl_eff, emu_eff)

        scenario_json = {
            "scenario": sid,
            "description": s.description,
            "offset": off,
            "rtl_frames": len(rtl_frames),
            "emu_frames": len(emu_frames),
            "frame_cmp": frame_cmp,
            "event_cmp": eff_cmp,
            "rtl_event_effects": rtl_eff,
            "emu_event_effects": emu_eff,
        }
        (LOG_DIR / f"{sid}_report.json").write_text(json.dumps(scenario_json, ensure_ascii=False, indent=2), encoding="utf-8")

        rows.append(
            {
                "name": sid,
                "offset": off,
                "rtl_frames": len(rtl_frames),
                "emu_frames": len(emu_frames),
                "frame_ratio": frame_cmp["ratio"],
                "event_ratio": eff_cmp["ratio"],
                "frame_mismatches": frame_cmp["mismatches"],
                "event_diffs": eff_cmp["diffs"],
            }
        )

    summary_md = LOG_DIR / "summary.md"
    write_summary_md(summary_md, rows)

    print(f"[compare] summary: {summary_md}")
    for r in rows:
        print(
            "[compare] {name}: frame={fr:.2%} event={er:.2%} offset={off}"
            .format(name=r["name"], fr=r["frame_ratio"], er=r["event_ratio"], off=r["offset"])
        )

    if args.strict:
        bad = [r for r in rows if (r["frame_ratio"] < 0.999) or (r["event_ratio"] < 0.999)]
        if bad:
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
