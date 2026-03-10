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
Usage: ./vhdl/run_ghdl.sh [--cycles N] [--mode 0|1|2] [--no-gen-roms] [--no-build] [--use-external-events]
  --cycles N      Number of master cycles for VHDL TB (default: 20000)
  --mode M        0=RAD, 1=DEG, 2=GRD (default: 0)
  --no-gen-roms   Skip VHDL ROM regeneration step
  --no-build      Skip analyze/elaborate and run existing tb_mk61_vhdl
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

if ! [[ "$mode_sel" =~ ^[0-9]+$ ]]; then
  echo "[ERR] --mode must be 0, 1 or 2, got: $mode_sel" >&2
  exit 2
fi

if [ "$mode_sel" -gt 2 ]; then
  echo "[ERR] --mode must be 0, 1 or 2, got: $mode_sel" >&2
  exit 2
fi

if [ "$regen_roms" -eq 1 ]; then
  ./tools/generate_vhdl_roms.py >/dev/null
fi

if [ "$no_build" -eq 0 ]; then
  ./vhdl/ghdl.sh -a --std=08 \
    vhdl/ik13_mrom.vhd \
    vhdl/ik13_urom.vhd \
    vhdl/ik13_srom.vhd \
    vhdl/cmem_shift.vhd \
    vhdl/mcu145ik13_core.vhd \
    vhdl/mk61_top.vhd \
    vhdl/tb_mk61_vhdl.vhd

  ./vhdl/ghdl.sh -e --std=08 tb_mk61_vhdl
elif [ ! -x tb_mk61_vhdl ]; then
  echo "[ERR] --no-build requested, but tb_mk61_vhdl executable is missing" >&2
  exit 2
fi

./vhdl/ghdl.sh -r --std=08 tb_mk61_vhdl \
  -gG_SIM_CYCLES="$sim_cycles" \
  -gG_MODE="$mode_sel" \
  -gG_USE_EXTERNAL_EVENTS="$use_external_events"

echo "[OK] generated rtl_trace_vhdl.csv (cycles=$sim_cycles mode=$mode_sel)"
