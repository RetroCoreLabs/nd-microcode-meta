# nd-microcode-meta

Canonical metadata for the Norsk Data ND-100/110/120 microcode.

This repository is the **single source of truth** for:

- **Token encodings** - every `ALUF,PASSD` / `COMM,EWRF` / etc. with its
  full 64-bit octal encoding
- **Bitfield positions** - what lives at which bits of the microinstruction word
- **Runtime data flow** - ALU sources, destinations, IDBS producers,
  COMM side-effects (extracted from the reference CPU emulator)
- **Assembly format rules** - 3-line layout, zero-display conventions,
  jump-context detection
- **Reference microcode** - known-good `.CODE` binaries and the physical
  EPROM images from real ND-110 and ND-120 CPU cards, used by all
  toolchain implementations for bit-exact validation
- **Undocumented details** - the bits-20-27 region, ROM XOR flip,
  B-register dual-role semantics

All downstream tools consume these YAML files directly (or via a
generated snapshot). Toolchain implementations live in separate repos
that pull in `nd-microcode-meta` as a git submodule.

## Layout

```
defs/
├── tokens/
│   ├── nd110-tokens.yaml       356 tokens
│   └── nd120-tokens.yaml       358 tokens (12 ND-120-only are marked)
├── fields/
│   ├── nd110-fields.yaml       Bit ranges for each named field
│   ├── nd120-fields.yaml       ND-120 deltas
│   └── nd100-fields.yaml       Placeholder (awaiting ROM analysis)
├── runtime/
│   └── data-flow.yaml          ALU / IDBS / COMM runtime semantics
├── format/
│   └── assembly-format.yaml    3-line layout + zero-display rules
└── common/
    ├── registers.yaml
    └── conditions.yaml

docs/
├── special-bits.md             The undocumented 20-27 bit region
└── ND-06.031.1-...pdf          Official Norsk Data Microprogrammer's Guide

reference/                           Read-only hardware reference material
├── README.md                         What lives here and why
├── ND-110-RASK.uc                    Valid ND-110 RASK microcode source
├── ND-120-*.uc                       (work in progress - not yet valid)
├── ND-100-*.uc                       (not yet available)
└── roms/
    ├── ND100/                        (ROMs pending)
    ├── ND110/
    │   ├── 37948L.bin                ND-110 3095 LOW chip  (version L / 0o14)
    │   └── 37949L.bin                ND-110 3095 HIGH chip (version L / 0o14)
    └── ND120/
        ├── AM27256_45132L.bin        ND-120 AM27256 LOW chip  (version L / 0o14)
        └── AM27256_45133L.bin        ND-120 AM27256 HIGH chip (version L / 0o14)

NOTE: compile outputs (.CODE, .SYMBOLS.TXT) are NOT stored here.
They are regenerable from the .uc sources and live with whichever
toolchain produced them (ND110Compile C# assembler for now).

schemas/                        (reserved for future JSON Schema files)
tools/
├── validate.py                 Cross-checks YAML against reference binaries
└── generate_tokens_yaml.py     Re-extracts tokens from the C# source
```

## Versioning

Semantic versioning: see [`CHANGELOG.md`](CHANGELOG.md). Consumer repos
pin a specific commit (via git submodule) and opt into new versions
deliberately. Breaking schema changes bump the major version.

## Consumers

| Consumer | Repo | How it references this |
|----------|------|------------------------|
| TS disassembler / assembler / VSCode ext | `nd100uc` | Git submodule at `defs/` (→ this repo's `defs/`) |
| C# assembler (reference) | `ND110Compile` | Git submodule; a generator produces `ND110Tokens.cs` / `ND120Tokens.cs` from `defs/tokens/*.yaml` |
| C# CPU emulator (reference) | `ND110Compile/ND110CPU` | Reads this repo's `defs/runtime/data-flow.yaml` as documentation; emulator logic is hand-written |
| C# ROM combiner | `ND110MicroCode` | No direct dependency; compared against this repo's `reference/roms/` for validation |

## YAML schema (quick reference)

### Token entry

```yaml
- token: "ALUF,PASSD"                               # canonical name
  category: ALUF                                    # A_REG|B_REG|AB_REG|PIC|ALUF|ALUD|ALUM|STS|CRY|MIS|IDBS|COMM|T_SEQ|T_STK|F_SEQ|F_STK|COND|SPECIAL
  display_line: 1                                   # 1|2|3 (3-line format)
  encoding: { w4: "015600", w3: "000000", w2: "000000", w1: "000000" }
  description: "D -> F"
  provides: ""                                      # "A"|"B"|"AB"|"PIC" (optional)
  requires: ""                                      # "A"|"B"|"AB"|"PIC" (optional)
  nd120_only: false
  models: [nd100, nd110, nd120]
```

### Field entry

```yaml
IDBS:
  bits: [41, 37]                 # [hi, lo] inclusive
  width: 5
  description: "Internal Data Bus source"
  default: 0
```

### Runtime entry (data-flow.yaml)

```yaml
aluf_formulas:
  "ALUF,PASSD": "F = D"
  "ALUF,A+B":   "F = A + B"

alud_behavior:
  3:                             # ALUD field value
    name: RAMF
    y_bus: F
    b_register_write: "Reg[BOP] := F"
    note: "Standard ALU write path."

comm_effects:
  "COMM,LDGPR":
    reads: IDB
    writes: "GPR register"
    uses_a: false
    uses_b: false
```

See `docs/special-bits.md` for the detailed semantics behind bits 20-27.

## Validation

The `tools/validate.py` script cross-checks the YAML against the
reference `.CODE` binary. Run from the repo root:

```bash
python3 tools/validate.py
```

Expected output:

```
Loaded 356 ND-110 tokens, 358 ND-120 tokens
=== Stage 1: Per-model sanity checks === (0 errors)
=== Stage 2: ND-110 vs ND-120 delta === (OK)
=== Stage 3: Shared-token encoding consistency === (only timing-bit differences)
=== Stage 4: Binary load from reference/ND-110-RASK.CODE === (4865 records, 1094 symbols)
Total errors: 0
```

## Regenerating tokens from C# source

When the reference C# assembler at `ND110Compile/ND110Compile/` changes
(new tokens, renamed opcodes), regenerate the YAML:

```bash
python3 tools/generate_tokens_yaml.py
```

This reads `ND110Tokens.cs` and `ND120Tokens.cs` from a known path and
rewrites `defs/tokens/nd110-tokens.yaml` / `nd120-tokens.yaml`. Commit
the result and bump the minor version in `VERSION` and `CHANGELOG.md`.

## Adding to a consumer repo

From a consumer repo (for example `nd100uc`), add this as a submodule:

```bash
cd nd100uc
git submodule add https://github.com/RonnyA/nd-microcode-meta.git defs-external
git submodule update --init --recursive
```

Then point build scripts at `defs-external/defs/` instead of the old
in-tree `defs/`. To bump the metadata version, `cd` into the submodule
and `git pull origin main` (or checkout a specific tag), then commit
the new submodule pointer in the consumer repo.

## Contributing

Fix a token description, add a runtime-semantic entry, add a new
reference ROM - all via pull requests to this repo. Keep the C# side
in sync by running `generate_tokens_yaml.py` in the opposite direction
(see that script's header comment for the current policy).

## License

MIT - see [LICENSE](LICENSE).
