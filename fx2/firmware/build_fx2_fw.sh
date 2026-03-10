#!/usr/bin/env bash
set -euo pipefail
if [ -n "${ZSH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

OUT_DIR="$ROOT/build"
OUT_IHX="$OUT_DIR/mk61_fx2_fw.ihx"
OUT_BASE="$OUT_DIR/mk61_fx2_fw"

mkdir -p "$OUT_DIR"

if ! command -v sdcc >/dev/null 2>&1; then
  echo "[ERR] sdcc not found. Install: brew install sdcc" >&2
  exit 1
fi

CFLAGS=(
  -mmcs51
  --std-c99
  --opt-code-size
  --model-small
  --xram-loc 0x0000
  --xram-size 0x4000
  --code-loc 0x0000
  --code-size 0x3E00
  -I"$ROOT/include"
)

sdcc "${CFLAGS[@]}" -c "$ROOT/src/mk61_fx2_fw.c" -o "$OUT_DIR/mk61_fx2_fw.rel"
sdcc "${CFLAGS[@]}" -c "$ROOT/src/setupdat.c" -o "$OUT_DIR/setupdat.rel"
sdcc "${CFLAGS[@]}" -c "$ROOT/src/delay.c" -o "$OUT_DIR/delay.rel"
sdas8051 -l -o "$OUT_DIR/dscr.rel" "$ROOT/src/dscr.a51"

sdcc "${CFLAGS[@]}" \
  "$OUT_DIR/mk61_fx2_fw.rel" \
  "$OUT_DIR/setupdat.rel" \
  "$OUT_DIR/delay.rel" \
  "$OUT_DIR/dscr.rel" \
  -o "$OUT_IHX"

if [ ! -f "$OUT_IHX" ] && [ -f "$OUT_BASE" ]; then
  cp "$OUT_BASE" "$OUT_IHX"
fi

echo "[OK] firmware built: $OUT_IHX"
