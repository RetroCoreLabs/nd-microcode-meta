# ND-100 microcode PROM layout

This document describes the physical layout of the microcode, sequencer,
and instruction-decoder PROMs on the Norsk Data **ND-100** CPU card,
and how the many small bipolar PROMs combine to form one logical
microinstruction word.

Unlike the later ND-110 and ND-120, which hold the microcode in two
large EPROMs on a single card, the ND-100 CPU uses **dozens of small
Signetics 82S185 PROMs** (2K x 8 bipolar fuse-link), each providing
4 bits (low nibble) of a wider microword plus auxiliary data.

---

## 1. Card variants

Two ND-100 CPU variants are documented in this repo:

| Variant      | Folder                     | PROMs | Purpose                                          |
|--------------|----------------------------|-------|--------------------------------------------------|
| **3033S**    | `reference/roms/ND100/3033S/`     | 19    | Base ND-100 CPU                                  |
| **3033E-CX** | `reference/roms/ND100/3033E-CX/`  | 35    | "CX" - extended CPU (second microcode bank + patched base slot) |

Both cards are 48-bit microcode machines, following the same general
conventions as the later ND-110.

---

## 2. Chip technology: Signetics 82S185

The ND-100 uses the **Signetics 82S185** bipolar PROM:

| Parameter    | Value                            |
|--------------|----------------------------------|
| Organisation | 2048 x 8-bit                     |
| Address bus  | 11 bits (`A10..A0`) -> 2048 rows |
| Data bus     | 8 bits (`Q7..Q0`)                |
| Technology   | Bipolar, fuse-link (one-time programmable) |
| Access time  | ~40 ns                           |

### 4-bit usage convention

Every ND-100 microcode PROM in this archive uses **only the low
nibble** (`Q3..Q0`). The upper four bits (`Q7..Q4`) are always 0. This
is verifiable by inspection - every byte in every PROM has its high
nibble clear. Operationally the chip is being used as if it were a
`2K x 4` PROM (like an 82S131) sitting in an 8-bit socket.

Likely reason: the socket footprint and address decoder were designed
around the 82S185 family for sourcing reasons, but the CPU only needs
4 bits per chip. The unused upper pins are ignored by the bus logic.

---

## 3. PCB slot naming

Each PROM sits in a labelled socket on the CPU PCB:

    Row B   b5 b6 b7 b8 b9 b10 b11 b12 b13 b14 b15 b16 b17 b18 b19 b20
    Row C   c5 c6 c7 c8 c9 c10 c11 c12 c13 c14 c15 c16 c17 c18 c19 c20
    Row D   d5 d6 d7 d8 d9 d10 d11 d12 d13 d14 d15 d16 d17 d18 d19 d20
                                                     ^ "d15 upper" is a key position

The file naming convention in this archive is:

    <part-number><revision>.82s185.<slot>
    e.g. 01504N.82s185.d16

Where:
- `part-number` - Norsk Data part number (five digits)
- `revision`    - single-letter rev code (`N`, `P`, `Q`, `D`, `E`)
- `82s185`      - chip family
- `slot`        - PCB slot identifier (`d5`, `c16`, `b20`, ...)

---

## 4. Functional roles

Each row of PROMs has a specific role in the CPU architecture:

### Row D (base bank) - always present

| Slot range   | Chips | Role                                             |
|--------------|-------|--------------------------------------------------|
| `d5`..`d16`  | 12    | **48-bit microcode data** (12 x 4 bits)          |
| `d17`..`d20` | 4     | **Sequencer**: next-microaddress + test-select (16 bits) |

- Addressed by the current 11-bit **microaddress**.
- The 12 data chips output the microinstruction to be executed.
- The 4 sequencer chips output the branch target and condition test
  selector used by the microsequencer to compute the NEXT microaddress.

### Row C (extension bank) - 3033E-CX only

| Slot range   | Chips | Role                                             |
|--------------|-------|--------------------------------------------------|
| `c5`..`c16`  | 12    | **48-bit microcode data** - extension bank       |
| `c17`..`c20` | 4     | **Sequencer** - extension bank                   |

- Effectively a second 2K-word microstore for additional instructions
  (floating-point, ring-protection, I/O extensions, ...).
- Addressed in parallel with row D; which bank is selected depends on
  the high microaddress bit(s) and/or a bank-select signal driven by
  the decoder PLA.

### Row B - instruction decoder PLA

