#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT/hpprime/build"
OUT="$OUT_DIR/mk61_hpprime_host"

mkdir -p "$OUT_DIR"

c++ -std=c++17 -O2 -Wall -Wextra \
  "$ROOT/nspire/mk61_engine.cpp" \
  "$ROOT/hls/mk61_hls.cpp" \
  "$ROOT/hpprime/mk61_hpprime_host.cpp" \
  -o "$OUT"

echo "[OK] built: $OUT"
