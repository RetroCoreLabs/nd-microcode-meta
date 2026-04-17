/**
 * EPROM image combiner and splitter.
 *
 * Combines or splits the two EPROM chips that together form the control
 * store on ND-100/110/120 CPU cards. The combine/split operations are
 * PURE byte interleaving - no XOR, no semantic transformation. Both
 * ND-110 and ND-120 ROMs are stored in the same form as their matching
 * .CODE file, so interleaving the chip bytes yields the .CODE format
 * directly for both models.
 *
 * ROM layout
 * ----------
 * Each chip is 32 KiB (8192 x 4 bytes). Each 4-byte slot in the pair
 * forms one 64-bit microinstruction. The "high" chip contributes the
 * high byte of each 16-bit sub-word; the "low" chip contributes the
 * low byte.
 *
 * For each address i in [0, 8192):
 *   for b in {3, 2, 1, 0}:
 *     word[b] = (highChip[i*4 + b] << 8) | lowChip[i*4 + b]
 *   microword = (word[3] << 48) | (word[2] << 32) | (word[1] << 16) | word[0]
 *
 * For the ND-110 3095 card, high = 37949L, low = 37948L.
 * For a typical ND-120 card with AM27256 chips, high = 45133L, low = 45132L.
 *
 * XOR and canonical vs token form
 * -------------------------------
 * ND-110 stores microcode in "token form" (canonical XOR'd with 0x0FC00000).
 * ND-120 stores microcode in canonical form directly.
 *
 * If you need to convert between the two forms, pass `xorFlip: true`. The
 * disassembler handles this automatically via the `nd110XorFlip` option on
 * `parseCodeFile`, so you rarely need to pass it here.
 *
 * An empty microword in canonical form is `0`. In ND-110 token form it is
 * `0x0FC00000` (bits 22-27 set).
 */

import { readFileSync } from "node:fs";
import { ND110_XOR_MASK } from "./bitfield.js";

/** Number of 4-byte microword slots per EPROM chip. */
export const ROM_WORDS = 8192;

/** Size in bytes of a single 32-KiB EPROM image. */
export const ROM_SIZE_BYTES = ROM_WORDS * 4;

/** Options for ROM combination. */
export interface CombineRomsOptions {
  /**
   * If true, XOR each microword with 0x0FC00000 after interleaving.
   * Default: false (pure byte interleave, no transformation).
   *
   * Use this only when you need to convert between ND-110 token form
   * and canonical form. For a direct ROM -> .CODE conversion you
   * should leave this off.
   */
  xorFlip?: boolean;
}

/**
 * Combine two EPROM images into a map of address -> microinstruction word.
 *
 * @param highChip - Contents of the HIGH chip (e.g. 37949L.bin). Contributes
 *                   the upper byte of each 16-bit sub-word.
 * @param lowChip  - Contents of the LOW chip (e.g. 37948L.bin). Contributes
 *                   the lower byte.
 */
export function combineRoms(
  highChip: Uint8Array,
  lowChip: Uint8Array,
  options: CombineRomsOptions = {},
): Map<number, bigint> {
  if (highChip.length !== lowChip.length) {
    throw new Error(
      `ROM size mismatch: high chip has ${highChip.length} bytes, ` +
      `low chip has ${lowChip.length} bytes`,
    );
  }
  const wordCount = Math.floor(highChip.length / 4);
  const out = new Map<number, bigint>();
  for (let addr = 0; addr < wordCount; addr++) {
    const base = addr * 4;
    let microword = 0n;
    for (let b = 3; b >= 0; b--) {
      const word16 = (highChip[base + b]! << 8) | lowChip[base + b]!;
      microword = (microword << 16n) | BigInt(word16 & 0xFFFF);
    }
    if (options.xorFlip) microword ^= ND110_XOR_MASK;
    out.set(addr, microword);
  }
  return out;
}

/** Convenience: combine two ROM files from disk paths. */
export function combineRomFiles(
  highChipPath: string,
  lowChipPath: string,
  options: CombineRomsOptions = {},
): Map<number, bigint> {
  const high = readFileSync(highChipPath);
  const low = readFileSync(lowChipPath);
  return combineRoms(high, low, options);
}

/** Options for splitting microcode into ROM images. */
export interface SplitRomsOptions {
  /**
   * If true, XOR each microword with 0x0FC00000 before splitting into
   * chip bytes. Default: false. Mirrors `CombineRomsOptions.xorFlip`
   * so that combine + split is an identity when both use the same
   * setting.
   */
  xorFlip?: boolean;

