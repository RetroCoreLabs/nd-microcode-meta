# YAML format

The definitions are in `defs/`. Bit numbers count from the least significant
bit: bit 0 is the last bit of the word.

| Folder | Content |
|--------|---------|
| `defs/tokens/<name>-tokens.yaml` | the mnemonics (tokens) of one variant, with their bits |
| `defs/fields/<name>-fields.yaml` | the bit fields of the microinstruction word of one variant |
| `defs/runtime/data-flow.yaml` | how the ND-100/110/120 execute an instruction ([page](definitions/data-flow.md)) |
| `defs/format/assembly-format.yaml` | how an ND-100/110/120 instruction is written as text ([page](definitions/assembly-format.md)) |
| `defs/common/registers.yaml`, `conditions.yaml` | register and condition names ([page](definitions/registers-and-conditions.md)) |

`<name>` is one of `nd10`, `nd100`, `nd110`, `nd120`, `nd500`, `nd5000`. The
seventh variant, `nd120-dly`, has no files of its own (see
[variant_overrides](#variant_overrides)). Each variant has a page under
[Variants](variants/index.md) that is made from these files.

## Token files

A token file starts with some header keys and then has the list `tokens`.

| Header key | Meaning |
|------------|---------|
| `model` | the name of the machine, for example `ND-500` |
| `word_size_bits` | width of the microinstruction word |
| `part_count` | number of 16-bit groups (files that use `parts`) |
| `token_count` | number of tokens the generator wrote. The library does not read it, and in `nd100-tokens.yaml` and `nd110-tokens.yaml` it differs from the number of entries |
| `source` | the C# file the tokens were generated from |
| `byte_count`, `byte_order` | in `nd100-tokens.yaml` |

### One token

The keys of a token differ between the files.

| Key | Files | Meaning |
|-----|-------|---------|
| `token` | all | the name as written in the source, for example `ALUF,PASSD` |
| `category` | all | the group of the token. ND-100/110/120: `A_REG`, `B_REG`, `AB_REG`, `PIC`, `ALUF`, `ALUD`, `ALUM`, `STS`, `CRY`, `MIS`, `IDBS`, `COMM`, `T_SEQ`, `T_STK`, `F_SEQ`, `F_STK`, `COND`, `SPECIAL`. NORD-10: the section of the format (`format`, `test`, `alu` and so on). ND-500 and ND-5000: the name of the field the token sets |
| `encoding` | all | the bits, see below |
| `description` | all | text from the documentation. May be empty |
| `display_line` | nd100, nd110, nd120 | `1`, `2` or `3`: the line of the three-line instruction format the token is written on. Required; the library refuses any other value |
| `models` | nd100, nd110, nd120 | the variants that have the token (`nd100`, `nd110`, `nd120`). When missing, all three |
| `nd120_only` | nd120 | `true` for tokens that only the ND-120 has |
| `provides`, `requires` | nd110, nd120, nd100 (`provides`) | register kind that a token gives or needs: `A`, `B`, `AB` or `PIC` |
| `alias_of`, `alias_on_manual` | nd100 | `alias_of`: this token has the same bits as the named token. `alias_on_manual`: the name that the manual uses |
| `hex` | nd10 | the 32-bit word in hex, the same bits as `encoding` |
| `field`, `value` | nd5000 | the token puts `value` into `field`, shifted to the low bit of the field. `encoding` already holds the result |
| `mem_code` | nd5000 | a memory operation. The 4-bit code is split over the word: bit 3 goes to word bit 41, bits 2-0 go to bits 34-32 |

### Encoding

The tokens of one instruction are **ORed together** to make the word.

ND-100, ND-110, ND-120: four groups of 16 bits, each 6 octal digits.

```yaml
- token: "A,Z"
  category: A_REG
  display_line: 1
  encoding: { w4: "000000", w3: "000000", w2: "000000", w1: "000000" }
  description: "A-OP. IS O. USED TO ADDR. ZERO REG., STATUS OR SCRATCH"
```

`w4` is bits 63-48, `w3` bits 47-32, `w2` bits 31-16, `w1` bits 15-0.

NORD-10, ND-500, ND-5000: a list `parts` of 6-digit octal strings, **most
significant group first**. NORD-10 has 2 parts (bits 31-16, 15-0), ND-5000
has 8 (bits 127-112 down to 15-0), ND-500 has 9 (bits 143-128 down to 15-0).

```yaml
- token: "A,A1"
  category: A_OP
  field: A_OP
  value: 36
  encoding: { parts: ["000000", "000000", "044000", "000000", "000000", "000000", "000000", "000000"] }
  description: "A-BUS IS FLOATING MOST REGISTER A1"
```

### variant_overrides

`nd120-tokens.yaml` ends with a block that makes the seventh variant:

```yaml
variant_overrides:
  nd120-dly:
    - token: 'B,P'
      encoding: { w4: '000000', w3: '000000', w2: '000002', w1: '000000' }
      description: 'B-OP. IS 2. USED TO ADDR. THE P-REGISTER (L: no DLY1)'
```

The variant is the ND-120 table with these tokens replaced. An entry keeps
every other key of the base token and replaces `encoding` and, when given,
`description`. An entry for a token that is not in the table is an error.
See [ND-120 (version L)](variants/nd120-dly.md).

## Field files

A field file has the same kind of header (`model`, `word_size_bits`,
`byte_count`, `byte_order`, `part_count`) and these keys that tell about the
image: `control_store_words` (size of the control store; NORD-10 gives two
sizes) and `binary_format` (`prom-hex`, `packed18` or `be16x8`).

The fields come in three shapes.

**ND-100, ND-110, ND-120:** `fields` is a map from the field name.

```yaml
IDBS:
  bits: [41, 37]        # [high, low], both included
  width: 5
  description: "Internal Data Bus Source - selects what drives the IDB"
  default: 0
  used_when: "SCOND == 1"     # only some fields
```

`nd100-fields.yaml` and `nd120-fields.yaml` say `inherits_from:
nd110-fields.yaml` and list only the fields that differ; the library merges
them with the ND-110 fields. `nd110-fields.yaml` also has `categories`, which
groups the fields by the line of the instruction.

**NORD-10:** `fields` is a list. A field can be used by some formats of the
instruction only, so fields overlap on purpose.

```yaml
- { name: LOG, high_bit: 29, low_bit: 29, format: "ARITHMETIC|INTERBLOCK" }
```

`format` is `ALL` or a list of formats separated by `|`.

**ND-500, ND-5000:** `partition` is a list of fields that do not overlap,
highest bit first. `subfields` are fields that lie inside the partition
(for example the ALU operation and the carry inside `ALU_TRUE`).

```yaml
- { name: ALU_TRUE, high_bit: 127, low_bit: 122, description: "ALU function, true path (4-bit op + 2-bit carry)" }
```

### ROM storage form

`nd100-fields.yaml` has `rom_bit_inversion` and `nd120-fields.yaml` has
`rom_bit_flip`. `rom_bit_inversion` says that the ND-100 PROMs store bits 22-27
inverted (mask `0x0FC00000`, same as the ND-110); `rom_bit_flip` says that the
ND-120 images do not (mask `0x00000000`). Both name the manual text. The values
are printed on the page of the variant.

## Where the files come from

The token files and the NORD-10, ND-500 and ND-5000 field files are written
by the scripts in `tools/` from the C# files of the compiler. The header of
each file names its script. See [Tools](tools.md).
