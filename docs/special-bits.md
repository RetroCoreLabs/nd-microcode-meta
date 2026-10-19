# Special / Undocumented Bits in the ND-110/120 Microinstruction Word

This document records details of the **bits 20-27** region of the ND-110 / ND-120 microinstruction word, which are sparsely described (and in some cases contradicted) in the official Norsk Data Microprogrammer's Guide (ND-06.031.1).

The knowledge below was recovered by:

1. Reading the reference C# assembler (`ND110Compile`)
2. Bit-for-bit round-tripping the **full** `ND-110-RASK.CODE` microcode (4865 instructions) through `disassemble → re-assemble` until 100% byte-identical output was achieved
3. Diffing the ND-110 3095 ROM binaries (`37948L.bin` + `37949L.bin`) against the assembled form

If you are writing a microcode toolchain (assembler, disassembler, emulator, Verilog CPU, or static-analysis tool) for the ND-110 / ND-120, **read this carefully**. Getting these bits wrong is the single biggest source of hard-to-find bugs.

---

## 1. Region overview

Bits 20-27 of the 64-bit microinstruction word fall into three broad categories:

| Bit | Name                   | Kind       | Semantic                                                   |
|-----|------------------------|------------|------------------------------------------------------------|
| 20  | `CSBIT20`              | Semantic   | High bit of the 13-bit branch address                      |
| 21  | (delay)                | **Timing** | Memory/IO cycle pacing (`LDLC`, `SLOW`, etc.)              |
| 22  | `LCOUNT`               | Semantic   | Count loop counter; if 0, return & hold                    |
| 23  | `CONDENABL` (ECOND)    | Semantic   | Enable conditional sequencing                              |
| 24  | `SCOND`                | Semantic   | Set Condition - selects interpretation of bits 11:0        |
| 25  | `VECT`                 | Semantic   | Vector-jump selector (set by `T,JMP0-3` / `T,JMPAOPR`)     |
| 26  | (delay upper)          | **Timing** | Paired with bit 21/27 for cycle timing                     |
| 27  | (delay lower)          | **Timing** | Paired with bit 21/26 for cycle timing                     |

The crucial thing to understand: **bits 21, 26, 27 are "timing hints" that are baked into the encoding of many assembler tokens**. They are *not* a separate user-visible timing field. An instruction that selects a particular `IDBS` or `COMM` source inherits the timing characteristics of that source via bits 26/27 being OR'd in as part of the token's encoding.

The official guide hand-waves this as "delay bits" without explaining which tokens set them, or the consequence of mixing tokens that set different timing bits. Our experience: **do not strip or unify these bits; treat them as part of the token's identity**.

---

## 2. The ND-110 and ND-100 bit-22-27 ROM inversion

The ND-110 EPROMs store bits 22-27 **inverted** relative to the canonical assembled form:

```
ROM_value = CANONICAL_value XOR 0x000000000FC00000
```

- **Canonical form** = the value produced by OR'ing all token encodings together. Conceptually what the programmer wrote.
- **ROM storage form** = what is physically burned into the 37948L / 37949L EPROMs.

Both the ND-110 reference assembler (`ND110Compile`) and the ROM-combiner tool (`ND110MicroCode/Program.cs`) apply this XOR at the boundary. The ND-120 does NOT apply this flip - its ROMs store the canonical form directly.

Manual references:

- ND-06.031.1 EN, "ND-110 and ND-120 Microprogrammer's Guide", chapter 4, "Writing Microprogram": "Note that for ND-110 only, bits 22-27 of the microinstruction word are inverted after the word is assembled." and, in the mnemonic list introduction, "the microcode assembler for ND-110 inverts bits 22-27."
- ND-06.018.01 EN, "NORD-100 Microprogramming Description", chapter "Writing the Microprogram": "It is important to be aware that bits 22 - 27 are inverted after the word is assembled." The ND-100 PROMs therefore have the same mask (`ND100_XOR_MASK = 0x0FC00000`); see `../reference/roms/ND100/README.md`.

### Practical consequence

