#!/usr/bin/env bash
set -euo pipefail
if [ -n "${ZSH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

cycles=20000
if [ "$#" -gt 0 ]; then
  cycles="$1"
fi

if ! [[ "$cycles" =~ ^[0-9]+$ ]]; then
  echo "[ERR] cycles must be non-negative integer, got: $cycles" >&2
  exit 2
fi

echo "[*] compare mode=RAD(0) cycles=$cycles"
./tools/compare_vhdl_verilog.py --cycles "$cycles" --mode 0

echo "[*] compare mode=DEG(1) cycles=$cycles"
./tools/compare_vhdl_verilog.py --cycles "$cycles" --mode 1 --skip-verilog-build

echo "[*] compare mode=GRD(2) cycles=$cycles"
./tools/compare_vhdl_verilog.py --cycles "$cycles" --mode 2 --skip-verilog-build

echo "[OK] VHDL and Verilog match in all modes for cycles=$cycles"
