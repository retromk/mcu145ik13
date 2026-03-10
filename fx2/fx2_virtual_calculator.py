#!/usr/bin/env python3
"""Run MK61 calculator over Tang Nano 1K + FX2LP hardware bridge."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import List, Sequence, Tuple

try:
    from .fx2_bridge import BridgeError, FX2MK61Bridge, render_display_emu145
except ImportError:
    from fx2_bridge import BridgeError, FX2MK61Bridge, render_display_emu145

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_IHX = ROOT / "fx2" / "firmware" / "build" / "mk61_fx2_fw.ihx"

if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

# Reuse alias/preset ecosystem from virtual simulator.
from virtual_calculator import (
    PRESETS,
    build_default_aliases,
    parse_button_token,
    parse_low_level_token,
    print_key_help,
    print_presets,
    resolve_aliases,
    split_tokens,
)


class CLIError(RuntimeError):
    pass


def select_tokens(args: argparse.Namespace) -> Tuple[str, List[str]]:
    if args.expr:
        return "expr", split_tokens(args.expr)
    if args.keys:
        return "keys", split_tokens(args.keys)
    if args.preset:
        return f"preset:{args.preset}", split_tokens(PRESETS[args.preset]["keys"])
    return "preset:boot_probe", split_tokens(PRESETS["boot_probe"]["keys"])


def resolve_button_events(tokens: Sequence[str]) -> List[Tuple[int, int] | None]:
    events: List[Tuple[int, int] | None] = []

    for token in tokens:
        t = token.upper()

        ll = parse_low_level_token(t)
        if ll == (0, 0):
            events.append(None)
            continue
        if ll is not None:
            raise CLIError(
                f"Low-level token '{token}' is not supported in FX2 button mode. "
                "Use matrix tokens/aliases (e.g. B_1_2, ENTER, SIN)."
            )

        btn = parse_button_token(t)
        if btn is None:
            raise CLIError(f"Unsupported token '{token}' after alias resolution")

        row, dnum = btn
        events.append((row, dnum - 2))

    return events


def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Hardware MK61 runner over FX2LP bridge")

    p.add_argument("--expr", default="", help="Semantic tokens, e.g. '1 ENTER 2 +'")
    p.add_argument("--keys", default="", help="Token sequence (spaces/commas)")
    p.add_argument("--preset", choices=tuple(sorted(PRESETS.keys())), help="Built-in preset")
    p.add_argument("--list-presets", action="store_true", help="Show available presets")
    p.add_argument("--list-keys", action="store_true", help="Show key aliases/help")

    p.add_argument("--mode", choices=("rad", "deg", "grd"), default="rad")
    p.add_argument("--ihx", default=str(DEFAULT_IHX), help=f"FX2 firmware image (.ihx), default {DEFAULT_IHX}")
    p.add_argument("--no-upload", action="store_true", help="Do not upload firmware; connect to already running runtime device")
    p.add_argument("--force-upload", action="store_true", help="Force firmware reload")

    p.add_argument("--hold", type=int, default=4, help="How many FPGA cycles to hold detected key row (firmware default 4)")
    p.add_argument("--boot-cycles", type=int, default=120000, help="Warm-up cycles after reset release")
    p.add_argument("--reset-cycles", type=int, default=2000, help="Cycles with reset asserted")
    p.add_argument("--gap-cycles", type=int, default=12000, help="Extra cycles between key events")
    p.add_argument("--settle-cycles", type=int, default=4000, help="Cycles after each accepted key")
    p.add_argument("--step-chunk", type=int, default=2000, help="Chunk size for step polling")
    p.add_argument("--press-timeout", type=int, default=250000, help="Max cycles to wait until queued key is consumed")
    p.add_argument("--frames", type=int, default=6, help="Frames to wait before final display snapshot")

    p.add_argument("--no-scan-gate", action="store_true", help="Disable scan_active gating (not recommended)")
    p.add_argument("--no-auto-k2", action="store_true", help="Disable firmware auto-K2 pulse at scan column 12")

    return p


def run_sequence(args: argparse.Namespace) -> int:
    aliases = build_default_aliases()

    source, raw_tokens = select_tokens(args)
    tokens = resolve_aliases(raw_tokens, aliases)
    events = resolve_button_events(tokens)

    bridge = FX2MK61Bridge()
    try:
        if args.no_upload:
            bridge.connect()
        else:
            bridge.ensure_runtime(
                ihx_path=Path(args.ihx),
                force_reload=bool(args.force_upload),
                timeout_s=6.0,
            )

        bridge.set_hold_cycles(max(1, args.hold))

        bridge.set_mode(
            args.mode,
            rst=True,
            use_scan_gate=not args.no_scan_gate,
            auto_k2=not args.no_auto_k2,
        )
        bridge.step(max(1, args.reset_cycles))

        bridge.set_mode(
            args.mode,
            rst=False,
            use_scan_gate=not args.no_scan_gate,
            auto_k2=not args.no_auto_k2,
        )

        bridge.clear_frame_counter()
        if args.boot_cycles > 0:
            bridge.step(args.boot_cycles)

        for ev in events:
            if ev is None:
                if args.gap_cycles > 0:
                    bridge.step(args.gap_cycles)
                continue

            row, col = ev
            bridge.press_button(
                row,
                col,
                step_chunk=max(1, args.step_chunk),
                timeout_cycles=max(1, args.press_timeout),
                settle_cycles=max(0, args.settle_cycles),
            )

            if args.gap_cycles > 0:
                bridge.step(args.gap_cycles)

        if args.frames > 0:
            st = bridge.wait_frames(args.frames, step_chunk=max(1, args.step_chunk))
        else:
            st = bridge.get_state()

        disp = render_display_emu145(st.display)

        print(f"Input source: {source}")
        print(f"Raw tokens: {' '.join(raw_tokens) if raw_tokens else '(none)'}")
        print(f"Resolved tokens: {' '.join(tokens) if tokens else '(none)'}")
        print(f"Events: {len(events)}")
        print(f"Mode: {args.mode}")
        print(f"Frame counter: {st.frame_counter}")
        print(f"Display (emu145 order): {disp}")
        return 0
    finally:
        bridge.close()


def main(argv: Sequence[str] | None = None) -> int:
    args = build_arg_parser().parse_args(argv)

    try:
        if args.list_presets:
            print_presets()
            return 0
        if args.list_keys:
            print_key_help()
            return 0

        return run_sequence(args)
    except (BridgeError, CLIError, FileNotFoundError, ValueError) as exc:
        print(f"[ERR] {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
