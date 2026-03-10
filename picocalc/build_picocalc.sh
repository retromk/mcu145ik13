#!/usr/bin/env bash
set -euo pipefail
if [ -n "${ZSH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OUT_DIR="$ROOT/picocalc/build"
OUT_BIN="$OUT_DIR/mk61_picocalc"

mkdir -p "$OUT_DIR"

if ! command -v g++ >/dev/null 2>&1; then
  echo "[ERR] g++ not found" >&2
  exit 1
fi

g++ \
  -std=c++17 \
  -O2 \
  -Wall -Wextra -Wpedantic \
  "$ROOT/picocalc/mk61_picocalc.cpp" \
  "$ROOT/hls/mk61_hls.cpp" \
  -o "$OUT_BIN"

echo "[OK] built: $OUT_BIN"
