# Reference material

This directory holds **read-only reference material** used for validating
downstream toolchains against real hardware.

## What belongs here

- **ROM chip binaries** (`roms/ND100/`, `roms/ND110/`, `roms/ND120/`)
  — raw dumps of physical EPROM chips from original ND cards.
- **Microcode source files** (`*.uc`) — human-readable microcode written
  in the Norsk Data 3-line assembly format. These are INPUTS to the
  C# assembler.

## Comparison files from the C# toolchain

Output of the reference C# assembler is kept here as comparison files, so
the TypeScript library can be checked against it without the C# repo:

- `ND-110-RASK.CODE` - C# output for `ND-110-RASK.uc` (10-byte records).
  The TypeScript assembler produces the same 48650 bytes, 0 differences.
- `ND-110-RASK.SYMBOLS.TXT` - symbol dump from the same C# run.

Do not regenerate these from the TypeScript library and commit over them.

## Current contents

### Source files

| File | Status |
|------|--------|
| `ND-110-RASK.uc` | Valid hand-patched ND-110 RASK microcode source |
| `ND-120-*.uc`    | Work in progress - not yet valid, will be added when ready |
| `ND-100-*.uc`    | Not yet available |

### Comparison files (SHA-1)

| File | SHA-1 |
|------|-------|
| `ND-110-RASK.CODE` | `e3c80060999e4a0f33c7de76251de98eecebeafe` |
| `ND-110-RASK.SYMBOLS.TXT` | `a1ba3375869bd907ff179d3b7d8b77870c84b504` |

### ROM images

| Path | Chip | Card | Version |
|------|------|------|---------|
| `roms/ND110/37948L.bin` | LOW chip | ND-110 3095 | L (0o14) |
| `roms/ND110/37949L.bin` | HIGH chip | ND-110 3095 | L (0o14) |
| `roms/ND120/4MB/45132L.27c256.b23.bin` | LOW chip | ND-120 4MB | L (0o14) |
| `roms/ND120/4MB/45133L.27c256.b26.bin` | HIGH chip | ND-120 4MB | L (0o14) |
| `roms/ND120/6MB/45132L.27c256.b23.bin` | LOW chip | ND-120 6MB | L (0o14); differs from 4MB at byte 6633 |
| `roms/ND120/6MB/45133L.27c256.b26.bin` | HIGH chip | ND-120 6MB | L (0o14) |
| `roms/ND100/3033S/`, `roms/ND100/3033E-CX/` | PROM files | ND-100 | see `roms/ND100/README.md` |

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

## Images and sources for NORD-10, ND-500, ND-5000 and ND-120 DELILAH

Copied byte for byte (checked with `cmp`) from the C# project ND110Compile
and from the nd500uc / nd5000uc projects. They are the ground truth the
TypeScript library is tested against.

- `nord10/` - the two NORD-10 PROM dumps (`.hex`, 1024 and 4096 words) and
  the MICMAC sources that assemble to them (`NORD-10.uc`, `NORD-10-CE.uc`).
- `nd500/` - `CONT-STORE-10611.DATA` (ND-500 control store, packed18, 147456
  bytes), the source `CONT-STORE-10611.uc`, and the C# output
  `CONT-STORE-10611.CODE` (identical to the `.DATA`).
  `ND-500-EXAMPLE.uc` is a small example source.
- `nd5000/` - 13 ND-5000 control store images `*.DATA` (262144 bytes each,
  16 bytes per word) with their label files `*.LABE`.
- `nd120/` - `ND-120-DELILAH-K.uc` / `ND-120-DELILAH-L.uc` and the C# output
  `ND-120-DELILAH-K.CODE` / `ND-120-DELILAH-L.CODE`. The L file is compiled
  with the version L fixup (variant nd120-dly).

