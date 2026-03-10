#!/usr/bin/env bash
set -euo pipefail
if [ -n "${ZSH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

TOP="mk61_top_1k_board"
FAMILY="gw1n"
NEXTPNR_DEVICE="GW1NZ-LV1QN48C6/I5"
PACK_DEVICE="GW1NZ-LV1QN48C6/I5"
FREQ_MHZ="27"
BUILD_DIR="$ROOT/build/tangnano1k"
CST_PATH="$ROOT/fpga/tangnano1k/tangnano1k_board.cst"
UTIL_ONLY=0
BRAM_ROM=1
BRAM_SHIFT=1
CST_USER=0
PROFILE_EXTERNAL=0
PROFILE_FX2=0
TN1K_LUT4_MAX=1152
TN1K_FF_MAX=864
TN1K_BSRAM_MAX=4

RTL_FILES=(
  "rom_mrom_1302.v"
  "rom_mrom_1303.v"
  "rom_mrom_1306.v"
  "rom_urom_1302.v"
  "rom_urom_1303.v"
  "rom_urom_1306.v"
  "rom_srom_1302.v"
  "rom_srom_1303.v"
  "rom_srom_1306.v"
  "rom_wrappers.v"
  "cmem_shift.v"
  "mcu145ik13_core.v"
  "mk61_top_1k_board.v"
  "mk61_top_1k.v"
  "mk61_top_1k_fx2.v"
  "mk61_top.v"
)

usage() {
  cat <<EOF
Usage: ./synth_tangnano1k.sh [options]

Options:
  --top <module>             Top module (default: $TOP)
  --family <gw1n|gw2a|gw5a>  Yosys synth_gowin family (default: $FAMILY)
  --freq <MHz>               Target frequency for nextpnr (default: $FREQ_MHZ)
  --cst <path>               Gowin constraints file (default: $CST_PATH)
  --nextpnr-device <name>    nextpnr-gowin device (default: $NEXTPNR_DEVICE)
  --pack-device <name>       gowin_pack device (default: $PACK_DEVICE)
  --build-dir <path>         Output directory (default: $BUILD_DIR)
  --util-only                Run Yosys utilization only (no PnR/bitstream)
  --full-mk61                Use full mk61_top instead of resource-reduced mk61_top_1k
  --top-1k-core              Use mk61_top_1k (pin-compatible core top) instead of board wrapper
  --external                 Use mk61_top_1k + external CST profile
  --fx2                      Use mk61_top_1k_fx2 + FX2 CST profile
  --no-bram-rom              Disable BRAM-forced ROM mode (GOWIN_BRAM_ROM)
  --no-bram-shift            Disable BRAM-forced shift-chain mode (GOWIN_BRAM_SHIFT)
  -h, --help                 Show this help

Outputs:
  \$build_dir/yosys_stat.log
  \$build_dir/yosys_synth.log
  \$build_dir/<top>.json
  \$build_dir/nextpnr.log
  \$build_dir/gowin_pack.log
  \$build_dir/<top>.fs
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --top)
      TOP="${2:?missing value for --top}"
      shift 2
      ;;
    --family)
      FAMILY="${2:?missing value for --family}"
      shift 2
      ;;
    --freq)
      FREQ_MHZ="${2:?missing value for --freq}"
      shift 2
      ;;
    --cst)
      CST_PATH="${2:?missing value for --cst}"
      CST_USER=1
      shift 2
      ;;
    --nextpnr-device)
      NEXTPNR_DEVICE="${2:?missing value for --nextpnr-device}"
      shift 2
      ;;
    --pack-device)
      PACK_DEVICE="${2:?missing value for --pack-device}"
      shift 2
      ;;
    --build-dir)
      BUILD_DIR="${2:?missing value for --build-dir}"
      shift 2
      ;;
    --util-only)
      UTIL_ONLY=1
      shift
      ;;
    --full-mk61)
      TOP="mk61_top"
      shift
      ;;
    --top-1k-core)
      TOP="mk61_top_1k"
      shift
      ;;
    --external)
      PROFILE_EXTERNAL=1
      TOP="mk61_top_1k"
      shift
      ;;
    --fx2)
      PROFILE_FX2=1
      TOP="mk61_top_1k_fx2"
      shift
      ;;
    --no-bram-rom)
      BRAM_ROM=0
      shift
      ;;
    --no-bram-shift)
      BRAM_SHIFT=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[ERR] unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ "$CST_USER" -eq 0 ]; then
  if [ "$PROFILE_FX2" -eq 1 ]; then
    CST_PATH="$ROOT/fpga/tangnano1k/tangnano1k_fx2_mk61_top_1k_fx2.cst"
  elif [ "$PROFILE_EXTERNAL" -eq 1 ]; then
    CST_PATH="$ROOT/fpga/tangnano1k/tangnano1k_external_mk61_top_1k.cst"
  elif [ "$TOP" != "mk61_top_1k_board" ]; then
    CST_PATH="$ROOT/fpga/tangnano1k/tangnano1k.cst"
  fi
