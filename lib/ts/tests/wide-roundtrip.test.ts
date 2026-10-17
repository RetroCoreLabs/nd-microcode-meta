/**
 * NORD-10, ND-500 and ND-5000: real images, disassemble -> format ->
 * assemble round trips, and assembling the sources that must give the
 * images. All files are under reference/ in this repo.
 */

import { describe, it, expect } from "vitest";
import { readFileSync, readdirSync } from "node:fs";
import { resolve } from "node:path";

import {
  assembleWide,
  disassembleWide,
  formatProgramWide,
  loadWideDefinitions,
  parseLabeBytes,
  readBe16x8,
  readPacked18,
  readPromHex,
  writePromHex,
} from "../src/index.js";

const REPO_ROOT = resolve(__dirname, "../../..");
const ref = (p: string): string => resolve(REPO_ROOT, "reference", p);

function errorsOf(r: { diagnostics: { severity: string; message: string }[] }): string[] {
  return r.diagnostics.filter((d) => d.severity === "error").map((d) => d.message);
}

describe("NORD-10 real PROM dumps", () => {
  const pack = loadWideDefinitions("nd10");
  const dumps: Array<[string, string, string, number]> = [
    ["1k", "nord10/NORD-10-1K-prom.hex", "nord10/NORD-10.uc", 1024],
    ["CE 4k", "nord10/NORD-10-CE-4K-prom4k.hex", "nord10/NORD-10-CE.uc", 4096],
  ];

  for (const [name, hexFile, ucFile, count] of dumps) {
    const text = readFileSync(ref(hexFile), "utf8");
    const rom = readPromHex(text);

    it(`${name}: ${count} words disassemble and reassemble bit for bit`, () => {
      expect(rom.length).toBe(count);
      const src = formatProgramWide(
        pack,
        rom.map((w) => BigInt(w)),
        { header: hexFile },
      );
      const r = assembleWide(src, pack);
      expect(errorsOf(r)).toEqual([]);
      expect(r.romWords).toEqual(rom);
      console.log(`NORD-10 ${name}: words=${rom.length} mismatches=0`);
    });

    it(`${name}: ${ucFile} assembles to the dump and writePromHex gives the same text`, () => {
      const r = assembleWide(readFileSync(ref(ucFile), "utf8"), pack);
      expect(errorsOf(r)).toEqual([]);
      expect(r.romWords).toEqual(rom);
      expect(writePromHex(r.romWords!)).toBe(text);
    });
  }
});

describe("ND-500 CONT-STORE-10611", () => {
  const pack = loadWideDefinitions("nd500");
  const image = new Uint8Array(readFileSync(ref("nd500/CONT-STORE-10611.DATA")));

  it("147456 bytes, 8192 words: disassemble, assemble, 0 byte differences", () => {
    expect(image.length).toBe(147456);
    const words = readPacked18(image);
    expect(words.length).toBe(8192);
    const src = formatProgramWide(pack, words, { header: "CONT-STORE-10611.DATA" });
    const r = assembleWide(src, pack, { stampDate: false });
    expect(errorsOf(r)).toEqual([]);
    expect(r.image.length).toBe(image.length);
    let diffs = 0;
    for (let i = 0; i < image.length; i++) if (r.image[i] !== image[i]) diffs++;
    console.log(`ND-500 CONT-STORE-10611: words=8192 byte differences=${diffs}`);
    expect(diffs).toBe(0);
  });

  it("CONT-STORE-10611.uc assembles to the DATA image", () => {
    const r = assembleWide(readFileSync(ref("nd500/CONT-STORE-10611.uc"), "utf8"), pack, {
      stampDate: false,
    });
    expect(errorsOf(r)).toEqual([]);
    expect(Buffer.compare(Buffer.from(r.image), Buffer.from(image))).toBe(0);
  });
});

describe("ND-5000 control store images", () => {
  const pack = loadWideDefinitions("nd5000");
  const dir = ref("nd5000");
  const dataFiles = readdirSync(dir).filter((f) => f.endsWith(".DATA")).sort();

  it("there are 13 images", () => {
    expect(dataFiles.length).toBe(13);
  });

  for (const f of dataFiles) {
    it(`${f}: 16384 words, disassemble, assemble, 0 byte differences`, () => {
      const image = new Uint8Array(readFileSync(resolve(dir, f)));
      expect(image.length).toBe(262144);
      const words = readBe16x8(image);
      const src = formatProgramWide(pack, words, { header: f });
      const r = assembleWide(src, pack);
      expect(errorsOf(r)).toEqual([]);
      expect(r.image.length).toBe(image.length);
      let diffs = 0;
      for (let i = 0; i < image.length; i++) if (r.image[i] !== image[i]) diffs++;
      console.log(`ND-5000 ${f}: words=16384 mismatches=${diffs}`);
      expect(diffs).toBe(0);
    });
  }

  it("label names from a .LABE file keep the reassembled image identical", () => {
    const image = new Uint8Array(readFileSync(resolve(dir, "MICRO-5800-A29.DATA")));
    const labels = parseLabeBytes(new Uint8Array(readFileSync(resolve(dir, "MICRO-5800-A29.LABE"))));
    expect(labels.nameToAddr.size).toBeGreaterThan(100);
    const src = formatProgramWide(pack, readBe16x8(image), { labels });
    expect(src).toMatch(/\/ [A-Za-z][A-Za-z0-9_.$]*: /);
    const r = assembleWide(src, pack);
    expect(errorsOf(r)).toEqual([]);
    expect(Buffer.compare(Buffer.from(r.image), Buffer.from(image))).toBe(0);
  });
});

describe("disassembly of single words", () => {
  it("an all-zero ND-500 or ND-5000 word has no items", () => {
    expect(disassembleWide(loadWideDefinitions("nd500"), 0n)).toEqual([]);
    expect(disassembleWide(loadWideDefinitions("nd5000"), 0n)).toEqual([]);
  });
});
