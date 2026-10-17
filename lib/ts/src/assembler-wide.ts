/**
 * Assemblers for the wide-word models: ND-500 (144 bits), ND-5000 (128 bits)
 * and NORD-10 (32 bits).
 *
 * Direct ports of the C# classes ND500Compiler.cs, ND5000Compiler.cs and
 * ND10Compiler.cs (project ND110Compile). Rules and error texts are kept as
 * they are in C# so the output is the same byte for byte. The ND-1x0
 * assembler in assembler.ts is not touched.
 *
 * ND-500 / ND-5000 source:
 *   - '%' starts a comment; '#' at line start or after a space/tab too
 *     ('#' inside a token is a register select, e.g. A,AL#17)
 *   - 'nnnn/' at the start of an instruction sets the address
 *   - 'NAME:' at the start of an instruction defines a label
 *   - ';' ends an instruction, an instruction may span several lines
 *   - mnemonic, FIELDNAME=octal, 'n,n' long argument, label, short argument
 *   - overlapping bits and writing an address twice are errors
 *
 * NORD-10 source (MICMAC dialect): one instruction per line, '%' comment,
 * 'nnnn:' or four octal digits set the address, 'NAME,' defines a label,
 * a bare octal number is ORed in, '*n' is relative, 'NAME+n' label offset.
 */

import type { WideModel } from "./types.js";
import type { WidePack } from "./wide-defs.js";
import { writePartsImage } from "./binary-formats.js";
import { octal } from "./word.js";

/** A message from the assembler. */
export interface WideDiagnostic {
  severity: "error" | "warning" | "info";
  /** 1-based source line, 0 when the message belongs to no line. */
  line: number;
  address?: number;
  message: string;
}

/** One assembled instruction, in source order. */
export interface WideInstruction {
  address: number;
  /** First and last source line (the same for NORD-10). */
  startLine: number;
  endLine: number;
  /** The items of the instruction as written (mnemonics, numbers, labels). */
  items: string[];
}

export interface WideLabel {
  name: string;
  address: number;
  line: number;
}

export interface WideAssembleOptions {
  /**
   * nd500 only: put the assembly date in word 0 bits 15-0 when the code left
   * them zero (default true, as the C# compiler does). Use false for
   * bit-exact comparison with an existing image.
   */
  stampDate?: boolean;
  /** Date used for the stamp (default: now). */
  date?: Date;
  /**
   * nd500 / nd5000: write the full control store (default true). When false
   * the image ends after the highest address used.
   */
  writeFullControlStore?: boolean;
}

export interface WideAssemblyResult {
  model: WideModel;
  /** Address -> word, for every address that was written. */
  words: Map<number, bigint>;
  /**
   * nd500 / nd5000: the image in the native format (packed18 / be16x8).
   * nd10: the .CODE image, 32-bit big-endian words (1024 or 4096 words).
   */
  image: Uint8Array;
  /** nd10 only: the ROM words (1024 or 4096). */
  romWords?: number[];
  labels: WideLabel[];
  /** Every instruction found in the source, also those with errors. */
  instructions: WideInstruction[];
  diagnostics: WideDiagnostic[];
  errorCount: number;
}

/** Octal number as the ND-500 / ND-5000 assembler reads it, or -1. */
export function parseOctalGeneric(text: string): number {
  let value = text.trim();
  if (value.length === 0) return -1;
  if (value.endsWith("B") || value.endsWith("b")) {
    value = value.slice(0, -1);
    if (value.length === 0) return -1;
  }
  if (!/^[0-7]+$/.test(value)) return -1;
  const n = parseInt(value, 8);
  // C# Convert.ToInt32 gives a negative number above 0x7FFFFFFF: not a number here.
  return n > 0x7fffffff ? -1 : n;
}

/** '%' always starts a comment; '#' at line start or after space/tab does too. */
export function stripCommentGeneric(line: string): string {
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (c === "%") return line.slice(0, i);
    if (c === "#" && (i === 0 || line[i - 1] === " " || line[i - 1] === "\t")) {
      return line.slice(0, i);
    }
  }
  return line;
}

interface GenericInstruction {
  /** Line that holds the ';' (as in the C# compiler). */
  line: number;
  /** First line of the instruction. */
  startLine: number;
  address: number;
  raw: string;
}

function isLabelName(label: string): boolean {
  return label.length > 0 && /^[A-Za-z]/.test(label);
}

