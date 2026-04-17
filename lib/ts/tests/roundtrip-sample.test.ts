/**
 * Sample disassembly test - prints the first 20 instructions of RASK
 * so we can eyeball the output against the known .uc source file.
 */

import { describe, it } from "vitest";
import { resolve } from "node:path";
import { loadDefinitions } from "../src/yaml-loader.js";
import {
  compileDisassemblerPack,
  disassembleMap,
} from "../src/disassembler.js";
import { parseCodeFile, parseSymbolsFile } from "../src/bitfield.js";
import { formatProgram } from "../src/formatter.js";

const REPO_ROOT = resolve(__dirname, "../../..");

describe("RASK sample output", () => {
  it("prints first 50 addresses", () => {
    const pack = compileDisassemblerPack(loadDefinitions("nd110"));
    const records = parseCodeFile(
      resolve(REPO_ROOT, "microcode/ND-110-RASK.CODE"),
      { nd110XorFlip: true },
    );
    const symbols = parseSymbolsFile(
      resolve(REPO_ROOT, "microcode/ND-110-RASK.SYMBOLS.TXT"),
    );

    const addresses = [...records.keys()].sort((a, b) => a - b).slice(0, 50);
    const picked = new Map(addresses.map((a) => [a, records.get(a)!]));
    const instrs = disassembleMap(picked, pack, symbols);
    const text = formatProgram(instrs);

    // Print to stderr so vitest shows it
    console.log("=".repeat(72));
    console.log("Sample RASK disassembly (first 50 addresses):");
    console.log("=".repeat(72));
    console.log(text);
    console.log("=".repeat(72));
  });
});