fi

require_cmd() {
  local c="$1"
  if ! command -v "$c" >/dev/null 2>&1; then
    echo "[ERR] required tool not found: $c" >&2
    exit 1
  fi
}

print_yosys_top_block() {
  local log_file="$1"
  local top="$2"
  awk -v top="$top" '
    $0 ~ ("=== " top " ===") {inblk=1; print; next}
    inblk {
      if ($0 ~ /^=== / && $0 !~ ("=== " top " ===")) exit
      print
    }
  ' "$log_file"
}

extract_cell_count() {
  local log_file="$1"
  local top="$2"
  local cell="$3"
  awk -v top="$top" -v cell="$cell" '
    $0 ~ ("=== " top " ===") {inblk=1; next}
    inblk {
      if ($0 ~ /^=== / && $0 !~ ("=== " top " ===")) inblk=0;
      if ($2 == cell) val = $1;
    }
    END {
      if (val == "") print 0;
      else print val;
    }
  ' "$log_file"
}

require_cmd yosys
mkdir -p "$BUILD_DIR"

YOSYS_DEFINE_STR=""
if [ "$BRAM_ROM" -eq 1 ]; then
  YOSYS_DEFINE_STR="$YOSYS_DEFINE_STR -D GOWIN_BRAM_ROM"
fi
if [ "$BRAM_SHIFT" -eq 1 ]; then
  YOSYS_DEFINE_STR="$YOSYS_DEFINE_STR -D GOWIN_BRAM_SHIFT"
fi
YOSYS_READ_CMD="read_verilog${YOSYS_DEFINE_STR} ${RTL_FILES[*]}"

if [ "$BRAM_ROM" -eq 1 ]; then
  for memf in \
    rom_data/mrom_1302.mem rom_data/mrom_1303.mem rom_data/mrom_1306.mem \
    rom_data/urom_1302.mem rom_data/urom_1303.mem rom_data/urom_1306.mem \
    rom_data/srom_1302.mem rom_data/srom_1303.mem rom_data/srom_1306.mem; do
    if [ ! -f "$ROOT/$memf" ]; then
      echo "[ERR] missing $memf (run ./tools/generate_gowin_mem.py)" >&2
      exit 1
    fi
  done
fi

echo "[CFG] top=$TOP family=$FAMILY freq=${FREQ_MHZ}MHz bram_rom=$BRAM_ROM bram_shift=$BRAM_SHIFT"

YOSYS_STAT_LOG="$BUILD_DIR/yosys_stat.log"
YOSYS_SYNTH_LOG="$BUILD_DIR/yosys_synth.log"
NETLIST_JSON="$BUILD_DIR/${TOP}.json"
NEXTPNR_LOG="$BUILD_DIR/nextpnr.log"
PACK_LOG="$BUILD_DIR/gowin_pack.log"
PNR_JSON="$BUILD_DIR/${TOP}.pnr.json"
BITSTREAM_FS="$BUILD_DIR/${TOP}.fs"

echo "[1/4] Yosys utilization/stat..."
yosys -l "$YOSYS_STAT_LOG" -p "
  $YOSYS_READ_CMD
  hierarchy -check -top $TOP
  proc; opt
  stat -top $TOP
" >/dev/null

echo "[2/4] Yosys synth_gowin..."
yosys -l "$YOSYS_SYNTH_LOG" -p "
  $YOSYS_READ_CMD
  synth_gowin -family $FAMILY -top $TOP -json $NETLIST_JSON
