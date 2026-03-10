# Tang Nano 1K flow

Use the dedicated script:

```bash
./synth_tangnano1k.sh --util-only
```

Defaults:

- device: `GW1NZ-LV1QN48C6/I5`
- top: `mk61_top_1k_board` (board wrapper with onboard CLK/KEY/RGB mapping)
- BRAM optimizations enabled: `GOWIN_BRAM_ROM`, `GOWIN_BRAM_SHIFT`
- constraints file: `fpga/tangnano1k/tangnano1k_board.cst`

One-command build (and optional flash):

```bash
./build_tangnano1k.sh
./build_tangnano1k.sh --flash
./build_tangnano1k.sh --external
./build_tangnano1k.sh --fx2
```

The script prints an estimated fit check against Tang Nano 1K limits:

- LUT4: `1152`
- FF: `864`
- BSRAM blocks: `4` (`72 Kbit total`)

You can compare modes:

```bash
./synth_tangnano1k.sh --util-only --no-bram-rom --no-bram-shift
./synth_tangnano1k.sh --util-only --no-bram-rom
./synth_tangnano1k.sh --util-only --no-bram-shift
```

Build the original full 3-chip top for reference:

```bash
./synth_tangnano1k.sh --util-only --full-mk61
```

For full PnR of non-wrapper tops (`--full-mk61` or `--top-1k-core`), provide a matching CST:

```bash
./synth_tangnano1k.sh --full-mk61 --cst path/to/your_full_top.cst
```

Build pin-compatible reduced top (without board wrapper):

```bash
./synth_tangnano1k.sh --util-only --top-1k-core
./synth_tangnano1k.sh --util-only --external
./synth_tangnano1k.sh --util-only --fx2
```

Current measured utilization (Yosys mapped cells):

- `mk61_top_1k_board` (default): `LUT4=132`, `FF=613`, `BSRAM=4` -> fits 1K limits
- `mk61_top_1k --top-1k-core`: `LUT4=113`, `FF=576`, `BSRAM=4` -> fits 1K limits
- `mk61_top_1k_fx2 --fx2`: `LUT4=113`, `FF=576`, `BSRAM=4` -> fits 1K limits
- `mk61_top_1k --no-bram-rom --no-bram-shift`: `LUT4=1162`, `FF=576`, `BSRAM=0` -> slightly above LUT4 limit
- `mk61_top` (full): `LUT4=343`, `FF=1741`, `BSRAM=14` -> does not fit 1K limits

Onboard mapping used by `mk61_top_1k_board`:

- `CLK` -> pin `47` (27 MHz)
- `KEY_A_N` -> pin `13` (active-low key)
- `LED_R_N` -> pin `9` (active-low)
- `LED_G_N` -> pin `11` (active-low)
- `LED_B_N` -> pin `10` (active-low)

Pin mapping was taken from Tang Nano 1K schematic:
`tang_nano_1k_schematic.pdf` (Tang nano 6100, 2021-10-28).

External profile:

- CST file: `fpga/tangnano1k/tangnano1k_external_mk61_top_1k.cst`
- Top: `mk61_top_1k`
- Ports mapped for direct external wiring: `rst`, `k1`, `k2`, `mode[1:0]`, `dcycle[3:0]`, `syncout`, `segment[7:0]`
- Header hints from schematic (verify on your board):
  - `clk` pin `47` -> `P2-15`
  - `rst/k1/k2/mode[0]/mode[1]` pins `40/41/38/39/42` -> `P1-12/11/10/9/8`
  - `dcycle[3:0]` pins `15/16/17/18` -> `P2-3/4/5/6`
  - `syncout` pin `19` -> `P1-4`
  - `segment[0..7]` pins `20/22/23/24/27/28/29/30` -> `P1-5`, `P2-7/8/9/2/1`, `P1-3/2`

FX2 profile:

- CST file: `fpga/tangnano1k/tangnano1k_fx2_mk61_top_1k_fx2.cst`
- Top: `mk61_top_1k_fx2`
- Adds `scan_active` output for robust external keypad gating (`command[23:18] == 0`)
- Main usage: `./build_tangnano1k.sh --fx2`

Full PnR/bitstream (requires `nextpnr-gowin` + `gowin_pack`):

```bash
./synth_tangnano1k.sh
```

If ROM tables change, regenerate `.mem` files:

```bash
./tools/generate_gowin_mem.py
```
