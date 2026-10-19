# @nd100uc/microcode

TypeScript library for assembling and disassembling NORD-10, ND-100, ND-110,
ND-120 (also version L, `nd120-dly`), ND-500 and ND-5000 microcode. It also
reads and writes the image formats and guesses the variant of a source file.

Documentation: <https://retrocorelabs.github.io/nd-microcode-meta/> (page
"Using the library", and the list of every exported name under "Library API").

## Usage

```typescript
import {
  loadDefinitions,
  compileDisassemblerPack,
  parseCodeFile,
  parseSymbolsFile,
  disassembleMap,
  formatProgram,
} from "@nd100uc/microcode";

// Load YAML definitions once.
const pack = compileDisassemblerPack(loadDefinitions("nd110"));

// Read a .CODE binary and its symbol file.
// Pass { nd110XorFlip: true } for ND-110 .CODE files to apply the
// bit-22-27 inversion between ROM storage and canonical form.
const records = parseCodeFile("microcode/ND-110-RASK.CODE", {
  nd110XorFlip: true,
});
const symbols = parseSymbolsFile("microcode/ND-110-RASK.SYMBOLS.TXT");

// Disassemble every instruction.
const instrs = disassembleMap(records, pack, symbols);

// Format as a .uc-style source file.
const source = formatProgram(instrs);
console.log(source);
```

## Architecture

All files are in `src/`.

| File                      | Purpose                                                        |
|---------------------------|----------------------------------------------------------------|
| `types.ts`                | Types, `ALL_MODELS`, `normaliseModelName`                      |
| `word.ts`                 | Helpers for microcode words of any width (bigint)              |
| `yaml-loader.ts`          | Load the YAML in `defs/` (or the JSON copy) into a DefinitionPack |
| `generated-defs.json`     | JSON copy of the definitions, made by `scripts/generate-defs.mjs` |
| `bitfield.ts`             | Field extraction, `.CODE` and `.SYMBOLS.TXT` readers           |
| `assembler.ts`            | Assembler for ND-100, ND-110, ND-120                           |
| `disassembler.ts`         | Disassembler entry point; picks the ND-100 or ND-110 code      |
| `disassembler-nd100.ts`, `disassembler-nd110.ts` | The two disassemblers behind it          |
| `formatter.ts`            | The 3-line source layout                                       |
| `wide-defs.ts`, `assembler-wide.ts`, `disassembler-wide.ts`, `formatter-wide.ts` | NORD-10, ND-500, ND-5000 |
| `binary-formats.ts`       | Readers and writers for the image formats                      |
| `nd100-proms.ts`          | Combine the ND-100 PROM files into 64-bit words                |
| `rom-combiner.ts`         | Combine and split the two EPROM chips of an ND-110 or ND-120   |
| `detect-model.ts`         | Guess the variant of a source file from its words              |
| `index.ts`                | Public API                                                     |

## Key design decisions

- **YAML-driven**: All tokens, field positions, and format rules are loaded
  at runtime from `defs/*.yaml`. No hardcoded tables in the source.
- **Timing bits ignored during decode**: Bits 21, 26, 27 are pure
  timing/delay hints that different tokens set for hardware timing. They
  are excluded from token-identity matching so that shared bits do not
  cause one category to "consume" bits from another.
- **XOR flip**: ND-110 .CODE files store bits 22-27 inverted relative
  to the canonical assembled form (`nd110XorFlip`). The ND-100 PROMs do the same
  (`nd100XorFlip`, same mask `0x0FC00000`; ND-06.018.01). The ND-120 images are
  canonical. Both options are off by default; `assembleSource` writes the
  storage form for `nd110` and `nd100`.
- **Most-specific-first matching**: Within each category, tokens are sorted
  by logical-popcount descending so composite tokens (e.g. COMM+MIS
  sub-selectors) are matched before simpler versions.

## Testing

```bash
npm test           # one-shot
npm run test:watch # watch mode
```

The tests are in `tests/`. They include round trips (binary to source and
back) of the ND-110 RASK image, the ND-120 DELILAH images, the ND-100 PROM
files and the wide-word images in `../../reference/`.

## Building

```bash
npm run build      # produces dist/
npm run validate   # type-check only
```

After a change to a YAML file in `../../defs/`, make the JSON copy again:
`node scripts/generate-defs.mjs` (or `make generate` in `../..`).
