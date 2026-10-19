# nd-microcode-meta

Canonical metadata for the Norsk Data NORD-10, ND-100, ND-110, ND-120, ND-500
and ND-5000 microcode (and the ND-120 version L, `nd120-dly`).

Documentation site: <https://retrocorelabs.github.io/nd-microcode-meta/>

This repository is the **single source of truth** for:

- **Token encodings** - every `ALUF,PASSD` / `COMM,EWRF` / etc. with its
  full 64-bit octal encoding
- **Bitfield positions** - what lives at which bits of the microinstruction word
- **Runtime data flow** - ALU sources, destinations, IDBS producers,
  COMM side-effects (extracted from the reference CPU emulator)
- **Assembly format rules** - 3-line layout, zero-display conventions,
  jump-context detection
- **Reference microcode** - known-good `.CODE` binaries and the physical
  PROM and EPROM images from real ND-100, ND-110 and ND-120 CPU cards, plus
  NORD-10, ND-500 and ND-5000 images, used by all toolchain
  implementations for bit-exact validation
- **Undocumented details** - the bits-20-27 region, ROM XOR flip,
  B-register dual-role semantics

All downstream tools consume these YAML files directly (or via a
generated snapshot). Toolchain implementations live in separate repos
that pull in `nd-microcode-meta` as a git submodule.

## Layout

```
defs/
├── tokens/
│   ├── nd10-tokens.yaml        197 tokens (NORD-10, 32-bit word, `parts` encoding)
│   ├── nd100-tokens.yaml       300 tokens (ND-100, 48-bit word)
│   ├── nd110-tokens.yaml       357 tokens
│   ├── nd120-tokens.yaml       358 tokens (12 ND-120-only are marked) + `variant_overrides` for nd120-dly
│   ├── nd500-tokens.yaml       721 tokens (ND-500, 144-bit word, 9 parts)
│   └── nd5000-tokens.yaml      609 tokens (ND-5000, 128-bit word, 8 parts, field + value)
├── fields/
│   ├── nd110-fields.yaml       Bit ranges for each named field (27 fields)
│   ├── nd120-fields.yaml       ND-120 deltas
│   ├── nd100-fields.yaml       ND-100 deltas from ND-110 (10 fields)
│   ├── nd10-fields.yaml        NORD-10: 30 fields, overlapping by format
│   ├── nd500-fields.yaml       ND-500: partition (bits 143-32) + subfields
│   └── nd5000-fields.yaml      ND-5000: partition (bits 127-0) + subfields
├── runtime/
│   └── data-flow.yaml          ALU / IDBS / COMM runtime semantics
├── format/
│   └── assembly-format.yaml    3-line layout + zero-display rules
└── common/
    ├── registers.yaml
    └── conditions.yaml

docs/
├── special-bits.md             The undocumented 20-27 bit region
├── nd100-prom-layout.md        ND-100 CPU PROM layout (slots, bit mapping, roles)
├── integration-plan.md         How consumer repos wire this in as a submodule
├── yaml-format.md              The YAML files, field by field
├── library.md                  Using the TypeScript library
├── tools.md                    The scripts in tools/
├── variants/, definitions/, api/   Pages made by tools/gen_docs.py
└── ND-06.031.1-...pdf          Official Norsk Data Microprogrammer's Guide

reference/                           Read-only hardware reference material
├── README.md                         What lives here and why
├── ND-110-RASK.uc                    Valid ND-110 RASK microcode source
├── nd120/                            ND-120 DELILAH K and L (.uc and .CODE)
├── nord10/, nd500/, nd5000/          NORD-10, ND-500 and ND-5000 images and sources
└── roms/
    ├── ND100/                        3033S and 3033E-CX PROM files (see its README.md)
    ├── ND110/
    │   ├── 37948L.bin                ND-110 3095 LOW chip  (version L / 0o14)
    │   └── 37949L.bin                ND-110 3095 HIGH chip (version L / 0o14)
    └── ND120/
        ├── 4MB/45132L.27c256.b23.bin  ND-120 4MB LOW chip  (version L / 0o14)
        ├── 4MB/45133L.27c256.b26.bin  ND-120 4MB HIGH chip (version L / 0o14)
        ├── 6MB/45132L.27c256.b23.bin  ND-120 6MB LOW chip  (differs from 4MB at byte 6633)
        └── 6MB/45133L.27c256.b26.bin  ND-120 6MB HIGH chip

NOTE: ND-110-RASK.CODE and ND-110-RASK.SYMBOLS.TXT are the C# assembler
output for ND-110-RASK.uc, kept here as comparison files (see
reference/README.md).

schemas/                        (reserved for future JSON Schema files)
tools/
├── validate.py                 Cross-checks the ND-110 / ND-120 YAML against the reference binary
├── generate_tokens_yaml.py     Re-extracts ND-110 / ND-120 tokens from the C# source
├── generate_tokens_yaml_nd10.py    NORD-10 tokens from ND10Tokens.cs
├── generate_tokens_yaml_nd500.py   ND-500 tokens from ND500Tokens.cs
├── generate_tokens_yaml_nd5000.py  ND-5000 tokens from ND5000Tokens.cs
├── generate_fields_yaml.py     NORD-10 / ND-500 / ND-5000 fields from the C# field files
├── validate_new_models.py      Checks the new YAML files against the C# files
├── nd100-combine.py            Combines and splits ND-100 PROM images
└── gen_docs.py                 Writes the generated pages of the documentation site
```

## ND-120 variant nd120-dly (version L register selects)

`nd120-tokens.yaml` holds the version K token values (the C# `ND120Tokens`
table). The real ND-120 L EPROM never sets DLY1 (bit 27, w2 `004000`)
together with B-operand P, B or X, so the C# assembler replaces three
tokens when it compiles version L (`ND120Tokens.AdjustTokensForVersionL()`).
The YAML keeps that as the block `variant_overrides: nd120-dly:` at the end
of `nd120-tokens.yaml`. The variant is `nd120` with exactly these three
tokens replaced; everything else is identical:

| Token | nd120 (K), w2 | nd120-dly (L), w2 |
|-------|---------------|-------------------|
| `B,P` | `004002` | `000002` |
| `B,B` | `004003` | `000003` |
| `B,X` | `004007` | `000007` |

Accepted names for the variant: `nd120-dly`, `nd120l`, `nd120-l`.

## Versioning

Semantic versioning: see [`CHANGELOG.md`](CHANGELOG.md). Consumer repos
pin a specific commit (via git submodule) and opt into new versions
deliberately. Breaking schema changes bump the major version.

## Consumers

| Consumer | Repo | How it references this |
|----------|------|------------------------|
| VS Code extension `nd-microcode` | `nd-microcode` | Git submodule at `external/meta/`; builds the TS library in `lib/ts` and reads `defs/` |
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

It runs four stages: per-model sanity checks, the ND-110 against ND-120
token delta, consistency of the tokens the two share, and a load of
`reference/ND-110-RASK.CODE` with its symbols. Read the summary lines at the
end for the error and warning counts. The options are
`--model nd110|nd120`, `--binary`, `--symbols` and `--verbose`. It needs
PyYAML. The other variants are checked by the library tests:

```bash
cd lib/ts && npm ci && npm test
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
git submodule add https://github.com/RetroCoreLabs/nd-microcode-meta.git defs-external
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
