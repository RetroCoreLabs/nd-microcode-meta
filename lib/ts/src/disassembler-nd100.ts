/**
 * ND-100 microinstruction disassembler.
 *
 * ND-100's microinstruction word differs from ND-110/120 in four
 * structural ways that can't be expressed as simple value-table swaps:
 *
 *   1. Bits 20-21 are a 2-bit cycle-timing selector (TC = FAST / NORM /
 *      SLOW / WAIT), rendered as CYCL,* tokens. Bit 20 is NOT a branch-
 *      address extension on ND-100, so the effective branch target is
 *      only 12 bits wide.
 *
 *   2. Bits 25/26/27 are three active-low branch-mode select lines
 *      (VECT0 / SLWCS0 / MAPJ0) that combine with MIS to pick the
 *      source of the lower 4 bits of the next-microaddress. This function
 *      takes the CANONICAL (active high) word, where "VECT asserted"
 *      means bit 25 set. The PROMs hold bits 22-27 inverted (ND-06.018.01,
 *      "Writing the Microprogram": "bits 22 - 27 are inverted after the
 *      word is assembled"), so words read from the PROMs or from an ND-100
 *      .CODE file must first be XOR'ed with ND100_XOR_MASK (0x0FC00000),
 *      for example with parseCodeBytes(bytes, { nd100XorFlip: true }). See
 *      reference/roms/ND100/README.md, "Stored form (XOR)".
 *
 *   3. IDBS is a 4-bit field at bits 37-40 with a separate SEXT modifier
 *      at bit 41 (vs ND-110's 5-bit IDBS at 37-41). The GPR-with-SEXT
 *      composite is a named token in nd100-tokens.yaml; other IDBS
 *      sources with SEXT set are rendered as two tokens (IDBS,XXX +
 *      SEXT). Currently the ND-100 token YAML only lists the
 *      IDBS,GPR,SEXT composite; the standalone SEXT bit can still be
 *      carried through because the bit is not part of the 4-bit IDBS
 *      field mask.
 *
 *   4. MIS (bits 42-43) has three context-dependent roles:
 *        - shift mode when ALUM = 0b11 (ALUM,IR / the shift-instruction
 *          mode; MIS picks ROT/ZIN/LIN/ASH)
 *        - page mode when COMM is a memory-op (EXRQ/IRDRQ/RDRQ/WRRQ:
 *          MIS picks FETCH/PT/APT/HOLD)
 *        - vect-operand source when VECT0 is asserted (bit 25 set in
 *          canonical): MIS picks IR[0-3] / IR[8-10] / ALD / AOP and is
 *          already embedded in the T,JMP0-3 / T,JMP8-10 / T,JMPALD /
 *          T,JMPAOPR tokens.
 *
 * The ND-100 helper PROMs (decode PLA at row b18-b20; sequencer at
 * d17-d20 + c17-c20 on CX variants) are NOT consulted here - they
 * live in separate .CODE files and affect macro-opcode entry
 * labelling and runtime next-address selection respectively, neither
 * of which changes the static decoding of the main microword.
 */

import { decodeFields, toOctal } from "./bitfield.js";
import type {
  DecodedFields,
  DisassembledInstruction,
  EmittedToken,
  SymbolTable,
  Token,
  TokenCategory,
} from "./types.js";
import {
  findExactABReg,
  findExactRegToken,
  findTokenInCategory,
  emitByName,
  emitRegister,
} from "./disassembler-nd110.js";
import type {
  DisassemblerPack,
  DisassemblyState,
} from "./disassembler-nd110.js";

/**
 * ND-100 timing/delay bits that carry no logical meaning for decoding.
 * On ND-100 there are none of these - every bit in 22-27 has semantic
 * meaning (LCOUNT / CONDENABL / SCOND / VECT0 / SLWCS0 / MAPJ0), and
 * bits 20-21 are the TC cycle-timing selector.
 *
 * This mask is kept at zero so the generic token-consumption tracking
 * in findTokenInCategory does not mis-attribute bits as "timing-only".
 */
const ND100_TIMING_MASK = 0x0n;

/** Bit masks for ND-100-specific field positions. */
const TC_MASK = 0x0000_0000_0030_0000n;  // bits 21-20
const LCOUNT_BIT = 1n << 22n;
const CONDENABL_BIT = 1n << 23n;
const SCOND_BIT = 1n << 24n;
const VECT_BIT = 1n << 25n;
const SLWCS_BIT = 1n << 26n;
const MAPJ_BIT = 1n << 27n;
const SEXT_BIT = 1n << 41n;

