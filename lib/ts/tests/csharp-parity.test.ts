/**
 * The TypeScript assemblers must give the same bytes as the C# compiler
 * (project ND110Compile) on the same sources. The C# output files were copied
 * to reference/ (see reference/README.md for the SHA-1 values).
 */

import { describe, it, expect } from "vitest";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

import {
  assembleSource,
  assembleWide,
  recordsToCodeBytes,
  loadDefinitions,
  loadWideDefinitions,
} from "../src/index.js";

const REPO_ROOT = resolve(__dirname, "../../..");
const ref = (p: string): string => resolve(REPO_ROOT, "reference", p);
const text = (p: string): string => readFileSync(ref(p), "utf8");
const bytes = (p: string): Buffer => readFileSync(ref(p));

function firstDifference(a: Uint8Array, b: Uint8Array): number {
  const n = Math.min(a.length, b.length);
  for (let i = 0; i < n; i++) if (a[i] !== b[i]) return i;
  return a.length === b.length ? -1 : n;
}

describe("C# parity", () => {
  it("ND-500 CONT-STORE-10611.uc -> CONT-STORE-10611.CODE (date stamp on, as the C# run)", () => {
    const pack = loadWideDefinitions("nd500");
    const r = assembleWide(text("nd500/CONT-STORE-10611.uc"), pack);
    expect(r.errorCount).toBe(0);
    const want = bytes("nd500/CONT-STORE-10611.CODE");
    expect(r.image.length).toBe(want.length);
    expect(firstDifference(r.image, want)).toBe(-1);
  });

  it("ND-500-EXAMPLE.uc assembles without errors (no C# output file to compare)", () => {
    const pack = loadWideDefinitions("nd500");
    const r = assembleWide(text("nd500/ND-500-EXAMPLE.uc"), pack, { stampDate: false });
    expect(r.errorCount).toBe(0);
    expect(r.words.size).toBeGreaterThan(0);
  });

  it("ND-120 DELILAH-K.uc (nd120) -> DELILAH-K.CODE", () => {
    const pack = loadDefinitions("nd120");
    const r = assembleSource(text("nd120/ND-120-DELILAH-K.uc"), pack, { model: "nd120" });
    const got = recordsToCodeBytes(r.records);
    const want = bytes("nd120/ND-120-DELILAH-K.CODE");
    console.log(`DELILAH-K: ${got.length} bytes, wanted ${want.length}, first difference ${firstDifference(got, want)}`);
    expect(firstDifference(got, want)).toBe(-1);
  });

  it("ND-120 DELILAH-L.uc (nd120-dly) -> DELILAH-L.CODE", () => {
    const pack = loadDefinitions("nd120-dly");
    const r = assembleSource(text("nd120/ND-120-DELILAH-L.uc"), pack, { model: "nd120-dly" });
    const got = recordsToCodeBytes(r.records);
    const want = bytes("nd120/ND-120-DELILAH-L.CODE");
    console.log(`DELILAH-L: ${got.length} bytes, wanted ${want.length}, first difference ${firstDifference(got, want)}`);
    expect(firstDifference(got, want)).toBe(-1);
  });

  it("DELILAH-L.uc with the plain nd120 table does NOT give the L output (DLY1 bit set)", () => {
    const pack = loadDefinitions("nd120");
    const r = assembleSource(text("nd120/ND-120-DELILAH-L.uc"), pack, { model: "nd120" });
    const got = recordsToCodeBytes(r.records);
    expect(firstDifference(got, bytes("nd120/ND-120-DELILAH-L.CODE"))).not.toBe(-1);
  });

  it("nd120-dly differs from nd120 in exactly B,P / B,B / B,X (w2 000002, 000003, 000007)", () => {
    const k = loadDefinitions("nd120");
    const l = loadDefinitions("nd120-dly");
    expect(l.model).toBe("nd120-dly");
    expect(l.tokens.length).toBe(k.tokens.length);
    const changed = l.tokens.filter((t, i) => t.encodingValue !== k.tokens[i].encodingValue);
    expect(changed.map((t) => `${t.name}:${t.encodingOctal[2]}`)).toEqual([
      "B,P:000002",
      "B,B:000003",
      "B,X:000007",
    ]);
  });
});
