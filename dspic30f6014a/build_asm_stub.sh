#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/dspic30f6014a/mk61_dspic30f6014a_stub.s"
OUT_DIR="$ROOT/dspic30f6014a/build"
OUT_OBJ="$OUT_DIR/mk61_dspic30f6014a_stub.o"

mkdir -p "$OUT_DIR"

if command -v xc16-as >/dev/null 2>&1; then
  AS="xc16-as"
  AS_FLAGS=("-mcpu=30F6014A")
elif command -v pic30-as >/dev/null 2>&1; then
  AS="pic30-as"
  AS_FLAGS=("-p30F6014A")
else
  echo "[ERR] assembler not found. Install MPLAB XC16 (xc16-as) or pic30-as." >&2
  exit 1
fi

"$AS" "${AS_FLAGS[@]}" -o "$OUT_OBJ" "$SRC"

echo "[OK] built: $OUT_OBJ"
