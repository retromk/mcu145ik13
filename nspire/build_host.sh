#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT/nspire/build"
OUT="$OUT_DIR/mk61_nspire_host"

mkdir -p "$OUT_DIR"

c++ -std=c++17 -O2 -Wall -Wextra \
  "$ROOT/nspire/mk61_engine.cpp" \
  "$ROOT/hls/mk61_hls.cpp" \
  "$ROOT/nspire/mk61_nspire_host.cpp" \
  -o "$OUT"

echo "[OK] built: $OUT"
