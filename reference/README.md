# Reference material

This directory holds **read-only reference material** used for validating
downstream toolchains against real hardware.

## What belongs here

- **ROM chip binaries** (`roms/ND100/`, `roms/ND110/`, `roms/ND120/`)
  — raw dumps of physical EPROM chips from original ND cards.
- **Microcode source files** (`*.uc`) — human-readable microcode written
  in the Norsk Data 3-line assembly format. These are INPUTS to the
  C# assembler.

## What does NOT belong here

- `.CODE` binary output from the C# assembler — regenerable from `.uc`;
  lives with the toolchain that produces it.
- `.SYMBOLS.TXT` symbol dumps — regenerable from `.uc`; same reason.
- Anything produced by compilation — always stay with the compiler.

## Current contents

### Source files

| File | Status |
|------|--------|
| `ND-110-RASK.uc` | Valid hand-patched ND-110 RASK microcode source |
| `ND-120-*.uc`    | Work in progress - not yet valid, will be added when ready |
| `ND-100-*.uc`    | Not yet available |

### ROM images

| Path | Chip | Card | Version |
|------|------|------|---------|
| `roms/ND110/37948L.bin` | LOW chip | ND-110 3095 | L (0o14) |
| `roms/ND110/37949L.bin` | HIGH chip | ND-110 3095 | L (0o14) |
| `roms/ND120/AM27256_45132L.bin` | LOW chip | ND-120 AM27256 | L (0o14) |
| `roms/ND120/AM27256_45133L.bin` | HIGH chip | ND-120 AM27256 | L (0o14) |
| `roms/ND100/`                   | — | — | ROMs pending |

Each pair combines into a 64 KiB microcode image. The "HIGH" chip
contributes the upper byte of each 16-bit sub-word; the "LOW" chip
contributes the lower byte.

## Important: storage form

- **ND-110 ROMs** store microcode in **token form** — bits 22-27 are
  XOR'd with `0x0FC00000` relative to the canonical (assembled) form.
- **ND-120 ROMs** store microcode in **canonical form** directly.

The XOR is applied at compile time by the reference C# assembler for
ND-110. Consumers reading raw ROM bytes must handle this difference.
See `../docs/special-bits.md`.

## Do not modify

These files are immutable reference. Never overwrite a ROM image
(unless replacing an inaccurate dump with a better one, in which case
note it in `../CHANGELOG.md`). Never regenerate the `.uc` from a
disassembly and commit over the original — the original is the source.
