# MK-61 / IK13xx bit-serial RTL (Verilog-2005, no Makefile)

This project embeds:
- MROM (mcommands.h) as async case ROM
- UROM (ucommands.h) as async case ROM
- SROM (synchro.h) as async case ROM

Core `mcu145ik13_core.v` is a direct Verilog-2005 port of pmkemu `cMCU::tick()` (cmcu13.cpp),
including the exact ucmd_u bitfields from cmcu13.h.

Run checks:
  ./build_and_check.sh

Bit-exact differential check against local `./emu145` core model:
  ./tools/build_emu145_ref.sh
  ./tools/compare_rtl_emu145.py --skip-build

Full pipeline including differential check:
  WITH_EMU145_DIFF=1 ./build_and_check.sh
  WITH_HLS_DIFF=1 ./build_and_check.sh

VHDL RTL port (GHDL):
  ./vhdl/run_ghdl.sh --cycles 20000 --mode 0
  ./tools/compare_vhdl_verilog.py --cycles 20000 --mode 0
  ./tools/check_vhdl_equivalence.sh 20000
  # details: ./vhdl/README.md

HLS RTL variant (C++/HLS style):
  ./hls/run_hls.sh --cycles 20000 --mode 0
  ./tools/compare_hls_verilog.py --cycles 20000 --mode 0
  ./tools/check_hls_equivalence.sh 20000
  # details: ./hls/README.md

Tang Nano 9K flow (Yosys -> nextpnr-gowin -> gowin_pack):
  ./synth_tangnano9k.sh --util-only
  ./synth_tangnano9k.sh --util-only --no-bram-rom --no-bram-shift   # compare against pure FF/LUT mode
  ./synth_tangnano9k.sh --util-only --no-bram-shift                 # keep BRAM ROM, disable BRAM shift
  ./synth_tangnano9k.sh
  ./tools/generate_gowin_mem.py                      # regenerate BRAM ROM images after ROM edits
  # details: ./fpga/tangnano9k/README.md

Tang Nano 1K flow (GW1NZ-LV1QN48C6/I5):
  ./synth_tangnano1k.sh --util-only
  ./build_tangnano1k.sh                                  # default top: mk61_top_1k_board (onboard CLK/KEY/RGB)
  ./build_tangnano1k.sh --flash
  ./build_tangnano1k.sh --external
  ./build_tangnano1k.sh --fx2                            # mk61_top_1k_fx2 + FX2 bridge CST profile
  ./synth_tangnano1k.sh --util-only --full-mk61              # reference: full top (does not fit 1K)
  ./synth_tangnano1k.sh --util-only --top-1k-core            # reduced pin-compatible top
  ./synth_tangnano1k.sh --util-only --external               # mk61_top_1k + external CST profile
  ./synth_tangnano1k.sh --util-only --fx2                    # mk61_top_1k_fx2 + scan_active output for FX2
  ./synth_tangnano1k.sh --util-only --no-bram-rom --no-bram-shift
  ./synth_tangnano1k.sh
  # details: ./fpga/tangnano1k/README.md

FX2LP hardware bridge (CY7C68013A) for external MK-61 control:
  ./fx2/firmware/build_fx2_fw.sh
  ./fx2/fx2_loader.py --ihx fx2/firmware/build/mk61_fx2_fw.ihx
  ./fx2/fx2_virtual_calculator.py --preset calc_12_enter_3_plus --mode rad
  # details: ./fx2/README.md

Virtual calculator (testbench-driven):
  ./virtual_calculator.py --preset boot_probe --mode rad --cycles 260000 --start 100000 --gap 12000
  ./virtual_calculator.py --engine verilog --preset calc_12_enter_3_plus --preset-timing on
  ./virtual_calculator.py --engine hls --preset calc_12_enter_3_plus --preset-timing on
  ./virtual_calculator.py --engine vhdl --preset calc_12_enter_3_plus --preset-timing on

GUI for everyday use:
  ./virtual_calculator_gui.py

TI nSpire CX II variant:
  ./nspire/build_host.sh
  ./nspire/build/mk61_nspire_host
  make -f ./nspire/Makefile.ndless
  # details: ./nspire/README.md

HP Prime variant:
  ./hpprime/build_host.sh
  ./hpprime/build/mk61_hpprime_host
  # details: ./hpprime/README.md

