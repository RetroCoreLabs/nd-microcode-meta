# Changelog

All notable changes to the ND-100/110/120 microcode metadata.

This repository uses [Semantic Versioning](https://semver.org/):
- **MAJOR** - incompatible schema changes (token format, YAML structure)
- **MINOR** - new tokens, new runtime facts, backwards-compatible
- **PATCH** - description fixes, typo corrections, doc updates

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
