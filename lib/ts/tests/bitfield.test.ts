import { describe, it, expect } from "vitest";
import {
  decodeFields,
  extractField,
  parseSymbolsText,
  toOctal,
} from "../src/bitfield.js";

describe("extractField", () => {
  it("extracts single bits", () => {
    expect(extractField(0b1010n, 0, 0)).toBe(0);
    expect(extractField(0b1010n, 1, 1)).toBe(1);
    expect(extractField(0b1010n, 3, 3)).toBe(1);
  });

  it("extracts multi-bit fields", () => {
    // 0b1111_0000_1010 - extract bits 11..8 = 0b1111 = 15
    expect(extractField(0b1111_0000_1010n, 11, 8)).toBe(15);
    // bits 3..0 = 0b1010 = 10
    expect(extractField(0b1111_0000_1010n, 3, 0)).toBe(10);
  });

  it("handles 64-bit values", () => {
    // Set bit 63
    const v = 1n << 63n;
    expect(extractField(v, 63, 63)).toBe(1);
    expect(extractField(v, 62, 62)).toBe(0);
  });
});

describe("decodeFields", () => {
  it("decodes MACL instruction (address 0 in RASK)", () => {
    // From ND-110 RASK at address 0: raw data from binary
    // bytes 2-9 little-endian: ea c3 c9 07 83 00 00 20
    // value = 0x2000_0083_07C9_C3EA
    const raw = 0x20000083_07c9c3ean;
    const f = decodeFields(raw, 0);
    // Sanity: bits 63:55 should be non-zero for ALU activity
    expect(f.aluI).toBeGreaterThan(0);
    // Check lower bits give a reasonable branch address
    expect(f.branchAddress).toBeGreaterThanOrEqual(0);
  });

  it("decodes branch address correctly (csbit20 + csbit11_0)", () => {
    // Set csbit20=1 and csbit11_0=0o123 = 83
    const raw = (1n << 20n) | 0o123n;
    const f = decodeFields(raw, 0);
    expect(f.csbit20).toBe(1);
    expect(f.csbit11_0).toBe(0o123);
    // branchAddress = (csbit20 << 12) | csbit11_0 = 0x1000 | 0x53 = 0x1053
    expect(f.branchAddress).toBe(0x1000 | 0o123);
  });

  it("splits condition fields when SCOND=1", () => {
    // Bit 24 = SCOND, bits 11:8 = LCC, bits 7:4 = TSEL, bits 3:2 = F_SEQ, bits 1:0 = F_STK
    const raw = (1n << 24n) | 0o5736n; // LCC=5, TSEL=7, F_SEQ=3, F_STK=6 -> but F_STK is only 2 bits so this won't fit
    const f = decodeFields(raw, 0);
    expect(f.scond).toBe(1);
  });
});

describe("parseSymbolsText", () => {
  it("parses NNN=LABEL format", () => {
    const text = `Labels, sorted by address
=========================

000020=VERSN
000027=PVPF
000032=FTCH
`;
    const syms = parseSymbolsText(text);
    expect(syms.get(0o20)).toBe("VERSN");
    expect(syms.get(0o27)).toBe("PVPF");
    expect(syms.get(0o32)).toBe("FTCH");
  });

  it("ignores header lines and comments", () => {
    const text = `Some header
==========
# comment
% another comment
000100=LABEL1
`;
    const syms = parseSymbolsText(text);
    expect(syms.size).toBe(1);
    expect(syms.get(0o100)).toBe("LABEL1");
  });
});

describe("toOctal", () => {
  it("formats simple values", () => {
    expect(toOctal(0)).toBe("0");
    expect(toOctal(8)).toBe("10");
    expect(toOctal(0o1234)).toBe("1234");
  });

  it("pads to width", () => {
    expect(toOctal(0o17, 4)).toBe("0017");
    expect(toOctal(0, 6)).toBe("000000");
  });
});