  /**
   * Value to use for addresses missing from the microcode map.
   * - `"empty"` (default): fill with the "empty instruction" - 0x0FC00000
   *   in ND-110 token form, or 0 when `xorFlip` is set.
   * - `"zero"`: fill with literal zero bytes.
   */
  fill?: "empty" | "zero";

  /** Number of 4-byte slots to emit. Default: {@link ROM_WORDS} (8192). */
  wordCount?: number;
}

/**
 * Split a microcode map into two EPROM images. Mirrors {@link combineRoms}.
 * Combining the returned chips with the same `xorFlip` setting reproduces
 * the input map exactly.
 *
 * @returns Object with `highChip` (upper byte of each 16-bit sub-word)
 *          and `lowChip` (lower byte).
 */
export function splitRoms(
  microcode: Map<number, bigint>,
  options: SplitRomsOptions = {},
): { highChip: Uint8Array; lowChip: Uint8Array } {
  const wordCount = options.wordCount ?? ROM_WORDS;
  const byteSize = wordCount * 4;
  const highChip = new Uint8Array(byteSize);
  const lowChip = new Uint8Array(byteSize);

  const xorFlip = options.xorFlip ?? false;
  const fillMode = options.fill ?? "empty";

  // "Empty instruction" fill value - 0 when the caller wants canonical
  // form (xorFlip applied), otherwise ND-110 token form 0x0FC00000.
  const emptyValue =
    fillMode === "zero" ? 0n : xorFlip ? 0n : ND110_XOR_MASK;

  for (let addr = 0; addr < wordCount; addr++) {
    let value = microcode.get(addr);
    if (value === undefined) value = emptyValue;
    if (xorFlip) value ^= ND110_XOR_MASK;
    const base = addr * 4;
    for (let b = 0; b < 4; b++) {
      const word16 = Number((value >> BigInt(b * 16)) & 0xFFFFn);
      highChip[base + b] = (word16 >> 8) & 0xFF;
      lowChip[base + b] = word16 & 0xFF;
    }
  }

  return { highChip, lowChip };
}

/**
 * Convenience: load a .CODE file and split it into two ROM images.
 * Addresses missing from the .CODE file are filled with the empty
 * instruction (matching what a freshly-programmed ROM would contain).
 */
export function splitCodeFile(
  codeBytes: Uint8Array,
  options: SplitRomsOptions = {},
): { highChip: Uint8Array; lowChip: Uint8Array } {
  const microcode = new Map<number, bigint>();
  for (let i = 0; i + 9 < codeBytes.length; i += 10) {
    const addr = codeBytes[i]! | (codeBytes[i + 1]! << 8);
    let value = 0n;
    for (let j = 0; j < 8; j++) {
      value |= BigInt(codeBytes[i + 2 + j]!) << BigInt(j * 8);
    }
    microcode.set(addr, value);
  }
  return splitRoms(microcode, options);
}

// ---------------------------------------------------------------------------
// Automatic high/low chip detection + version reporting.
// ---------------------------------------------------------------------------

/** Result of chip-order auto-detection. */
export interface DetectChipOrderResult {
  /** Which of the two inputs is the HIGH chip. */
  high: "a" | "b";
  /** Confidence score (higher = more confident). */
  confidence: number;
  /** Reason for the choice, for error reporting. */
  reason: string;
}

/**
 * Check whether a microword "looks like" a valid ND microinstruction
 * at address 0. Returns a score in [0, N]; higher = more confident
 * this is a real instruction in canonical/token form.
 *
 * Heuristics (each adds 1 to the score):
 *   - Bit 61 set (ALUD,NONE) or bit 60 set (ALUD,B) - a common dest
 *   - Any of the COMM field bits (32-36) is set - indicates a command
 *   - Any of the IDBS field bits (37-41) is set - indicates a bus source
 *   - Upper 3 bits (63:61) are NOT all 1 (which would be an invalid ALUD)
 *   - The word is not all zero and not all ones
 */
function score(word: bigint): number {
  let s = 0;
  if (word === 0n || word === 0xFFFFFFFFFFFFFFFFn) return 0;
  s++;
  const aludBits = Number((word >> 61n) & 7n);
  if (aludBits === 1 || aludBits === 3) s++;         // NONE or B
  if (aludBits !== 7) s++;                           // not all-ones ALUD
  const commField = Number((word >> 32n) & 0x1Fn);
  if (commField !== 0) s++;
  const idbsField = Number((word >> 37n) & 0x1Fn);
  if (idbsField !== 0) s++;
  return s;
}