If you read an ND-110 `.CODE` file (the format produced by the C# assembler) and **do not** apply the XOR, the bits in the 22-27 region will be nonsense. This was the single biggest bug during development of the TypeScript disassembler. See `lib/ts/src/bitfield.ts::parseCodeFile` - the `nd110XorFlip: true` option toggles this.

### Empty-instruction test

A fresh microword with no tokens OR'd in has canonical value `0`. After the ND-110 XOR, the ROM form is `0x0FC00000` (bits 22-27 all set). Any ND-110 ROM image where many words have that value is correctly storing "no-op" slots.

---

## 3. Token-by-token bit contribution (ND-110)

### Bit 20 - `CSBIT20` (address extension)

No tokens set this directly. It is set ONLY by the assembler when resolving a label or numeric branch target above `0o7777`:

```c
// From ND110Compile/Compiler.cs:
l |= (ulong)((ushort)(labelAddress & 0xFFF));         // low 12 bits
l |= (ulong)((labelAddress >> 12) & 0x01) << 20;      // bit 12 -> bit 20
```

The effective branch address is 13 bits: `(bit20 << 12) | bits[11:0]`.

### Bit 21 - timing (62 tokens)

Bit 21 is set by nearly every `COMM` token from `0o20` onward (`COMM,LDSEG` through `COMM,IOX`). It is **not** set by:

- `COMM,LDPIL` (0o1), `COMM,LDGPR` (0o2), `COMM,EWRF` (0o3), `COMM,CLIRQ` (0o4)
- `COMM,RSDA` (0o5), `COMM,TBSTR` (0o6), `COMM,LDPANC`, `COMM,LDPCR`
- `COMM,SIOC` (0o7), `COMM,SLOW1/SLOW2` (0o10), `COMM,EPIC` (0o11)
- `COMM,SMPID` (0o12), `COMM,START` (0o13), `COMM,SSTOP` (0o14)
- `COMM,CLRTC` (0o15), `COMM,CLFF` (0o16), `COMM,LDLC` (0o17)

The pattern is: **memory/I/O-cycle commands (jumps, reads, writes, paging, segment-register operations) all set bit 21; short internal register-file commands do not.** This tracks with the documented "slow memory cycle" timing.

### Bit 22 - `LCOUNT`

Set ONLY by the `LCOUNT` token (category `SPECIAL`, in the C# tokens file `AddToken("LCOUNT", "000000", "000000", "000100", "000000", ...)`).

Causes the hardware to decrement the loop counter at the end of the microinstruction. If the counter is then non-zero and a RETURN is in flight, the RETURN is squashed into HOLD (i.e. we stay in the loop).

### Bit 23 - `CONDENABL` (ECOND)

Set ONLY by the `CONDENABL` token. When set, the microinstruction uses the *false-path* sequencing fields (F_SEQ at bits 3:2, F_STK at bits 1:0) if the previously-latched condition was FALSE.

**Important**: `CONDENABL` can coexist with `SCOND=1` (condition test). The two are orthogonal. See `lib/ts/src/disassembler.ts` where both are emitted when both bits are set.

### Bit 24 - `SCOND`

Set by all 14 `COND,*` tokens (COND,STP, COND,PXM, COND,OVF, COND,CRY, COND,F11, COND,F15, COND,F=0, COND,LC=0, COND,FETCH, COND,IRQ, COND,RESTR, COND,OOD, COND,DZD, COND,COND).

When set, bits 11:0 are re-interpreted as:

| Bits  | Field   | Meaning                                                        |
|-------|---------|----------------------------------------------------------------|
| 11:8  | `LCC`   | Loop-counter compare value (rarely used)                       |
| 7:4   | `TSEL`  | Condition selector (which condition to test)                   |
| 3:2   | `F_SEQ` | False-path sequence: `F,JMP` / `F,RETURN` / `F,NEXT`           |
| 1:0   | `F_STK` | False-path stack op: `F,HOLD` / `F,POP` / `F,LOAD` / `F,PUSH`  |

When `SCOND=0`, bits 11:0 are the low 12 bits of the branch address.

### Bit 25 - `VECT`

Set ONLY by `T,JMP0-3` and `T,JMPAOPR`. These two tokens live outside the normal `T_SEQ` field (bits 31:30) - they leave `T_SEQ=0` but set `VECT=1`, which combined with the other encoding bits selects the vectored-jump behaviour.

**Implementation note**: this means `T,JMP0-3` can be *combined with* `T,NEXT` in a source instruction. The 2 round-trip mismatches during development at addresses `0o52` and `0o4204` in RASK are cases of exactly this pattern. The disassembler must look for `VECT=1` independently of the `T_SEQ` field and emit `T,JMP0-3` (or `T,JMPAOPR` if MIS bits 42/43 are also set) in addition to any `T_SEQ` token.

### Bit 26 - timing (22 tokens)

Set by:

- **15 `IDBS` tokens** that read from "extended" data sources that need an extra cycle: `REG`, `PEA`, `PES`, `PIC`, `IOR`, `MIPANS`, `MAPANS`, `PGS`, `CSR`, `PCR`, `ALD`, `PANEL`, `PICVC`, `LBR`, `INR`
- **7 `COMM` tokens**: `SMPID`, and the 6 `JMP,*` family (`JMP,*`, `JMP,B`, `JMP,I`, `JMP,X`, `JMP,XB`, `JMP,XI`)

### Bit 27 - timing (43 tokens)

Set by:

- **3 `B_REG` named-register tokens**: `B,P`, `B,B`, `B,X` - these are "delayed B read" variants. See Section 5 for the key `B,B` vs `B,3` distinction.
- **15 `IDBS` tokens** (the same extended data sources that set bit 26)
- **25 `COMM` tokens**

No `A_REG` tokens set bit 27 in ND-110 (this is interesting - the A-operand read path does not have a paired delay variant).

---

## 4. Per-category timing-bit summary

| Category | Bit 21 count | Bit 26 count | Bit 27 count |
|----------|--------------|--------------|--------------|
| `A_REG`  | 0            | 0            | 0            |
| `B_REG`  | 0            | 0            | **3** (`B,P`, `B,B`, `B,X`) |
| `IDBS`   | 0            | **15**       | **15**       |
| `COMM`   | **62**       | 7            | **25**       |
| `T_SEQ`  | 0            | 0            | 0            |
| `COND`   | 0            | 0            | 0            |

The table makes the hardware picture clear: timing bits are set almost exclusively by `COMM` (command) and `IDBS` (bus-source) tokens, plus three special "delayed B-read" register tokens.

---

## 5. The `B,B` vs `B,3` distinction (critical)

This is the most surprising finding, and the last one to fall during development.

```
B,B:  w4="000000", w3="000000", w2="004003", w1="000000"   -> BOP=3 + bit 27
B,3:  w4="000000", w3="000000", w2="000003", w1="000000"   -> BOP=3 only
```

**Both tokens encode BOP=3 (which selects the B-register). They differ only in bit 27.**

The microcode programmer was expected to choose between them based on the required hardware timing:

- Write `B,3` for the "default" cycle timing.
- Write `B,B` when the instruction needs the extra delay associated with reading register B via the delayed path.

The same distinction applies to `B,P` vs `B,2` (both BOP=2) and `B,X` vs `B,7` (both BOP=7). All other B register tokens (`B,Z`, `B,D`, `B,L`, `B,A`, `B,T`, `B,STS`, `B,R1`..`B,R7`) have `extra=0` - they don't set bit 27.

**There is no equivalent distinction on the A-operand side.** `A,B` (named) and `A,3` (numeric) have the exact same encoding.

### Disassembler implication

If your disassembler picks tokens purely by field value (BOP), you cannot distinguish `B,B` from `B,3`. The round-trip will produce bit-different output, and the emulator may experience different cycle timing than the original ROM intended.

The correct approach (implemented in `lib/ts/src/disassembler.ts::findExactRegToken`):

> Require the token's BOP/AOP field to match raw EXACTLY, then prefer the token whose non-field bits are *also* set in the raw word. When raw has bit 27 set (from any source), pick `B,B` over `B,3`.

---

## 6. Tokens that inject timing bits "under the hood"

Several token categories expose multiple tokens for the same semantic operation, differing only in which timing bits they set. This mirrors a hardware choice - the programmer is selecting a timing variant, not a semantic one.

### COMM,LDPANC / LDPCR / LDSEG family

```
COMM,TBSTR:    COMM field 6, no extra bits
COMM,LDPANC:   COMM field 6 + bit 43        (MIS.1 sub-selector)
COMM,LDPCR:    COMM field 6 + bits 42, 43   (MIS sub-selector)

COMM,LDSEG:    COMM field 20 + bits 21, 27
COMM,LDDOMI:   COMM field 20 + bits 21, 27, 42
COMM,LDPS:     COMM field 20 + bits 21, 27, 43
COMM,LDIRV:    COMM field 20 + bits 21, 27, 42, 43
```

Here bits 42, 43 act as a 2-bit sub-selector within the same COMM opcode, choosing between 4 variants. Bits 21 and 27 are timing-related.

### COMM,JMP,\* family (vectored jumps)

```
COMM,JMP,*:    COMM=0o26 + bits 21, 26
COMM,JMP,B:    COMM=0o26 + bits 21, 26, 42
COMM,JMP,I:    COMM=0o26 + bits 21, 26, 43
COMM,JMP,X:    COMM=0o26 + bits 21, 26, 42, 43
COMM,JMP,XB:   COMM=0o27 + bits 21, 26
COMM,JMP,XI:   COMM=0o27 + bits 21, 26, 42
```

### COMM,SLOW1 vs COMM,SLOW2

These two tokens have **identical** encodings: `COMM=0o10` with no extra bits. They are aliases. The C# assembler accepts both. The ND-120 drops this duplicate and uses a single `COMM,SLOW`.

---

## 7. Ignored-address list (known-broken microcode)

The C# compiler hard-codes a list of ND-110 RASK addresses whose microcode is "sloppy" - written by hand with tokens that don't satisfy the normal `RequireA` / `RequireB` constraints:

```c
// From ND110Compile/Compiler.cs:
static readonly ushort[] myArray = new ushort[] {
    429, 507, 1004, 1073, 2008, 2456, 4797
};  // Converted from OCT
```

One specific known workaround at address `0o1754`:

```
MACL3:    B,177777    ALUF,PASSD   ALUD,Q                    % ORIGINAL: B,1 - changed
                                                              % to "B,177777" to avoid
                                                              % delay during MACL
```

`B,177777` is not a valid token - the `B,` prefix is stripped and the numeric value `177777` is OR'd into bits 15:0 of the word. This is a deliberate hand-patched "force a long word" workaround. The assembler treats it as a **warning**, not an error.

---

## 8. Validation procedure

To verify any ND-110 / ND-120 microcode toolchain:

1. **Source → binary**: Assemble `microcode/ND-110-RASK.uc` and compare byte-by-byte with `microcode/ND-110-RASK.CODE`. Must be 100% identical.
2. **Round-trip**: Parse `microcode/ND-110-RASK.CODE`, disassemble, re-assemble the disassembly, compare with the original binary. Must be 100% identical **in canonical (XOR-undone) form**.

See `lib/ts/tests/source-validation.test.ts` and `lib/ts/tests/roundtrip.test.ts` in this repo for reference implementations.

---

## 9. Sources

- **Primary reference**: `ND110Compile/ND110Compile/ND110Tokens.cs` - the token table with explicit `w1`, `w2`, `w3`, `w4` values.
- **ROM-storage reference**: `ND110MicroCode/Program.cs` - the XOR flip and ROM combination logic.
- **Struct layout**: `src/microcode.h` in this repo - C bitfield definition of the 64-bit word.
- **Official manual**: `docs/ND-06.031.1 EN ND-110 and ND-120 Microprogrammer's Guide.pdf` - high-level description without the timing-bit detail.
- **ND-110 3095 card ROMs**: `37948L.bin`, `37949L.bin` (https://www.ndwiki.org/wiki/3095#Microcode).

---

## 10. Quick reference - "which bits does this token set?"

Run the bit survey script in this repo:

```bash
cd lib/ts
npx vitest run tests/bit-survey.test.ts
```

Or read the canonical data directly from `defs/tokens/nd110-tokens.yaml`. Every token's full encoding is there as four octal strings (w1..w4), and the YAML is the single source of truth consumed by the disassembler, assembler, and VSCode extension.
