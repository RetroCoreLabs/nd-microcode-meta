# Changelog

All notable changes to the ND-100/110/120 microcode metadata.

This repository uses [Semantic Versioning](https://semver.org/):
- **MAJOR** - incompatible schema changes (token format, YAML structure)
- **MINOR** - new tokens, new runtime facts, backwards-compatible
- **PATCH** - description fixes, typo corrections, doc updates

## Unreleased

### Added

- **NORD-10, ND-500, ND-5000 tokens and fields** - `defs/tokens/nd10-tokens.yaml`
  (197), `nd500-tokens.yaml` (721), `nd5000-tokens.yaml` (609) and
  `defs/fields/nd10-fields.yaml`, `nd500-fields.yaml`, `nd5000-fields.yaml`,
  generated from the C# files `ND10Tokens.cs`, `ND500Tokens.cs`,
  `ND5000Tokens.cs` and the matching `*Fields.cs`. New encoding form
  `encoding: { parts: [...] }` (6-digit octal, most significant part first).
- **Tools** - `generate_tokens_yaml_nd10.py`, `_nd500.py`, `_nd5000.py`,
  `generate_fields_yaml.py`, and `validate_new_models.py` (compares the
  YAML with the C# files).
- **nd120-dly variant** - `variant_overrides` block in `nd120-tokens.yaml`:
  `B,P`, `B,B`, `B,X` without the DLY1 bit (w2 `000002`, `000003`,
  `000007`), as the C# `ND120Tokens.AdjustTokensForVersionL()` does.
- **Reference files** - `reference/ND-110-RASK.CODE` and
  `reference/ND-110-RASK.SYMBOLS.TXT` (C# assembler output, comparison files).

### Changed

- **ND-100 token names, from the printed Norsk Data listing** - `A,SHCE` is now `A,SRCE` (the listing
  prints SRCE 35 times and the sibling `B,SRCE` exists; SHCE was a misreading of the dot matrix print
  of ND-06.018.01 Appendix A page A-2). New token `XRF` (bit 50, the name the listing uses 145 times,
  same bit as `EN_EXT`). 300 tokens. `tools/nd100-prom-to-uc.mjs` now says its output is the plain
  chip decoding; the source with the original names and comments is in the NDMicroAsm repository
  (`microcode/ND-100/*.uc`).
- `lib/ts/scripts/generate-defs.mjs` also writes NORD-10, ND-500 and
  ND-5000 into `lib/ts/src/generated-defs.json`.
- Library tests read their files from `reference/` (paths were wrong);
  a 6MB ND-120 ROM round-trip test was added.
- `reference/README.md` and `README.md` describe the 4MB / 6MB ROM folders.

## 1.0.0 - 2026-04-16

Initial extraction from the `nd100uc` repository. Establishes this as
the single source of truth for microcode metadata consumed by all
downstream toolchains (C# assembler, TypeScript library, VSCode
extension, future C library, FPGA reference, etc.).

### Contents

- **Tokens** - 356 ND-110, 358 ND-120 (extracted from the reference
  C# assembler `ND110Compile/ND110Tokens.cs` and `ND120Tokens.cs`)
- **Fields** - bit-position definitions for ND-110 and ND-120
  microinstruction words (ND-100 placeholder)
- **Runtime data flow** - ALU / IDBS / COMM / ALUD runtime semantics
  derived from the ND-110 CPU emulator source
- **Format rules** - 3-line assembly layout conventions, zero-display
  rules, jump-context heuristics
- **Common** - register naming, condition codes

### Reference material

- `ND-110-RASK.uc` - valid hand-patched ND-110 RASK microcode source
  (ND-120 and ND-100 `.uc` sources will be added as they become
  available)
- ROM images organised by CPU family:
  - `roms/ND110/37948L.bin` + `37949L.bin` (ND-110 3095 card, version L)
  - `roms/ND120/AM27256_45132L.bin` + `AM27256_45133L.bin` (ND-120, version L)
  - `roms/ND100/` reserved for ND-100 chip dumps

**Note:** `.CODE` and `.SYMBOLS.TXT` compile outputs do NOT live in
this repo - they are regenerable from the `.uc` sources and belong
with the toolchain that produces them. Only ROM chip binaries and
hand-written `.uc` sources are tracked here.

### Documentation

- `docs/special-bits.md` - reference for the undocumented bits 20-27
  region (timing hints in tokens, `B,B` vs `B,3`, ROM XOR flip, etc.)
- `docs/ND-06.031.1-*.pdf` - official Norsk Data Microprogrammer's Guide
