/**
 * Source-to-binary validation.
 *
 * Assembles the original ND-110-RASK.uc source and compares the output
 * with the authoritative ND-110-RASK.CODE binary. This proves the
 * assembler produces exactly the same bits as the reference C#
 * implementation.
 */

import { describe, it, expect } from "vitest";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { loadDefinitions } from "../src/yaml-loader.js";
import { parseCodeFile } from "../src/bitfield.js";
import { assembleSource } from "../src/assembler.js";

const REPO_ROOT = resolve(__dirname, "../../..");

function popcount(v: bigint): number {
  let c = 0;
  let x = v;
  while (x > 0n) {
    x &= x - 1n;
    c++;
  }
  return c;
}

describe("RASK source -> binary validation", () => {
  it("assembles ND-110-RASK.uc to the reference ND-110-RASK.CODE", () => {
    const pack = loadDefinitions("nd110");
    const source = readFileSync(
      resolve(REPO_ROOT, "reference/ND-110-RASK.uc"),
      "utf8",
    );

    const { binary, sourceMap, diagnostics } = assembleSource(source, pack, {
      model: "nd110",
    });

    // Report any unknown-token errors up front.
    const errors = diagnostics.filter((d) => d.severity === "error");
    if (errors.length > 0) {
      console.log(`First 20 assembly errors (of ${errors.length}):`);
      for (const e of errors.slice(0, 20)) {
        console.log(
          `  line ${e.line} addr 0o${e.address?.toString(8) ?? "?"}: ${e.message}`,
        );
      }
    }

    console.log(`Instructions parsed: ${sourceMap.instructions.length}`);
    console.log(`Labels collected:    ${sourceMap.labels.size}`);
    console.log(`Binary records:      ${binary.size}`);

    // Load the reference .CODE file (in ROM storage form, so no XOR flip).
    const reference = parseCodeFile(
      resolve(REPO_ROOT, "reference/ND-110-RASK.CODE"),
      { nd110XorFlip: false },
    );

    console.log(`Reference records:   ${reference.size}`);

    // Compare.
    let bitExact = 0;
    let mismatches: { addr: number; ours: bigint; ref: bigint; diff: bigint }[] = [];
    let missing = 0;
    for (const [addr, ourValue] of binary) {
      const refValue = reference.get(addr);
      if (refValue === undefined) {
        missing++;
        continue;
      }
      if (ourValue === refValue) {
        bitExact++;
      } else {
        mismatches.push({
          addr,
          ours: ourValue,
          ref: refValue,
          diff: ourValue ^ refValue,
        });
      }
    }

    console.log(`Bit-exact matches:   ${bitExact}/${binary.size}`);
    console.log(`Mismatches:          ${mismatches.length}`);
    console.log(`Missing in reference: ${missing}`);

    if (mismatches.length > 0) {
      console.log("First 10 mismatches:");
      for (const m of mismatches.slice(0, 10)) {
        console.log(
          `  0o${m.addr.toString(8).padStart(6, "0")}: ` +
          `ours=0x${m.ours.toString(16).padStart(16, "0")} ` +
          `ref=0x${m.ref.toString(16).padStart(16, "0")} ` +
          `diff=0x${m.diff.toString(16).padStart(16, "0")} (${popcount(m.diff)} bits)`,
        );
      }
    }

    expect(errors).toEqual([]);
    expect(binary.size).toBe(reference.size);
    expect(mismatches.length).toBe(0);
  });
});
