/**
 * Full RASK microcode disassembly validation.
 *
 * Checks that the disassembler produces expected content for known
 * addresses in the ND-110 RASK microcode.
 */

import { describe, it, expect } from "vitest";
import { resolve } from "node:path";
import { loadDefinitions } from "../src/yaml-loader.js";
import {
  compileDisassemblerPack,
  disassembleMap,
  disassembleWord,
} from "../src/disassembler.js";
import { parseCodeFile, parseSymbolsFile } from "../src/bitfield.js";
import { formatInstruction } from "../src/formatter.js";

const REPO_ROOT = resolve(__dirname, "../../..");

function loadRASK() {
  const pack = compileDisassemblerPack(loadDefinitions("nd110"));
  const records = parseCodeFile(
    resolve(REPO_ROOT, "microcode/ND-110-RASK.CODE"),
    { nd110XorFlip: true },
  );
  const symbols = parseSymbolsFile(
    resolve(REPO_ROOT, "microcode/ND-110-RASK.SYMBOLS.TXT"),
  );
  return { pack, records, symbols };
}

describe("RASK full disassembly", () => {
  it("address 0 is MASTER CLEAR with AB,MACL COMM,EWRF", () => {
    const { pack, records, symbols } = loadRASK();
    const instr = disassembleWord(records.get(0)!, 0, pack, symbols);
    const texts = instr.tokens.map((t) => t.text);
    expect(texts).toContain("AB,MACL");
    expect(texts).toContain("ALUD,NONE");
    expect(texts).toContain("IDBS,ARG");
    expect(texts).toContain("COMM,EWRF");
    expect(texts).toContain("T,JMP");
    expect(texts).toContain("T,HOLD");
    expect(texts).toContain("MACL");  // Branch target label
  });

  it("address 0o16 is PANEL INTERRUPT with COMM,LDLC", () => {
    const { pack, records, symbols } = loadRASK();
    const instr = disassembleWord(records.get(0o16)!, 0o16, pack, symbols);
    const texts = instr.tokens.map((t) => t.text);
    expect(texts).toContain("ALUD,NONE");
    expect(texts).toContain("IDBS,PANEL");
    expect(texts).toContain("COMM,LDLC");
    expect(texts).toContain("PANEL"); // Branch target
  });

  it("VERSN label is at 0o20", () => {
    const { pack, records, symbols } = loadRASK();
    const instr = disassembleWord(records.get(0o20)!, 0o20, pack, symbols);
    expect(instr.label).toBe("VERSN");
  });

  it("PVPF at 0o27 has AB,PGS and condition test", () => {
    const { pack, records, symbols } = loadRASK();
    const instr = disassembleWord(records.get(0o27)!, 0o27, pack, symbols);
    const texts = instr.tokens.map((t) => t.text);
    expect(instr.label).toBe("PVPF");
    expect(texts).toContain("AB,PGS");
    expect(texts).toContain("COND,FETCH");
    expect(texts).toContain("F,NEXT");
    expect(texts).toContain("F,HOLD");
  });

  it("CONDENABL instruction after PVPF jumps to FTCH", () => {
    const { pack, records, symbols } = loadRASK();
    // Address 0o30 (one after PVPF)
    const instr = disassembleWord(records.get(0o30)!, 0o30, pack, symbols);
    const texts = instr.tokens.map((t) => t.text);
    expect(texts).toContain("CONDENABL");
    expect(texts).toContain("FTCH");
  });

  it("disassembles every RASK record without error", () => {
    const { pack, records, symbols } = loadRASK();
    const instrs = disassembleMap(records, pack, symbols);
    expect(instrs.length).toBe(records.size);
    for (const instr of instrs) {
      expect(instr.tokens.length).toBeGreaterThanOrEqual(0);
      const formatted = formatInstruction(instr);
      expect(formatted.lines.length).toBeGreaterThan(0);
    }
  });

  it("loads at least 180 labelled addresses", () => {
    const { symbols } = loadRASK();
    expect(symbols.size).toBeGreaterThan(180);
  });
});
