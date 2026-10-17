/**
 * ND-100 PROM round-trip tests.
 *
 * The 16 PROM files of the factory 3033S card (reference/roms/ND100/3033S)
 * are combined into 2048 64-bit words (src/nd100-proms.ts, same chip order as
 * tools/nd100-combine.py), disassembled with the ND-100 disassembler,
 * assembled again, and compared. Result: 2048 of 2048 words equal.
 *
 * History: an earlier version of this test reported 57.1 percent (1170/2048)
 * and blamed missing COMM mnemonics 0o22-0o33 and ALUF bits 56-58. That was
 * wrong. The 1201 lost words all lost only bit 31 (1052 words, T,NEXT) or
 * bit 30 (149 words, T,RETURN), the T_SEQ field, and all of them have VECT
 * (bit 25) set: the disassembler skipped the T_SEQ field whenever it had
 * emitted a vectored jump token (T,JMP0-3 and the like). Fixed in
 * src/disassembler-nd100.ts.
 *
 * Open question (not decided by this test): which bits of the PROM words are
 * stored inverted. The round trip is 2048/2048 with the words as they come
 * from the chips and also with XOR 0x01800000, 0x0F800000 or 0x0FC00000
 * applied first (checked 2026-10-17); a lossless disassembler does not tell
 * which form is the right reading of the hardware. This test uses the words
 * as they come from the chips, like the .CODE files of nd100-combine.py.
 */

import { describe, it, expect } from "vitest";
import { resolve } from "node:path";

import {
  assembleSource,
  compileDisassemblerPack,
  disassembleWord,
  formatInstruction,
  loadDefinitions,
  loadNd100Proms,
} from "../src/index.js";

const REPO_ROOT = resolve(__dirname, "../../..");
const ROMS = resolve(REPO_ROOT, "reference/roms/ND100");

function roundTrip(words: Map<number, bigint>): {
  exact: number;
  total: number;
  mismatches: number[];
  errors: string[];
} {
  const pack = loadDefinitions("nd100");
  const dpack = compileDisassemblerPack(pack);
  let src = "";
  for (const [addr, raw] of [...words.entries()].sort((a, b) => a[0] - b[0])) {
    const fi = formatInstruction(disassembleWord(raw, addr, dpack));
    src += `${addr.toString(8).padStart(6, "0")}/ ${fi.lines.join("\n    ")}\n`;
  }
  const result = assembleSource(src, pack, { model: "nd100" });
  const mismatches: number[] = [];
  let exact = 0;
  for (const [addr, original] of words) {
    if (result.binary.get(addr) === original) exact++;
    else mismatches.push(addr);
  }
  return {
    exact,
    total: words.size,
    mismatches,
    errors: result.diagnostics.filter((d) => d.severity === "error").map((d) => d.message),
  };
}

describe("ND-100 PROM round trip", () => {
  it("3033S: 2048 words from 16 PROMs", () => {
    const words = loadNd100Proms(resolve(ROMS, "3033S"), "3033S");
    expect(words.size).toBe(2048);
  });

  it("3033S: address 0 is a vectored jump", () => {
    const words = loadNd100Proms(resolve(ROMS, "3033S"), "3033S");
    const dpack = compileDisassemblerPack(loadDefinitions("nd100"));
    const tokens = disassembleWord(words.get(0)!, 0, dpack).tokens.map((t) => t.text);
    expect(tokens).toContain("T,JMP0-3");
  });

  it("3033S: 2048 of 2048 words disassemble and reassemble bit for bit", () => {
    const r = roundTrip(loadNd100Proms(resolve(ROMS, "3033S"), "3033S"));
    console.log(`ND-100 3033S: ${r.exact}/${r.total} words equal`);
    expect(r.errors).toEqual([]);
    expect(r.mismatches.map((a) => a.toString(8))).toEqual([]);
    expect(r.exact).toBe(2048);
  });

  it("3033E-CX base bank: every non-zero word round-trips", () => {
    const words = loadNd100Proms(resolve(ROMS, "3033E-CX"), "3033E-CX", "microcode");
    const r = roundTrip(words);
    console.log(`ND-100 3033E-CX base: ${r.exact}/${r.total} words equal`);
    expect(r.errors).toEqual([]);
    expect(r.mismatches.map((a) => a.toString(8))).toEqual([]);
    expect(r.exact).toBe(r.total);
  });

  it("3033E-CX extension bank (0o4000 and up): every non-zero word round-trips", () => {
    const words = loadNd100Proms(resolve(ROMS, "3033E-CX"), "3033E-CX", "microcode_ext");
    expect(Math.min(...words.keys())).toBeGreaterThanOrEqual(0o4000);
    const r = roundTrip(words);
    console.log(`ND-100 3033E-CX extension: ${r.exact}/${r.total} words equal`);
    expect(r.errors).toEqual([]);
    expect(r.mismatches.map((a) => a.toString(8))).toEqual([]);
    expect(r.exact).toBe(r.total);
  });
});
