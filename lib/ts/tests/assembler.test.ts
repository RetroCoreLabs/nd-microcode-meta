/**
 * Assembler unit tests.
 */

import { describe, it, expect } from "vitest";
import {
  assembleSource,
  parseNumericLiteral,
  preprocess,
} from "../src/assembler.js";
import { loadDefinitions } from "../src/yaml-loader.js";

describe("parseNumericLiteral", () => {
  it("defaults to octal", () => {
    expect(parseNumericLiteral("10")).toBe(8);
    expect(parseNumericLiteral("170000")).toBe(0o170000);
  });

  it("accepts decimal with d prefix", () => {
    expect(parseNumericLiteral("d10")).toBe(10);
    expect(parseNumericLiteral("D255")).toBe(255);
  });

  it("accepts hex with 0x and $ prefixes", () => {
    expect(parseNumericLiteral("0x1A")).toBe(26);
    expect(parseNumericLiteral("$FF")).toBe(255);
  });

  it("rejects non-octal strings when no prefix", () => {
    expect(parseNumericLiteral("89")).toBe(NaN);
    expect(parseNumericLiteral("ABC")).toBe(NaN);
  });
});

describe("preprocess", () => {
  it("strips comments", () => {
    const src = "% this is a comment\n0/\nT,JMP T,HOLD 6 COMM,SLOW1;";
    const sm = preprocess(src);
    expect(sm.instructions.length).toBe(1);
    expect(sm.instructions[0]!.args).toEqual([
      "T,JMP",
      "T,HOLD",
      "6",
      "COMM,SLOW1",
    ]);
  });

  it("tracks address markers", () => {
    const src = `
20/
A,D ALUD,NONE IDBS,ARG T,JMP T,HOLD 6;
`;
    const sm = preprocess(src);
    expect(sm.instructions.length).toBe(1);
    expect(sm.instructions[0]!.address).toBe(0o20);
  });

  it("collects labels with addresses", () => {
    const src = `
10/
LOOP: A,D ALUD,NONE IDBS,ARG T,JMP T,HOLD 6;
EXIT: A,A ALUD,NONE IDBS,ARG T,JMP T,HOLD 6;
`;
    const sm = preprocess(src);
    expect(sm.labels.get("LOOP")).toBe(0o10);
    expect(sm.labels.get("EXIT")).toBe(0o11);
  });

  it("handles multi-line instructions", () => {
    const src = `
0/
          AB,MACL                ALUD,NONE
          IDBS,ARG               COMM,EWRF T,JMP T,HOLD
          MACL;
`;
    const sm = preprocess(src);
    expect(sm.instructions.length).toBe(1);
    expect(sm.instructions[0]!.args).toContain("AB,MACL");
    expect(sm.instructions[0]!.args).toContain("ALUD,NONE");
    expect(sm.instructions[0]!.args).toContain("COMM,EWRF");
    expect(sm.instructions[0]!.args).toContain("MACL");
  });

  it("normalises spaces around commas", () => {
    const src = "0/ A , D ALUD, NONE IDBS ,ARG T,JMP T,HOLD 6;";
    const sm = preprocess(src);
    const args = sm.instructions[0]!.args;
    expect(args).toContain("A,D");
    expect(args).toContain("ALUD,NONE");
    expect(args).toContain("IDBS,ARG");
  });
});

describe("assembleSource", () => {
  it("assembles a single simple instruction", () => {
    const pack = loadDefinitions("nd110");
    const src = "0/ T,JMP T,HOLD 6 COMM,SLOW1;";
    const { binary, diagnostics } = assembleSource(src, pack);
    expect(diagnostics).toEqual([]);
    expect(binary.size).toBe(1);
    const value = binary.get(0);
    expect(value).toBeDefined();
    // Expected: COMM,SLOW1 (w3=000010 = bit 35) OR branch addr 6 OR ND-110 XOR
    const comm_slow1 = pack.tokensByName.get("COMM,SLOW1")!;
    const expectedCanonical = comm_slow1.encodingValue | 6n;
    const expectedRom = expectedCanonical ^ 0x0FC00000n;
    expect(value).toBe(expectedRom);
  });

  it("resolves a forward-declared label", () => {
    const pack = loadDefinitions("nd110");
    const src = `
0/ T,JMP T,HOLD TARGET COMM,SLOW1;
10/
TARGET: T,JMP T,HOLD TARGET;
`;
    const { binary, sourceMap, diagnostics } = assembleSource(src, pack);
    expect(diagnostics).toEqual([]);
    expect(sourceMap.labels.get("TARGET")).toBe(0o10);
    // Instruction at 0 should have branch addr = 0o10 (low 12 bits).
    const value = binary.get(0)! ^ 0x0FC00000n; // undo ROM flip for analysis
    expect(value & 0xFFFn).toBe(0o10n);
  });

  it("reports unknown tokens", () => {
    const pack = loadDefinitions("nd110");
    const src = "0/ T,JMP T,HOLD SOMETHING_UNKNOWN COMM,SLOW1;";
    const { diagnostics } = assembleSource(src, pack);
    expect(diagnostics.length).toBeGreaterThan(0);
    expect(diagnostics[0]!.message).toContain("SOMETHING_UNKNOWN");
  });

  it("handles numeric branch targets", () => {
    const pack = loadDefinitions("nd110");
    // Plain digits are octal (Norsk Data convention).
    const src = "0/ T,JMP T,HOLD 1752 COMM,SLOW1;";
    const { binary, diagnostics } = assembleSource(src, pack);
    expect(diagnostics).toEqual([]);
    // 0o1752 = 0x3EA, fits in 12 bits
    const value = binary.get(0)! ^ 0x0FC00000n;
    expect(value & 0xFFFn).toBe(0o1752n & 0xFFFn);
  });

  it("sets bit 20 for addresses >= 0x1000", () => {
    const pack = loadDefinitions("nd110");
    // Label at a high address (bit 12 set).
    const src = `
0/ T,JMP T,HOLD HIGH;
10000/
HIGH: T,JMP T,HOLD 0;
`;
    const { binary, sourceMap } = assembleSource(src, pack);
    expect(sourceMap.labels.get("HIGH")).toBe(0o10000);
    expect(sourceMap.labels.get("HIGH")! >> 12).toBe(1);
    const value = binary.get(0)! ^ 0x0FC00000n; // undo ROM flip
    // Bit 20 set?
    expect((value >> 20n) & 1n).toBe(1n);
    // Low 12 bits = 0
    expect(value & 0xFFFn).toBe(0n);
  });
});
