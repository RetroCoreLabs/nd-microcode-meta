/**
 * Diagnostic "test" that surveys which tokens set which bits in the
 * 20-27 control/timing region. Prints a report that backs the
 * documentation in docs/special-bits.md.
 *
 * Run explicitly with:
 *   npx vitest run tests/bit-survey.test.ts
 */

import { describe, it } from "vitest";
import { loadDefinitions } from "../src/yaml-loader.js";

describe("bit survey (diagnostic)", () => {
  it("groups tokens by bits 20-27", () => {
    const pack = loadDefinitions("nd110");
    const byBit = new Map<number, string[]>();
    for (let b = 20; b <= 27; b++) byBit.set(b, []);

    const perCategory = new Map<string, Map<number, number>>();

    for (const tok of pack.tokens) {
      for (let b = 20; b <= 27; b++) {
        if ((tok.encodingValue & (1n << BigInt(b))) !== 0n) {
          byBit.get(b)!.push(tok.name);
          const cat = tok.category;
          if (!perCategory.has(cat)) perCategory.set(cat, new Map());
          const bm = perCategory.get(cat)!;
          bm.set(b, (bm.get(b) ?? 0) + 1);
        }
      }
    }

    for (const b of [20, 21, 22, 23, 24, 25, 26, 27]) {
      const tokens = byBit.get(b)!;
      console.log(`Bit ${b}: ${tokens.length} tokens`);
    }

    console.log("\nPer-category bit counts:");
    for (const [cat, bits] of perCategory) {
      const line: string[] = [];
      for (const b of [20, 21, 22, 23, 24, 25, 26, 27]) {
        if (bits.has(b)) line.push(`bit${b}=${bits.get(b)}`);
      }
      if (line.length > 0) console.log(`  ${cat.padEnd(10)} ${line.join(" ")}`);
    }
  });
});
