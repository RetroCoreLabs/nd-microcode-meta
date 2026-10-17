/**
 * Real-ROM round-trip validation.
 *
 * Loads both chip pairs from the repo's `microcode/roms/` directory,
 * combines each into a microcode map, splits the map back into chip
 * images, and verifies byte-identical output to the input.
 *
 * Combine and split are pure byte operations, so this is a direct
 * identity test that does not depend on any .CODE file or .uc source.
 */

import { describe, it, expect } from "vitest";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { combineRoms, splitRoms } from "../src/rom-combiner.js";

const REPO_ROOT = resolve(__dirname, "../../..");

function roundtrip(highPath: string, lowPath: string) {
  const highBytes = new Uint8Array(readFileSync(resolve(REPO_ROOT, highPath)));
  const lowBytes = new Uint8Array(readFileSync(resolve(REPO_ROOT, lowPath)));

  const microcode = combineRoms(highBytes, lowBytes);
  const { highChip: high2, lowChip: low2 } = splitRoms(microcode);

  return {
    highMatches: Buffer.compare(Buffer.from(highBytes), Buffer.from(high2)) === 0,
    lowMatches: Buffer.compare(Buffer.from(lowBytes), Buffer.from(low2)) === 0,
    byteCount: highBytes.length,
    instrCount: microcode.size,
  };
}

describe("real-ROM round-trip (authoritative)", () => {
  it("ND-110 3095 card: 37949L (high) + 37948L (low)", () => {
    const r = roundtrip(
      "reference/roms/ND110/37949L.bin",
      "reference/roms/ND110/37948L.bin",
    );
    console.log(
      `ND-110 3095: 2 x ${r.byteCount} bytes, ${r.instrCount} microinstructions`,
    );
    expect(r.highMatches).toBe(true);
    expect(r.lowMatches).toBe(true);
  });

  it("ND-120 4MB pair: 45133L (high) + 45132L (low)", () => {
    const r = roundtrip(
      "reference/roms/ND120/4MB/45133L.27c256.b26.bin",
      "reference/roms/ND120/4MB/45132L.27c256.b23.bin",
    );
    console.log(
      `ND-120 AM27256: 2 x ${r.byteCount} bytes, ${r.instrCount} microinstructions`,
    );
    expect(r.highMatches).toBe(true);
    expect(r.lowMatches).toBe(true);
  });

  it("ND-120 6MB pair: 45133L (high) + 45132L (low)", () => {
    const r = roundtrip(
      "reference/roms/ND120/6MB/45133L.27c256.b26.bin",
      "reference/roms/ND120/6MB/45132L.27c256.b23.bin",
    );
    console.log(
      `ND-120 6MB: 2 x ${r.byteCount} bytes, ${r.instrCount} microinstructions`,
    );
    expect(r.highMatches).toBe(true);
    expect(r.lowMatches).toBe(true);
  });
});
