#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT/mk90/build"
OUT="$OUT_DIR/mk61_mk90_rt11_stub_host"

mkdir -p "$OUT_DIR"

cc -std=c11 -O2 -Wall -Wextra -DMK90_STUB_MAIN \
  -c "$ROOT/mk90/mk61_mk90_rt11_stub.c" \
  -o "$OUT_DIR/mk61_mk90_rt11_stub.o"

c++ -std=c++17 -O2 -Wall -Wextra \
  "$ROOT/mk90/mk61_engine_c_api.cpp" \
  "$ROOT/nspire/mk61_engine.cpp" \
  "$ROOT/hls/mk61_hls.cpp" \
  "$OUT_DIR/mk61_mk90_rt11_stub.o" \
  -o "$OUT"

echo "[OK] built: $OUT"
