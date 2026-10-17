/**
 * Tests for auto chip-order detection and version reporting.
 */

import { describe, it, expect } from "vitest";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import {
  combineRoms,
  detectChipOrder,
  detectForm,
  readMicrocodeVersion,
} from "../src/rom-combiner.js";

const REPO_ROOT = resolve(__dirname, "../../..");

function readRom(relPath: string): Uint8Array {
  return new Uint8Array(readFileSync(resolve(REPO_ROOT, relPath)));
}

describe("detectChipOrder on real ROMs", () => {
  it("identifies 37949L as high and 37948L as low (ND-110 3095)", () => {
    // Pass them in both orders and the detector should pick the correct one.
    const a = readRom("reference/roms/ND110/37949L.bin"); // actually high
    const b = readRom("reference/roms/ND110/37948L.bin"); // actually low
    const r1 = detectChipOrder(a, b);
    expect(r1.high).toBe("a");
    expect(r1.confidence).toBeGreaterThan(0);

    const r2 = detectChipOrder(b, a);
    expect(r2.high).toBe("b");
    expect(r2.confidence).toBeGreaterThan(0);
  });

  it("identifies 45133L as high and 45132L as low (ND-120 AM27256)", () => {
    const high = readRom("reference/roms/ND120/4MB/45133L.27c256.b26.bin");
    const low = readRom("reference/roms/ND120/4MB/45132L.27c256.b23.bin");
    const r1 = detectChipOrder(high, low);
    expect(r1.high).toBe("a");
    const r2 = detectChipOrder(low, high);
    expect(r2.high).toBe("b");
  });

  it("throws when chips produce equally scored orderings (e.g. all-zero)", () => {
    const zeros = new Uint8Array(32768);
    expect(() => detectChipOrder(zeros, zeros)).toThrow(/Cannot determine/);
  });
});

describe("readMicrocodeVersion", () => {
  it("reads version L (octal 14 / decimal 12) from ND-110 3095 ROM", () => {
    const high = readRom("reference/roms/ND110/37949L.bin");
    const low = readRom("reference/roms/ND110/37948L.bin");
    const microcode = combineRoms(high, low);
    const version = readMicrocodeVersion(microcode);
    expect(version).toBeDefined();
    expect(version!.octalValue).toBe("0o14");
    expect(version!.decimalValue).toBe(12);
    expect(version!.letter).toBe("L");
  });

  it("reads version K (octal 13 / decimal 11) from the patched RASK.CODE", () => {
    // Load RASK.CODE via parseCodeBytes (we're testing readMicrocodeVersion
    // on any microcode map, not just ROM-derived ones).
    const codeBytes = new Uint8Array(
      readFileSync(resolve(REPO_ROOT, "reference/ND-110-RASK.CODE")),
    );
    const microcode = new Map<number, bigint>();
    for (let i = 0; i + 9 < codeBytes.length; i += 10) {
      const addr = codeBytes[i]! | (codeBytes[i + 1]! << 8);
      let v = 0n;
      for (let j = 0; j < 8; j++) v |= BigInt(codeBytes[i + 2 + j]!) << BigInt(j * 8);
      microcode.set(addr, v);
    }
    const version = readMicrocodeVersion(microcode);
    expect(version).toBeDefined();
    expect(version!.octalValue).toBe("0o13");
    expect(version!.decimalValue).toBe(11);
    expect(version!.letter).toBe("K");
  });

  it("letter mapping: J=10, K=11, L=12", () => {
    // Synthetic microcode with known version values.
    for (const [value, expectedLetter] of [
      [10, "J"],
      [11, "K"],
      [12, "L"],
      [15, "O"],
      [26, "Z"],
      [27, "?"], // out of range
      [0, "?"],  // out of range (no letter)
    ] as const) {
      const mc = new Map<number, bigint>([[0o20, BigInt(value)]]);
      const v = readMicrocodeVersion(mc);
      expect(v!.decimalValue).toBe(value);
      expect(v!.letter).toBe(expectedLetter);
    }
  });
});

describe("detectForm", () => {
  it("identifies 37948/37949 as ND-110 (token form)", () => {
    const high = readRom("reference/roms/ND110/37949L.bin");
    const low = readRom("reference/roms/ND110/37948L.bin");
    const mc = combineRoms(high, low);
    const r = detectForm(mc);
    expect(r.form).toBe("nd110");
    expect(r.flagBitRatio).toBeGreaterThan(0.8); // ~93% in practice
    expect(r.confidence).toBeGreaterThan(0.6);
  });

  it("identifies 45132/45133 as ND-120 (canonical form)", () => {
    const high = readRom("reference/roms/ND120/4MB/45133L.27c256.b26.bin");
    const low = readRom("reference/roms/ND120/4MB/45132L.27c256.b23.bin");
    const mc = combineRoms(high, low);
    const r = detectForm(mc);
    expect(r.form).toBe("nd120");
    expect(r.flagBitRatio).toBeLessThan(0.2); // ~5% in practice
    expect(r.confidence).toBeGreaterThan(0.6);
  });

  it("handles empty microcode gracefully", () => {
    const r = detectForm(new Map());
    expect(r.nonEmptyCount).toBe(0);
    expect(r.confidence).toBe(0);
  });
});
