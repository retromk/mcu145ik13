# Tang Nano 9K flow

Use the top-level script:

```bash
./synth_tangnano9k.sh --util-only
```

This runs Yosys stats + `synth_gowin` and writes logs to:

- `build/tangnano9k/yosys_stat.log`
- `build/tangnano9k/yosys_synth.log`

By default the script enables both `GOWIN_BRAM_ROM` and `GOWIN_BRAM_SHIFT`:

- large ROMs (`MROM/UROM/SROM`) are inferred as synchronous block RAM
- long shift chains (`cmem_shift`) are inferred as block RAM backed circular buffers
- memory init is loaded from `rom_data/*.mem`

Disable it for comparison:

```bash
./synth_tangnano9k.sh --util-only --no-bram-rom --no-bram-shift
```

Selective disable is also supported:

```bash
./synth_tangnano9k.sh --util-only --no-bram-shift
./synth_tangnano9k.sh --util-only --no-bram-rom
```

To run full PnR + bitstream generation you need:

- `nextpnr-gowin`
- `gowin_pack`
- valid pin constraints in `fpga/tangnano9k/tangnano9k.cst`

Then run:

```bash
./synth_tangnano9k.sh
```

Outputs:

- `build/tangnano9k/mk61_top.json`
- `build/tangnano9k/mk61_top.pnr.json`
- `build/tangnano9k/mk61_top.fs`
- `build/tangnano9k/nextpnr.log`
- `build/tangnano9k/gowin_pack.log`

Override defaults if needed:

```bash
./synth_tangnano9k.sh \
  --top mk61_top \
  --family gw1n \
  --nextpnr-device GW1NR-LV9QN88PC6/I5 \
  --pack-device GW1N-9C \
  --freq 27 \
  --cst fpga/tangnano9k/tangnano9k.cst
```

If you change ROM contents in `rom_*.v`, regenerate `.mem` images:

```bash
./tools/generate_gowin_mem.py
```