/**
 * Attempt to determine which of the two ROM images is HIGH and which is
 * LOW, by combining both orderings and checking which produces a
 * plausible MASTER CLEAR / startup instruction at address 0.
 *
 * The heuristic works because:
 *   - Most ND startup microcode has ALUD,NONE at address 0, which sets
 *     bit 61 of the microword.
 *   - The HIGH chip contributes byte 3 = bits 63:56. If the chip order
 *     is reversed, the word's upper byte is garbage and the heuristics
 *     fail.
 *
 * Returns the detection result, or throws if both orderings look
 * plausible / neither looks plausible.
 */
export function detectChipOrder(
  chipA: Uint8Array,
  chipB: Uint8Array,
): DetectChipOrderResult {
  // Look at the first 4 addresses - most startup microcode has
  // predictable, non-trivial instructions there.
  const samples = [0, 1, 2, 3];
  let scoreAB = 0;
  let scoreBA = 0;
  for (const addr of samples) {
    const wordAB = combineWord(chipA, chipB, addr);
    const wordBA = combineWord(chipB, chipA, addr);
    scoreAB += score(wordAB);
    scoreBA += score(wordBA);
  }

  if (scoreAB === scoreBA) {
    throw new Error(
      `Cannot determine chip order: both orderings score equally ` +
      `(${scoreAB} each). Specify --high and --low explicitly.`,
    );
  }
  const high: "a" | "b" = scoreAB > scoreBA ? "a" : "b";
  return {
    high,
    confidence: Math.abs(scoreAB - scoreBA),
    reason: `Score: (A=high, B=low) = ${scoreAB}, (B=high, A=low) = ${scoreBA}`,
  };
}

/** Combine a single 4-byte slot at `addr` without building the whole map. */
function combineWord(high: Uint8Array, low: Uint8Array, addr: number): bigint {
  const base = addr * 4;
  if (base + 3 >= high.length || base + 3 >= low.length) return 0n;
  let v = 0n;
  for (let b = 3; b >= 0; b--) {
    v = (v << 16n) | BigInt((high[base + b]! << 8) | low[base + b]!);
  }
  return v;
}

/** Result of auto-detecting whether microcode is in ND-110 or ND-120 form. */
export interface DetectFormResult {
  /** Best guess: "nd110" (token form, bits 22-27 XOR'd) or "nd120" (canonical). */
  form: "nd110" | "nd120";
  /** Ratio of bits 22, 23, 24, 25 set across non-empty instructions. */
  flagBitRatio: number;
  /**
   * Confidence in [0, 1]. 0 means ambiguous (ratio near 50%), 1 means
   * the ratio was near 0% or 100%, matching one form very clearly.
   */
  confidence: number;
  /** Non-empty instructions examined. */
  nonEmptyCount: number;
}

/**
 * Detect whether a microcode map is in ND-110 token form (bits 22-27
 * XOR'd with 0x0FC00000 relative to canonical) or ND-120 canonical form.
 *
 * Algorithm
 * ---------
 * For each instruction with a recognisable COMM field, look up what the
 * canonical token for that COMM code encodes in bits 22-27. Compare
 * with the observed bits 22-27 in the ROM word.
 *
 *   - If they match -> this word is in canonical form (ND-120 storage).
 *   - If they are the complement -> this word is in token form (ND-110
 *     storage), because the XOR 0x0FC00000 inverts exactly those bits.
 *
 * Across many instructions the two cases give very strong signals.
 * A single anomalous instruction cannot flip the verdict.
 *
 * The table of "expected canonical bits 22-27 per COMM field value" is
 * derived from the ND110Tokens.cs data, keyed by the COMM field value
 * alone (ignoring sub-selector variants). When multiple COMM tokens
 * share a field value but have different bits 22-27, we skip that
 * instruction rather than guess.
 */