| Slot range   | Chips | Role                                             |
|--------------|-------|--------------------------------------------------|
| `b18`..`b20` | 3     | **Decode PLA**: macro-opcode -> microcode entry address (12 bits) |

- Addressed not by microaddress but by the **macro instruction
  opcode** (the upper bits of the currently-fetched 16-bit user
  instruction).
- Outputs a 12-bit microaddress that serves as the entry point for
  the instruction's microcode routine.
- Many macro opcodes map to the same "illegal/undefined instruction"
  handler, so the decode PLA typically has long runs of the same
  value (observed: `0x910` repeated).

---

## 5. Bit ordering

Physical slot number determines which nibble of the output word a
PROM contributes:

    slot (row D)   microword bits   description
    --------------------------------------------
    d5             3..0             low nibble (LSB)
    d6             7..4
    d7             11..8
    d8             15..12
    d9             19..16
    d10            23..20
    d11            27..24
    d12            31..28
    d13            35..32
    d14            39..36
    d15            43..40
    d16            47..44           high nibble (MSB)

Same rule for row C (c5 = LSB, c16 = MSB) in the extension bank, and
for the sequencer (d17 = LSB, d20 = MSB for its 16-bit output) and
decode PLA (b18 = LSB, b20 = MSB for its 12-bit output).

This is the standard TTL-schematic convention of "lowest-numbered
chip maps to the lowest-weight bit".

---

## 6. Address flow

```
                              ┌──────────────────────────┐
                              │  MIC (microsequencer)    │
                              │  - 11-bit uADDR latch    │
                              │  - test condition inputs │
                              │  - stack / jump logic    │
                              └──────────┬───────────────┘
                                         │ uADDR[10:0]
                 ┌───────────────────────┼──────────────────────┐
                 ▼                       ▼                      ▼
    ┌──────────────────────┐  ┌──────────────────────┐  ┌──────────────────┐
    │ MICROCODE DATA       │  │ SEQUENCER            │  │                  │
    │ row D d5..d16        │  │ row D d17..d20       │  │                  │
    │ (row C c5..c16 CX)   │  │ (row C c17..c20 CX)  │  │                  │
    │ 12 x 4 = 48 bits     │  │ 4 x 4 = 16 bits      │  │                  │
    └──────────┬───────────┘  └──────────┬───────────┘  │                  │
               ▼                         ▼              │                  │
    ┌──────────────────────┐  ┌──────────────────────┐  │                  │
    │  48-bit micro-word   │  │  next-uADDR + test   │──┘                  │
    │  -> ALU / IDB / ...  │  │  selector            │                     │
    └──────────────────────┘  └──────────────────────┘                     │
                                                                           │
                                   MACRO INSTRUCTION FETCH                 │
                                          │                                │
                                          ▼                                │
                              ┌──────────────────────────┐                 │
                              │ DECODE PLA (row B b18-b20)│                 │
                              │ addressed by opcode bits  │                 │
                              │ 3 x 4 = 12 bits output    │                 │
                              └──────────┬───────────────┘                 │
                                         │ macro-entry uADDR               │
                                         └─────────────────────────────────┘
                                               (initial branch into MIC)
```

---

## 7. Combining the PROMs into one image

For each address `a` in `0..2047`:

    microword[a]  = 0
    for i in 0..11:
        nibble = chip_d(5+i)[a] & 0x0F
        microword[a] |= nibble << (i * 4)

Equivalent operation for the sequencer (4 chips at `d17..d20`) and
the decode PLA (3 chips at `b18..b20`).

This is implemented by `tools/nd100-combine.py`:

```bash
python3 tools/nd100-combine.py combine \
    --variant 3033S \
    --indir  reference/roms/ND100/3033S \
    --outdir /tmp/nd100-3033S
```

Output format: 10-byte records (2-byte little-endian address + 8-byte
little-endian value, with the 48-bit microword zero-padded to 64 bits).
Compatible with the `parseCodeFile()` loader in the TS library.

Per-role output files:

| File                            | Records | Width   | Meaning                            |
|---------------------------------|---------|---------|------------------------------------|
| `<variant>-microcode.CODE`      | up to 2048 | 48 bits | Main microinstruction ROM           |
| `<variant>-sequencer.CODE`      | up to 2048 | 16 bits | Next-uADDR / test select            |
| `<variant>-microcode_ext.CODE`  | up to 2048 | 48 bits | (CX only) extension microcode bank  |
| `<variant>-sequencer_ext.CODE`  | up to 2048 | 16 bits | (CX only) extension sequencer       |
| `<variant>-decode.CODE`         | up to 2048 | 12 bits | Macro-opcode dispatch PLA           |

