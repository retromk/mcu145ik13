#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASM="$ROOT/zxspectrum/mk61_z80_stub.asm"
OUT_BIN="$ROOT/zxspectrum/mk61_z80_stub.bin"

if ! command -v sjasmplus >/dev/null 2>&1; then
  echo "[ERR] sjasmplus not found. Install it and retry." >&2
  exit 1
fi

sjasmplus --syntax=abfw "$ASM"

if [[ ! -f "$OUT_BIN" ]]; then
  echo "[ERR] expected output not found: $OUT_BIN" >&2
  exit 1
fi

echo "[OK] built: $OUT_BIN"
