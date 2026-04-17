/**
 * Disassembler core.
 *
 * Decodes a raw 64-bit microinstruction word into a sequence of tokens
 * classified by category and display line.
 *
 * Algorithm: iterate categories in a fixed order; within each category,
 * find the most specific token whose encoded bits are all present in the
 * word. Track consumed bits so that sub-selector bits (e.g. COMM+MIS
 * composites) are not double-counted as plain MIS tokens.
 *
 * Zero-encoded "default" tokens (T,JMP / T,HOLD / F,JMP / F,HOLD / ALUD,Q
 * / IDBS,ALU) are emitted contextually based on the rules in
 * defs/format/assembly-format.yaml.
 */

import { decodeFields, toOctal } from "./bitfield.js";
import type {
  DecodedFields,
  DefinitionPack,
  DisassembledInstruction,
  EmittedToken,
  SymbolTable,
  Token,
  TokenCategory,
} from "./types.js";

/**
 * Timing / delay bits. These are hints emitted by the assembler for various
 * tokens but carry no logical meaning for decoding. We ignore them when
 * matching tokens so that e.g. COMM,LDLC can be identified even if a prior
 * IDBS,PANEL consumed bit 27.
 *
 * Bits 20 (CSBIT20 - actually semantic, keep), 21, 26, 27.
 *
 * NOTE: bit 20 IS semantic (address extension) so we do NOT mask it.
 * Bits 21, 26, 27 are pure timing hints per ND110MicroCode/Program.cs.
 */
export const TIMING_MASK = 0x0000000_0C200000n; // bits 21, 26, 27

/** Precomputed category metadata for fast decode. */
export interface CategoryMeta {
  category: TokenCategory;
  /**
   * Logical mask: OR of all tokens' encoding bits, EXCLUDING timing bits.
   * Used for identifying which bits of the raw word belong to this category.
   */
  mask: bigint;
  /** Tokens sorted by popcount(encoding) descending (most specific first). */
  tokens: Token[];
  /**
   * Map from exact logical encoding value (masked with category mask) to
   * token. Timing bits are stripped from keys.
   */
  byValue: Map<bigint, Token>;
}

/** A precompiled disassembler pack. Cheaper than the raw DefinitionPack. */
export interface DisassemblerPack {
  definitions: DefinitionPack;
  categoryMeta: Map<TokenCategory, CategoryMeta>;
}

export function popcount(v: bigint): number {
  let count = 0;
  let x = v;
  while (x > 0n) {
    x &= x - 1n;
    count++;
  }
  return count;
}

/** Precompile a definition pack into a faster disassembler pack. */
export function compileDisassemblerPack(
  definitions: DefinitionPack,
): DisassemblerPack {
  const categoryMeta = new Map<TokenCategory, CategoryMeta>();

  for (const [cat, tokens] of definitions.tokensByCategory) {
    let mask = 0n;
    for (const t of tokens) mask |= t.encodingValue;
    // Sort by full popcount descending. Composite tokens like COMM,LDPANC
    // match before simpler versions. Token identity uses the FULL encoding
    // including timing bits (bits 21, 26, 27) because different tokens with
    // the same logical field value may set different timing bits (e.g.
    // B,B includes bit 27 while B,3 does not - the author picks one or
    // the other based on the desired hardware timing).
    const sorted = [...tokens].sort(
      (a, b) => popcount(b.encodingValue) - popcount(a.encodingValue),
    );
    const byValue = new Map<bigint, Token>();
    for (const t of sorted) {
      if (!byValue.has(t.encodingValue)) {
        byValue.set(t.encodingValue, t);
      }
    }
    categoryMeta.set(cat, {
      category: cat,
      mask,
      tokens: sorted,
      byValue,
    });
  }

  return { definitions, categoryMeta };
}

/**
 * Find the most specific token in `meta` whose bits are all present in `raw`
 * and not already consumed. Returns undefined if nothing matches.
 *
 * If `allowZero` is false (default), tokens with encoding == 0 are never
 * returned. Those "zero-default" tokens (like ALUF,A+Q or T,JMP) are only
 * emitted when the caller decides it's contextually appropriate.
 */
const AOP_MASK = 0x000000000000F000n; // bits 15:12
const BOP_MASK = 0x00000000000F0000n; // bits 19:16
const AOP_BOP_MASK = AOP_MASK | BOP_MASK;