/** Port of ND500Compiler.Preprocess (same code in ND5000Compiler). */
export function preprocessGeneric(source: string): {
  instructions: GenericInstruction[];
  labels: WideLabel[];
} {
  const instructions: GenericInstruction[] = [];
  const labels: WideLabel[] = [];
  const lines = source.replace(/\r/g, "").split("\n");
  let ucAddress = 0;
  let ucLine = "";
  let startLine = 1;
  let lineNo = 1;

  for (const current of lines) {
    let line = stripCommentGeneric(current).trim();
    line = line.split(" ,").join(",");
    line = line.split(", ").join(",");

    const startOfInstruction = ucLine.trim().length === 0;

    if (startOfInstruction) {
      const idxSlash = line.indexOf("/");
      if (idxSlash > 0) {
        const adr = parseOctalGeneric(line.slice(0, idxSlash).trim());
        if (adr >= 0) {
          ucAddress = adr;
          line = line.slice(idxSlash + 1).trim();
        }
      }
    }

    const idxColon = line.indexOf(":");
    if (idxColon > 0 && idxColon < 30 && startOfInstruction) {
      const label = line.slice(0, idxColon).trim();
      if (isLabelName(label)) {
        labels.push({ name: label, address: ucAddress, line: lineNo });
        line = line.slice(idxColon + 1).trim();
      }
    }

    if (ucLine.trim().length === 0) startLine = lineNo;
    ucLine = ucLine + " " + line;

    if (ucLine.indexOf(";") > 0) {
      ucLine = ucLine.split(";").join("");
      instructions.push({ line: lineNo, startLine, address: ucAddress, raw: ucLine });
      ucAddress++;
      ucLine = "";
    }
    lineNo++;
  }
  return { instructions, labels };
}

interface GenericConfig {
  partCount: number;
  storeWords: number;
  addressMask: number;
  /** ND-500 error text names the part ("overlaps in CS8"), ND-5000 does not. */
  overlapNamesPart: boolean;
  stampDate: boolean;
}

function partOf(word: bigint, partCount: number, index: number): number {
  return Number((word >> BigInt(16 * (partCount - 1 - index))) & 0xffffn);
}

