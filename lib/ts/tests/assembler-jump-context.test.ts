/**
 * Context-aware numeric split tests for translateInstruction.
 *
 * Verifies that a numeric literal in a T,JMP-like context is treated
 * as a 13-bit branch address (bit 12 split to bit 20), while a numeric
 * in a T,NEXT or SCOND=1 context is OR'd as data.
 */

import { describe, it, expect } from "vitest";
import { assembleSource } from "../src/assembler.js";
import { loadDefinitions } from "../src/yaml-loader.js";
import { ND110_XOR_MASK } from "../src/bitfield.js";

describe("assembler: context-aware numeric split", () => {
  const pack = loadDefinitions("nd110");

  function assemble(source: string): bigint {
    const { binary, diagnostics } = assembleSource(source, pack, { model: "nd110" });
    const errors = diagnostics.filter((d) => d.severity === "error");
    expect(errors).toEqual([]);
    // Undo the ND-110 XOR to get canonical form for easier bit inspection.
    return (binary.get(0) ?? 0n) ^ ND110_XOR_MASK;
  }

  it("T,JMP with numeric 14000 (=0x1800) splits: bit 20 set, low 12 = 0x800", () => {
    const value = assemble("0/ T,JMP T,HOLD 14000;");
    expect((value >> 20n) & 1n).toBe(1n);           // bit 20 set
    expect(value & 0xFFFn).toBe(0x800n);            // low 12 = 0x800
    // AOP field (bits 15:12) should be 0 (not 0x1 as it would with OR).
    expect((value >> 12n) & 0xFn).toBe(0n);
  });

  it("T,RETURN with numeric 14000 is DATA (uses return stack, not low bits)", () => {
    // Matches C# reference behaviour - see RASK addr 0o4752.
    const value = assemble("0/ T,RETURN T,HOLD 14000;");
    expect((value >> 20n) & 1n).toBe(0n);
    expect(value & 0xFFFFn).toBe(0x1800n);
  });

  it("T,JMP with numeric 14000 AND CONDENABL still splits (T,JMP dominates)", () => {
    const value = assemble("0/ T,JMP T,HOLD 14000 CONDENABL;");
    expect((value >> 20n) & 1n).toBe(1n);
    expect(value & 0xFFFn).toBe(0x800n);
  });

  it("CONDENABL without T,JMP is NOT jump context - numeric is DATA", () => {
    // Matches C# reference behaviour - see RASK addr 0o1535 where
    // IDBS,ARG + T,NEXT + CONDENABL + 10000 uses the 10000 as data.
    const value = assemble("0/ IDBS,ARG T,NEXT T,HOLD 10000 CONDENABL;");
    expect((value >> 20n) & 1n).toBe(0n);
    expect(value & 0xFFFFn).toBe(0x1000n);
  });

  it("T,NEXT with numeric 14000 is DATA: no split, OR into low 16 bits", () => {
    // IDBS,ARG + T,NEXT + numeric should preserve the data OR behaviour.
    const value = assemble("0/ IDBS,ARG T,NEXT T,HOLD 14000;");
    expect((value >> 20n) & 1n).toBe(0n);           // bit 20 NOT set
    expect(value & 0xFFFFn).toBe(0x1800n);          // bits 11 + 12 set
    expect((value >> 12n) & 1n).toBe(1n);           // AOP.0 set (via OR)
  });

  it("SCOND=1 (COND,xxx present) preserves low 12 bits for condition fields", () => {
    // COND,F=0 sets SCOND; numeric 400 is the LCC=1 value.
    const value = assemble("0/ ALUD,NONE IDBS,ALU COND,F=0 F,JMP F,HOLD 400;");
    expect((value >> 20n) & 1n).toBe(0n);           // bit 20 NOT set
    // 400 octal = 0x100 - LCC.0 bit (bit 8) set via OR.
    expect((value >> 8n) & 0xFn).toBe(1n);
  });

  it("T,JMP with small numeric (< 0x1000) still produces no bit 20", () => {
    const value = assemble("0/ T,JMP T,HOLD 1752;");
    expect((value >> 20n) & 1n).toBe(0n);           // bit 20 NOT set
    expect(value & 0xFFFn).toBe(0o1752n);           // low 12 = 0o1752
  });

  it("T,JMP with numeric >= 0x2000 (beyond 13-bit addr range) is data-OR", () => {
    // 0x2000 = 8192 = 0o20000. Too big to be a branch target.
    const value = assemble("0/ T,JMP T,HOLD 20000;");
    // We OR as data into low 16 bits. Bit 13 (part of AOP) gets set.
    expect((value >> 20n) & 1n).toBe(0n);
    expect(value & 0xFFFFn).toBe(0x2000n);
  });
});
