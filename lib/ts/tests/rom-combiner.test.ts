/**
 * ROM combiner / splitter tests.
 *
 * Combine and split are pure byte operations - they never transform the
 * microcode data. These tests verify:
 *   1. combine -> split is an identity on byte arrays
 *   2. split -> combine is an identity on maps
 *   3. The interleaving layout (high/low byte mapping) is correct
 *   4. The optional xorFlip is symmetric
 */

import { describe, it, expect } from "vitest";
import {
  combineRoms,
  splitRoms,
  ROM_WORDS,
  ROM_SIZE_BYTES,
} from "../src/rom-combiner.js";
import { ND110_XOR_MASK } from "../src/bitfield.js";

/** Build a synthetic microcode map that exercises many bit positions. */
function makeSyntheticMap(size: number): Map<number, bigint> {
  const map = new Map<number, bigint>();
  for (let addr = 0; addr < size; addr++) {
    const a = BigInt(addr);
    const value =
      ((a & 0xFFn) << 0n) |
      ((a & 0xFFn) << 16n) |
      ((a & 0xFFn) << 32n) |
      ((a & 0xFFn) << 48n) |
      ((a & 0x0Fn) << 12n);
    map.set(addr, value & 0xFFFFFFFFFFFFFFFFn);
  }
  return map;
}

describe("constants", () => {
  it("ROM_WORDS = 8192, ROM_SIZE_BYTES = 32768", () => {
    expect(ROM_WORDS).toBe(8192);
    expect(ROM_SIZE_BYTES).toBe(32768);
  });
});

describe("combine is a pure interleave", () => {
  it("high byte of each 16-bit sub-word comes from highChip", () => {
    const highChip = new Uint8Array(ROM_SIZE_BYTES);
    const lowChip = new Uint8Array(ROM_SIZE_BYTES);
    highChip[0] = 0xAB;  lowChip[0] = 0xCD;  // w1 = 0xABCD
    highChip[1] = 0x12;  lowChip[1] = 0x34;  // w2 = 0x1234
    highChip[2] = 0x56;  lowChip[2] = 0x78;  // w3 = 0x5678
    highChip[3] = 0x9A;  lowChip[3] = 0xBC;  // w4 = 0x9ABC
    const microcode = combineRoms(highChip, lowChip);
    expect(microcode.get(0)).toBe(0x9ABC_5678_1234_ABCDn);
  });

  it("no XOR is applied by default (same bytes in, same bytes out)", () => {
    const highChip = new Uint8Array(ROM_SIZE_BYTES);
    const lowChip = new Uint8Array(ROM_SIZE_BYTES);
    const microcode = combineRoms(highChip, lowChip);
    // All-zero ROM in, all-zero microword out.
    expect(microcode.get(0)).toBe(0n);
    expect(microcode.get(ROM_WORDS - 1)).toBe(0n);
  });

  it("xorFlip: true applies 0x0FC00000 after interleave", () => {
    const highChip = new Uint8Array(ROM_SIZE_BYTES);
    const lowChip = new Uint8Array(ROM_SIZE_BYTES);
    const microcode = combineRoms(highChip, lowChip, { xorFlip: true });
    expect(microcode.get(0)).toBe(ND110_XOR_MASK);
  });
});

describe("split -> combine round-trip (synthetic map)", () => {
  it("default (no xorFlip): map is preserved", () => {
    const original = makeSyntheticMap(ROM_WORDS);
    const { highChip, lowChip } = splitRoms(original);
    const recombined = combineRoms(highChip, lowChip);
    expect(recombined.size).toBe(original.size);
    for (const [addr, value] of original) {
      expect(recombined.get(addr)).toBe(value);
    }
  });

  it("xorFlip: true on both sides: map is preserved (XOR cancels)", () => {
    const original = makeSyntheticMap(ROM_WORDS);
    const { highChip, lowChip } = splitRoms(original, { xorFlip: true });
    const recombined = combineRoms(highChip, lowChip, { xorFlip: true });
    for (const [addr, value] of original) {
      expect(recombined.get(addr)).toBe(value);
    }
  });
});

describe("combine -> split round-trip (synthetic ROM bytes)", () => {
  it("arbitrary byte pattern is preserved", () => {
    const highChip = new Uint8Array(ROM_SIZE_BYTES);
    const lowChip = new Uint8Array(ROM_SIZE_BYTES);
    for (let i = 0; i < ROM_SIZE_BYTES; i++) {
      highChip[i] = (i * 37 + 11) & 0xFF;
      lowChip[i] = (i * 53 + 23) & 0xFF;
    }
    const microcode = combineRoms(highChip, lowChip);
    const { highChip: h2, lowChip: l2 } = splitRoms(microcode);
    expect(Buffer.from(h2)).toEqual(Buffer.from(highChip));
    expect(Buffer.from(l2)).toEqual(Buffer.from(lowChip));
  });
});

describe("splitRoms fill modes", () => {
  it("fill='empty' (default) produces ND-110 token form 0x0FC00000 for missing addrs", () => {
    const empty = new Map<number, bigint>();
    const { highChip, lowChip } = splitRoms(empty);
    // 0x0FC00000 decomposes to: w1=0, w2=0x0FC0, w3=0, w4=0
    expect(highChip[0]).toBe(0);
    expect(lowChip[0]).toBe(0);
    expect(highChip[1]).toBe(0x0F);
    expect(lowChip[1]).toBe(0xC0);
  });

  it("fill='zero' produces literal 0 bytes for missing addrs", () => {
    const empty = new Map<number, bigint>();
    const { highChip, lowChip } = splitRoms(empty, { fill: "zero" });
    expect(highChip[0]).toBe(0);
    expect(highChip[1]).toBe(0);
    expect(lowChip[0]).toBe(0);
    expect(lowChip[1]).toBe(0);
  });

  it("sparse map: defined addrs preserved, others get empty fill", () => {
    const sparse = new Map<number, bigint>([[100, 0x123456789ABCDEFn]]);
    const { highChip, lowChip } = splitRoms(sparse);
    // Read back addr 100.
    const base = 100 * 4;
    let v = 0n;
    for (let b = 3; b >= 0; b--) {
      const w = (highChip[base + b]! << 8) | lowChip[base + b]!;
      v = (v << 16n) | BigInt(w);
    }
    expect(v).toBe(0x123456789ABCDEFn);

    // Addr 0 was not in the map - should have empty fill.
    let empty = 0n;
    for (let b = 3; b >= 0; b--) {
      const w = (highChip[b]! << 8) | lowChip[b]!;
      empty = (empty << 16n) | BigInt(w);
    }
    expect(empty).toBe(ND110_XOR_MASK);
  });
});