function assembleGeneric(
  source: string,
  pack: WidePack,
  options: WideAssembleOptions,
): WideAssemblyResult {
  const model = pack.model;
  const cfg: GenericConfig =
    model === "nd500"
      ? { partCount: 9, storeWords: 8192, addressMask: 0x1fff, overlapNamesPart: true, stampDate: options.stampDate ?? true }
      : { partCount: 8, storeWords: 16384, addressMask: 0xffff, overlapNamesPart: false, stampDate: false };
  if (pack.partCount !== cfg.partCount) {
    throw new Error(`${model}: pack has ${pack.partCount} parts, expected ${cfg.partCount}`);
  }
  const shortPart = cfg.partCount - 1; // bits 15-0
  const longPart = cfg.partCount - 2; // bits 31-16

  const diagnostics: WideDiagnostic[] = [];
  let errorCount = 0;
  const error = (line: number, message: string, address?: number): void => {
    errorCount++;
    diagnostics.push({ severity: "error", line, address, message });
  };

  const map = preprocessGeneric(source);
  const labelAddress = new Map<string, number>();
  for (const l of map.labels) {
    if (!labelAddress.has(l.name)) labelAddress.set(l.name, l.address); // first definition wins
  }

  const store: bigint[] = new Array(cfg.storeWords).fill(0n);
  const written: boolean[] = new Array(cfg.storeWords).fill(false);
  let highest = -1;
  const found: WideInstruction[] = [];

  for (const instr of map.instructions) {
    found.push({
      address: instr.address,
      startLine: instr.startLine,
      endLine: instr.line,
      items: instr.raw.split(" ").map((x) => x.trim()).filter((x) => x.length > 0),
    });
    if (instr.address >= cfg.storeWords) {
      error(
        instr.line,
        `Current location counter is at upper limit: ${octal(instr.address, 6)}, line ${instr.line}`,
        instr.address,
      );
      continue;
    }
    if (written[instr.address]) {
      error(
        instr.line,
        `Attempt to write on former entry: ${octal(instr.address, 6)}, line ${instr.line}`,
        instr.address,
      );
      continue;
    }

    const at = octal(instr.address, 6);
    const where = `at ${at}, line ${instr.line}`;
    let word = 0n;

    const overlapMessage = (tok: string, part: number, argument: boolean): string => {
      const what = argument ? `argument ${tok}` : tok;
      return cfg.overlapNamesPart
        ? `OR-ing rejected due to overlapping of MNE-values: ${what} overlaps in CS${8 - part} ${where}`
        : `OR-ing rejected due to overlapping of MNE-values: ${what} overlaps ${where}`;
    };
    // OR a contribution into the word; one error per part that overlaps.
    const orBits = (contribution: bigint, tok: string, argument: boolean): void => {
      for (let i = 0; i < cfg.partCount; i++) {
        if ((partOf(word, cfg.partCount, i) & partOf(contribution, cfg.partCount, i)) !== 0) {
          error(instr.line, overlapMessage(tok, i, argument), instr.address);
        }
      }
      word |= contribution;
    };
    const orArgument = (part: number, value: number, tok: string): void => {
      if ((partOf(word, cfg.partCount, part) & value) !== 0) {
        error(instr.line, overlapMessage(tok, part, true), instr.address);
      }
      word |= BigInt(value) << BigInt(16 * (cfg.partCount - 1 - part));
    };

    for (const tok of instr.raw.split(" ").map((s) => s.trim()).filter((s) => s.length > 0)) {
      const token = pack.tokensByName.get(tok);
      if (token) {
        orBits(token.value, tok, false);
        continue;
      }

      const idxEquals = tok.indexOf("=");
      if (idxEquals > 0) {
        const fieldName = tok.slice(0, idxEquals);
        const field = pack.fieldsByName.get(fieldName);
        if (field) {
          const fieldValue = parseOctalGeneric(tok.slice(idxEquals + 1));
          if (fieldValue < 0) {
            error(instr.line, `Bad octal value in field assignment: ${tok} ${where}`, instr.address);
            continue;
          }
          const width = field.high - field.low + 1;
          if (BigInt(fieldValue) > (1n << BigInt(width)) - 1n) {
            error(instr.line, `Transform overflow: ${tok} does not fit ${width}-bit field ${where}`, instr.address);
            continue;
          }
          orBits(BigInt(fieldValue) << BigInt(field.low), tok, false);
          continue;
        }
        error(instr.line, `Unknown field name: ${tok} ${where}`, instr.address);
        continue;
      }

      const idxComma = tok.indexOf(",");
      if (idxComma > 0) {
        const hi = parseOctalGeneric(tok.slice(0, idxComma));
        const lo = parseOctalGeneric(tok.slice(idxComma + 1));
        if (hi >= 0 && lo >= 0) {
          if (hi > 0xffff || lo > 0xffff) {
            error(instr.line, `Transform overflow: long argument ${tok} ${where}`, instr.address);
            continue;
          }
          orArgument(longPart, hi, tok);
          orArgument(shortPart, lo, tok);
          continue;
        }
      }

      const lbl = labelAddress.get(tok);
      if (lbl !== undefined) {
        orArgument(longPart, lbl & cfg.addressMask, tok);
        continue;
      }

      const numeric = parseOctalGeneric(tok);
      if (numeric >= 0) {
        if (numeric > 0xffff) {
          error(instr.line, `Transform overflow: ${tok} ${where}`, instr.address);
          continue;
        }
        orArgument(shortPart, numeric, tok);
        continue;
      }

      error(instr.line, `Unknown token: ${tok} ${where}`, instr.address);
    }

    store[instr.address] = word;
    written[instr.address] = true;
    if (instr.address > highest) highest = instr.address;
  }

  const words = new Map<number, bigint>();
  for (let a = 0; a < cfg.storeWords; a++) {
    if (written[a]) words.set(a, store[a]);
  }

  // ND-500: word 0 bits 15-0 hold the assembly date (year<<9 | month<<5 | day).
  if (model === "nd500") {
    if ((store[0] & 0xffffn) === 0n) {
      if (cfg.stampDate) {
        const now = options.date ?? new Date();
        const stamp = ((now.getFullYear() % 100) << 9) | ((now.getMonth() + 1) << 5) | now.getDate();
        store[0] |= BigInt(stamp);
        words.set(0, store[0]);
        if (highest < 0) highest = 0;
      }
    } else {
      diagnostics.push({
        severity: "info",
        line: 0,
        message:
          "Word 0 bits 0-15 occupied by code - no assembly date stamped (the original assembler treats this as an error)",
      });
    }
  }

  let wordsToWrite = options.writeFullControlStore === false ? highest + 1 : cfg.storeWords;
  if (wordsToWrite < 0) wordsToWrite = 0;
  const image = writePartsImage(store, cfg.partCount, wordsToWrite);

  return {
    model,
    words,
    image,
    labels: map.labels,
    instructions: found,
    diagnostics,
    errorCount,
  };
}

