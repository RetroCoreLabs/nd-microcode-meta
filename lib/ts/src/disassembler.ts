/**
 * Disassembler public API and model dispatcher.
 *
 * The disassembler implementation is split per CPU family because the
 * ND-100 microinstruction word has architectural differences from the
 * ND-110/120 that cannot be expressed as simple value-table swaps:
 *
 *   - ND-100 bits 25-27 are three active-low branch-mode select lines
 *     (VECT0 / SLWCS0 / MAPJ0) that combine with MIS to form a 5-bit
 *     "effective branch source" selector. ND-110 reuses the same bits
 *     as VECT + DLY0 + DLY1 (microcycle delay).
 *   - ND-100 bits 20-21 are a 2-bit cycle-timing selector (TC). ND-110
 *     uses bit 20 as the branch-address extension and bit 21 as a
 *     single-bit DELAY.
 *   - ND-100 IDBS is a 4-bit field (bits 37-40) with a separate SEXT
 *     modifier at bit 41. ND-110 widens IDBS to 5 bits (bits 37-41).
 *   - ND-100 MIS (bits 42-43) has three context-dependent roles
 *     (shift mode / page mode / vect-operand selector). ND-110 uses
 *     only two (shift + page).
 *
 * Dispatch is driven by `pack.definitions.model`:
 *   - "nd100"        -> disassembler-nd100.ts (not yet implemented;
 *                       currently falls through to ND-110 decode with
 *                       known-incomplete results)
 *   - "nd110"/"nd120" -> disassembler-nd110.ts (canonical implementation,
 *                        bit-exact validated vs ND-110 RASK)
 */

import type {
  DefinitionPack,
  DisassembledInstruction,
  SymbolTable,
} from "./types.js";

import {
  compileDisassemblerPack as compileNd110Pack,
  disassembleWord as disassembleNd110Word,
  disassembleMap as disassembleNd110Map,
  TIMING_MASK,
} from "./disassembler-nd110.js";
import type { DisassemblerPack as Nd110DisassemblerPack } from "./disassembler-nd110.js";
import {
  disassembleWord as disassembleNd100Word,
  disassembleMap as disassembleNd100Map,
} from "./disassembler-nd100.js";

// Re-exported so existing callers can continue `import { TIMING_MASK }
// from "./disassembler.js"` unchanged.
export { TIMING_MASK };

/**
 * A precompiled disassembler pack. The underlying shape is per-model
 * (currently only ND-110-style packs are produced) but callers should
 * treat this as an opaque handle.
 */
export type DisassemblerPack = Nd110DisassemblerPack;

/**
 * Precompile a DefinitionPack for fast decoding.
 *
 * The pack carries its model through; downstream calls to
 * disassembleWord / disassembleMap dispatch on that model.
 */
export function compileDisassemblerPack(
  definitions: DefinitionPack,
): DisassemblerPack {
  // All three models currently use the ND-110-style precompilation step
  // (the compile phase is just token indexing; it's model-agnostic).
  // When disassembler-nd100.ts lands with a different precomputed
  // structure, add a branch on definitions.model here.
  return compileNd110Pack(definitions);
}

/**
 * Disassemble a single microinstruction word at the given address.
 *
 * Dispatches to the model-specific decoder based on the pack's model.
 * `symbols` provides branch-target labels; addresses referenced from
 * the disassembled instruction will be rendered as labels when a
 * matching symbol exists.
 */
export function disassembleWord(
  raw: bigint,
  address: number,
  pack: DisassemblerPack,
  symbols?: SymbolTable,
): DisassembledInstruction {
  if (pack.definitions.model === "nd100") {
    return disassembleNd100Word(raw, address, pack, symbols);
  }
  return disassembleNd110Word(raw, address, pack, symbols);
}

/**
 * Disassemble every microinstruction in an address-keyed map.
 *
 * Optionally attaches labels from a symbol table. Output is sorted by
 * address ascending.
 */
export function disassembleMap(
  map: Map<number, bigint>,
  pack: DisassemblerPack,
  symbols?: SymbolTable,
): DisassembledInstruction[] {
  if (pack.definitions.model === "nd100") {
    return disassembleNd100Map(map, pack, symbols);
  }
  return disassembleNd110Map(map, pack, symbols);
}