" >/dev/null

echo
echo "=== Yosys stat: $TOP ==="
print_yosys_top_block "$YOSYS_STAT_LOG" "$TOP" || true
echo

echo "=== Yosys synth_gowin mapped: $TOP ==="
print_yosys_top_block "$YOSYS_SYNTH_LOG" "$TOP" || true
echo

LUT4_USED="$(extract_cell_count "$YOSYS_SYNTH_LOG" "$TOP" "LUT4")"
SPX9_USED="$(extract_cell_count "$YOSYS_SYNTH_LOG" "$TOP" "SPX9")"
DPB_USED="$(extract_cell_count "$YOSYS_SYNTH_LOG" "$TOP" "DPB")"
DFF_USED="$(extract_cell_count "$YOSYS_SYNTH_LOG" "$TOP" "DFF")"
DFFC_USED="$(extract_cell_count "$YOSYS_SYNTH_LOG" "$TOP" "DFFC")"
DFFCE_USED="$(extract_cell_count "$YOSYS_SYNTH_LOG" "$TOP" "DFFCE")"
DFFPE_USED="$(extract_cell_count "$YOSYS_SYNTH_LOG" "$TOP" "DFFPE")"
DFFRE_USED="$(extract_cell_count "$YOSYS_SYNTH_LOG" "$TOP" "DFFRE")"
DFFE_USED="$(extract_cell_count "$YOSYS_SYNTH_LOG" "$TOP" "DFFE")"
FF_USED=$((DFF_USED + DFFC_USED + DFFCE_USED + DFFPE_USED + DFFRE_USED + DFFE_USED))
BSRAM_USED=$((SPX9_USED + DPB_USED))

echo "[TN1K] est usage: LUT4=${LUT4_USED}/${TN1K_LUT4_MAX} FF=${FF_USED}/${TN1K_FF_MAX} BSRAM=${BSRAM_USED}/${TN1K_BSRAM_MAX}"
if [ "$LUT4_USED" -gt "$TN1K_LUT4_MAX" ] || [ "$FF_USED" -gt "$TN1K_FF_MAX" ] || [ "$BSRAM_USED" -gt "$TN1K_BSRAM_MAX" ]; then
  echo "[WARN] likely does not fit Tang Nano 1K resource limits."
fi
echo

if [ "$UTIL_ONLY" -eq 1 ]; then
  echo "[OK] util-only mode completed."
  echo "Logs: $YOSYS_STAT_LOG, $YOSYS_SYNTH_LOG"
  exit 0
fi

if ! command -v nextpnr-gowin >/dev/null 2>&1 || ! command -v gowin_pack >/dev/null 2>&1; then
  echo "[WARN] nextpnr-gowin/gowin_pack not found. Falling back to util-only result."
  echo "       Install tools and rerun without --util-only for PnR + bitstream."
  exit 0
fi

if [ ! -f "$CST_PATH" ]; then
  echo "[ERR] constraints file not found: $CST_PATH" >&2
  exit 1
fi

if grep -q "<PIN>" "$CST_PATH"; then
  echo "[ERR] constraints file has placeholder pins: $CST_PATH" >&2
  echo "      Fill IO_LOC values or use --cst with a board-specific CST." >&2
  exit 1
fi

echo "[3/4] nextpnr-gowin..."
nextpnr-gowin \
  --json "$NETLIST_JSON" \
  --write "$PNR_JSON" \
  --device "$NEXTPNR_DEVICE" \
  --freq "$FREQ_MHZ" \
  --cst "$CST_PATH" \
  >"$NEXTPNR_LOG" 2>&1

echo "[4/4] gowin_pack..."
gowin_pack \
  -d "$PACK_DEVICE" \
  -o "$BITSTREAM_FS" \
  "$PNR_JSON" \
  >"$PACK_LOG" 2>&1

echo
echo "=== nextpnr summary ==="
grep -E "Info: Device utilisation|Info: Max frequency|Critical path|^ +LUT|^ +DFF|^ +BSRAM" "$NEXTPNR_LOG" || true
echo
echo "[OK] bitstream: $BITSTREAM_FS"
echo "Logs: $YOSYS_STAT_LOG, $YOSYS_SYNTH_LOG, $NEXTPNR_LOG, $PACK_LOG"
