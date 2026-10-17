/**
 * Helpers for microcode words of any width (NORD-10 32 bits, ND-1x0 48/64
 * bits, ND-5000 128 bits, ND-500 144 bits).
 *
 * A word is a bigint. A word is also written as a list of 16-bit parts,
 * most significant part first (the order of the YAML `parts:` lists and of
 * the C# ushort[] arrays).
 */

/** Build a word from 16-bit parts, most significant part first. */
export function partsToValue(parts: readonly number[]): bigint {
  let v = 0n;
  for (const p of parts) {
    v = (v << 16n) | BigInt(p & 0xffff);
  }
  return v;
}

/** Split a word into `partCount` 16-bit parts, most significant part first. */
export function valueToParts(value: bigint, partCount: number): number[] {
  const parts: number[] = new Array(partCount);
  for (let i = partCount - 1; i >= 0; i--) {
    parts[i] = Number(value & 0xffffn);
    value >>= 16n;
  }
  return parts;
}

/** Mask with bits hi..lo set (inclusive). */
export function bitMask(hi: number, lo: number): bigint {
  return ((1n << BigInt(hi - lo + 1)) - 1n) << BigInt(lo);
}

/** Bits hi..lo of a word as a number (the field must be at most 53 bits wide). */
export function extractBits(value: bigint, hi: number, lo: number): number {
  return Number((value >> BigInt(lo)) & ((1n << BigInt(hi - lo + 1)) - 1n));
}

/** `fieldValue` placed with its lowest bit at `lo`. */
export function placeBits(fieldValue: number | bigint, lo: number): bigint {
  return BigInt(fieldValue) << BigInt(lo);
}

/** True when the two words have at least one set bit in common. */
export function overlaps(a: bigint, b: bigint): boolean {
  return (a & b) !== 0n;
}

/** Octal text, zero-padded on the left to `width` digits. */
export function octal(value: number | bigint, width = 0): string {
  return value.toString(8).padStart(width, "0");
}
