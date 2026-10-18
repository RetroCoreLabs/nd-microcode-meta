# Using the library

`@nd100uc/microcode` is in `lib/ts`. It is an ES module package for Node 18
or newer. It reads the YAML definitions (or a JSON copy of them), assembles
and disassembles microcode for all seven variants, reads and writes the image
formats, and guesses the variant of a source file.

The full list of exported names is under [Library API](api/index.md).

## Build and test

```bash
cd lib/ts
npm ci
npm run build      # tsc, writes dist/
npm test           # vitest
```

A program that uses the library imports it as an ES module. A program
that is compiled to CommonJS cannot `require` it.

## Definitions

| Call | Reads | Variants |
|------|-------|----------|
| `loadDefinitions(model)` | the YAML files in `defs/` (Node only) | `nd100`, `nd110`, `nd120`, `nd120-dly` |
| `loadWideDefinitions(model)` | the YAML files in `defs/` (Node only) | `nd10`, `nd500`, `nd5000` |
| `loadDefinitionsFromJSON(model, data)` | a JSON copy, no files | `nd100`, `nd110`, `nd120`, `nd120-dly` |
| `loadWideDefinitionsFromJSON(model, data)` | a JSON copy, no files | `nd10`, `nd500`, `nd5000` |

The JSON copy is `lib/ts/src/generated-defs.json`. It is made from the YAML
by `node lib/ts/scripts/generate-defs.mjs` (or `make generate`). A program
that cannot read files, such as a browser or a bundled extension, imports the
JSON and uses the `...FromJSON` calls.

`normaliseModelName(text)` turns a spelling such as `ND-500` or `nd120l` into
the canonical name, or `undefined`. `ALL_MODELS` lists the seven names.

## Assemble and disassemble ND-100, ND-110, ND-120

```js
import {
  assembleSource, loadDefinitions, recordsToCodeBytes, parseCodeBytes,
} from "@nd100uc/microcode";

const source = `0/
        AB,MACL                                         ALUD,NONE
        IDBS,ARG               COMM,EWRF T,JMP         T,HOLD
        100;
`;
const pack = loadDefinitions("nd110");
const result = assembleSource(source, pack, { model: "nd110" });

result.diagnostics;                          // errors and warnings, with line numbers
result.binary;                               // Map: address -> 64-bit word (bigint)
const code = recordsToCodeBytes(result.records);   // .CODE file, 10 bytes per record
const back = parseCodeBytes(code);           // Map: address -> word
```

To go the other way: `compileDisassemblerPack(pack)`, then
`disassembleMap(words, dpack, symbols)` and `formatProgram(...)`.

## Assemble and disassemble NORD-10, ND-500, ND-5000

```js
import {
  loadWideDefinitions, assembleWide, detectBinaryFormat, readPacked18, formatProgramWide,
} from "@nd100uc/microcode";

const pack = loadWideDefinitions("nd500");
const result = assembleWide("10/ A,A#1 ;\n", pack, { stampDate: false });

result.errorCount;                     // 0
result.image;                          // Uint8Array, 147456 bytes: the ND-500 image (packed18)
detectBinaryFormat(result.image);      // "packed18"

const words = readPacked18(result.image);               // array of bigint, one per address
const text = formatProgramWide(pack, new Map([[8, words[8]]]));
// "% ND-500 microcode (lossless disassembly)\n000010/ A,A#1 ;\n"
```

`assembleWide` also builds the image when there are errors, so check
`errorCount` before the image is used.

## Image formats

`detectBinaryFormat(bytes)` finds the format from the size and the content.
Each format has a reader and a writer (see [binary-formats.ts](api/binary-formats.md)).

| Format | Variant | Size |
|--------|---------|------|
| `packed18` | ND-500 | 147456 bytes |
| `be16x8` | ND-5000 | 262144 bytes |
| `prom-hex` | NORD-10 | text |
| `be32` | NORD-10 | 4096 or 16384 bytes |
| `code-records` | ND-100, ND-110, ND-120 | 10 bytes per record |

## Guess the variant of a source file

```js
import { detectModel } from "@nd100uc/microcode";

// names: { nd10: Set, nd100: Set, ... } with the token names of each variant
const guess = detectModel(sourceText, names);
guess.model;     // "nd500", or undefined when the words do not settle it
guess.note;      // one line that says why
```

The rule is written in the header of [detect-model.ts](api/detect-model.md).
The VS Code extension uses it for the guess that its status bar shows.
