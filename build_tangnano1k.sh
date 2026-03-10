#!/usr/bin/env bash
set -euo pipefail
if [ -n "${ZSH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

TOP="mk61_top_1k_board"
BUILD_DIR="$ROOT/build/tangnano1k"
FLASH=0
FLASH_BOARD="tangnano1k"
UTIL_ONLY=0
SYNTH_ARGS=()

usage() {
  cat <<EOF
Usage: ./build_tangnano1k.sh [options]

Runs:
  1) ./synth_tangnano1k.sh
  2) optional openFPGALoader flash

Options:
  --flash                    Program FPGA after successful bitstream build
  --flash-board <name>       openFPGALoader board id (default: $FLASH_BOARD)
  --full-mk61                Build full mk61_top (for reference; likely too large for 1K)
  --top-1k-core              Build mk61_top_1k (pin-compatible core top)
  --external                 Build mk61_top_1k with external CST profile
  --fx2                      Build mk61_top_1k_fx2 with FX2 CST profile
  --top <module>             Explicit top (overrides defaults)
  --build-dir <path>         Build directory (default: $BUILD_DIR)
  --util-only                Run utilization-only flow (no PnR/bitstream)
  --help                     Show this help

Other options are passed through to ./synth_tangnano1k.sh.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --flash)
      FLASH=1
      shift
      ;;
    --flash-board)
      FLASH_BOARD="${2:?missing value for --flash-board}"
      shift 2
      ;;
    --full-mk61)
      TOP="mk61_top"
      SYNTH_ARGS+=("$1")
      shift
      ;;
    --top-1k-core)
      TOP="mk61_top_1k"
      SYNTH_ARGS+=("$1")
      shift
      ;;
    --external)
      TOP="mk61_top_1k"
      SYNTH_ARGS+=("$1")
      shift
      ;;
    --fx2)
      TOP="mk61_top_1k_fx2"
      SYNTH_ARGS+=("$1")
      shift
      ;;
    --top)
      TOP="${2:?missing value for --top}"
      SYNTH_ARGS+=("$1" "$2")
      shift 2
      ;;
    --build-dir)
      BUILD_DIR="${2:?missing value for --build-dir}"
      SYNTH_ARGS+=("$1" "$2")
      shift 2
      ;;
    --util-only)
      UTIL_ONLY=1
      SYNTH_ARGS+=("$1")
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      SYNTH_ARGS+=("$1")
      shift
      ;;
  esac
done

./synth_tangnano1k.sh "${SYNTH_ARGS[@]}"

if [ "$FLASH" -eq 0 ]; then
  exit 0
fi

if [ "$UTIL_ONLY" -eq 1 ]; then
  echo "[ERR] cannot flash in --util-only mode." >&2
  exit 1
fi

if ! command -v openFPGALoader >/dev/null 2>&1; then
  echo "[ERR] openFPGALoader not found. Install it or rerun without --flash." >&2
  exit 1
fi

BITSTREAM="$BUILD_DIR/${TOP}.fs"
if [ ! -f "$BITSTREAM" ]; then
  echo "[ERR] bitstream not found: $BITSTREAM" >&2
  exit 1
fi

echo "[FLASH] openFPGALoader -b $FLASH_BOARD $BITSTREAM"
openFPGALoader -b "$FLASH_BOARD" "$BITSTREAM"
echo "[OK] flashed: $BITSTREAM"
