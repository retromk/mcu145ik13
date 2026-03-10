#!/usr/bin/env bash
set -euo pipefail
if [ -n "${ZSH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
mkdir -p logs

echo "[*] Tool versions" > logs/versions.log
(iverilog -V || true) >> logs/versions.log 2>&1
(verilator --version || true) >> logs/versions.log 2>&1
(yosys -V || true) >> logs/versions.log 2>&1

echo "[*] iverilog compile" | tee logs/status.log
iverilog -g2005 -o sim \
  rom_mrom_1302.v rom_mrom_1303.v rom_mrom_1306.v \
  rom_urom_1302.v rom_urom_1303.v rom_urom_1306.v \
  rom_srom_1302.v rom_srom_1303.v rom_srom_1306.v \
  rom_wrappers.v \
  cmem_shift.v mcu145ik13_core.v mk61_top.v tb_mk61.v \
  > logs/iverilog.log 2>&1

echo "[*] vvp run" | tee -a logs/status.log
vvp sim > logs/vvp.log 2>&1

echo "[*] verilator lint" | tee -a logs/status.log
verilator --lint-only *.v > logs/verilator.log 2>&1 || true

echo "[*] yosys check" | tee -a logs/status.log
yosys -p "read_verilog \
  rom_mrom_1302.v rom_mrom_1303.v rom_mrom_1306.v \
  rom_urom_1302.v rom_urom_1303.v rom_urom_1306.v \
  rom_srom_1302.v rom_srom_1303.v rom_srom_1306.v \
  rom_wrappers.v \
  cmem_shift.v mcu145ik13_core.v mk61_top.v; \
  proc; opt; check; stat" > logs/yosys.log 2>&1

if [ "${WITH_EMU145_DIFF:-0}" = "1" ]; then
  echo "[*] emu145 differential check" | tee -a logs/status.log
  ./tools/build_emu145_ref.sh > logs/emu145_ref_build.log 2>&1
  ./tools/compare_rtl_emu145.py --skip-build --strict > logs/emu145_compare.log 2>&1
fi

if [ "${WITH_HLS_DIFF:-0}" = "1" ]; then
  echo "[*] hls differential check" | tee -a logs/status.log
  ./tools/check_hls_equivalence.sh 20000 > logs/hls_compare.log 2>&1
fi

echo "[*] DONE" | tee -a logs/status.log
