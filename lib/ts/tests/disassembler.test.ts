import { describe, it, expect } from "vitest";
import { loadDefinitions } from "../src/yaml-loader.js";
import {
  compileDisassemblerPack,
  disassembleWord,
  disassembleMap,
} from "../src/disassembler.js";
import {
  parseCodeFile,
  parseSymbolsFile,
} from "../src/bitfield.js";
import { formatInstruction, formatProgram } from "../src/formatter.js";
import { resolve } from "node:path";

const REPO_ROOT = resolve(__dirname, "../../..");

describe("disassembleWord", () => {
  it("decodes a simple instruction", () => {
    const pack = compileDisassemblerPack(loadDefinitions("nd110"));
    // An instruction that just does T,JMP to address 6 with COMM,SLOW1
    // RASK address 6: "T,JMP 6 COMM,SLOW1;"
    // T,JMP encoding is 0 (default), COMM,SLOW1 = w3="000010" = bit 3 of w3 = bit 35
    // branch addr 6 in low 4 bits
    const instr = disassembleWord(
      // Manually construct: COMM,SLOW1 (bit 35) + branch addr 6 (bits 2-0, shifted into 0xF of low 4)
      (1n << 35n) | 0o6n,
      0o6,
      pack,
    );
    expect(instr.fields.comm).toBe(0o10);
    expect(instr.fields.branchAddress).toBe(0o6);
    // Should emit COMM,SLOW1 and a branch target
    const texts = instr.tokens.map((t) => t.text);
    expect(texts).toContain("COMM,SLOW1");
  });
});

describe("end-to-end: ND-110 RASK", () => {
  it("loads and disassembles the full RASK microcode", () => {
    const pack = compileDisassemblerPack(loadDefinitions("nd110"));
    const records = parseCodeFile(
      resolve(REPO_ROOT, "reference/ND-110-RASK.CODE"),
      { nd110XorFlip: true },
    );
    const symbols = parseSymbolsFile(
      resolve(REPO_ROOT, "reference/ND-110-RASK.SYMBOLS.TXT"),
    );

    expect(records.size).toBeGreaterThan(4000);
    expect(symbols.size).toBeGreaterThan(100);

    const instrs = disassembleMap(records, pack, symbols);
    expect(instrs.length).toBeGreaterThan(4000);

    // Every instruction should disassemble without throwing.
    for (const instr of instrs.slice(0, 200)) {
      expect(instr.tokens).toBeInstanceOf(Array);
    }

    // Address 0o20 should have label VERSN.
    const versn = instrs.find((i) => i.address === 0o20);
    expect(versn?.label).toBe("VERSN");
  });

  it("formats the first few instructions as multi-line", () => {
    const pack = compileDisassemblerPack(loadDefinitions("nd110"));
    const records = parseCodeFile(
      resolve(REPO_ROOT, "reference/ND-110-RASK.CODE"),
      { nd110XorFlip: true },
    );
    const symbols = parseSymbolsFile(
      resolve(REPO_ROOT, "reference/ND-110-RASK.SYMBOLS.TXT"),
    );

    const instrs = disassembleMap(records, pack, symbols).slice(0, 20);
    const text = formatProgram(instrs);
    // Should contain some of the expected labels from the source
    expect(text).toContain("VERSN");
    // Should contain COND or F, tokens from the trap handling
    expect(text).toMatch(/COND,|T,JMP|COMM,/);
  });

  it("formatInstruction produces up to 3 lines", () => {
    const pack = compileDisassemblerPack(loadDefinitions("nd110"));
    const records = parseCodeFile(
      resolve(REPO_ROOT, "reference/ND-110-RASK.CODE"),
      { nd110XorFlip: true },
    );

    // Pick PVPF at address 0o27 - known to span 3 lines in source
    const raw = records.get(0o27);
    expect(raw).toBeDefined();
    const instr = disassembleWord(raw!, 0o27, pack);
    const formatted = formatInstruction(instr);
    expect(formatted.lines.length).toBeGreaterThanOrEqual(1);
    expect(formatted.lines.length).toBeLessThanOrEqual(3);
  });
});
