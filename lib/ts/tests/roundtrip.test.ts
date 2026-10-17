/**
 * Round-trip validation.
 *
 *   1. Load RASK binary
 *   2. Disassemble every instruction into formatted source text
 *   3. Preprocess + translate that source back to binary
 *   4. Compare binaries (ignoring timing bits that don't participate in
 *      the logical round-trip)
 *
 * This proves the disassembler produces output the assembler can round-trip.
 */

import { describe, it, expect } from "vitest";
import { resolve } from "node:path";
import { loadDefinitions } from "../src/yaml-loader.js";
import {
  compileDisassemblerPack,
  disassembleMap,
  TIMING_MASK,
} from "../src/disassembler.js";
import { parseCodeFile, parseSymbolsFile } from "../src/bitfield.js";
import { formatProgram } from "../src/formatter.js";
import { assembleSource } from "../src/assembler.js";
import { ND110_XOR_MASK } from "../src/bitfield.js";

const REPO_ROOT = resolve(__dirname, "../../..");

function popcount(v: bigint): number {
  let c = 0;
  let x = v;
  while (x > 0n) {
    x &= x - 1n;
    c++;
  }
  return c;
}

describe("RASK round-trip: binary -> disasm -> asm -> binary", () => {
  it("produces identical canonical microcode (ignoring timing bits)", () => {
    const pack = compileDisassemblerPack(loadDefinitions("nd110"));
    const records = parseCodeFile(
      resolve(REPO_ROOT, "reference/ND-110-RASK.CODE"),
      { nd110XorFlip: true },
    );
    const symbols = parseSymbolsFile(
      resolve(REPO_ROOT, "reference/ND-110-RASK.SYMBOLS.TXT"),
    );

    // 1. Disassemble everything.
    const instrs = disassembleMap(records, pack, symbols);

    // 2. Format as .uc source text.
    const source = formatProgram(instrs);

    // 3. Reassemble. assembleSource returns ROM-storage form for ND-110;
    //    we convert back to canonical for comparison against our
    //    already-canonical `records` map.
    const { binary, diagnostics } = assembleSource(
      source,
      pack.definitions,
      { model: "nd110" },
    );

    // Fail fast on unknown-token errors.
    const errors = diagnostics.filter((d) => d.severity === "error");
    if (errors.length > 0) {
      console.log("First 10 assembly errors:");
      for (const e of errors.slice(0, 10)) {
        console.log(`  line ${e.line} addr 0o${e.address?.toString(8) ?? "?"}: ${e.message}`);
      }
    }
    expect(errors.length).toBe(0);

    // 4. Compare bit-by-bit, ignoring timing bits.
    expect(binary.size).toBe(records.size);

    const mismatches: { addr: number; orig: bigint; reasm: bigint; diff: bigint }[] = [];
    for (const [addr, origCanonical] of records) {
      const reasmRom = binary.get(addr);
      if (reasmRom === undefined) {
        mismatches.push({ addr, orig: origCanonical, reasm: 0n, diff: origCanonical });
        continue;
      }
      const reasmCanonical = reasmRom ^ ND110_XOR_MASK;
      // Compare ignoring timing bits.
      const diff =
        (origCanonical ^ reasmCanonical) & ~TIMING_MASK;
      if (diff !== 0n) {
        mismatches.push({ addr, orig: origCanonical, reasm: reasmCanonical, diff });
      }
    }

    if (mismatches.length > 0) {
      console.log(`${mismatches.length} mismatches out of ${records.size} instructions:`);
      for (const m of mismatches.slice(0, 20)) {
        console.log(
          `  0o${m.addr.toString(8).padStart(6, "0")}: ` +
          `orig=0x${m.orig.toString(16).padStart(16, "0")} ` +
          `reasm=0x${m.reasm.toString(16).padStart(16, "0")} ` +
          `diff=0x${m.diff.toString(16).padStart(16, "0")} ` +
          `(${popcount(m.diff)} bits)`,
        );
      }
    }

    expect(mismatches.length).toBe(0);
  });

  it("reports bit-exact match statistics (including timing bits)", () => {
    const pack = compileDisassemblerPack(loadDefinitions("nd110"));
    const records = parseCodeFile(
      resolve(REPO_ROOT, "reference/ND-110-RASK.CODE"),
      { nd110XorFlip: true },
    );
    const symbols = parseSymbolsFile(
      resolve(REPO_ROOT, "reference/ND-110-RASK.SYMBOLS.TXT"),
    );
    const instrs = disassembleMap(records, pack, symbols);
    const source = formatProgram(instrs);
    const { binary } = assembleSource(source, pack.definitions, { model: "nd110" });

    let bitExact = 0;
    let timingOnly = 0;
    let logicalDiff = 0;
    for (const [addr, orig] of records) {
      const reasm = (binary.get(addr) ?? 0n) ^ ND110_XOR_MASK;
      if (orig === reasm) {
        bitExact++;
      } else if (((orig ^ reasm) & ~TIMING_MASK) === 0n) {
        timingOnly++;
      } else {
        logicalDiff++;
      }
    }
    const total = records.size;
    console.log(`Bit-exact match:    ${bitExact}/${total} (${((100 * bitExact) / total).toFixed(1)}%)`);
    console.log(`Timing-bits only:   ${timingOnly}/${total} (${((100 * timingOnly) / total).toFixed(1)}%)`);
    console.log(`Logical mismatches: ${logicalDiff}/${total}`);
    expect(logicalDiff).toBe(0);
  });
});