| File | Bytes | SHA-1 |
|------|-------|-------|
| `reference/nd120/ND-120-DELILAH-K.CODE` | 48860 | `440232ff2b836546fe8e00464d48098fa714f4fe` |
| `reference/nd120/ND-120-DELILAH-K.uc` | 795414 | `ab6cb5f9fb1af682d75c098cb9ac5ef463238fb7` |
| `reference/nd120/ND-120-DELILAH-L.CODE` | 48870 | `ca3fe81135b3745a194d8f84b9b4d8800121a768` |
| `reference/nd120/ND-120-DELILAH-L.uc` | 795623 | `7706270c5d7949b8b8d079949648899d658a0344` |
| `reference/nd500/CONT-STORE-10611.CODE` | 147456 | `f8f557873105e2f94f402e50c47297b0a31837ec` |
| `reference/nd500/CONT-STORE-10611.DATA` | 147456 | `f8f557873105e2f94f402e50c47297b0a31837ec` |
| `reference/nd500/CONT-STORE-10611.uc` | 517308 | `1d568c14ccbb41506a20fb6af30eee5b5d57c71d` |
| `reference/nd500/ND-500-EXAMPLE.uc` | 1370 | `184b326f5b743a9ff1e1373d42cd013f35e8ebd5` |
| `reference/nd5000/CONTROL-STORE.DATA` | 262144 | `b94cfd5d27403d9633b6d19856beb4315dace6e6` |
| `reference/nd5000/MIC-5200-90-500.DATA` | 262144 | `ab1e16850f8ba3cae47be585b3c5147f057ae9f7` |
| `reference/nd5000/MIC-5500-90-500.DATA` | 262144 | `a70ff019e5b77ba2b1b776f3275320a0df2db156` |
| `reference/nd5000/MIC-5700-90-500.DATA` | 262144 | `404c59682fd5e22ba70daa19b560bef50c712778` |
| `reference/nd5000/MIC-5800-90-500.DATA` | 262144 | `05aa4af77d31832da43c2d3e7b89360cecba9ab6` |
| `reference/nd5000/MICRO-5200-A27.LABE` | 80808 | `a46bd5a55830c43c6967c56b72fc487e5f15f3e4` |
| `reference/nd5000/MICRO-5200-B27.LABE` | 81144 | `725735a3f12ce947f9a03c89a4d26d80cfb34ccf` |
| `reference/nd5000/MICRO-5200-M27.DATA` | 262144 | `40656b43b467dc782d0bffa45ae0ca3fe5dc309c` |
| `reference/nd5000/MICRO-5500-A27.LABE` | 76272 | `d456eaabdca57ffef501e90cbf8b1e4e88fff390` |
| `reference/nd5000/MICRO-5500-B27.LABE` | 82272 | `6c4bdd4ce4abc1449a5e53b7170f13dfa6627269` |
| `reference/nd5000/MICRO-5500-M27.DATA` | 262144 | `c42b6123c3411f9a7d969bb8e86e438d0bb5347d` |
| `reference/nd5000/MICRO-5700-A27.LABE` | 76272 | `d456eaabdca57ffef501e90cbf8b1e4e88fff390` |
| `reference/nd5000/MICRO-5700-B27.LABE` | 82272 | `6c4bdd4ce4abc1449a5e53b7170f13dfa6627269` |
| `reference/nd5000/MICRO-5700-M27.DATA` | 262144 | `dfce82f5d59d8b85f665feeac6a9254919f26c54` |
| `reference/nd5000/MICRO-5800-A27.LABE` | 81936 | `9b0206482c3f73f853dfb05b55554cb4c77fc51b` |
| `reference/nd5000/MICRO-5800-A29.DATA` | 262144 | `19a0eacd643c7c1161ea8c21b5ae5cb14d5e7f57` |
| `reference/nd5000/MICRO-5800-A29.LABE` | 133424 | `317129322608fe282048e5ddb17ea6538729ed94` |
| `reference/nd5000/MICRO-5800-A30.DATA` | 262144 | `dab9c9dc5813f83921778a4b1773513f04058463` |
| `reference/nd5000/MICRO-5800-A30.LABE` | 130926 | `c8e248c3c2bceb7a18f40017a73d9157ed0c57ed` |
| `reference/nd5000/MICRO-5800-B27.LABE` | 82272 | `05ab55c45e36b8bf57419e408e56fc51322725e0` |
| `reference/nd5000/MICRO-5800-B29.DATA` | 262144 | `70e0107b57de64d80c2d10d15fe730d8ff4d576d` |
| `reference/nd5000/MICRO-5800-B29.LABE` | 139616 | `50f624697dfafbd5d902cd8a5a9bfe0f7406e28c` |
| `reference/nd5000/MICRO-5800-B30.DATA` | 262144 | `7cba6b1bd9bd3f9e9fb095bddc49876e18279b81` |
| `reference/nd5000/MICRO-5800-B30.LABE` | 137219 | `4b28c77a8b0a4e8393d385dd420cf9d6c0be2810` |
| `reference/nd5000/MICRO-5800-M27.DATA` | 262144 | `493f2db3565c8119354ba0befb57de0699970273` |
| `reference/nord10/NORD-10-1K-prom.hex` | 9216 | `3a6e71884d26c883b248e1d0b6732c60e3686665` |
| `reference/nord10/NORD-10-CE-4K-prom4k.hex` | 36864 | `f3189148c10bf2c7eabd9f6a87cdea6b9872f9cf` |
| `reference/nord10/NORD-10-CE.uc` | 191016 | `47c52dc243ca61f74f0c72415e46d634d482236b` |
| `reference/nord10/NORD-10.uc` | 66728 | `7e4252d39ad2ff9184f9ef7901ed6a2084adc975` |
| `reference/nord10/README.md` | 2357 | `69bb4642f5169ed41523173db62f34d2d442d0a7` |

## Do not modify

These files are immutable reference. Never overwrite a ROM image
(unless replacing an inaccurate dump with a better one, in which case
note it in `../CHANGELOG.md`). Never regenerate the `.uc` from a
disassembly and commit over the original — the original is the source.
