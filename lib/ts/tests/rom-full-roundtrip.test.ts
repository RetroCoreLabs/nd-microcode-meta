/**
 * Full-pipeline round-trip validation against real EPROM contents.
 *
 *   raw EPROMs -> combine -> disassemble -> re-assemble -> compare
 *
 * Unlike tests/roundtrip.test.ts (which uses the already-patched
 * ND-110-RASK.CODE file), this test starts from the physical ROM images
 * in microcode/roms/ and verifies the FULL toolchain on both supported
 * CPU types: ND-110 (factory 3095 card, 37948L+37949L) and ND-120
 * (AM27256_45132L+45133L).
 *
 * Both chip pairs are 32 KiB each (8192 4-byte microwords). The factory
 * ROMs contain both used and unused ("empty") slots. The test validates
 * bit-exact agreement on the non-empty slots.
 */

import { describe, it, expect } from "vitest";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import {
  combineRoms,
  detectForm,
  readMicrocodeVersion,
} from "../src/rom-combiner.js";
import { loadDefinitions } from "../src/yaml-loader.js";
import {
  compileDisassemblerPack,
  disassembleMap,
  TIMING_MASK,
} from "../src/disassembler.js";
import { formatProgram } from "../src/formatter.js";
import { assembleSource } from "../src/assembler.js";
import { ND110_XOR_MASK } from "../src/bitfield.js";
import type { Model } from "../src/types.js";

const REPO_ROOT = resolve(__dirname, "../../..");

function readRom(relPath: string): Uint8Array {
  return new Uint8Array(readFileSync(resolve(REPO_ROOT, relPath)));
}

function popcount(v: bigint): number {
  let c = 0;
  let x = v;
  while (x > 0n) {
    x &= x - 1n;
    c++;
  }
  return c;
}

/**
 * Run the full pipeline on a ROM pair and return statistics.
 *
 *   (highChip, lowChip) -> combine -> (per-model preprocessing) ->
 *       disassemble -> format -> assemble -> compare to input microcode
 */
function fullRoundtrip(
  highPath: string,
  lowPath: string,
  model: Model,
): {
  totalRecords: number;
  emptySlots: number;
  nonEmpty: number;
  bitExact: number;
  timingOnly: number;
  logicalDiff: number;
  sampleMismatches: { addr: number; orig: bigint; reasm: bigint; diff: bigint }[];
} {
  const high = readRom(highPath);
  const low = readRom(lowPath);
  const combined = combineRoms(high, low);

  // For ND-110, the combined ROM is in token form. Convert to canonical
  // for the disassembler. For ND-120 the combined form is already canonical.
  const canonical = new Map<number, bigint>();
  for (const [addr, value] of combined) {
    canonical.set(addr, model === "nd110" ? value ^ ND110_XOR_MASK : value);
  }

  // Skip "empty" slots (canonical 0) so we don't disassemble garbage
  // and produce spurious mismatches.
  const nonEmpty = new Map<number, bigint>();
  let emptySlots = 0;
  for (const [addr, value] of canonical) {
    if (value === 0n) {
      emptySlots++;
    } else {
      nonEmpty.set(addr, value);
    }
  }

  // Disassemble and re-assemble.
  const pack = compileDisassemblerPack(loadDefinitions(model));
  const instrs = disassembleMap(nonEmpty, pack);
  const source = formatProgram(instrs);
  const { binary, diagnostics } = assembleSource(source, pack.definitions, {
    model,
  });

  // Ignore unknown-token warnings (they may occur for unique ND-120
  // opcodes not yet in our table; we care about bit correctness here).
  const errors = diagnostics.filter((d) => d.severity === "error");
  if (errors.length > 0) {
    console.log(
      `  ${errors.length} assembly errors (first 5 shown):`,
    );
    for (const e of errors.slice(0, 5)) {
      console.log(`    line ${e.line} addr 0o${e.address?.toString(8) ?? "?"}: ${e.message}`);
    }
  }

  // Compare reassembled binary against the input (canonical) microcode.
  let bitExact = 0;
  let timingOnly = 0;
  let logicalDiff = 0;
  const sampleMismatches: { addr: number; orig: bigint; reasm: bigint; diff: bigint }[] = [];
  for (const [addr, origCanonical] of nonEmpty) {
    const reasmRaw = binary.get(addr) ?? 0n;
    // assembleSource emits ROM-storage form (XOR'd for nd110). Convert
    // back to canonical for comparison.
    const reasmCanonical =
      model === "nd110" ? reasmRaw ^ ND110_XOR_MASK : reasmRaw;
    if (origCanonical === reasmCanonical) {
      bitExact++;
    } else {
      const diff = origCanonical ^ reasmCanonical;
      if ((diff & ~TIMING_MASK) === 0n) {
        timingOnly++;
      } else {
        logicalDiff++;
        if (sampleMismatches.length < 10) {
          sampleMismatches.push({ addr, orig: origCanonical, reasm: reasmCanonical, diff });
        }
      }
    }
  }

  return {
    totalRecords: canonical.size,
    emptySlots,
    nonEmpty: nonEmpty.size,
    bitExact,
    timingOnly,
    logicalDiff,
    sampleMismatches,
  };
}

