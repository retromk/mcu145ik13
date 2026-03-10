#!/usr/bin/env bash
set -euo pipefail
if [ -n "${ZSH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

sim_cycles=20000
mode_sel=0
regen_roms=1
no_build=0
use_external_events=0

usage() {
  cat <<'EOF'
Usage: ./hls/run_hls.sh [--cycles N] [--mode 0|1|2] [--no-gen-roms] [--no-build] [--use-external-events]
  --cycles N      Number of master cycles (default: 20000)
  --mode M        0=RAD, 1=DEG, 2=GRD (default: 0)
  --no-gen-roms   Skip HLS ROM regeneration step
  --no-build      Skip C++ build and reuse existing hls/tb_mk61_hls
  --use-external-events  Read logs/virtual_buttons.txt or logs/virtual_keys.txt
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --cycles)
      if [ "$#" -lt 2 ]; then
        echo "[ERR] --cycles requires integer value" >&2
        exit 2
      fi
      sim_cycles="$2"
      shift 2
      ;;
    --mode)
      if [ "$#" -lt 2 ]; then
        echo "[ERR] --mode requires value 0|1|2" >&2
        exit 2
      fi
      mode_sel="$2"
      shift 2
      ;;
    --no-gen-roms)
      regen_roms=0
      shift
      ;;
    --no-build)
      no_build=1
      shift
      ;;
    --use-external-events)
      use_external_events=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[ERR] unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if ! [[ "$sim_cycles" =~ ^[0-9]+$ ]]; then
  echo "[ERR] --cycles must be non-negative integer, got: $sim_cycles" >&2
  exit 2
fi
if ! [[ "$mode_sel" =~ ^[0-9]+$ ]] || [ "$mode_sel" -gt 2 ]; then
  echo "[ERR] --mode must be 0, 1 or 2, got: $mode_sel" >&2
  exit 2
fi

if [ "$regen_roms" -eq 1 ]; then
  ./tools/generate_hls_roms.py >/dev/null
fi

CXX_BIN="${CXX:-}"
if [ -z "$CXX_BIN" ]; then
  if command -v clang++ >/dev/null 2>&1; then
    CXX_BIN=clang++
  elif command -v g++ >/dev/null 2>&1; then
    CXX_BIN=g++
  else
    echo "[ERR] no C++ compiler found (clang++/g++)" >&2
    exit 2
  fi
fi

if [ "$no_build" -eq 0 ]; then
  "$CXX_BIN" -std=c++17 -O2 -Wall -Wextra -pedantic \
    -Ihls \
    hls/mk61_hls.cpp hls/tb_mk61_hls.cpp \
    -o hls/tb_mk61_hls
elif [ ! -x hls/tb_mk61_hls ]; then
  echo "[ERR] --no-build requested, but hls/tb_mk61_hls is missing" >&2
  exit 2
fi

cmd=(./hls/tb_mk61_hls --cycles "$sim_cycles" --mode "$mode_sel")
if [ "$use_external_events" -eq 1 ]; then
  cmd+=(--use-external-events)
fi
"${cmd[@]}"
