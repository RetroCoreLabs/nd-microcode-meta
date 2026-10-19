/**
 * Bitfield extraction utilities and .CODE/.SYMBOLS.TXT file parsing.
 */

import { readFileSync } from "node:fs";

import type { DecodedFields, SymbolTable } from "./types.js";

/**
 * Extract bits [hi..lo] (inclusive) from a 64-bit BigInt.
 * Returns a small Number (assumes width <= 30).
 */
export function extractField(v: bigint, hi: number, lo: number): number {
  const width = BigInt(hi - lo + 1);
  const mask = (1n << width) - 1n;
  return Number((v >> BigInt(lo)) & mask);
}

/**
 * Decode a raw 64-bit microinstruction word into named fields.
 *
 * Field positions are shared between ND-110 and ND-120 in the canonical
 * (unflipped) form. ND-120 ROM images need the bit-22-27 flip applied
 * before calling this function (see rom-combiner.ts).
 */
export function decodeFields(raw: bigint, address: number): DecodedFields {
  const csbit11_0 = extractField(raw, 11, 0);
  const csbit20 = extractField(raw, 20, 20);

  return {
    raw,
    address,

    aluI: extractField(raw, 63, 55),
    aluSts: extractField(raw, 54, 53),
    rasel: extractField(raw, 52, 51),
    xrf: extractField(raw, 50, 50),
    rbsel: extractField(raw, 49, 48),
    cin: extractField(raw, 47, 46),
    alum: extractField(raw, 45, 44),
    mis: extractField(raw, 43, 42),

    idbs: extractField(raw, 41, 37),
    comm: extractField(raw, 36, 32),

    tSeq: extractField(raw, 31, 30),
    tStk: extractField(raw, 29, 28),

    csdelay27_26: extractField(raw, 27, 26),
    vect: extractField(raw, 25, 25),
    scond: extractField(raw, 24, 24),
    condEnabl: extractField(raw, 23, 23),
    loop: extractField(raw, 22, 22),
    csdelay21: extractField(raw, 21, 21),
    csbit20,

    bop: extractField(raw, 19, 16),
    aop: extractField(raw, 15, 12),

    csbit11_0,
    lcc: extractField(raw, 11, 8),
    tsel: extractField(raw, 7, 4),
    fSeq: extractField(raw, 3, 2),
    fStk: extractField(raw, 1, 0),

    branchAddress: (csbit20 << 12) | csbit11_0,
  };
}

/**
 * XOR mask for the ND-110 "storage vs canonical" bit flip.
 *
 * ND-110 .CODE files and ROM images store bits 22-27 inverted relative
 * to the canonical (active high) form used by the assembler tokens. When
 * reading an ND-110 file, apply this XOR to obtain the canonical
 * microword. When writing to ND-110 format, apply the same XOR to flip
 * back.
 *
 * These bits are LOOP (22), ECOND / CONDENABL (23), SCOND (24), VECT (25)
 * and the two delay bits (26, 27).
 *
 * Sources:
 *   - ND-06.031.1 EN "ND-110 and ND-120 Microprogrammer's Guide",
 *     chapter 4 "Writing Microprogram": "Note that for ND-110 only, bits
 *     22-27 of the microinstruction word are inverted after the word is
 *     assembled." Chapter 3 lists bits 22-25 of the ND-110 as "logic
 *     sense inverted" against the ND-100.
 *   - ND110Compile Compiler.cs and NDMicroCpu ControlStore.cs:
 *     uc = uc ^ 0x000000000FC00000; // Invert bit 22-27
 *   - The ND-120 does not do this: its images hold the bits active high.
 */
export const ND110_XOR_MASK = 0x0FC00000n;