export function detectForm(microcode: Map<number, bigint>): DetectFormResult {
  // Expected canonical bits 22-27 (mask 0x3F) for each unambiguous COMM
  // field value (0o0 .. 0o37 = 0-31). `null` means "ambiguous - multiple
  // COMM tokens with this field value set DIFFERENT bits 22-27, so
  // skip this instruction". Derived from defs/tokens/nd110-tokens.yaml.
  const canonicalBits22_27ByComm: (number | null)[] = [
    /* 0o00 */ 0,      // no COMM issued; canonical 0
    /* 0o01 */ 0,      // LDPIL       - 0 in 22-27
    /* 0o02 */ 0,      // LDGPR       - 0
    /* 0o03 */ 0b100000, // EWRF      - bit 27
    /* 0o04 */ 0,      // CLIRQ
    /* 0o05 */ 0,      // RSDA
    /* 0o06 */ null,   // TBSTR/LDPANC/LDPCR - bits 42,43 subselect, 22-27 vary
    /* 0o07 */ 0,      // SIOC
    /* 0o10 */ 0,      // SLOW1/SLOW2
    /* 0o11 */ 0,      // EPIC
    /* 0o12 */ 0b100000, // SMPID      - bit 27
    /* 0o13 */ 0,      // START
    /* 0o14 */ 0,      // SSTOP
    /* 0o15 */ 0,      // CLRTC
    /* 0o16 */ 0,      // CLFF
    /* 0o17 */ 0b100000, // LDLC      - bit 27 (from w2="004000")
    /* 0o20 */ 0b100010, // LDSEG/LDDOMI/LDPS/LDIRV - bit 21 + 27 (ignoring sub-select)
    /* 0o21 */ 0b100010, // WCIHM + sub-selects
    /* 0o22 */ 0b000010, // IREAD,PT + sub-selects (no bit 27 for IREAD!)
    /* 0o23 */ 0b100010, // CJMP family
    /* 0o24 */ 0b100010, // CNEXT family
    /* 0o25 */ 0b100010, // CNEXT F15/F=0 family
    /* 0o26 */ 0b010010, // JMP,* family - bit 21 + 26
    /* 0o27 */ null,   // JMP,XB/XI/LBCONT/CONTINUE - inconsistent
    /* 0o30 */ 0b000010, // AREAD,* family - only bit 21
    /* 0o31 */ 0b000010, // AREAD cont'd
    /* 0o32 */ 0b000010, // AWRITE,* family
    /* 0o33 */ 0b000010, // AWRITE cont'd
    /* 0o34 */ 0b000010, // RDRQ,*
    /* 0o35 */ 0b000010, // WRRQ,*
    /* 0o36 */ null,   // ADCS/RWCS/WLBR/WALBR - varies
    /* 0o37 */ 0b000010, // IDENT/IOX
  ];
  // Reverse-indexed bit meaning: bit 0 of the 6-bit value = bit 22 of word,
  // bit 5 of the 6-bit value = bit 27 of word. Convert to the 22-27 mask.

  const emptyToken = ND110_XOR_MASK;
  let matchCanonical = 0; // instructions consistent with canonical form
  let matchTokenForm = 0; // instructions consistent with ND-110 token form
  let nonEmpty = 0;

  for (const [, v] of microcode) {
    // Skip "empty" slots - they look the same in both encodings.
    if (v === 0n || v === emptyToken) continue;
    nonEmpty++;

    const commField = Number((v >> 32n) & 0x1Fn);
    const expected = canonicalBits22_27ByComm[commField];
    if (expected === null || expected === undefined) continue;

    const observedBits22_27 = Number((v >> 22n) & 0x3Fn);
    if (observedBits22_27 === expected) {
      matchCanonical++;
    } else if (observedBits22_27 === (expected ^ 0x3F)) {
      matchTokenForm++;
    }
    // If neither, this instruction is inconclusive (maybe custom tokens
    // or edge cases) - don't count it.
  }

  const total = matchCanonical + matchTokenForm;
  if (total === 0) {
    return {
      form: "nd110",
      flagBitRatio: 0,
      confidence: 0,
      nonEmptyCount: nonEmpty,
    };
  }

  const tokenFormRatio = matchTokenForm / total;
  const form: "nd110" | "nd120" = tokenFormRatio > 0.5 ? "nd110" : "nd120";
  const confidence = Math.abs(tokenFormRatio - 0.5) * 2;
  return {
    form,
    flagBitRatio: tokenFormRatio,
    confidence,
    nonEmptyCount: nonEmpty,
  };
}

/**
 * Read the microcode version byte stored at address 0o20 in a combined
 * microcode map. The VERSN instruction in standard ND microcode (RASK,
 * DELILAH, etc.) contains the ROM revision number as an octal literal
 * OR'd into the low 8 bits.
 *
 * The returned object includes:
 *   - `octalValue`: the raw octal value (e.g. `0o14`)
 *   - `decimalValue`: decimal equivalent (e.g. 12)
 *   - `letter`: the letter that conventionally labels this revision
 *     (e.g. 'L' for 0o14). Letter N corresponds to octal value
 *     (N + 1) in decimal, so 'A'=1, 'B'=2, ..., 'J'=10=0o12,
 *     'K'=11=0o13, 'L'=12=0o14. Returns '?' for out-of-range values.
 */
export function readMicrocodeVersion(
  microcode: Map<number, bigint>,
): { octalValue: string; decimalValue: number; letter: string } | undefined {
  const word = microcode.get(0o20);
  if (word === undefined) return undefined;
  const value = Number(word & 0xFFn);
  const letter =
    value >= 1 && value <= 26
      ? String.fromCharCode(64 + value)
      : "?";
  return {
    octalValue: "0o" + value.toString(8),
    decimalValue: value,
    letter,
  };
}