Addresses with all-zero content are omitted (matching the ND110Compile
`.CODE` convention).

---

## 8. 3033S vs 3033E-CX

### Chips that are IDENTICAL in both variants

Row D slots `d5` through `d14`, `d16`, and `d17` through `d20` all
hold the same `015xx` part numbers in both cards. They are byte-for-
byte identical dumps (same N/P/Q revision codes).

### Chips that DIFFER

| Slot | 3033S         | 3033E-CX      | Notes |
|------|---------------|---------------|-------|
| `d15`| `01505N`      | `01705N`      | "Upper d15" — replacement chip for the base microcode bank in the CX variant. The part number prefix jumps to `017xx`, suggesting a major rework of this slice. |
| `b18`| `01602N`      | `08602D`      | Decode PLA - different implementation on the CX. |
| `b19`| `01601N`      | `08601D`      | Decode PLA. |
| `b20`| `01600N`      | `08600D`      | Decode PLA. |

### Chips that EXIST ONLY in 3033E-CX

All 16 chips of row C (`c5`..`c20`), plus no additional row B chips.
This row provides the second microcode + sequencer bank for the
extended instruction set.

---

## 9. Comparison with ND-110 / ND-120

| Feature                   | ND-100 (this doc)                          | ND-110 / ND-120                         |
|---------------------------|--------------------------------------------|------------------------------------------|
| Microcode word size       | 48 bits                                    | 48 bits (ND-110) / 64 bits (ND-120)      |
| Storage medium            | Many small 82S185 bipolar PROMs             | Two large EPROMs (27256 / 28-pin)        |
| Chip count per card       | 19 (base) or 35 (CX)                       | 2                                        |
| Addressable microaddrs    | 2048 (base); 2048 + 2048 banks (CX)        | 8192 (13-bit addr with bit-20 extension) |
| Sequencer                 | Separate PROMs (`d17`-`d20`, + `c17`-`c20` on CX) | Encoded in the main microword |
| Decode PLA                | Separate PROMs (`b18`-`b20`)               | Integrated (no dedicated decode ROM on the CPU card) |
| ROM XOR flip              | Not applicable                             | ND-110 applies `XOR 0x0FC00000` to bits 22-27 |
| Fresh ROM empty value     | All-zero bytes (a fuse-link that was never blown reads as... implementation-detail of 82S185) | ND-110: `0x0FC00000` (canonical zero after XOR) |

The ND-100 architecture is **more decomposed**: data, sequencing, and
instruction decoding live in separate physical PROMs. The later
ND-110/120 integrated the sequencer bits into the main microword and
dropped the decode-PLA PROMs in favour of microcoded dispatch.

---

## 10. Open questions

Things not yet nailed down (contributions welcome):

- **Upper microaddress bit for CX bank selection.** We assume the
  microsequencer's address bus drives both banks in parallel and a
  separate bank-select signal gates which bank's output reaches the
  main microword latch. The exact signal source (is it bit 11 of the
  microaddress? or a control flip-flop set by the decode PLA?) is not
  currently documented here.

- **Sequencer output encoding.** The 16-bit sequencer word contains
  the next-microaddress + test-select. The exact bit assignment
  (how many bits are address, how many are condition select, how many
  are stack-ops) hasn't been mapped to specific bit ranges in this
  document. The ND-110's corresponding fields (stored within the main
  microword at bits 31:20) are a reasonable starting hypothesis.

- **Decode PLA address bus.** The three decode PROMs give 11-bit
  addressing (2048 entries) but macro instructions are 16-bit. Which
  11 bits of the opcode address the PLA? Likely bits 15:5 of the
  macro instruction (the primary opcode field in the ND convention),
  but this should be confirmed against the ND-100 CPU schematics.

- **Where does `d15 upper` (01705N) fit semantically?** We know it's
  a replacement for `d15` in the CX variant but the reason for the
  rework (bug fix? new feature? timing adjustment?) is not recorded.

When these are resolved they should be added to this document and
ideally reflected in `defs/fields/nd100-fields.yaml`.

---

## 11. See also

- [`reference/roms/ND100/README.md`](../reference/roms/ND100/README.md) - brief ROM-folder contents
- [`docs/special-bits.md`](special-bits.md) - bits 20-27 semantics (ND-110/120 focused, may apply to ND-100)
- [`tools/nd100-combine.py`](../tools/nd100-combine.py) - the combiner implementation