/**
 * Identifying bitfield per category. When a token is matched against the
 * raw word, the field bits must match EXACTLY. This avoids picking a
 * token with a different field value when it would otherwise be a valid
 * subset match.
 *
 * Categories not in this map fall back to the generic subset-match logic.
 */
const CATEGORY_FIELD_MASK: Partial<Record<TokenCategory, bigint>> = {
  COMM:  0x0000001F00000000n,  // bits 36:32
  IDBS:  0x000003E000000000n,  // bits 41:37
  T_SEQ: 0x00000000C0000000n,  // bits 31:30
  T_STK: 0x0000000030000000n,  // bits 29:28
  F_SEQ: 0x000000000000000Cn,  // bits 3:2
  F_STK: 0x0000000000000003n,  // bits 1:0
  COND:  0x00000000010000F0n,  // SCOND (bit 24) + TSEL (bits 7:4)
  ALUD:  0xE000000000000000n,  // bits 63:61
};

/**
 * Find an AB_REG token whose AOP+BOP encoding EXACTLY matches the raw
 * word's AOP+BOP fields. Subset matches would incorrectly pick an alias
 * whose register indices differ from the instruction's.
 */
export function findExactABReg(
  pack: DisassemblerPack,
  raw: bigint,
): Token | undefined {
  const meta = pack.categoryMeta.get("AB_REG");
  if (!meta) return undefined;
  const rawAopBop = raw & AOP_BOP_MASK;
  for (const t of meta.tokens) {
    if ((t.encodingValue & AOP_BOP_MASK) === rawAopBop && rawAopBop !== 0n) {
      return t;
    }
  }
  return undefined;
}

/**
 * Find a register token (A_REG or B_REG) whose operand field exactly
 * matches the raw word's corresponding field, AND whose other bits are
 * a subset of the available bits.
 *
 * This avoids the `B,X` vs `B,R7` ambiguity: both are "B_REG" tokens,
 * but B,X encodes BOP=7 and B,R7 encodes BOP=15. Requiring exact field
 * match forces the correct choice when the raw word has e.g. BOP=15.
 *
 * Returns undefined if the raw field value is 0 AND no special (RASEL/
 * RBSEL) token matches - in that case no register token should be emitted.
 */
export function findExactRegToken(
  category: "A_REG" | "B_REG",
  meta: CategoryMeta,
  raw: bigint,
  consumed: bigint,
): Token | undefined {
  const fieldMask = category === "A_REG" ? AOP_MASK : BOP_MASK;
  const rawField = raw & fieldMask;
  const available = raw & ~consumed & meta.mask;

  // 1. Prefer RASEL/RBSEL-based tokens (A,PIL / A,REG / A,SRCE / A,LC
  //    for A_REG; B,DEST / B,SRCE / B,LC for B_REG). These do NOT set
  //    the AOP/BOP field, so their field bits are 0. If raw's field bits
  //    are also 0, they can match directly.
  for (const t of meta.tokens) {
    if ((t.encodingValue & fieldMask) !== 0n) continue; // skip standard tokens
    if (t.encodingValue === 0n) continue;               // skip pure-zero (would match anything)
    if ((t.encodingValue & available) === t.encodingValue) {
      return t;
    }
  }

  // 2. Standard register tokens: require EXACT field match.
  if (rawField === 0n) return undefined;
  let best: Token | undefined;
  let bestBits = -1;
  for (const t of meta.tokens) {
    if ((t.encodingValue & fieldMask) !== rawField) continue;
    // Check that the token's other bits are a subset of available.
    const other = t.encodingValue & ~fieldMask;
    if ((other & ~available) !== 0n) continue;
    const pop = popcount(t.encodingValue);
    if (pop > bestBits) {
      best = t;
      bestBits = pop;
    }
  }
  return best;
}

export function findTokenInCategory(
  meta: CategoryMeta,
  raw: bigint,
  consumed: bigint,
  allowZero = false,
): Token | undefined {
  const available = raw & ~consumed & meta.mask;
  if (available === 0n && !allowZero) return undefined;

  // If the category has an identifying field (COMM, IDBS, T_SEQ, etc.),
  // require the field bits to match raw EXACTLY. Other bits may still be
  // subset matches (e.g. MIS sub-selector bits embedded in COMM tokens).
  const fieldMask = CATEGORY_FIELD_MASK[meta.category];
  if (fieldMask !== undefined) {
    const rawField = raw & fieldMask;
    for (const t of meta.tokens) {
      if (t.encodingValue === 0n) continue;
      if ((t.encodingValue & fieldMask) !== rawField) continue;
      // Check that the token's non-field bits are a subset of available.
      const otherBits = t.encodingValue & ~fieldMask;
      if ((otherBits & available) !== otherBits) continue;
      return t;
    }
    return undefined;
  }

  // No identifying field - use plain subset matching. Most-specific first.
  const exact = meta.byValue.get(available);
  if (exact) {
    if (exact.encodingValue === 0n && !allowZero) return undefined;
    return exact;
  }
  for (const t of meta.tokens) {
    if (t.encodingValue === 0n) continue;
    if ((t.encodingValue & available) === t.encodingValue) {
      return t;
    }
  }
  return undefined;
}

