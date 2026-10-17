/**
 * Source text output for the wide-word models and the ND-5000 .LABE label
 * file reader.
 *
 * ND-500 / ND-5000 text is what Program.cs `nd500-disasm` writes: a '%'
 * header line, then one line `AAAAAA/ item item ... ;` for every word that
 * is not zero (zero words stay zero in the control store).
 * NORD-10 text is what `nd10-disasm` writes: a '%' header line, then
 * `AAAA: item item ...` for every word, zero words too.
 */

import { disassembleWide } from "./disassembler-wide.js";
import type { WidePack } from "./wide-defs.js";
import { octal } from "./word.js";

/** Label names and addresses from a .LABE file. */
export interface LabelMap {
  /** Name -> address; a later entry with the same name overwrites. */
  nameToAddr: Map<string, number>;
  /** Address -> name; a later entry for the same address overwrites. */
  addrToName: Map<number, string>;
}

/**
 * Parse the bytes of an ND-5000 .LABE file (port of ND5000LabelMap.Parse):
 * bit 7 of every byte is removed, empty lines, lines containing
 * "microprogram cross reference table" and lines that start with a space
 * are skipped; the others are `NAME <spaces> octal-address[*]`.
 */
export function parseLabeBytes(bytes: Uint8Array): LabelMap {
  const nameToAddr = new Map<string, number>();
  const addrToName = new Map<number, string>();
  let text = "";
  for (const b of bytes) text += String.fromCharCode(b & 0x7f);
  for (const line of text.split("\n")) {
    const t = line.trim();
    if (t.length === 0) continue;
    if (t.includes("microprogram cross reference table")) continue;
    if (line.length > 0 && line[0] === " ") continue;
    const m = /^(\S+)\s+(\d+)\*?/.exec(t);
    if (!m) continue;
    if (!/^[0-7]+$/.test(m[2])) continue;
    const addr = parseInt(m[2], 8);
    if (addr > 0x7fffffff) continue;
    nameToAddr.set(m[1], addr);
    addrToName.set(addr, m[1]);
  }
  return { nameToAddr, addrToName };
}

export interface WideFormatOptions {
  /** Text of the first line after '%' (default: a generic line). */
  header?: string;
  /**
   * nd5000 only: label names. A word at a labelled address gets `NAME:`
   * in front of its items, and ABS_ADDR=n is written as the label name
   * when that label is defined in the output. The reassembled bits stay
   * the same (both put the address in bits 31-16).
   */
  labels?: LabelMap;
}

function safeLabel(pack: WidePack, name: string): boolean {
  return (
    /^[A-Za-z][A-Za-z0-9_.$]*$/.test(name) &&
    name.length < 30 &&
    !pack.tokensByName.has(name)
  );
}

/**
 * Disassemble a set of words into source text. `words` maps address to word
 * (or is an array indexed by address).
 */
export function formatProgramWide(
  pack: WidePack,
  words: ReadonlyMap<number, bigint> | readonly bigint[],
  options: WideFormatOptions = {},
): string {
  const entries: Array<[number, bigint]> =
    words instanceof Map
      ? [...words.entries()].sort((a, b) => a[0] - b[0])
      : (words as readonly bigint[]).map((w, i) => [i, w] as [number, bigint]);

  const header =
    options.header ?? `${pack.displayName} microcode (lossless disassembly)`;
  const out: string[] = [`% ${header}`];

  if (pack.model === "nd10") {
    for (const [addr, word] of entries) {
      out.push(`${octal(addr, 4)}: ${disassembleWide(pack, word).join(" ")}`);
    }
    return out.join("\n") + "\n";
  }

  const printed = entries
    .map(([addr, word]) => ({ addr, items: disassembleWide(pack, word) }))
    .filter((e) => e.items.length > 0);

  const labels = pack.model === "nd5000" ? options.labels : undefined;
  const defined = new Map<number, string>();
  if (labels) {
    for (const e of printed) {
      const name = labels.addrToName.get(e.addr);
      if (
        name !== undefined &&
        labels.nameToAddr.get(name) === e.addr &&
        safeLabel(pack, name)
      ) {
        defined.set(e.addr, name);
      }
    }
  }

  for (const e of printed) {
    const items = e.items.map((item) => {
      if (defined.size > 0 && item.startsWith("ABS_ADDR=")) {
        const target = parseInt(item.slice("ABS_ADDR=".length), 8);
        const name = defined.get(target);
        if (name !== undefined) return name;
      }
      return item;
    });
    const label = defined.get(e.addr);
    out.push(
      `${octal(e.addr, 6)}/ ${label !== undefined ? label + ": " : ""}${items.join(" ")} ;`,
    );
  }
  return out.join("\n") + "\n";
}
