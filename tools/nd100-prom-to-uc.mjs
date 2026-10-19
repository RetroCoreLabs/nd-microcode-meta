#!/usr/bin/env node
/**
 * Recover an ND-100 micro code source (.uc) from the PROM chip dumps.
 *
 * This tool makes the plain decoding of the PROM chips. (The printed Norsk Data listing, with
 * the original labels and comments, was typed back from the scan into the .uc files of the
 * NDMicroAsm repository, microcode/ND-100/*.uc; this tool makes the files in its DISASSEMBLY
 * folder, which have no original names.) It reads the 82S185 chips of reference/roms/ND100/<variant>, combines them into 64-bit words, flips
 * bits 22-27 back to the canonical (active high) form (ND-06.018.01, "Writing the
 * Microprogram": "bits 22 - 27 are inverted after the word is assembled"), disassembles
 * every word with the ND-100 disassembler of lib/ts and writes the text. The text
 * assembles back to the same words (see the validation in the NDMicroAsm repository).
 *
 * Usage (from the root of this repository, after `npm run build` in lib/ts):
 *
 *   node tools/nd100-prom-to-uc.mjs --variant 3033S --out <file.uc> [--symbols <file.SYMBOLS.TXT> ...]
 *   node tools/nd100-prom-to-uc.mjs --variant 3033E-CX --out <file.uc> [--symbols ...]
 *
 * --symbols gives address=label lines (octal address, one per line); the label is used in
 * jumps and defined in front of its instruction. 3033E-CX writes both banks, the extension
 * bank at 0o4000 and up.
 */

import { readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "..");
const lib = await import(resolve(root, "lib/ts/dist/index.js"));

function arg(name, all = false) {
  const out = [];
  for (let i = 2; i < process.argv.length; i++) {
    if (process.argv[i] === name && i + 1 < process.argv.length) out.push(process.argv[++i]);
  }
  return all ? out : out[0];
}

const variant = arg("--variant");
const outFile = arg("--out");
if ((variant !== "3033S" && variant !== "3033E-CX") || !outFile) {
  console.error("usage: node tools/nd100-prom-to-uc.mjs --variant 3033S|3033E-CX --out <file.uc> [--symbols <file> ...]");
  process.exit(1);
}

const chips = resolve(root, "reference/roms/ND100", variant);
const promWords = new Map(lib.loadNd100Proms(chips, variant, "microcode"));
if (variant === "3033E-CX") {
  for (const [a, w] of lib.loadNd100Proms(chips, variant, "microcode_ext")) promWords.set(a, w);
}

// PROM form -> canonical form (bits 22-27 are inverted in the PROM).
const canonical = new Map();
for (const [a, w] of promWords) canonical.set(a, w ^ lib.ND100_XOR_MASK);

const symbols = new Map();
for (const f of arg("--symbols", true)) {
  for (const [a, n] of lib.parseSymbolsText(readFileSync(f, "utf8"))) symbols.set(a, n);
}

const pack = lib.loadDefinitions("nd100");
const instrs = lib.disassembleMap(canonical, lib.compileDisassemblerPack(pack), symbols.size ? symbols : undefined);
const body = lib.formatProgram(instrs, { model: "nd100" });

const head = [
  "%#MODEL nd100",
  `% ND-100 ${variant} micro code, decoded from the PROM chips in reference/roms/ND100/${variant}.`,
  "% This is the plain disassembly of the factory PROMs by tools/nd100-prom-to-uc.mjs, in the",
  "% mnemonics of ND-06.018.01, with no original names or comments. The source with the names",
  "% and comments of the printed Norsk Data listing is ND-100-<variant>.uc in the folder above.",
  `% Words: ${canonical.size}. Assembled with nd100-asm the words come back bit for bit.`,
  symbols.size ? "% Labels are the macro instruction entry points from the decode PLA (L<octal address>)." : "%",
  "%",
  "",
].join("\n");

writeFileSync(outFile, head + body + "\n", "utf8");
console.log(`wrote ${outFile}: ${canonical.size} words`);
