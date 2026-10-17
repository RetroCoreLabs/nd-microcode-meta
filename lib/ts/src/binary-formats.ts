/**
 * Binary and text formats of the microcode images, one reader and one
 * writer per format. All functions are pure (no file access).
 *
 *   packed18     ND-500: 18 bytes per word, CS8 first, big-endian per part;
 *                the full control store is 8192 words = 147456 bytes.
 *   be16x8       ND-5000: 16 bytes per word, big-endian (byte 0 = bits
 *                127-120); the full control store is 16384 words = 262144 bytes.
 *   prom-hex     NORD-10: text, 8 upper-case hex digits and LF per word.
 *   be32         NORD-10: 4 bytes per word, big-endian (the C# .CODE file).
 *   code-records ND-100/110/120: 10 bytes per record, 16-bit little-endian
 *                address then 64-bit little-endian word (see bitfield.ts).
 *
 * Sources: ND500Compiler.Assemble, ND5000Compiler.Assemble,
 * ND10Compiler.ReadHexFile / WriteHexFile / WriteBinaryFile (C# project
 * ND110Compile).
 */

export const ND500_WORDS = 8192;
export const ND500_PARTS = 9;
export const ND5000_WORDS = 16384;
export const ND5000_PARTS = 8;

export type BinaryFormat =
  | "packed18"
  | "be16x8"
  | "prom-hex"
  | "be32"
  | "code-records"
  | "unknown";

/**
 * Read an image of `partCount` big-endian 16-bit parts per word, most
 * significant part first. The byte count must be a multiple of the word size.
 */
export function readPartsImage(
  bytes: Uint8Array,
  partCount: number,
): bigint[] {
  const wordBytes = partCount * 2;
  if (bytes.length % wordBytes !== 0) {
    throw new Error(
      `${bytes.length} bytes is not a multiple of ${wordBytes} (${partCount} parts of 16 bits)`,
    );
  }
  const words: bigint[] = new Array(bytes.length / wordBytes);
  for (let a = 0; a < words.length; a++) {
    let v = 0n;
    const off = a * wordBytes;
    for (let i = 0; i < wordBytes; i++) {
      v = (v << 8n) | BigInt(bytes[off + i]);
    }
    words[a] = v;
  }
  return words;
}

/**
 * Write words as an image of `partCount` big-endian parts per word.
 * `words` is an array or a map address -> word; missing addresses are zero.
 * `wordCount` is the number of words written (addresses 0..wordCount-1).
 */
export function writePartsImage(
  words: ReadonlyMap<number, bigint> | readonly bigint[],
  partCount: number,
  wordCount: number,
): Uint8Array {
  const wordBytes = partCount * 2;
  const out = new Uint8Array(wordCount * wordBytes);
  const get = (a: number): bigint =>
    (words instanceof Map ? words.get(a) : (words as readonly bigint[])[a]) ?? 0n;
  for (let a = 0; a < wordCount; a++) {
    let v = get(a);
    const off = a * wordBytes;
    for (let i = wordBytes - 1; i >= 0; i--) {
      out[off + i] = Number(v & 0xffn);
      v >>= 8n;
    }
  }
  return out;
}

export const readPacked18 = (bytes: Uint8Array): bigint[] =>
  readPartsImage(bytes, ND500_PARTS);
export const writePacked18 = (
  words: ReadonlyMap<number, bigint> | readonly bigint[],
  wordCount = ND500_WORDS,
): Uint8Array => writePartsImage(words, ND500_PARTS, wordCount);

export const readBe16x8 = (bytes: Uint8Array): bigint[] =>
  readPartsImage(bytes, ND5000_PARTS);
export const writeBe16x8 = (
  words: ReadonlyMap<number, bigint> | readonly bigint[],
  wordCount = ND5000_WORDS,
): Uint8Array => writePartsImage(words, ND5000_PARTS, wordCount);

