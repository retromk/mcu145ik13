#!/usr/bin/env bash
set -euo pipefail
if [ -n "${ZSH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "[*] build emu145 reference runner"
clang++ -std=c++17 -O2 \
  tools/emu145_ref_runner.cpp \
  emu145/pmkemu/cmcu13.cpp \
  emu145/pmkemu/cmem.cpp \
  $(pkg-config --cflags --libs Qt6Core Qt6Widgets) \
  -o tools/emu145_ref_runner

echo "[*] built tools/emu145_ref_runner"