/**
 * Disassemble a single ND-100 microinstruction word.
 *
 * The `raw` BigInt is the 64-bit word as combined from the PROM chips (see
 * nd100-proms.ts), in the form the ND-100 token table describes. No XOR is
 * applied by this function.
 */
export function disassembleWord(
  raw: bigint,
  address: number,
  pack: DisassemblerPack,
  symbols?: SymbolTable,
): DisassembledInstruction {
  const fields = decodeFields(raw, address);
  const tokens: EmittedToken[] = [];
  const state: DisassemblyState = { consumed: 0n };

  const tryEmit = (
    cat: TokenCategory,
    line?: 1 | 2 | 3,
  ): Token | undefined => {
    const meta = pack.categoryMeta.get(cat);
    if (!meta) return undefined;
    const tok = findTokenInCategory(meta, raw, state.consumed);
    if (!tok) return undefined;
    state.consumed |= tok.encodingValue & ~ND100_TIMING_MASK;
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

  // COMM,EPIC means AOP holds a PIC command, not a register index.
  const isEpic = fields.comm === 0b01001; // 0o11 on ND-100 = EPIC

  // AB,xxx scratch-register pairs combine AOP+BOP.
  const abToken = findExactABReg(pack, raw);
  if (abToken) {
    tokens.push({ text: abToken.name, field: "AB_REG", line: 1 });
    state.consumed |= abToken.encodingValue;
  }

  if (!abToken && isEpic) {
    tryEmit("PIC", 1);
  }

  if (!isEpic) {
    const aMeta = pack.categoryMeta.get("A_REG");
    if (aMeta) {
      const aTok = findExactRegToken("A_REG", aMeta, raw, state.consumed);
      if (aTok) {
        tokens.push({ text: aTok.name, field: "A_REG", line: 1 });
        state.consumed |= aTok.encodingValue;
      } else if (!abToken && (fields.aop !== 0 || nd100NeedsAop(fields, pack))) {
        emitRegister(tokens, "A_REG", fields.aop, pack, 1, state);
      }
    }
  }

  const bMeta = pack.categoryMeta.get("B_REG");
  if (bMeta) {
    const bTok = findExactRegToken("B_REG", bMeta, raw, state.consumed);
    if (bTok) {
      tokens.push({ text: bTok.name, field: "B_REG", line: 1 });
      state.consumed |= bTok.encodingValue;
    } else if (!abToken && (fields.bop !== 0 || nd100NeedsBop(fields, pack))) {
      emitRegister(tokens, "B_REG", fields.bop, pack, 1, state);
    }
  }

  // ALU function (composite of aluI + cin).
  tryEmit("ALUF", 1);

  // ALU destination.
  tryEmit("ALUD", 1);

  if (fields.aluSts !== 0) tryEmit("STS", 1);
  if (fields.cin !== 0) tryEmit("CRY", 1);
  if (fields.alum !== 0) tryEmit("ALUM", 1);

  // EN_EXT (= XRF on ND-110) at bit 50. Emit when set.
  if (fields.xrf !== 0) {
    emitByName(tokens, "EN_EXT", 1, pack);
    state.consumed |= (1n << 50n);
  }

  // ------------------------------------------------------------------
  // LINE 2: IDB + command + sequencing + timing
  // ------------------------------------------------------------------

  // IDBS source. On ND-100 this is a 4-bit field at bits 37-40 with
  // SEXT as a separate modifier at bit 41. The generic category scanner
  // can't handle this directly because ND-110's 5-bit IDBS mask would
  // absorb the SEXT bit. Do custom matching:
  //   (a) If IDBS value is 0b0010 (GPR) AND SEXT is set, emit the
  //       composite IDBS,GPR,SEXT (5-bit encoding).
  //   (b) Otherwise, emit the 4-bit IDBS,* token matching bits 37-40
  //       exactly (ignoring SEXT in the match).
  //   (c) If SEXT remains unconsumed, no standalone SEXT token exists
  //       in the ND-100 tokens YAML today - carry the bit as-is.
  {
    const idbsValue = Number((raw >> 37n) & 0xFn);
    const sextSet = (raw & SEXT_BIT) !== 0n;
    const idbsMeta = pack.categoryMeta.get("IDBS");
    if (idbsMeta) {
      const IDBS_4BIT_MASK = 0x0000_01E0_0000_0000n; // bits 40:37
      const rawField = raw & IDBS_4BIT_MASK;

      if (idbsValue === 0b0010 && sextSet) {
        const composite =
          pack.definitions.tokensByName.get("IDBS,GPR,SEXT");
        if (composite) {
          tokens.push({ text: composite.name, field: "IDBS", line: 2 });
          state.consumed |= composite.encodingValue;
        }
      } else if (idbsValue !== 0) {
        // Find the 4-bit-exact IDBS token that does NOT also set SEXT.
        for (const t of idbsMeta.tokens) {
          if ((t.encodingValue & SEXT_BIT) !== 0n) continue;
          if ((t.encodingValue & IDBS_4BIT_MASK) === rawField) {
            tokens.push({ text: t.name, field: "IDBS", line: 2 });
            state.consumed |= t.encodingValue;
            break;
          }
        }
      }
      // If SEXT is still set but hasn't been consumed by the
      // IDBS,GPR,SEXT composite above, emit the standalone SEXT
      // token so the bit round-trips through the assembler.
      if (sextSet && (state.consumed & SEXT_BIT) === 0n) {
        const sextTok = pack.definitions.tokensByName.get("SEXT");
        if (sextTok) {
          tokens.push({ text: "SEXT", field: "SPECIAL", line: 2 });
          state.consumed |= sextTok.encodingValue;
        }
      }
    }
  }

  // COMM command.
  tryEmit("COMM", 2);

  // MIS - role-aware disambiguation. Defer emission until AFTER T_SEQ
  // decoding, because the vectored-jump composites (T,JMP0-3 / JMP8-10
  // / JMPALD / JMPAOPR) already embed the MIS bits and we must not
  // double-cover them. We re-visit MIS below after T_SEQ emission.

  // True-path sequence + stack. Detect the vectored-jump composite
  // (VECT0 set + MIS role = vect) first, since the T,JMP* tokens
  // already embed the MIS bits.
  let tSeqTok: Token | undefined;
  const vectActive = (raw & VECT_BIT) !== 0n;
  if (vectActive) {
    // Pick the T,JMP* vectored variant based on MIS value.
    const name = pickVectJmpToken(fields.mis);
    if (name) {
      const tok = pack.definitions.tokensByName.get(name);
      if (tok) {
        tokens.push({ text: tok.name, field: "T_SEQ", line: 2 });
        state.consumed |= tok.encodingValue;
        tSeqTok = tok;
      }
    }
  }
  if (!tSeqTok) {
    tSeqTok = tryEmit("T_SEQ", 2);
    if (!tSeqTok && nd100IsBranchLikelyPresent(fields)) {
      emitByName(tokens, "T,JMP", 2, pack);
      const tJmp = pack.definitions.tokensByName.get("T,JMP");
      if (tJmp) tSeqTok = tJmp;
    }
  }

  // A vectored jump token (T,JMP0-3 and the like) does not cover bits 31:30,
  // the T_SEQ field. Emit T,NEXT / T,RETURN as well, otherwise those bits
  // are lost: 1201 of the 2048 words of the 3033S PROMs have them
  // (1052 with bit 31, 149 with bit 30, all with VECT set).
  if (tSeqTok && Number((raw >> 30n) & 3n) !== 0) {
    tryEmit("T_SEQ", 2);
  }

  // MAPJ standalone (bit 27). Emitted as T,MAPJ token.
  if ((raw & MAPJ_BIT) !== 0n && (state.consumed & MAPJ_BIT) === 0n) {
    emitByName(tokens, "T,MAPJ", 2, pack);
    state.consumed |= MAPJ_BIT;
  }

  // MIS (bits 42-43) — now resolved AFTER T_SEQ. If the vect-variant
  // of T,JMP* has already consumed the MIS bits, skip. Otherwise pick
  // a MIS token by role, or by raw-bits-match as a fallback so we
  // don't lose bits in round-trip.
  const MIS_MASK = 0x0000_0C00_0000_0000n; // bits 43:42
  const rawMisBits = raw & MIS_MASK;
  const misBitsConsumed = (state.consumed & MIS_MASK) === rawMisBits;
  if (rawMisBits !== 0n && !misBitsConsumed) {
    const misRole = classifyMisRole(fields, raw, state.consumed);
    let misTokenName = pickMisToken(fields.mis, misRole);
    if (!misTokenName) {
      // Role is "none" (MIS bits set but context doesn't indicate a
      // specific role). Pick the page-mode variant as a neutral choice
      // that preserves the bits; on ND-100 the page-mode and
      // shift-mode families share identical encodings for each MIS
      // value, so the assembler output is independent of which name
      // we pick.
      misTokenName = pickMisToken(fields.mis, "page");
    }
    if (misTokenName) {
      const tok = pack.definitions.tokensByName.get(misTokenName);
      if (tok) {
        tokens.push({
          text: tok.name,
          field: "MIS",
          line: misRole === "shift" ? 1 : 2,
        });
        state.consumed |= tok.encodingValue;
      }
    }
  }

  if (fields.tStk !== 0) {
    tryEmit("T_STK", 2);
  } else if (tSeqTok !== undefined || nd100IsBranchLikelyPresent(fields)) {
    emitByName(tokens, "T,HOLD", 2, pack);
  }

  // Control flags.
  if ((raw & LCOUNT_BIT) !== 0n) {
    emitByName(tokens, "LCOUNT", 2, pack);
    state.consumed |= LCOUNT_BIT;
  }

  // SLWCS standalone (bit 26). Signals "start load writable control
  // store"; the hardware ignores normal sequencing for this microword.
  if ((raw & SLWCS_BIT) !== 0n && (state.consumed & SLWCS_BIT) === 0n) {
    emitByName(tokens, "SLWCS", 2, pack);
    state.consumed |= SLWCS_BIT;
  }

  // Cycle timing: emit CYCL,* when TC field is non-zero. TC=00 is
  // FAST (or "default") and omitted.
  const tc = Number((raw & TC_MASK) >> 20n);
  if (tc !== 0) {
    const cyclName =
      tc === 0b01 ? "CYCL,NORM" :
      tc === 0b10 ? "CYCL,SLOW" :
      tc === 0b11 ? "CYCL,WAIT" :
      null;
    if (cyclName) {
      emitByName(tokens, cyclName, 2, pack);
      state.consumed |= (BigInt(tc) << 20n);
    }
  }

  // ------------------------------------------------------------------
  // LINE 3: branch target OR condition test
  // ------------------------------------------------------------------

  if ((raw & SCOND_BIT) !== 0n) {
    // Condition test path (SCOND asserted).
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
    // When a vectored jump is present (T,JMP0-3 etc.), bits[11:0]
    // serve dual purpose: they are BOTH condition fields AND the branch
    // base address.  Display the base address as a BRANCH target
    // (clickable) rather than a COND sub-field.
    if (vectActive) {
      // Branch base = bits[11:2] with low 2 replaced by LC at runtime.
      const branchBase = fields.csbit11_0 & ~0x3;
      if (branchBase !== 0) {
        // Exact address only: a label of another address would assemble to
        // another branch target (the 3033E-CX extension bank at 0o4000 and up
        // has its own words at addresses whose low 11 bits equal base words).
        const label = symbols?.get(branchBase);
        tokens.push({
          text: label ?? toOctal(branchBase),
          field: "BRANCH",
          line: 3,
        });
      }
    } else if (fields.lcc !== 0) {
      tokens.push({
        text: toOctal(fields.lcc << 8),
        field: "COND",
        line: 3,
      });
    }
    if ((raw & CONDENABL_BIT) !== 0n) {
      tokens.push({ text: "CONDENABL", field: "SPECIAL", line: 3 });
      state.consumed |= CONDENABL_BIT;
    }
  } else if ((raw & CONDENABL_BIT) !== 0n) {
    // CONDENABL branch - emit target + CONDENABL keyword. Branch
    // target is 12 bits on ND-100 (no bit-20 extension).
    emitNd100BranchTarget(tokens, fields, symbols);
    tokens.push({ text: "CONDENABL", field: "SPECIAL", line: 3 });
    state.consumed |= CONDENABL_BIT;
  } else if (nd100IsBranchLikelyPresent(fields)) {
    emitNd100BranchTarget(tokens, fields, symbols);
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
// ND-100-specific helpers
// ---------------------------------------------------------------------------

/**
 * Determine which role MIS is playing in this microinstruction:
 *   - "shift" if ALUM selects shift-instruction mode (ALUM = 0b11)
 *   - "page"  if COMM is a memory-op (EXRQ/IRDRQ/RDRQ/WRRQ)
 *   - "vect"  if VECT0 is asserted (bit 25 set in canonical form)
 *   - "none"  otherwise (MIS bits are set but context implies no role;
 *             default to page-mode as the most benign fallback)
 */
type MisRole = "shift" | "page" | "vect" | "none";

function classifyMisRole(
  fields: DecodedFields,
  raw: bigint,
  _consumed: bigint,
): MisRole {
  if (fields.alum === 0b11) return "shift";
  const comm = fields.comm;
  // ND-100 memory-op COMM codes (5-bit): EXRQ/IRDRQ = 0o30, DERQ = 0o31,
  // RDRQ = 0o34, WRRQ = 0o35. MIS selects the page-mode variant.
  if (comm === 0o30 || comm === 0o31 || comm === 0o34 || comm === 0o35) {
    return "page";
  }
  if ((raw & VECT_BIT) !== 0n) return "vect";
  return "none";
}

/** Pick the right MIS-role-specific token name. */
function pickMisToken(misValue: number, role: MisRole): string | undefined {
  if (role === "shift") {
    return ["", "MIS,ROT", "MIS,ZIN", "MIS,LIN"][misValue];
    // MIS=0 in shift context = arithmetic shift, no token (default).
  }
  if (role === "page") {
    return ["MIS,FETCH", "MIS,PT", "MIS,APT", "MIS,HOLD"][misValue];
  }
  // Vect role is handled through T,JMP0-3 / JMP8-10 / JMPALD / JMPAOPR
  // which encode MIS bits inline, so we don't emit a separate MIS,*.
  return undefined;
}

/** MIS-encoded T,JMP* variant for the vectored-jump composite. */
function pickVectJmpToken(misValue: number): string | undefined {
  return [
    "T,JMP0-3",
    "T,JMP8-10",
    "T,JMPALD",
    "T,JMPAOPR",
  ][misValue];
}

function nd100IsBranchLikelyPresent(fields: DecodedFields): boolean {
  // ND-100 branch target is 12 bits (no bit-20 extension - bit 20 is
  // TC0, bit 21 is TC1).
  return fields.csbit11_0 !== 0 || fields.tSeq === 0;
}

/** Emit a 12-bit branch target (ND-100) with label resolution. */
function emitNd100BranchTarget(
  out: EmittedToken[],
  fields: DecodedFields,
  symbols?: SymbolTable,
): void {
  const addr = fields.csbit11_0; // 12-bit target, ignore bit 20
  // Exact address only. An earlier version fell back to the label of
  // addr & 0x7FF (the ROM is 2K words), but the 3033E-CX has its own words in
  // the extension bank at 0o4000 and up, and a jump to 0o4057 is not a jump to
  // 0o57: the label of the base word assembled to a different branch target
  // (41 words of the 3033E-CX differed).
  const label = symbols?.get(addr);
  out.push({
    text: label ?? toOctal(addr),
    field: "BRANCH",
    line: 3,
  });
}

function nd100NeedsAop(fields: DecodedFields, pack: DisassemblerPack): boolean {
  const idbsNeedsA = [1, 5, 0o16].includes(fields.idbs);
  // COMM,EWRF (3) writes to (AOP, BOP); COMM,EPIC (0o11) uses A as
  // PIC command code.
  const commNeedsA = [0o3, 0o11].includes(fields.comm);
  if (idbsNeedsA || commNeedsA) return true;
  if (fields.aluI === 0) return false;
  const aluTokens = pack.definitions.tokensByCategory.get("ALUF") ?? [];
  for (const t of aluTokens) {
    const tokenAluI = Number((t.encodingValue >> 55n) & 0x1FFn);
    if (
      tokenAluI === fields.aluI &&
      (t.requires === "A" || t.requires === "AB")
    ) {
      return true;
    }
  }
  return false;
}

function nd100NeedsBop(fields: DecodedFields, pack: DisassemblerPack): boolean {
  const idbsNeedsB = [5, 0o10].includes(fields.idbs);
  const commNeedsB = [0o3].includes(fields.comm);
  if (idbsNeedsB || commNeedsB) return true;
  if (fields.aluI === 0) return false;
  const aluTokens = pack.definitions.tokensByCategory.get("ALUF") ?? [];
  for (const t of aluTokens) {
    const tokenAluI = Number((t.encodingValue >> 55n) & 0x1FFn);
    if (
      tokenAluI === fields.aluI &&
      (t.requires === "B" || t.requires === "AB")
    ) {
      return true;
    }
  }
  return false;
}

/** Convenience wrapper: disassemble every record in an address map. */
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