/** Read prom.hex text: one hexadecimal 32-bit word per line, empty lines skipped. */
export function readPromHex(text: string): number[] {
  const words: number[] = [];
  for (const line of text.split("\n")) {
    const s = line.trim();
    if (s.length === 0) continue;
    if (!/^[0-9A-Fa-f]{1,8}$/.test(s)) {
      throw new Error(`Not a hexadecimal 32-bit word: "${s}"`);
    }
    words.push(parseInt(s, 16));
  }
  return words;
}

/** Write prom.hex text: 8 upper-case hex digits per word, LF line ends. */
export function writePromHex(words: ArrayLike<number>): string {
  let out = "";
  for (let i = 0; i < words.length; i++) {
    out += (words[i] >>> 0).toString(16).toUpperCase().padStart(8, "0") + "\n";
  }
  return out;
}

/** Read 32-bit big-endian words (NORD-10 .CODE). */
export function readBe32(bytes: Uint8Array): number[] {
  if (bytes.length % 4 !== 0) {
    throw new Error(`${bytes.length} bytes is not a multiple of 4`);
  }
  const words: number[] = new Array(bytes.length / 4);
  for (let i = 0; i < words.length; i++) {
    const o = i * 4;
    words[i] =
      ((bytes[o] << 24) | (bytes[o + 1] << 16) | (bytes[o + 2] << 8) | bytes[o + 3]) >>> 0;
  }
  return words;
}

/** Write 32-bit big-endian words (NORD-10 .CODE). */
export function writeBe32(words: ArrayLike<number>): Uint8Array {
  const out = new Uint8Array(words.length * 4);
  for (let i = 0; i < words.length; i++) {
    const w = words[i] >>> 0;
    out[i * 4] = w >>> 24;
    out[i * 4 + 1] = (w >>> 16) & 0xff;
    out[i * 4 + 2] = (w >>> 8) & 0xff;
    out[i * 4 + 3] = w & 0xff;
  }
  return out;
}

function looksLikePromHex(bytes: Uint8Array): boolean {
  if (bytes.length === 0 || bytes.length > 1 << 20) return false;
  for (const b of bytes) {
    const ok =
      (b >= 0x30 && b <= 0x39) ||
      (b >= 0x41 && b <= 0x46) ||
      (b >= 0x61 && b <= 0x66) ||
      b === 0x0a ||
      b === 0x0d;
    if (!ok) return false;
  }
  const lines = new TextDecoder("ascii")
    .decode(bytes)
    .split("\n")
    .map((l) => l.trim())
    .filter((l) => l.length > 0);
  return (
    (lines.length === 1024 || lines.length === 4096) &&
    lines.every((l) => /^[0-9A-Fa-f]{8}$/.test(l))
  );
}

function looksLikeCodeRecords(bytes: Uint8Array): boolean {
  if (bytes.length === 0 || bytes.length % 10 !== 0) return false;
  let prev = -1;
  for (let o = 0; o < bytes.length; o += 10) {
    const addr = bytes[o] | (bytes[o + 1] << 8);
    if (addr <= prev) return false;
    prev = addr;
  }
  return true;
}

/**
 * Decide the format of an image from its size and content. The rules:
 *   147456 bytes                       -> packed18 (ND-500 full control store)
 *   262144 bytes                       -> be16x8 (ND-5000 full control store)
 *   text, 1024 or 4096 lines of 8 hex  -> prom-hex (NORD-10)
 *   4096 or 16384 bytes, not text      -> be32 (NORD-10 .CODE, 1k or 4k words)
 *   size multiple of 10, ascending 16-bit addresses -> code-records
 *   anything else                      -> unknown
 */
export function detectBinaryFormat(bytes: Uint8Array): BinaryFormat {
  if (bytes.length === ND500_WORDS * ND500_PARTS * 2) return "packed18";
  if (bytes.length === ND5000_WORDS * ND5000_PARTS * 2) return "be16x8";
  if (looksLikePromHex(bytes)) return "prom-hex";
  if (bytes.length === 4096 || bytes.length === 16384) return "be32";
  if (looksLikeCodeRecords(bytes)) return "code-records";
  return "unknown";
}
