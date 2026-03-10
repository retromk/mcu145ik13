# HLS Variant (C++)

This directory contains a high-level synthesis (HLS) implementation of the MK-61 core pipeline.

Files:

- `mk61_hls.hpp` / `mk61_hls.cpp`: cycle-accurate HLS C++ model of `mcu145ik13_core` + `mk61_top`
- `tb_mk61_hls.cpp`: C++ testbench that writes `rtl_trace_hls.csv`
- `run_hls.sh`: build + run local C++ simulation
- `rom_tables.hpp`: generated ROM tables (`MROM/UROM/SROM`) for chips 1302/1303/1306
- `vitis_hls.tcl`: optional Vitis HLS synthesis script template

## Quick Start

1. Generate HLS ROM header:
   - `./tools/generate_hls_roms.py`
2. Run HLS simulation:
   - `./hls/run_hls.sh --cycles 20000 --mode 0`
   - external events from virtual calculator:
     - `./hls/run_hls.sh --cycles 760000 --mode 0 --use-external-events`
3. Compare against Verilog RTL:
   - `./tools/compare_hls_verilog.py --cycles 20000 --mode 0`
4. Check all modes (`RAD/DEG/GRD`):
   - `./tools/check_hls_equivalence.sh 20000`

`run_hls.sh` supports:

- `--no-build` (reuse existing `hls/tb_mk61_hls`)
- `--use-external-events` (read `logs/virtual_buttons.txt` / `logs/virtual_keys.txt`)

## HLS Top Function

For synthesis flows, use:

- `mk61_top_hls_step(...)` (`extern "C"`)

It keeps internal static state and performs exactly one master clock step per call.

## Optional Vitis HLS Flow

Example (adjust part/clock as needed):

- `vitis_hls -f hls/vitis_hls.tcl`