/**
 * ND-100 XOR mask: bits 22-27 are stored inverted in the PROMs, relative
 * to the canonical (active high) form used by the assembler tokens. It is
 * the same mask as the ND-110.
 *
 * Source: ND-06.018.01 EN "NORD-100 Microprogramming Description",
 * chapter "Writing the Microprogram", "Assembly Language Considerations":
 * "It is important to be aware that bits 22 - 27 are inverted after the
 * word is assembled." The description of the microinstruction word calls
 * each of the six bits active low: bit 22 (loop counter), bit 23 (enable
 * test), bit 24 (set test condition), bit 25 (vectorized jump), bit 26
 * (load WCS) and bit 27 (map jump).
 *
 * Earlier versions of this file used 0x0F800000 (bits 23-27, "bit 22 is
 * active high") and a tool comment gave 0x01800000 (bits 23-24). Both were
 * guesses from bit statistics and disagree with the manual. With the full
 * mask the LCOUNT token appears in 73 of the 2048 words of the 3033S PROM
 * set; with 0x0F800000 it appears in 1975 of them.
 */
export const ND100_XOR_MASK = 0x0FC00000n;

/** Options for parsing .CODE files. */
export interface ParseCodeOptions {
  /**
   * Apply the ND-110 XOR bit-flip to convert ROM storage form into the
   * canonical form used by the assembler tokens. Default: false.
   */
  nd110XorFlip?: boolean;

  /**
   * Apply the ND-100 XOR bit-flip (bits 22-27, ND100_XOR_MASK) to convert
   * PROM form into the canonical form used by the assembler tokens.
   * Default: false.
   */
  nd100XorFlip?: boolean;
}

/**
 * Parse a .CODE binary file into address -> microinstruction map.
 *
 * .CODE format: 10 bytes per record
 *   bytes 0-1: 16-bit little-endian address
 *   bytes 2-9: 64-bit little-endian microinstruction value
 *             (for ND-110 only bits 47:0 are used; upper 16 bits are 0)
 *
 * For ND-110 files, pass { nd110XorFlip: true } to convert the ROM-stored
 * bits into the canonical form used by the disassembler.
 */
export function parseCodeFile(
  path: string,
  options: ParseCodeOptions = {},
): Map<number, bigint> {
  const bytes = readFileSync(path);
  return parseCodeBytes(bytes, options);
}

/** Parse raw .CODE bytes (10-byte records). */
export function parseCodeBytes(
  bytes: Uint8Array,
  options: ParseCodeOptions = {},
): Map<number, bigint> {
  const result = new Map<number, bigint>();
  const flip110 = options.nd110XorFlip ?? false;
  const flip100 = options.nd100XorFlip ?? false;
  for (let i = 0; i + 9 < bytes.length; i += 10) {
    const addr = bytes[i]! | (bytes[i + 1]! << 8);
    let value = 0n;
    for (let j = 0; j < 8; j++) {
      value |= BigInt(bytes[i + 2 + j]!) << BigInt(j * 8);
    }
    // ND-110: ROM stores empty slots as 0 (all fuse-links intact).
    // After XOR that becomes 0x0FC00000 canonical, which is NOT a real
    // instruction. Skip these before XOR so they stay out of the map.
    if (flip110 && value === 0n) continue;
    if (flip110) value ^= ND110_XOR_MASK;
    if (flip100) value ^= ND100_XOR_MASK;
    result.set(addr, value);
  }
  return result;
}

/**
 * Parse a .SYMBOLS.TXT file into address -> label map.
 *
 * Format (from ND-110-RASK.SYMBOLS.TXT):
 *   Header text is skipped.
 *   Each data line looks like "000020=VERSN" where the address is in octal.
 *   Blank lines, lines starting with % or #, and non-matching lines are ignored.
 */
export function parseSymbolsFile(path: string): SymbolTable {
  const text = readFileSync(path, "utf8");
  return parseSymbolsText(text);
}

/** Parse .SYMBOLS.TXT text content. */
export function parseSymbolsText(text: string): SymbolTable {
  const map = new Map<number, string>();
  const lineRegex = /^([0-7]+)\s*=\s*(\S+)\s*$/;
  for (const line of text.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("%") || trimmed.startsWith("#")) continue;
    const m = lineRegex.exec(trimmed);
    if (m) {
      const addr = parseInt(m[1]!, 8);
      map.set(addr, m[2]!);
    }
  }
  return map;
}

/**
 * Convert a number to an octal string, left-padded to `width` digits.
 * This matches the Norsk Data convention used throughout the microcode.
 */
export function toOctal(n: number, width = 0): string {
  const s = n.toString(8);
  return width > 0 ? s.padStart(width, "0") : s;
}
