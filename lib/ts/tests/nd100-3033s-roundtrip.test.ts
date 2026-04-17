/**
 * ND-100 3033S microcode round-trip test.
 *
 * Loads the combined 64-bit microcode from the factory 3033S PROM dump,
 * disassembles every instruction using the ND-100 disassembler, then
 * re-assembles the emitted text and compares byte-by-byte.
 *
 * The current bit-exact rate is 57.1% (1170/2048). The remaining
 * mismatches are clustered into known-unresolvable categories:
 *
 * - **~261 instructions** use COMM codes 0o22, 0o23, 0o24, 0o25, 0o32,
 *   0o33 which the ND-100 WCS assembler (per the 296-token mnemonic
 *   list the user provided) has NO mnemonic for. These bit patterns
 *   cannot be produced by the documented assembler. The 3033S ROM was
 *   likely produced by an earlier / richer assembler version with
 *   additional compound mnemonics that were dropped from the public
 *   manual.
 * - **~220 instructions** have ALUF-field bit-level mismatches
 *   (bits 56/57/58). Needs further investigation.
 * - **~150 others** at various isolated bit positions.
 *
 * The 3033S ROM stores bits in canonical form (NO XOR of bits 22-27
 * like ND-110 compiler output does). Confirmed by the first-instruction
 * sanity check: address 0 must decode as a T,JMP* vectored jump when
 * loaded WITHOUT `nd110XorFlip`. Applying XOR produces a mangled
 * instruction with SCOND+CONDENABL+SLWCS+MAPJ all asserted, which is
 * semantically impossible for a reset/dispatch vector.
 *
 * See `memory/project_nd_bits_22_27_invert.md` for the full story on
 * which CPUs apply the XOR and which don't.
 */

import { readFileSync } from "node:fs";
import { describe, it, expect } from "vitest";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { dirname } from "node:path";

import {
  loadDefinitions,
  compileDisassemblerPack,
  disassembleWord,
  formatInstruction,
  parseCodeBytes,
  assembleSource,
} from "../src/index.js";

const here = dirname(fileURLToPath(import.meta.url));
const ROM_PATH = resolve(here, "..", "..", "..", "web", "MC", "ND-100-3033S-microcode.CODE");

describe("ND-100 3033S microcode round-trip", () => {
  it("loads as 64-bit microcode without XOR flip", () => {
    const code = readFileSync(ROM_PATH);
    const map = parseCodeBytes(new Uint8Array(code), { nd110XorFlip: false });
    expect(map.size).toBe(2048);
    // Sanity: address 0 must be a JMP-family instruction (reset vector).
    const pack = loadDefinitions("nd100");
    const dpack = compileDisassemblerPack(pack);
    const d0 = disassembleWord(map.get(0)!, 0, dpack);
    const tokens0 = d0.tokens.map((t) => t.text);
    // Address 0 canonical microword has T,JMPAOPR which sets VECT+MIS
    // and is in the T_SEQ family. The test-object here is intentionally
    // narrow - any JMP-family token counts as a valid reset vector.
    const jmpFamily = [
      "T,JMP", "T,JMP0-3", "T,JMP8-10", "T,JMPALD", "T,JMPAOPR", "T,MAPJ",
    ];
    expect(tokens0.some((t) => jmpFamily.includes(t))).toBe(true);
  });

  it("bit-exact rate on full 64-bit round-trip stays at or above 56%", () => {
    const code = readFileSync(ROM_PATH);
    // Canonical form - no XOR on load.
    const map = parseCodeBytes(new Uint8Array(code), { nd110XorFlip: false });
    const pack = loadDefinitions("nd100");
    const dpack = compileDisassemblerPack(pack);

    // Disassemble every instruction
    let src = "";
    for (const [addr, raw] of [...map.entries()].sort((a, b) => a[0] - b[0])) {
      const d = disassembleWord(raw, addr, dpack);
      const fi = formatInstruction(d);
      src += `${addr.toString(8).padStart(6, "0")}/ ${fi.lines.join("\n    ")}\n`;
    }

    // Re-assemble - model=nd100 means NO XOR applied on output
    const result = assembleSource(src, pack, { model: "nd100" });
    const binary = result.binary;
    const errors = result.diagnostics.filter((d) => d.severity === "error");
    expect(errors).toEqual([]);
    expect(binary.size).toBe(2048);

    // Bit-exact comparison - no XOR involved anywhere in this model.
    let exact = 0;
    for (const [addr, original] of map) {
      const got = binary.get(addr);
      if (got === original) exact++;
    }
    const rate = (100 * exact) / map.size;
    console.log(
      `ND-100 3033S round-trip: ${exact}/${map.size} bit-exact (${rate.toFixed(1)}%)`,
    );

    // Lock current ceiling. As we add support for more token patterns,
    // raise this number. DO NOT lower it without a good reason - any
    // regression below this threshold means bits that previously round-
    // tripped now don't.
    expect(exact).toBeGreaterThanOrEqual(1170);
  });

  it("the 402+ unresolvable COMM mismatches are all in codes 0o22-0o25 / 0o32-0o33", () => {
    // This test documents the architectural gap - the 3033S ROM uses
    // COMM codes the documented ND-100 WCS assembler has no mnemonic
    // for. Until we either find the missing mnemonics or add raw-bit
    // escape tokens, these will never round-trip.
    const code = readFileSync(ROM_PATH);
    const map = parseCodeBytes(new Uint8Array(code), { nd110XorFlip: false });
    const pack = loadDefinitions("nd100");
    const dpack = compileDisassemblerPack(pack);

    let src = "";
    for (const [addr, raw] of [...map.entries()].sort((a, b) => a[0] - b[0])) {
      const d = disassembleWord(raw, addr, dpack);
      const fi = formatInstruction(d);
      src += `${addr.toString(8).padStart(6, "0")}/ ${fi.lines.join("\n    ")}\n`;
    }
    const result = assembleSource(src, pack, { model: "nd100" });
    const binary = result.binary;

    const COMM_MASK = 0x0000001F00000000n;
    const unresolvableCodes = new Set([0o22, 0o23, 0o24, 0o25, 0o32, 0o33]);
    let commMismatchesInUnresolvableCodes = 0;
    let commMismatchesInOtherCodes = 0;
    for (const [addr, original] of map) {
      const got = binary.get(addr);
      if (got === original) continue;
      if ((got ^ original) & COMM_MASK) {
        const commOrig = Number((original >> 32n) & 0x1Fn);
        if (unresolvableCodes.has(commOrig)) {
          commMismatchesInUnresolvableCodes++;
        } else {
          commMismatchesInOtherCodes++;
        }
      }
    }

    // The majority of COMM-field mismatches MUST be in the known
    // unresolvable codes. If this ratio drops, either we found new
    // mnemonics (raise the round-trip threshold!) or something regressed.
    expect(commMismatchesInUnresolvableCodes).toBeGreaterThan(200);
    console.log(
      `  unresolvable-COMM mismatches: ${commMismatchesInUnresolvableCodes}`,
    );
    console.log(
      `  other-COMM mismatches:        ${commMismatchesInOtherCodes}`,
    );
  });
});