/**
 * Emit an instruction's tokens in the order they should appear in source.
 */
export function disassembleWord(
  raw: bigint,
  address: number,
  pack: DisassemblerPack,
  symbols?: SymbolTable,
): DisassembledInstruction {
  const fields = decodeFields(raw, address);
  const tokens: EmittedToken[] = [];
  const state = { consumed: 0n };

  // Helper to look up and emit from a category if a match is found.
  const tryEmit = (cat: TokenCategory, line?: 1 | 2 | 3): Token | undefined => {
    const meta = pack.categoryMeta.get(cat);
    if (!meta) return undefined;
    const tok = findTokenInCategory(meta, raw, state.consumed);
    if (!tok) return undefined;
    // Only mark the logical bits as consumed; timing bits remain available.
    state.consumed |= tok.encodingValue & ~TIMING_MASK;
    tokens.push({
      text: tok.name,
      field: cat,
      line: line ?? tok.displayLine,
    });
    return tok;
  };

  // ------------------------------------------------------------------
  // LINE 1: registers + ALU
  // ------------------------------------------------------------------

  // COMM,EPIC means the A-operand slot holds a PIC command, not a register.
  const isEpic = fields.comm === 9;

  // AB,xxx tokens combine A+B into a named scratch register pair. Only
  // accept an AB alias on an EXACT match of the aop+bop encoding - subset
  // matches would pick a token with different register indices.
  const abToken = findExactABReg(pack, raw);
  if (abToken) {
    tokens.push({ text: abToken.name, field: "AB_REG", line: 1 });
    state.consumed |= abToken.encodingValue & ~TIMING_MASK;
  }

  if (!abToken && isEpic) {
    tryEmit("PIC", 1);
  }

  // A-operand register. findExactRegToken prefers RASEL-based tokens
  // (A,PIL / A,REG / A,SRCE / A,LC) when the RASEL bits are set, else
  // requires an EXACT AOP field match for standard A,<register> tokens.
  // This avoids picking A,X (AOP=7) when raw has AOP=15.
  if (!isEpic) {
    const aRegMeta = pack.categoryMeta.get("A_REG");
    if (aRegMeta) {
      const aTok = findExactRegToken("A_REG", aRegMeta, raw, state.consumed);
      if (aTok) {
        tokens.push({ text: aTok.name, field: "A_REG", line: 1 });
        state.consumed |= aTok.encodingValue & ~TIMING_MASK;
      } else if (!abToken && (fields.aop !== 0 || needsAop(fields, pack))) {
        emitRegister(tokens, "A_REG", fields.aop, pack, 1, state);
      }
    }
  }

  const bRegMeta = pack.categoryMeta.get("B_REG");
  if (bRegMeta) {
    const bTok = findExactRegToken("B_REG", bRegMeta, raw, state.consumed);
    if (bTok) {
      tokens.push({ text: bTok.name, field: "B_REG", line: 1 });
      state.consumed |= bTok.encodingValue & ~TIMING_MASK;
    } else if (!abToken && (fields.bop !== 0 || needsBop(fields, pack))) {
      emitRegister(tokens, "B_REG", fields.bop, pack, 1, state);
    }
  }

  // ALU function (composite of aluI + sometimes cin).
  tryEmit("ALUF", 1);

  // ALU destination. ALUD,NONE (value 1) is typically emitted when other
  // ALU activity is visible; ALUD,Q (value 0) is the natural default but
  // is emitted if any ALU operation is specified (per format rules).
  tryEmit("ALUD", 1);

  // Status update / carry-in - suppressed when 0.
  if (fields.aluSts !== 0) tryEmit("STS", 1);
  if (fields.cin !== 0) tryEmit("CRY", 1);

  // XRF flag.
  if (fields.xrf !== 0) {
    const xrf = pack.definitions.tokensByName.get("XRF");
    if (xrf) {
      tokens.push({ text: "XRF", field: "SPECIAL", line: 1 });
      state.consumed |= xrf.encodingValue;
    }
  }

  // ------------------------------------------------------------------
  // LINE 2: IDB bus + command + true-path sequencing
  // ------------------------------------------------------------------

  // IDBS source. The zero-encoded IDBS,ALU is emitted when any line-2
  // activity is visible.
  tryEmit("IDBS", 2);

  // COMM command. Must be decoded BEFORE MIS/ALUM because some COMM
  // tokens (e.g. COMM,IOX, COMM,AREAD,B) embed MIS-region bits as
  // sub-selectors. If MIS were decoded first it would consume those
  // bits and COMM would fall back to a less specific token.
  tryEmit("COMM", 2);

  // MIS / ALUM - emitted only when their bits remain unconsumed by COMM.
  if (fields.alum !== 0) tryEmit("ALUM", 1);
  if (fields.mis !== 0) tryEmit("MIS", 1);

  // True-path sequence + stack. First try the category lookup which
  // catches non-zero-encoded tokens like T,NEXT, T,RETURN via exact
  // T_SEQ field match. Zero-encoded T,JMP is the fallback.
  const tSeqTok = tryEmit("T_SEQ", 2);
  if (!tSeqTok && isBranchLikelyPresent(fields)) {
    emitByName(tokens, "T,JMP", 2, pack);
  }

  // VECT (bit 25) is set by T,JMP0-3 (standalone) or T,JMPAOPR (with
  // MIS bits 42, 43). These are "secondary" T_SEQ tokens that don't
  // occupy the T_SEQ field but do set VECT. When VECT is still set
  // after the primary T_SEQ emission, add the appropriate token.
  const vectBit = 1n << 25n;
  if ((raw & vectBit) !== 0n && (state.consumed & vectBit) === 0n) {
    const bit42_43 = 1n << 42n | 1n << 43n;
    if ((raw & bit42_43) === bit42_43) {
      emitByName(tokens, "T,JMPAOPR", 2, pack);
    } else {
      emitByName(tokens, "T,JMP0-3", 2, pack);
    }
    // Track consumption so the category masks don't re-consume VECT.
    state.consumed |= vectBit;
  }
  if (fields.tStk !== 0) {
    tryEmit("T_STK", 2);
  } else if (tSeqTok !== undefined || isBranchLikelyPresent(fields)) {
    emitByName(tokens, "T,HOLD", 2, pack);
  }

  // ------------------------------------------------------------------
  // LINE 3: branch target OR condition test, then LCOUNT
  // ------------------------------------------------------------------

  if (fields.scond === 1) {
    // Condition test variant.
    tryEmit("COND", 3);
    if (fields.fSeq !== 0) {
      tryEmit("F_SEQ", 3);
    } else {
      emitByName(tokens, "F,JMP", 3, pack);
    }
    if (fields.fStk !== 0) {
      tryEmit("F_STK", 3);
    } else {
      emitByName(tokens, "F,HOLD", 3, pack);
    }
    // LCC (bits 11:8) is a 4-bit loop-counter compare value used by
    // some condition tests. It has no token; it's written as a raw
    // numeric literal in source, OR'd into bits 8-11. Emit as octal.
    if (fields.lcc !== 0) {
      const lccValue = fields.lcc << 8;
      tokens.push({
        text: toOctal(lccValue),
        field: "COND",
        line: 3,
      });
    }
    // SCOND and CONDENABL can be set simultaneously. Emit CONDENABL
    // after the condition test block in that case.
    if (fields.condEnabl === 1) {
      tokens.push({ text: "CONDENABL", field: "SPECIAL", line: 3 });
    }
  } else if (fields.condEnabl === 1) {
    // CONDENABL branch - emit target + CONDENABL keyword.
    emitBranchTarget(tokens, fields, symbols);
    tokens.push({ text: "CONDENABL", field: "SPECIAL", line: 3 });
  } else if (isBranchLikelyPresent(fields)) {
    // Plain branch target.
    emitBranchTarget(tokens, fields, symbols);
  }

  // Loop counter — on line 3 per RASK convention (appears after the
  // branch target: "CONT LCOUNT;").
  if (fields.loop === 1) {
    emitByName(tokens, "LCOUNT", 3, pack);
  }

  // Delay control (bits 27:26). Factory ROMs set these for instructions
  // that access slow hardware (memory bus, register file, segment regs).
  // RASK source doesn't encode them, but they're needed for bit-exact
  // roundtrip of factory ROM images.
  if (fields.csdelay27_26 !== 0) {
    tokens.push({
      text: `DELAY,${fields.csdelay27_26}`,
      field: "SPECIAL",
      line: 2,
    });
  }

  return {
    address,
    raw,
    label: symbols?.get(address),
    tokens,
    fields,
  };
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Mutable disassembly state passed through helper functions. */
export interface DisassemblyState {
  consumed: bigint;
}

export function emitRegister(
  out: EmittedToken[],
  category: "A_REG" | "B_REG",
  index: number,
  pack: DisassemblerPack,
  line: 1 | 2 | 3,
  state: DisassemblyState,
): void {
  // Named register form, e.g. "A,D" / "B,R7".
  const namedPrefix = category === "A_REG" ? "A," : "B,";
  const names = [
    "Z", "D", "P", "B", "L", "A", "T", "X",
    "STS", "R1", "R2", "R3", "R4", "R5", "R6", "R7",
  ];
  const name = namedPrefix + names[index]!;
  const token = pack.definitions.tokensByName.get(name);
  if (token) {
    out.push({ text: token.name, field: category, line });
    state.consumed |= token.encodingValue;
  }
}

export function emitByName(
  out: EmittedToken[],
  name: string,
  line: 1 | 2 | 3,
  pack: DisassemblerPack,
): void {
  const token = pack.definitions.tokensByName.get(name);
  if (!token) return;
  // Map the token's category to our EmittedToken field.
  out.push({ text: token.name, field: token.category, line });
}

function emitBranchTarget(
  out: EmittedToken[],
  fields: DecodedFields,
  symbols?: SymbolTable,
): void {
  const addr = fields.branchAddress;
  const label = symbols?.get(addr);
  out.push({
    text: label ?? toOctal(addr),
    field: "BRANCH",
    line: 3,
  });
}

/**
 * Decide whether the lower 12 bits look like a branch target vs an empty
 * field. Used to decide whether to emit T,JMP and a branch target.
 */
function isBranchLikelyPresent(fields: DecodedFields): boolean {
  return (
    fields.scond === 0 &&
    (fields.csbit11_0 !== 0 || fields.csbit20 === 1 || fields.tSeq === 0)
  );
}

/**
 * Does the current instruction actually consume an A-operand?
 *
 * Returns true when:
 *   - A non-trivial ALU operation exists (aluI != 0) AND its matching
 *     ALUF token requires an A operand
 *   - The IDBS source reads from a register file path that uses A (BMG,
 *     REG, AARG)
 *   - The COMM code uses A for register-file addressing (EWRF, EPIC)
 */
function needsAop(fields: DecodedFields, pack: DisassemblerPack): boolean {
  const idbsNeedsA = [1, 5, 12].includes(fields.idbs);
  const commNeedsA = [3, 9].includes(fields.comm);
  if (idbsNeedsA || commNeedsA) return true;

  // Only ask the ALUF token if the ALU is actually active.
  if (fields.aluI === 0) return false;
  const aluTokens = pack.definitions.tokensByCategory.get("ALUF") ?? [];
  for (const t of aluTokens) {
    const tokenAluI = Number((t.encodingValue >> 55n) & 0x1FFn);
    if (tokenAluI === fields.aluI && (t.requires === "A" || t.requires === "AB")) {
      return true;
    }
  }
  return false;
}

function needsBop(fields: DecodedFields, pack: DisassemblerPack): boolean {
  const idbsNeedsB = [5, 8].includes(fields.idbs);
  const commNeedsB = [3].includes(fields.comm);
  if (idbsNeedsB || commNeedsB) return true;

  if (fields.aluI === 0) return false;
  const aluTokens = pack.definitions.tokensByCategory.get("ALUF") ?? [];
  for (const t of aluTokens) {
    const tokenAluI = Number((t.encodingValue >> 55n) & 0x1FFn);
    if (tokenAluI === fields.aluI && (t.requires === "B" || t.requires === "AB")) {
      return true;
    }
  }
  return false;
}

/**
 * Convenience wrapper that disassembles an entire address-indexed map.
 */
export function disassembleMap(
  records: Map<number, bigint>,
  pack: DisassemblerPack,
  symbols?: SymbolTable,
): DisassembledInstruction[] {
  const addrs = [...records.keys()].sort((a, b) => a - b);
  return addrs.map((addr) =>
    disassembleWord(records.get(addr)!, addr, pack, symbols),
  );
}