// ---------------------------------------------------------------------------
// NORD-10
// ---------------------------------------------------------------------------

const ROM_1K = 1024;
const ROM_4K = 4096;
const ND10_ADDRESS_MASK = 0xfff;

/** Octal number as the NORD-10 assembler reads it, or -1. */
export function parseOctalNd10(value: string): number {
  if (value.length === 0 || value.length > 11) return -1;
  if (!/^[0-7]+$/.test(value)) return -1;
  return parseInt(value, 8);
}

interface Nd10Line {
  hasInstruction: boolean;
  expectedWord?: number;
  items: string[];
}

function assembleNd10(source: string, pack: WidePack): WideAssemblyResult {
  const diagnostics: WideDiagnostic[] = [];
  let errorCount = 0;
  const error = (line: number, message: string, address?: number): void => {
    errorCount++;
    diagnostics.push({ severity: "error", line, address, message });
  };
  const oct4 = (n: number): string => octal(n, 4);

  const labelMap = new Map<string, number>();
  const labels: WideLabel[] = [];
  const lines = source.replace(/\r/g, "").split("\n");

  const parseLine = (
    rawLine: string,
    lineNo: number,
    addr: { v: number },
    defineLabels: boolean,
  ): Nd10Line => {
    const result: Nd10Line = { hasInstruction: false, items: [] };
    const pct = rawLine.indexOf("%");
    const line = pct < 0 ? rawLine : rawLine.slice(0, pct);
    const parts = line.split(/[ \t]+/).filter((p) => p.length > 0);
    let i = 0;

    const isListingAddress = (s: string): boolean => s.length === 4 && parseOctalNd10(s) >= 0;
    if (parts.length > 0 && (parts[0].endsWith(":") || isListingAddress(parts[0]))) {
      const strAddress = parts[0].endsWith(":") ? parts[0].slice(0, -1) : parts[0];
      const adr = parseOctalNd10(strAddress);
      if (adr < 0 || adr >= ROM_4K) {
        if (!defineLabels) error(lineNo, `Bad octal address '${parts[0]}', line ${lineNo}`);
      } else {
        addr.v = adr;
      }
      i = 1;
      if (parts.length > 1 && /^[0-9A-Fa-f]{8}$/.test(parts[1])) {
        result.expectedWord = parseInt(parts[1], 16) >>> 0;
        i = 2;
      }
    }

    while (
      i < parts.length &&
      parts[i].length > 1 &&
      parts[i].endsWith(",") &&
      /^[A-Za-z]/.test(parts[i][0])
    ) {
      const name = parts[i].slice(0, -1);
      if (defineLabels) {
        if (pack.tokensByName.has(name)) {
          error(lineNo, `Label '${name}' has the name of a mnemonic, line ${lineNo}`);
        } else if (labelMap.has(name)) {
          error(lineNo, `Label '${name}' defined twice, line ${lineNo}`);
        } else {
          labelMap.set(name, addr.v);
          labels.push({ name, address: addr.v, line: lineNo });
        }
      }
      i++;
    }

    for (; i < parts.length; i++) result.items.push(parts[i]);
    result.hasInstruction = result.items.length > 0;
    return result;
  };

  const translate = (items: string[], address: number, lineNo: number): number => {
    let word = 0;
    const or = (contribution: number, item: string): void => {
      if (((word & contribution) >>> 0) !== 0) {
        error(
          lineNo,
          `OR-ing rejected due to overlapping of MNE-values: ${item} at ${oct4(address)}, line ${lineNo}`,
          address,
        );
      }
      word = (word | contribution) >>> 0;
    };

    for (const item of items) {
      const token = pack.tokensByName.get(item);
      if (token) {
        or(Number(token.value), item);
        continue;
      }

      const number = parseOctalNd10(item);
      if (number >= 0) {
        if (number > 0xffffffff) {
          error(lineNo, `Octal constant ${item} does not fit 32 bits at ${oct4(address)}, line ${lineNo}`, address);
          continue;
        }
        or(number, item);
        continue;
      }

      if (item[0] === "*") {
        let offset = 0;
        let rest = item.slice(1);
        const negative = rest.startsWith("-");
        if (rest.startsWith("+") || negative) rest = rest.slice(1);
        if (rest.length > 0) {
          offset = parseOctalNd10(rest);
          if (offset < 0) {
            error(lineNo, `Bad relative address ${item} at ${oct4(address)}, line ${lineNo}`, address);
            continue;
          }
        }
        const target = negative ? address - offset : address + offset;
        if (target < 0 || target > ND10_ADDRESS_MASK) {
          error(lineNo, `Relative address ${item} leaves the ROM at ${oct4(address)}, line ${lineNo}`, address);
          continue;
        }
        or(target, item);
        continue;
      }

      let labelName = item;
      let labelOffset = 0;
      let idxSign = -1;
      for (let k = 1; k < item.length; k++) {
        if (item[k] === "+" || item[k] === "-") {
          idxSign = k;
          break;
        }
      }
      if (idxSign > 0) {
        // Same as the C#: labelOffset takes the parse result even when it is -1.
        labelOffset = parseOctalNd10(item.slice(idxSign + 1));
        if (labelOffset >= 0) {
          labelName = item.slice(0, idxSign);
          if (item[idxSign] === "-") labelOffset = -labelOffset;
        }
      }
      const labelAddr = labelMap.get(labelName);
      if (labelAddr !== undefined) {
        const labelTarget = labelAddr + labelOffset;
        if (labelTarget < 0 || labelTarget > ND10_ADDRESS_MASK) {
          error(lineNo, `Address ${item} leaves the ROM at ${oct4(address)}, line ${lineNo}`, address);
          continue;
        }
        or(labelTarget, item);
        continue;
      }

      error(lineNo, `Unknown token: ${item} at ${oct4(address)}, line ${lineNo}`, address);
    }
    return word;
  };

  // Pass 1: labels. The counter is walked exactly as in pass 2.
  const addr = { v: 0 };
  for (let i = 0; i < lines.length; i++) {
    const parsed = parseLine(lines[i], i + 1, addr, true);
    if (parsed.hasInstruction) addr.v++;
  }

  // Pass 2: assemble.
  addr.v = 0;
  const rom: number[] = new Array(ROM_4K).fill(0);
  const written: boolean[] = new Array(ROM_4K).fill(false);
  const words = new Map<number, bigint>();
  const found: WideInstruction[] = [];
  let highest = -1;
  for (let i = 0; i < lines.length; i++) {
    const lineNo = i + 1;
    const parsed = parseLine(lines[i], lineNo, addr, false);
    if (!parsed.hasInstruction) continue;
    found.push({
      address: addr.v,
      startLine: lineNo,
      endLine: lineNo,
      items: parsed.items,
    });

    if (addr.v >= ROM_4K) {
      error(lineNo, `Location counter beyond the 4k ROM: ${oct4(addr.v)}, line ${lineNo}`, addr.v);
      addr.v++;
      continue;
    }
    if (written[addr.v]) {
      error(lineNo, `Attempt to write on former entry: ${oct4(addr.v)}, line ${lineNo}`, addr.v);
    }
    const word = translate(parsed.items, addr.v, lineNo);
    if (parsed.expectedWord !== undefined && parsed.expectedWord !== word) {
      error(
        lineNo,
        `Assembled word ${word.toString(16).toUpperCase().padStart(8, "0")} differs from the listed word ${parsed.expectedWord
          .toString(16)
          .toUpperCase()
          .padStart(8, "0")} at ${oct4(addr.v)}, line ${lineNo}`,
        addr.v,
      );
    }
    rom[addr.v] = word;
    written[addr.v] = true;
    words.set(addr.v, BigInt(word));
    if (addr.v > highest) highest = addr.v;
    addr.v++;
  }

  const size = highest >= ROM_1K ? ROM_4K : ROM_1K;
  const romWords = rom.slice(0, size);
  const image = new Uint8Array(size * 4);
  for (let k = 0; k < size; k++) {
    const w = romWords[k] >>> 0;
    image[k * 4] = w >>> 24;
    image[k * 4 + 1] = (w >>> 16) & 0xff;
    image[k * 4 + 2] = (w >>> 8) & 0xff;
    image[k * 4 + 3] = w & 0xff;
  }
  return {
    model: "nd10",
    words,
    image,
    romWords,
    labels,
    instructions: found,
    diagnostics,
    errorCount,
  };
}

/**
 * Assemble source text for NORD-10, ND-500 or ND-5000. For the other models
 * use assembleSource in assembler.ts. `errorCount` says whether the result
 * may be used; the image is built even when there are errors (the C# compiler
 * then reports a failure and writes nothing).
 */
export function assembleWide(
  source: string,
  pack: WidePack,
  options: WideAssembleOptions = {},
): WideAssemblyResult {
  return pack.model === "nd10"
    ? assembleNd10(source, pack)
    : assembleGeneric(source, pack, options);
}