MK-90 (PDP-11 compatible) variant:
  ./mk90/build_host.sh
  ./mk90/build/mk61_mk90_host
  ./mk90/build_rt11_stub.sh
  ./mk90/build/mk61_mk90_rt11_stub_host
  # details: ./mk90/README.md

Casio fx-CG50 variant:
  ./fxcg50/build_host.sh
  ./fxcg50/build/mk61_fxcg50_host
  ./fxcg50/build_sdk_stub.sh
  ./fxcg50/build/mk61_fxcg50_sdk_stub_host
  # details: ./fxcg50/README.md

Nintendo Switch (Smile BASIC 4) variant:
  ./switch_sb4/build_host.sh
  ./switch_sb4/build/mk61_switch_sb4_host
  # details: ./switch_sb4/README.md

ZX Spectrum (Z80 Assembler) variant:
  ./zxspectrum/build_host.sh
  ./zxspectrum/build/mk61_zx_host
  ./zxspectrum/build_z80_stub.sh
  # details: ./zxspectrum/README.md

dsPIC30F6014A (ASM) variant:
  ./dspic30f6014a/build_host.sh
  ./dspic30f6014a/build/mk61_dspic30_host
  ./dspic30f6014a/build_asm_stub.sh
  # details: ./dspic30f6014a/README.md

Detailed usage guide (RU):
  ./VIRTUAL_CALCULATOR_GUIDE.md

Custom scenario examples:
  # List built-in presets and key aliases
  ./virtual_calculator.py --list-presets
  ./virtual_calculator.py --list-keys

  # emu145 keypad matrix tokens (row 1..3, D2..D11): B_1_2 / R1D2 / 1:2
  ./virtual_calculator.py --keys "R1D2 R1D3 R2D10 R3D11" --gap 12000 --mode deg --cycles 320000

  # show per-button display reaction report
  ./virtual_calculator.py --preset scan_row1 --cycles 520000 --start 100000 --gap 20000 --report-events

  # RPN semantic demos
  ./virtual_calculator.py --preset calc_1_enter_2_plus --cycles 420000 --start 100000 --gap 15000
  ./virtual_calculator.py --expr "1 ENTER 2 +" --cycles 420000 --start 100000 --gap 15000

  # shifted function aliases from emu145 legends
  ./virtual_calculator.py --expr "1 SIN" --cycles 420000 --start 100000 --gap 15000
  ./virtual_calculator.py --expr "9 SQRT" --cycles 420000 --start 100000 --gap 15000

  # override semantic aliases from CLI
  ./virtual_calculator.py --expr "1 SIN" \
    --alias SIN=F+B_1_9

  # override aliases from file (see mk61_aliases.example.txt)
  ./virtual_calculator.py --expr "1 ENTER 2 +" --aliases-file mk61_aliases.example.txt

  # low-level line driving mode (legacy): K1, K2, K12, NONE
  ./virtual_calculator.py --keys "K1 K2 K12 NONE" --hold 20 --gap 300 --cycles 220000

Artifacts:
  rtl_trace.csv (simple master outputs per tick)
  logs/*.log (iverilog/vvp/verilator/yosys)
  logs/compare/* (RTL vs emu145 per-scenario reports and summary)

Notes:
- Default simulation keeps async case-ROM behavior; Tang Nano flow enables BRAM modes (`GOWIN_BRAM_ROM`, `GOWIN_BRAM_SHIFT`) for packing.
- `segment/dcycle/syncout` match cmcu13.cpp behavior.
- `virtual_calculator.py` key map is aligned with local `./emu145`:
  `pmkemu/mainwindow.cpp` scan order + `pmkemu/mainwindow.ui` + `pmkemu/buttons/_Nr.png`.
- `tb_mk61.v` supports scripted low-level key events via `+keys=<path>` where each line is:
  `<cycle> <k1> <k2>`
- `tb_mk61.v` supports emu145-style keypad events via `+buttons=<path>` where each line is:
  `<cycle> <row> <col>` (`row` in `1..3`, `col` in `0..9` mapping to D2..D11)
- For keypad scripts, use larger gaps (`--gap` around `12000..20000`) to avoid key overlap while MCU scan logic processes events.
- Aliases can be single-key or macro-style (`NAME=B_r_d+B_r_d`), e.g. `SIN=F+B_1_9`.
- `tools/compare_rtl_emu145.py` runs stress scenarios and compares sync-frame stream + per-button display effects.
