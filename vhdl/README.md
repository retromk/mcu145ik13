# VHDL RTL Port (MK-61 Core)

This directory contains a full VHDL-2008 version of the MK-61 RTL datapath:

- `mcu145ik13_core.vhd` -> `mcu145ik13_core_vhdl`
- `cmem_shift.vhd` -> `cmem_shift_vhdl`
- `mk61_top.vhd` -> `mk61_top_vhdl`
- `tb_mk61_vhdl.vhd` -> VHDL testbench that writes `rtl_trace_vhdl.csv`

Generated VHDL ROMs (from Verilog ROM tables):

- `ik13_mrom.vhd`
- `ik13_urom.vhd`
- `ik13_srom.vhd`

## Quick Start

1. Regenerate VHDL ROM tables:
   - `./tools/generate_vhdl_roms.py`
2. Run VHDL simulation (defaults: `cycles=20000`, `mode=0`):
   - `./vhdl/run_ghdl.sh`
3. Compare VHDL vs Verilog behavior:
   - `./tools/compare_vhdl_verilog.py --cycles 20000 --mode 0`
4. Run all modes in one command:
   - `./tools/check_vhdl_equivalence.sh 20000`

Expected successful compare output:

- `sync-frame payloads are identical`
- constant sync-frame cycle offset (`vhdl-verilog`), typically `+2`

## `run_ghdl.sh` Options

- `--cycles N` simulation master cycles
- `--mode 0|1|2` mode (`0=RAD`, `1=DEG`, `2=GRD`)
- `--no-gen-roms` skip ROM regeneration
- `--no-build` reuse existing elaborated testbench
- `--use-external-events` read `logs/virtual_buttons.txt` / `logs/virtual_keys.txt`

Examples:

- `./vhdl/run_ghdl.sh --cycles 40000 --mode 1`
- `./vhdl/run_ghdl.sh --cycles 260000 --mode 0 --no-gen-roms`

## Architecture Notes

- Core generics match Verilog:
  - `CHIP` (`1302`, `1303`, `1306`)
  - `PRETICK_IN` (`0`, `1`)
- Mode encoding matches Verilog top-level:
  - `"00"` = RAD, `"01"` = DEG, `"10"` = GRD
- Reset boot command is constant per chip (same value as MROM address `0`) to keep deterministic startup in both Verilog and VHDL flows.

## macOS GHDL

Use wrapper script `./vhdl/ghdl.sh`; it sets `DYLD_LIBRARY_PATH` for Homebrew GCC runtime, then calls `/opt/homebrew/bin/ghdl`.