describe("full EPROM round-trip (authoritative end-to-end)", () => {
  it("ND-110 factory ROM: 37949L (high) + 37948L (low)", () => {
    const combined = combineRoms(
      readRom("external/meta/reference/roms/ND110/37949L.bin"),
      readRom("external/meta/reference/roms/ND110/37948L.bin"),
    );
    const form = detectForm(combined);
    const version = readMicrocodeVersion(combined);
    console.log(
      `\nND-110 3095 factory ROM: form=${form.form} (conf=${form.confidence.toFixed(2)}), ` +
      `version=${version?.letter} (${version?.octalValue})`,
    );
    expect(form.form).toBe("nd110");

    const r = fullRoundtrip(
      "external/meta/reference/roms/ND110/37949L.bin",
      "external/meta/reference/roms/ND110/37948L.bin",
      "nd110",
    );
    console.log(
      `  non-empty: ${r.nonEmpty}/${r.totalRecords} ` +
      `(${r.emptySlots} empty canonical slots skipped)\n` +
      `  bit-exact:       ${r.bitExact}/${r.nonEmpty} ` +
      `(${((100 * r.bitExact) / r.nonEmpty).toFixed(1)}%)\n` +
      `  timing-only:     ${r.timingOnly}\n` +
      `  logical-diff:    ${r.logicalDiff}`,
    );
    if (r.sampleMismatches.length > 0) {
      console.log(`  First ${Math.min(5, r.sampleMismatches.length)} mismatches:`);
      for (const m of r.sampleMismatches.slice(0, 5)) {
        console.log(
          `    0o${m.addr.toString(8).padStart(6, "0")}: ` +
          `orig=0x${m.orig.toString(16).padStart(16, "0")} ` +
          `reasm=0x${m.reasm.toString(16).padStart(16, "0")} ` +
          `diff=0x${m.diff.toString(16).padStart(16, "0")} (${popcount(m.diff)} bits)`,
        );
      }
    }

    // Acceptance criterion: zero logical differences. Timing-bit-only
    // differences are allowed but currently expected to be 0 too.
    expect(r.logicalDiff).toBe(0);
  });

  it("ND-120 EPROM: AM27256_45133L (high) + AM27256_45132L (low)", () => {
    const combined = combineRoms(
      readRom("external/meta/reference/roms/ND120/AM27256_45133L.bin"),
      readRom("external/meta/reference/roms/ND120/AM27256_45132L.bin"),
    );
    const form = detectForm(combined);
    const version = readMicrocodeVersion(combined);
    console.log(
      `\nND-120 AM27256 ROM: form=${form.form} (conf=${form.confidence.toFixed(2)}), ` +
      `version=${version?.letter} (${version?.octalValue})`,
    );
    expect(form.form).toBe("nd120");

    const r = fullRoundtrip(
      "external/meta/reference/roms/ND120/AM27256_45133L.bin",
      "external/meta/reference/roms/ND120/AM27256_45132L.bin",
      "nd120",
    );
    console.log(
      `  non-empty: ${r.nonEmpty}/${r.totalRecords} ` +
      `(${r.emptySlots} empty canonical slots skipped)\n` +
      `  bit-exact:       ${r.bitExact}/${r.nonEmpty} ` +
      `(${((100 * r.bitExact) / r.nonEmpty).toFixed(1)}%)\n` +
      `  timing-only:     ${r.timingOnly}\n` +
      `  logical-diff:    ${r.logicalDiff}`,
    );
    if (r.sampleMismatches.length > 0) {
      console.log(`  First ${Math.min(5, r.sampleMismatches.length)} mismatches:`);
      for (const m of r.sampleMismatches.slice(0, 5)) {
        console.log(
          `    0o${m.addr.toString(8).padStart(6, "0")}: ` +
          `orig=0x${m.orig.toString(16).padStart(16, "0")} ` +
          `reasm=0x${m.reasm.toString(16).padStart(16, "0")} ` +
          `diff=0x${m.diff.toString(16).padStart(16, "0")} (${popcount(m.diff)} bits)`,
        );
      }
    }

    // ND-120 must be 100% bit-exact including timing bits.
    expect(r.logicalDiff).toBe(0);
    expect(r.timingOnly).toBe(0);
    expect(r.bitExact).toBe(r.nonEmpty);
  });
});
