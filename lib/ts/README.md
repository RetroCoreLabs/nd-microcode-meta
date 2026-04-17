# @nd100uc/microcode

TypeScript library for disassembling (and, in later phases, assembling) ND-100, ND-110, and ND-120 microcode.

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

| File                 | Purpose                                                   |
|----------------------|-----------------------------------------------------------|
| `src/types.ts`       | Type definitions (Model, Token, DecodedFields, ...)       |
| `src/yaml-loader.ts` | Load YAML defs from `defs/` into a DefinitionPack         |
| `src/bitfield.ts`    | Bitfield extraction + .CODE/.SYMBOLS parsers              |
| `src/disassembler.ts`| Decode raw 64-bit word into categorised tokens            |
| `src/formatter.ts`   | Format tokens into the 3-line assembly layout             |
| `src/index.ts`       | Public API surface                                         |

## Key design decisions

- **YAML-driven**: All tokens, field positions, and format rules are loaded
  at runtime from `defs/*.yaml`. No hardcoded tables in the source.
- **Timing bits ignored during decode**: Bits 21, 26, 27 are pure
  timing/delay hints that different tokens set for hardware timing. They
  are excluded from token-identity matching so that shared bits do not
  cause one category to "consume" bits from another.
- **ND-110 XOR flip**: ND-110 .CODE files store bits 22-27 inverted relative
  to the canonical assembled form. The loader applies the XOR optionally.
- **Most-specific-first matching**: Within each category, tokens are sorted
  by logical-popcount descending so composite tokens (e.g. COMM+MIS
  sub-selectors) are matched before simpler versions.

## Testing

```bash
npm test           # one-shot
npm run test:watch # watch mode
```

Tests validate against the real `microcode/ND-110-RASK.CODE` and known
addresses (MASTER CLEAR at 0, PANEL INTERRUPT at 0o16, VERSN at 0o20,
PVPF at 0o27, etc.).

## Building

```bash
npm run build      # produces dist/
npm run validate   # type-check only
```
