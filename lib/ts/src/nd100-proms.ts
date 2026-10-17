/**
 * Combine the ND-100 PROM files into 64-bit microcode words.
 *
 * The ND-100 CPU keeps its microcode in many 82S185 PROMs (2048 x 4 bit; the
 * files are 2048 bytes with only the low nibble used). Sixteen chips in
 * parallel give one 64-bit word per address. The chip list and the bit order
 * (d20 = bits 0-3 ... d5 = bits 60-63) are those of tools/nd100-combine.py.
 *
 * No XOR is applied here, as in the .CODE files that tool writes. Whether the
 * ROM form or the canonical form should have bits 23-27 inverted is not
 * settled, see reference/roms/ND100/README.md.
 */

import { readFileSync } from "node:fs";
import { join } from "node:path";

export type Nd100Variant = "3033S" | "3033E-CX";
export type Nd100Role = "microcode" | "microcode_ext";

/** [part number, board position] of the chips, low nibble first. */
type ChipList = ReadonlyArray<readonly [string, string]>;

const BASE_3033S: ChipList = [
  ["01500P", "d20"], ["01501P", "d19"], ["01502Q", "d18"], ["01503Q", "d17"],
  ["01504N", "d16"], ["01505N", "d15"], ["01506N", "d14"], ["01507N", "d13"],
  ["01508N", "d12"], ["01509N", "d11"], ["01510N", "d10"], ["01511N", "d9"],
  ["01512N", "d8"], ["01513N", "d7"], ["01514N", "d6"], ["01515N", "d5"],
];

/** 3033E-CX base bank: same as 3033S with 01705N at d15. */
const BASE_CX: ChipList = BASE_3033S.map(([p, pos]) =>
  pos === "d15" ? (["01705N", "d15"] as const) : ([p, pos] as const),
);

const EXT_CX: ChipList = [
  ["08500D", "c20"], ["08501D", "c19"], ["08502D", "c18"], ["08503D", "c17"],
  ["08504D", "c16"], ["08505D", "c15"], ["08506D", "c14"], ["08507D", "c13"],
  ["08508D", "c12"], ["08509D", "c11"], ["08510D", "c10"], ["08511D", "c9"],
  ["08512D", "c8"], ["08513E", "c7"], ["08514E", "c6"], ["08515E", "c5"],
];

export const ND100_PROM_LAYOUTS: Readonly<
  Record<Nd100Variant, Partial<Record<Nd100Role, ChipList>>>
> = {
  "3033S": { microcode: BASE_3033S },
  "3033E-CX": { microcode: BASE_CX, microcode_ext: EXT_CX },
};

export const ND100_PROM_DEPTH = 2048;

/** Microaddress of word 0 of the extension bank (chip address + 0o4000). */
export const ND100_EXT_ADDRESS_OFFSET = 0o4000;

/**
 * Combine the chips of one role. `getChip(partNo, position)` returns the
 * 2048 bytes of the chip file. Words that are zero are left out (as the
 * Python tool does); the extension bank addresses start at 0o4000.
 */
export function combineNd100Proms(
  variant: Nd100Variant,
  role: Nd100Role,
  getChip: (partNo: string, position: string) => Uint8Array,
): Map<number, bigint> {
  const chips = ND100_PROM_LAYOUTS[variant][role];
  if (!chips) throw new Error(`${variant} has no role ${role}`);
  const data = chips.map(([partNo, pos]) => {
    const d = getChip(partNo, pos);
    if (d.length !== ND100_PROM_DEPTH) {
      throw new Error(`${partNo}.${pos} is ${d.length} bytes, expected ${ND100_PROM_DEPTH}`);
    }
    for (const b of d) {
      if (b >> 4 !== 0) throw new Error(`${partNo}.${pos} uses more than the low 4 bits`);
    }
    return d;
  });
  const offset = role === "microcode_ext" ? ND100_EXT_ADDRESS_OFFSET : 0;
  const words = new Map<number, bigint>();
  for (let addr = 0; addr < ND100_PROM_DEPTH; addr++) {
    let w = 0n;
    data.forEach((d, idx) => {
      w |= BigInt(d[addr] & 0x0f) << BigInt(idx * 4);
    });
    if (w !== 0n) words.set(addr + offset, w);
  }
  return words;
}

/**
 * Read the chip files `<partNo>.82s185.<position>` from a folder (for
 * example reference/roms/ND100/3033S) and combine them. Node only.
 */
export function loadNd100Proms(
  folder: string,
  variant: Nd100Variant,
  role: Nd100Role = "microcode",
): Map<number, bigint> {
  return combineNd100Proms(variant, role, (partNo, pos) =>
    new Uint8Array(readFileSync(join(folder, `${partNo}.82s185.${pos}`))),
  );
}
