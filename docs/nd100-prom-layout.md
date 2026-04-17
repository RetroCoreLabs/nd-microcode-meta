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

Both cards produce a **64-bit microword** assembled from sixteen
4-bit-wide PROMs per bank. The CPU reads all 16 chips in parallel
and the full microinstruction is 64 bits wide. This is the form
stored in the `.CODE` files produced by `tools/nd100-combine.py`.

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

All 16 PROMs in row D are addressed together by the current 11-bit
**microaddress** and together produce ONE 64-bit microinstruction
word. The bits of that word partition internally into operation
fields (ALU, IDB, COMM, ...) and sequencer fields (next-uADDR,
test-select, stack-op), but there is only a single ROM output path:
the chips are read in parallel, their nibbles interleave, and the
resulting 64-bit word is what the CPU's microinstruction register
latches each cycle.

### Row C (extension bank) - 3033E-CX only

| Slot range   | Chips | Role                                                 |
|--------------|-------|------------------------------------------------------|
| `c5`..`c16`  | 12    | Extension-bank microcode (ALU / IDB / COMM field bits) |
| `c17`..`c20` | 4     | Extension-bank microcode (next-uADDR / test-select field bits) |

- A second 2K-word microstore for additional instructions.
- Lives at microaddresses `0o4000`..`0o7777` in the CPU's 12-bit
  microaddress space (row D occupies `0o0000`..`0o3777`).
- Addressed in parallel with row D; bank selection is driven by the
  high microaddress bits, with the upper half being WCS-overridable
  when LWCS has been executed (`0o4000`..`0o4377`).

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

**The PCB column number is INVERSE to the microword bit position.**
The chip at the highest-numbered PCB column (`d20` / `c20` / `b20`)
produces the LOWEST nibble (bits 0-3). The chip at the lowest-numbered
column (`d5` / `c5` / `b18`) produces the HIGHEST nibble.

    slot (row D)   microword bits   description
    --------------------------------------------
    d20            3..0             low nibble  (LSB, bit 0 = LSB of chip byte)
    d19            7..4
    d18            11..8
    d17            15..12
    d16            19..16
    d15            23..20
    d14            27..24
    d13            31..28
    d12            35..32
    d11            39..36
    d10            43..40
    d9             47..44
    d8             51..48
    d7             55..52
    d6             59..56
    d5             63..60           high nibble (MSB)

Row C follows the same rule (`c20` = LSB, `c5` = MSB). The decode PLA
(row B) has only three chips and follows the same convention:
`b20` = nibble 0 (bits 0-3), `b18` = nibble 2 (bits 8-11).

Within each PROM byte, bit 0 is LSB and bit 3 is MSB (standard).

**Validation.** This mapping was verified 100% bit-exact against an
independent reference stitching ("Frode's" set) on 2026-04-17 for
both 3033S and 3033E-CX banks (microcode, decode PLA, and the CX
extension bank). See `tools/nd100-combine.py`.

---

## 6. Address flow

```
                         +---------------------------+
                         | MIC (microsequencer)      |
                         | - 11-bit uADDR latch      |
                         | - condition-test inputs   |
                         | - stack / jump logic      |
                         +-------------+-------------+
                                       | uADDR[10:0]
                                       v
                         +---------------------------+
                         | MICROCODE ROM             |
                         | row D d5..d20  (16 chips) |
                         | row C c5..c20  (16 chips, |
                         |                CX only)   |
                         | 16 x 4 = 64 bits per cycle|
                         +-------------+-------------+
                                       | 64-bit microword
                                       v
                   +---------------------------------------+
                   | MICROINSTRUCTION REGISTER (64 bits)   |
                   |                                       |
                   | operation fields -> ALU / IDB / COMM  |
                   | sequencer fields -> next-uADDR + test |
                   |                     (feeds back MIC)  |
                   +---------------------------------------+

                   MACRO INSTRUCTION FETCH
                           |
                           v
                   +---------------------------+
                   | DECODE PLA (row B b18-b20)|
                   | addressed by opcode bits  |
                   | 3 x 4 = 12 bits output    |
                   +-------------+-------------+
                                 |  macro-entry uADDR
                                 v
                          (initial branch into MIC)
```

There is only one ROM output path per bank: all 16 chips read in
parallel, their nibbles interleave into a 64-bit word, and that
word's bits are partitioned internally into operation fields (ALU,
IDB, COMM) and sequencer fields (next-uADDR, test-select,
stack ops). The historical "microcode data" vs "sequencer" split
is a bit-range distinction inside the single word.

---

