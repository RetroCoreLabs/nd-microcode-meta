/**
 * Analyze the 608 ND-110 ROM vs .CODE differences to understand their
 * distribution. Per the user, the ROMs are from a physical ND-110 3095
 * card while the .CODE file is from a patched RASK.uc source.
 *
 * Questions to answer:
 *   1. Are the 608 diffs concentrated in a particular address range?
 *   2. Are they entirely in addresses >= last-used-in-source?
 *   3. Do they include known patches (MACL3 at 0o1754)?
 */

import { describe, it } from "vitest";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { combineRomFiles } from "../src/rom-combiner.js";
import { parseCodeBytes } from "../src/bitfield.js";

const REPO_ROOT = resolve(__dirname, "../../..");

describe("ND-110 ROM vs RASK.CODE analysis", () => {
  it("tabulates differences by address range", () => {
    const rom = combineRomFiles(
      resolve(REPO_ROOT, "reference/roms/ND110/37949L.bin"),
      resolve(REPO_ROOT, "reference/roms/ND110/37948L.bin"),
    );
    const codeBytes = readFileSync(
      resolve(REPO_ROOT, "reference/ND-110-RASK.CODE"),
    );
    const reference = parseCodeBytes(codeBytes);

    const refAddrs = new Set(reference.keys());
    const lastUsedAddr = Math.max(...refAddrs);
    console.log(`Reference address range: 0 to 0o${lastUsedAddr.toString(8)} (${lastUsedAddr} decimal)`);
    console.log(`ROM address range: 0 to 0o${(rom.size - 1).toString(8)} (${rom.size - 1} decimal)`);
    console.log(`Reference entries: ${reference.size}`);
    console.log(`Addresses in ROM but not in .CODE: ${rom.size - reference.size}`);

    // Only compare addresses present in both.
    const diffs: { addr: number; rom: bigint; ref: bigint; diff: bigint }[] = [];
    for (const [addr, refValue] of reference) {
      const romValue = rom.get(addr);
      if (romValue !== undefined && romValue !== refValue) {
        diffs.push({ addr, rom: romValue, ref: refValue, diff: romValue ^ refValue });
      }
    }

    console.log(`\nDifferences: ${diffs.length}`);
    console.log(`Match rate: ${(((reference.size - diffs.length) * 100) / reference.size).toFixed(1)}%`);

    // Address range distribution.
    const bucketSize = 1024;
    const buckets = new Map<number, number>();
    for (const d of diffs) {
      const bucket = Math.floor(d.addr / bucketSize);
      buckets.set(bucket, (buckets.get(bucket) ?? 0) + 1);
    }
    console.log("\nDifferences by address bucket (1024 words each):");
    for (const [bucket, count] of [...buckets.entries()].sort((a, b) => a[0] - b[0])) {
      const startOct = (bucket * bucketSize).toString(8);
      const endOct = (bucket * bucketSize + bucketSize - 1).toString(8);
      console.log(`  0o${startOct.padStart(6, "0")} - 0o${endOct.padStart(6, "0")}: ${count} diffs`);
    }

    // Diff-bit histogram: which bits differ most often?
    const bitCounts = new Array<number>(64).fill(0);
    for (const d of diffs) {
      for (let b = 0; b < 64; b++) {
        if ((d.diff & (1n << BigInt(b))) !== 0n) bitCounts[b]++;
      }
    }
    console.log("\nBit-difference histogram (bits with >= 5 changes):");
    for (let b = 0; b < 64; b++) {
      if (bitCounts[b]! >= 5) {
        console.log(`  bit ${b.toString().padStart(2)}: ${bitCounts[b]} changes`);
      }
    }

    // Show first 10 and the MACL3 patch.
    console.log("\nFirst 5 diffs:");
    for (const d of diffs.slice(0, 5)) {
      console.log(
        `  0o${d.addr.toString(8).padStart(6, "0")}: ` +
        `rom=0x${d.rom.toString(16).padStart(16, "0")} ` +
        `ref=0x${d.ref.toString(16).padStart(16, "0")} ` +
        `diff=0x${d.diff.toString(16).padStart(16, "0")}`,
      );
    }
    const macl3 = diffs.find((d) => d.addr === 0o1754);
    if (macl3) {
      console.log(`\nMACL3 (0o1754) patch confirmed:`);
      console.log(
        `  rom=0x${macl3.rom.toString(16).padStart(16, "0")} ` +
        `ref=0x${macl3.ref.toString(16).padStart(16, "0")}`,
      );
    }
  });
});
