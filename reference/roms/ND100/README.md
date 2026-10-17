# ND-100 PROMs

Unlike the ND-110/120 which use two large 32-KiB EPROMs, the ND-100
CPU stores its microcode in many small **Signetics 82S185** PROMs
(2K x 8-bit bipolar fuse-link). Each PROM only uses its **low 4 bits**
of output - so effectively they are 2K x 4 PROMs sitting in 8-bit
sockets.

Twelve PROMs in parallel produce a single 48-bit microinstruction;
additional PROMs provide the sequencer (next microaddress + test
select) and the instruction-decoder PLA (macro opcode → microcode
entry address).

## Card variants

Two variants of the ND-100 CPU card (both "48-bit", per the ROM
archive folder names) are stored here:

| Folder       | PROMs | Card                             |
|--------------|-------|----------------------------------|
| `3033S/`     | 19    | Base ND-100 CPU                  |
| `3033E-CX/`  | 35    | CPU eXtended (extra microcode + patched slot)|

## PROM role matrix

The PCB has chips arranged in labelled rows/columns. Each PROM file
name encodes its part number, chip family (`82s185`) and slot position.

### 3033S (base)

| Role        | Slot range  | Part numbers    | Chips | Width |
|-------------|-------------|-----------------|-------|-------|
| Microcode   | `d5`..`d16` | `01504N-01515N` | 12    | 48 bits (12 × 4) |
| Sequencer   | `d17`..`d20`| `01500P-01503Q` | 4     | 16 bits |
| Decode PLA  | `b18`..`b20`| `01600N-01602N` | 3     | 12 bits |

### 3033E-CX (extended)

| Role              | Slot range  | Part numbers    | Chips | Width |
|-------------------|-------------|-----------------|-------|-------|
| Microcode (base)  | `d5`..`d16` | `01504-01515` (d15 patched to `01705N`) | 12 | 48 bits |
| Sequencer (base)  | `d17`..`d20`| `01500P-01503Q` | 4     | 16 bits |
| Microcode (ext)   | `c5`..`c16` | `08504D-08515E` | 12    | 48 bits |
| Sequencer (ext)   | `c17`..`c20`| `08500D-08503D` | 4     | 16 bits |
| Decode PLA (CX)   | `b18`..`b20`| `08600D-08602D` | 3     | 12 bits |

The CX variant has a second complete bank of microcode + sequencer
(rows `c`), giving ~4K microinstructions total. The base instruction
set maps into the first 2K; extended instructions map into the second.
Slot `d15` is swapped to `01705N` in the CX - a replacement chip for
the part of the base microcode that was updated in the extended version.

## Bit ordering

The chip at the highest-numbered column (`d20` / `c20`) holds the LOW
nibble (bits 0-3) of the microword; the chip at the lowest-numbered
column (`d5` / `c5`) holds the HIGH nibble (bits 60-63). The sixteen
chips `d5`..`d20` together give a 64-bit word. This is the order of
`tools/nd100-combine.py` and of `lib/ts/src/nd100-proms.ts`:

    chip    output bits
    d20     3..0      (low nibble)
    d19     7..4
    d18     11..8
    d17     15..12
    d16     19..16
    d15     23..20
    d14     27..24
    d13     31..28
    d12     35..32
    d11     39..36
    d10     43..40
    d9      47..44
    d8      51..48
    d7      55..52
    d6      59..56
    d5      63..60    (high nibble)

An earlier version of this section said that `d5` is the low nibble and
that only 12 chips (`d5`..`d16`) form a 48-bit word. That contradicted the
tool and the 16-chip layout that the tests use.
`tests/nd100-3033s-roundtrip.test.ts` combines the 16 chips this way and
gets 2048 of 2048 words back from disassemble + assemble. A lossless round
trip does not by itself prove the bit order is the one on the board; the
tool's header says it was checked 100 percent against an independent
stitch of the same PROMs on 2026-04-17, which was not repeated here.

## Stored form (XOR)

The words are used as they come from the chips, with no XOR of bits 22-27
(see `docs/nd100-prom-layout.md`, section 7). The round trip is 2048/2048
with no XOR and also with XOR `0x01800000`, `0x0F800000` and `0x0FC00000`
(checked 2026-10-17), so the test cannot tell which form is the true
reading of the hardware. Open question, not settled.

## Combining the PROMs

Use `tools/nd100-combine.py`:

```bash
# From the repo root
python3 tools/nd100-combine.py combine \
    --variant 3033S \
    --indir  reference/roms/ND100/3033S \
    --outdir /tmp/nd100-3033S

# Produces:
#   3033S-microcode.CODE   48-bit microwords (2048 addresses)
#   3033S-sequencer.CODE   16-bit next-addr / test-select (2048 addresses)
#   3033S-decode.CODE      12-bit macro-opcode dispatch table (2048 entries)
```

Each `.CODE` file follows the same 10-byte-per-record format used by
ND-110/120 (`parseCodeFile()` in the TS library): 2-byte little-endian
address + 8-byte little-endian word. Addresses with all-zero content
are omitted, matching the ND110Compile convention.

## Splitting a combined microcode back to PROMs

Not yet implemented. Add a `split` subcommand to `nd100-combine.py`
when burning fresh PROMs becomes a concrete need.

## Full layout reference

See [`docs/nd100-prom-layout.md`](../../../docs/nd100-prom-layout.md)
for:

- Physical PCB slot diagrams
- Complete role matrix per variant
- Signal-flow diagram (microsequencer / decode-PLA / microcode)
- Per-bit ordering table
- Combine-formula pseudocode
- Differences between 3033S and 3033E-CX
- Comparison with ND-110/ND-120 CPU architectures
- Open questions (bank-select signal, sequencer bit assignment, ...)

## Source

ROM dumps provided by Frode (via the zip archive `Nord 100 ROMs.zip`),
April 2026. Folder names (`3033E NORD 100 CPU 48-bit CX` and
`3033S NORD 100 CPU 48-bit`) preserved in spirit as `3033E-CX` and
`3033S`.