## 7. Combining the PROMs into one image

Because the PCB-column -> bit-position mapping is inverse (see
Section 5), the combiner processes the 16 chips in REVERSE column
order. For each address `a` in `0..2047`:

    microword[a]  = 0
    for i in 0..15:
        chip  = chips_by_increasing_bit_position[i]   # i=0 -> d20, i=15 -> d5
        nibble = chip[a] & 0x0F
        microword[a] |= nibble << (i * 4)

Equivalent operation for the decode PLA (3 chips: `i=0 -> b20`,
`i=2 -> b18`).

This is implemented by `tools/nd100-combine.py`:

```bash
python3 external/meta/tools/nd100-combine.py combine \
    --variant 3033S \
    --indir  external/meta/reference/roms/ND100/3033S \
    --outdir /tmp/nd100-3033S
```

For 3033E-CX also run `--variant 3033E-CX` against the CX folder.

Output format: 10-byte records (2-byte little-endian address + 8-byte
little-endian microword). For the extension bank (`microcode_ext`)
the stored address is offset by `0o4000` so it reflects the CPU's
real microaddress. Compatible with the `parseCodeBytes()` loader in
the TS library.

Per-role output files:

| File                                | Records    | Width   | Meaning                                         |
|-------------------------------------|------------|---------|-------------------------------------------------|
| `<variant>-microcode.CODE`          | up to 2048 | 64 bits | Main microinstruction ROM (all 16 row-D chips)  |
| `<variant>-microcode_ext.CODE`      | up to 2048 | 64 bits | (CX only) extension bank; uaddrs `0o4000`-`0o7777` |
| `<variant>-decode.CODE`             | up to 2048 | 12 bits | Macro-opcode dispatch PLA (3 chips, row B)      |

Addresses with all-zero content are omitted (matching the ND110Compile
`.CODE` convention).

Note: there are **no separate sequencer output files**. Earlier
revisions of this document treated `d17`-`d20` as a distinct
"sequencer ROM" written to its own `.CODE`; that split has been
merged back into the single 64-bit `microcode.CODE` per bank, since
the chips are electrically read in parallel with the data PROMs and
their nibbles sit at bits 48-63 of the single microword.

The ND-100 PROMs are stored **canonical** - no `XOR 0x0FC00000`
(bits 22-27 inversion) is applied at either combine time or load
time. That transformation is specific to the ND-110 token-form
EPROMs and must not be applied to ND-100 images at any stage.

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
| Microcode word size       | 64 bits                                    | 48 bits (ND-110) / 64 bits (ND-120)      |
| Storage medium            | Many small 82S185 bipolar PROMs             | Two large EPROMs (27256 / 28-pin)        |
| Chip count per card       | 19 (base) or 35 (CX)                       | 2                                        |
| Addressable microaddrs    | 2048 (base); 2048 + 2048 banks (CX)        | 8192 (13-bit addr with bit-20 extension) |
| Sequencer                 | Bits 48-63 of the 64-bit microword (row D `d17`-`d20`) | Encoded inside the microword as well |
| Decode PLA                | Separate PROMs (`b18`-`b20`)               | Integrated (no dedicated decode ROM on the CPU card) |
| ROM XOR flip              | None - stored canonical                    | ND-110 applies `XOR 0x0FC00000` to bits 22-27 |
| PCB-column -> bit order   | Inverse (d20 = low nibble, d5 = high nibble) | N/A (single EPROM per half)           |

The ND-100 architecture is **more decomposed**: data, sequencing, and
instruction decoding live in separate physical PROMs. The later
ND-110/120 integrated the sequencer bits into the main microword and
dropped the decode-PLA PROMs in favour of microcoded dispatch.

---

## 10. Open questions

Things not yet nailed down (contributions welcome):

- **Upper microaddress bit for CX bank selection.** The CX extension
  bank sits at uaddrs `0o4000`..`0o7777` in the 12-bit microaddress
  space; the row-D bank sits at `0o0000`..`0o3777`. Bit 11 of the
  microaddress presumably drives bank selection, with WCS overriding
  bank 1 at `0o4000`..`0o4377` after LWCS has loaded the writable
  control store. The exact gating signal source is not documented
  here.

- **Bit-level assignment of the "sequencer" slice.** Bits 48-63 of
  the 64-bit microword come from `d17`..`d20` and encode the
  next-microaddress plus condition-test / stack-op selectors. The
  exact bit assignment (how many bits are address, how many are
  condition select, how many are stack-ops) within that 16-bit range
  should be nailed down in `defs/fields/nd100-fields.yaml`.

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
