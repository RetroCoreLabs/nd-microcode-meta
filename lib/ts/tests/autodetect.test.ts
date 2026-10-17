/**
 * The variant guess (detectModel) on the real sources in reference/ and on
 * the extension's sample.uc-like text.
 */

import { describe, it, expect } from "vitest";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

import {
  detectModel,
  formatProgramWide,
  loadDefinitions,
  loadWideDefinitions,
  readBe16x8,
  type AnyModel,
  type TokenNameSets,
} from "../src/index.js";

const REPO_ROOT = resolve(__dirname, "../../..");
const ref = (p: string): string => resolve(REPO_ROOT, "reference", p);

const names: TokenNameSets = {};
for (const m of ["nd100", "nd110", "nd120"] as const) {
  names[m] = new Set(loadDefinitions(m).tokens.map((t) => t.name));
}
for (const m of ["nd10", "nd500", "nd5000"] as const) {
  names[m] = new Set(loadWideDefinitions(m).tokens.map((t) => t.name));
}

function check(label: string, source: string, expected: AnyModel[]): void {
  const r = detectModel(source, names);
  const line = r.scores.map((s) => `${s.model}=${s.score.toFixed(2)}`).join(" ");
  console.log(`${label}: model=${r.model ?? "-"} candidates=${r.candidates.join("|")} items=${r.items} ${line}`);
  expect(expected).toContain(r.candidates.length === 1 ? r.candidates[0] : (r.model ?? r.candidates[0]));
  for (const c of r.candidates) expect(expected).toContain(c);
}

describe("detectModel on the real sources", () => {
  it("NORD-10.uc and NORD-10-CE.uc are nd10", () => {
    check("NORD-10.uc", readFileSync(ref("nord10/NORD-10.uc"), "utf8"), ["nd10"]);
    check("NORD-10-CE.uc", readFileSync(ref("nord10/NORD-10-CE.uc"), "utf8"), ["nd10"]);
  });

  it("CONT-STORE-10611.uc and ND-500-EXAMPLE.uc are nd500", () => {
    check("CONT-STORE-10611.uc", readFileSync(ref("nd500/CONT-STORE-10611.uc"), "utf8"), ["nd500"]);
    check("ND-500-EXAMPLE.uc", readFileSync(ref("nd500/ND-500-EXAMPLE.uc"), "utf8"), ["nd500"]);
  });

  it("a disassembled ND-5000 image is nd5000", () => {
    const pack = loadWideDefinitions("nd5000");
    const words = readBe16x8(new Uint8Array(readFileSync(ref("nd5000/MICRO-5800-A29.DATA"))));
    check("ND-5000 disassembly", formatProgramWide(pack, words), ["nd5000"]);
  });

  it("ND-110-RASK.uc is nd110 (or open between nd110 and nd120)", () => {
    check("ND-110-RASK.uc", readFileSync(ref("ND-110-RASK.uc"), "utf8"), ["nd110", "nd120"]);
  });

  it("ND-120-DELILAH-K.uc and -L.uc are nd120 (or open between nd110 and nd120)", () => {
    check("DELILAH-K", readFileSync(ref("nd120/ND-120-DELILAH-K.uc"), "utf8"), ["nd110", "nd120"]);
    check("DELILAH-L", readFileSync(ref("nd120/ND-120-DELILAH-L.uc"), "utf8"), ["nd110", "nd120"]);
  });

  it("empty text and plain comments decide nothing", () => {
    expect(detectModel("", names).model).toBeUndefined();
    expect(detectModel("% only a comment\n", names).model).toBeUndefined();
  });
});
