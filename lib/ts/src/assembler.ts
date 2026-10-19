/**
 * Assembler core.
 *
 * Takes .uc source text and produces a binary .CODE image. The algorithm
 * is a direct port of ND110Compile/ND110Compile/Compiler.cs with small
 * clean-ups for TypeScript.
 *
 * Pass 1 (preprocess): walk the source line-by-line, strip comments,
 *   handle address markers (NNN/), collect labels, and accumulate tokens
 *   until a ";" terminator is found. Produces a list of parsed
 *   instructions + a label table.
 *
 * Pass 2 (translate): for each instruction, OR the encoding of every
 *   known token into a 64-bit value. Unknown tokens are tried as label
 *   names (resolved to the low 12 bits + bit 20) or numeric literals
 *   (OR'd into the low 16 bits).
 *
 * For ND-110 and ND-100, the final value is XOR'd with 0x0FC00000 to
 * convert from canonical assembled form into ROM storage form (bits 22-27
 * flipped). The ND-120 stores the canonical form.
 */

import { ND100_XOR_MASK, ND110_XOR_MASK } from "./bitfield.js";
import type { DefinitionPack, Model, Token } from "./types.js";

// ---------------------------------------------------------------------------
// Source maps
// ---------------------------------------------------------------------------

/** A label definition discovered during preprocess. */
export interface LabelDef {
  name: string;
  address: number;
  /** Source line number where the label was declared (1-based). */
  line: number;
}

/** A preprocessed instruction ready for translation. */
export interface ParsedInstruction {
  address: number;
  line: number;
  /** Whitespace-separated tokens as they appear in source. */
  args: string[];
}

/** Result of the preprocess pass. */
export interface SourceMap {
  instructions: ParsedInstruction[];
  labels: Map<string, number>;
  /** List of label defs (includes duplicate detection via errors). */
  labelDefs: LabelDef[];
}

/** A diagnostic produced during assembly (unknown token, duplicate label, etc). */
export interface AssemblyDiagnostic {
  severity: "error" | "warning";
  line: number;
  address?: number;
  message: string;
}

/** Result of the full assembly. */
export interface AssemblyResult {
  /** Address -> 64-bit microinstruction value (in the target model's storage form). */
  binary: Map<number, bigint>;
  /**
   * Every assembled instruction in source order, also when an address was
   * written twice (the C# compiler writes one record per instruction; the
   * `binary` map keeps only the last value per address).
   */
  records: Array<{ address: number; value: bigint }>;
  sourceMap: SourceMap;
  diagnostics: AssemblyDiagnostic[];
}

// ---------------------------------------------------------------------------
// Numeric literal parsing - matches TokensBase.ParseIntValue in C#.
// ---------------------------------------------------------------------------

/**
 * Parse a numeric literal per the C# assembler's conventions.
 *
 * Prefixes:
 *   d123 / D123 -> decimal
 *   0x1A / $1A  -> hexadecimal
 *   o12 / O12   -> octal (explicit)
 *   (no prefix) -> OCTAL by default (matches Norsk Data convention)
 *
 * Returns NaN if the string is not a valid numeric literal.
 */
export function parseNumericLiteral(s: string): number {
  const v = s.trim();
  if (!v) return NaN;
  if (v[0] === "d" || v[0] === "D") {
    const n = Number.parseInt(v.slice(1), 10);
    return Number.isNaN(n) ? NaN : n;
  }
  if (v.startsWith("0x") || v.startsWith("0X")) {
    const n = Number.parseInt(v.slice(2), 16);
    return Number.isNaN(n) ? NaN : n;
  }
  if (v[0] === "$") {
    const n = Number.parseInt(v.slice(1), 16);
    return Number.isNaN(n) ? NaN : n;
  }
  if (v[0] === "o" || v[0] === "O") {
    const n = Number.parseInt(v.slice(1), 8);
    return Number.isNaN(n) ? NaN : n;
  }
  // Default: octal. Reject strings with 8/9 digits.
  if (!/^[0-7]+$/.test(v)) return NaN;
  return Number.parseInt(v, 8);
}

// ---------------------------------------------------------------------------
// Pass 1: Preprocess.
// ---------------------------------------------------------------------------

/**
 * Preprocess .uc source text.
 *
 * - Strips comments (% ... EOL)
 * - Normalises ", " and " ," to "," (tokens like "A,D" may have stray spaces)
 * - Handles address markers (NNN/)
 * - Collects labels (LABEL:) and their addresses
 * - Accumulates tokens until ";" terminates an instruction
 */
export function preprocess(source: string): SourceMap {
  const labels = new Map<string, number>();
  const labelDefs: LabelDef[] = [];
  const instructions: ParsedInstruction[] = [];

  let address = 0;
  let pending = ""; // accumulates multi-line instruction body
  let pendingLine = 0;

  const lines = source.replace(/\r/g, "").split("\n");
  for (let lineIdx = 0; lineIdx < lines.length; lineIdx++) {
    const lineNo = lineIdx + 1;
    // The C# compiler trims the line first.
    let line = lines[lineIdx]!.trim();

    // Normalise comma spacing - "A , D" and "A, D" both become "A,D".
    line = line.replace(/ ,/g, ",").replace(/, /g, ",");

    // Strip comments (% to end of line).
    const pctIdx = line.indexOf("%");
    if (pctIdx >= 0) line = line.slice(0, pctIdx);

    // Address marker (NNN/ sets current address).
    const slashIdx = line.indexOf("/");
    if (slashIdx >= 0) {
      const addrText = line.slice(0, slashIdx).trim();
      const parsed = parseNumericLiteral(addrText);
      if (!Number.isNaN(parsed) && parsed >= 0) {
        address = parsed;
      }
      line = line.slice(slashIdx + 1);
    }

    // Labels (LABEL: within the first 30 chars).
    const colonIdx = line.indexOf(":");
    if (colonIdx >= 0 && colonIdx < 30) {
      const name = line.slice(0, colonIdx).trim();
      if (name) {
        if (!labels.has(name)) {
          labels.set(name, address);
          labelDefs.push({ name, address, line: lineNo });
        }
        // If label redefined, we keep the first one (matches C# behaviour
        // of "addLabelAndAddress" which may or may not overwrite).
      }
      line = line.slice(colonIdx + 1);
    }

    // If we're starting a new instruction, remember the start line.
    if (pending.trim() === "") pendingLine = lineNo;
    pending += " " + line;

    // Instruction terminator. Same rule as Compiler.Preprosess in C#: the
    // instruction ends at the first LINE that has a ';' (not as its very
    // first character); every item of that line is part of the instruction,
    // also the items after the ';' (3-line format: "COND,LC=0;   T,NEXT").
    if (line.indexOf(";") > 0) {
      const args = pending
        .split(";")
        .join("")
        .split(/\s+/)
        .map((s) => s.trim())
        .filter((s) => s.length > 0);
      instructions.push({
        address,
        line: pendingLine || lineNo,
        args,
      });
      address = (address + 1) & 0xFFFF;
      pending = "";
      pendingLine = lineNo;
    }
  }

  return { instructions, labels, labelDefs };
}

// ---------------------------------------------------------------------------
// Pass 2: Translate.
// ---------------------------------------------------------------------------

/**
 * Tokens that indicate the instruction uses the low 13 bits as a branch
 * target address. In that context, a numeric literal is split across
 * bit 20 and bits 11:0; otherwise it is OR'd as 16-bit data.
 *
 * Deliberate exclusions
 * ---------------------
 *   - T,RETURN uses the return stack, not the low bits. Numerics there
 *     are data (see RASK addr 0o4752).
 *   - CONDENABL by itself doesn't guarantee the low bits are a branch
 *     target - combined with T,NEXT and IDBS,ARG, numerics are data
 *     (see RASK addr 0o1535). When CONDENABL is paired with T,JMP, the
 *     T,JMP token alone puts us in jump context.
 */
const JUMP_CONTEXT_TOKENS = new Set([
  "T,JMP",
  "T,JMP0-3",
  "T,JMPAOPR",
]);

/**
 * Translate a single preprocessed instruction into its 64-bit canonical value.
 *
 * Label references are resolved to a 13-bit address and split across
 * bit 20 (high) and bits 11:0 (low). This matches the reference C#
 * compiler.
 *
 * Numeric literals behave context-dependently:
 *
 *   - When the instruction contains a "jump context" token (T,JMP /
 *     T,RETURN / T,JMP0-3 / T,JMPAOPR / CONDENABL) AND no COND,xxx test
 *     is active (SCOND=0), a numeric 0..0x1FFF is treated as a branch
 *     target. Bit 12 of the numeric is split out to bit 20 of the word.
 *     This makes `T,JMP 14000;` produce the same bits as `T,JMP SOMEADDR;`
 *     where SOMEADDR is a label at octal 14000.
 *
 *   - Otherwise (T,NEXT, SCOND=1, or no jump context), the numeric is
 *     OR'd into bits 15:0 as data. This preserves the semantics of
 *     instructions like `IDBS,ARG T,NEXT 14000;` where the 16-bit value
 *     is loaded onto the internal data bus.
 *
 * The reference C# compiler does NOT perform this context-aware split;
 * it always OR's numerics into the low 16 bits. Our behaviour is a
 * correctness fix for cases where factory ROMs contain jumps to
 * hard-coded numeric addresses >= 0o10000 (disassembly of which cannot
 * reliably use labels when no symbol table is available).
 */
export function translateInstruction(
  instr: ParsedInstruction,
  pack: DefinitionPack,
  labels: Map<string, number>,
  diagnostics: AssemblyDiagnostic[],
  /**
   * ND-110/ND-120: a branch address has 13 bits, the 13th goes to bit 20.
   * ND-100: false. The branch address has 12 bits and bit 20 is the timing
   * bit TC0, so a label or a number never touches bit 20.
   */
  wideBranch = true,
): bigint {
  // Pre-scan to determine jump-context vs data-context for numerics.
  let isJumpContext = false;
  let hasCondToken = false;
  for (const arg of instr.args) {
    if (JUMP_CONTEXT_TOKENS.has(arg)) isJumpContext = true;
    if (arg.startsWith("COND,")) hasCondToken = true;
  }
  // SCOND=1 (indicated by any COND,xxx) reinterprets the low 12 bits as
  // condition fields; numerics there are LCC values, not addresses.
  const splitNumerics = isJumpContext && !hasCondToken;

  let value = 0n;
  for (const arg of instr.args) {
    const token = pack.tokensByName.get(arg);
    if (token) {
      value |= token.encodingValue;
      continue;
    }
    // DELAY,N — sets bits 27:26 (CSDELAY timing control).
    // Not a YAML token; emitted by the disassembler for factory ROMs.
    const delayMatch = arg.match(/^DELAY,(\d)$/);
    if (delayMatch) {
      const dv = parseInt(delayMatch[1], 10);
      value |= BigInt(dv & 3) << 26n;
      continue;
    }
    if (labels.has(arg)) {
      const addr = labels.get(arg)!;
      value |= BigInt(addr & 0xFFF);
      if (wideBranch) value |= BigInt((addr >> 12) & 0x1) << 20n;
      continue;
    }
    const numeric = parseNumericLiteral(arg);
    if (!Number.isNaN(numeric)) {
      if (splitNumerics && !wideBranch && numeric >= 0 && numeric <= 0xFFF) {
        // ND-100: 12-bit branch target, bits 11:0 only.
        value |= BigInt(numeric & 0xFFF);
      } else if (splitNumerics && wideBranch && numeric >= 0 && numeric <= 0x1FFF) {
        // Treat as 13-bit branch target: split bit 12 to bit 20.
        value |= BigInt(numeric & 0xFFF);
        value |= BigInt((numeric >> 12) & 0x1) << 20n;
      } else {
        value |= BigInt(numeric & 0xFFFF);
      }
      continue;
    }
    // Matches the C# Compiler's LogUnknownToken() behaviour - the token
    // is silently ignored and a warning is recorded. This is important for
    // source files that contain OCR-recovered quirks like "B,177777" in
    // RASK at address 0o1754 (a deliberate workaround documented in the
    // .uc source).
    diagnostics.push({
      severity: "warning",
      line: instr.line,
      address: instr.address,
      message: `Unknown token: "${arg}" (ignored)`,
    });
  }
  return value;
}

// ---------------------------------------------------------------------------
// Top-level assembly.
// ---------------------------------------------------------------------------

/** Options controlling the assembler output. */
export interface AssembleOptions {
  /** Target model. Default: nd110. */
  model?: Model;
}

/**
 * Assemble a .uc source string into a binary map.
 *
 * For ND-110 and ND-100, the binary values are already in ROM storage form
 * (with bits 22-27 flipped relative to canonical). For ND-120 they are the
 * canonical form.
 */
export function assembleSource(
  source: string,
  pack: DefinitionPack,
  options: AssembleOptions = {},
): AssemblyResult {
  const model: Model = options.model ?? "nd110";
  const sourceMap = preprocess(source);
  const diagnostics: AssemblyDiagnostic[] = [];
  const binary = new Map<number, bigint>();
  const records: Array<{ address: number; value: bigint }> = [];

  for (const instr of sourceMap.instructions) {
    let value = translateInstruction(instr, pack, sourceMap.labels, diagnostics, model !== "nd100");
    // ND-110 and ND-100 store bits 22-27 inverted (ND-06.031.1 chapter 4,
    // ND-06.018.01 "Writing the Microprogram"): XOR converts canonical ->
    // ROM storage form. The ND-120 stores the canonical form.
    if (model === "nd110") {
      value ^= ND110_XOR_MASK;
    } else if (model === "nd100") {
      value ^= ND100_XOR_MASK;
    }
    if (binary.has(instr.address)) {
      diagnostics.push({
        severity: "warning",
        line: instr.line,
        address: instr.address,
        message: `Duplicate address 0o${instr.address.toString(8)} - overwriting previous definition`,
      });
    }
    binary.set(instr.address, value);
    records.push({ address: instr.address, value });
  }

  return { binary, records, sourceMap, diagnostics };
}

// ---------------------------------------------------------------------------
// Binary serialisation (write .CODE format).
// ---------------------------------------------------------------------------

/**
 * Serialise a binary map to .CODE format (10 bytes per record: 2-byte
 * little-endian address + 8-byte little-endian value).
 *
 * Records are emitted in ascending address order.
 */
export function binaryToCodeBytes(binary: Map<number, bigint>): Uint8Array {
  const addrs = [...binary.keys()].sort((a, b) => a - b);
  const out = new Uint8Array(addrs.length * 10);
  let pos = 0;
  for (const addr of addrs) {
    out[pos++] = addr & 0xFF;
    out[pos++] = (addr >> 8) & 0xFF;
    let v = binary.get(addr)!;
    for (let j = 0; j < 8; j++) {
      out[pos++] = Number(v & 0xFFn);
      v >>= 8n;
    }
  }
  return out;
}

/**
 * Serialise records in the given order to .CODE format, exactly as the C#
 * compiler writes them (one record per instruction, source order, duplicate
 * addresses included).
 */
export function recordsToCodeBytes(
  records: ReadonlyArray<{ address: number; value: bigint }>,
): Uint8Array {
  const out = new Uint8Array(records.length * 10);
  let pos = 0;
  for (const { address, value } of records) {
    out[pos++] = address & 0xff;
    out[pos++] = (address >> 8) & 0xff;
    let v = value;
    for (let j = 0; j < 8; j++) {
      out[pos++] = Number(v & 0xffn);
      v >>= 8n;
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// Helpers for the disassembler -> assembler round trip.
// ---------------------------------------------------------------------------

/**
 * Translate an instruction from an array of pre-selected tokens (no label
 * lookup, no numeric parsing). Used by the round-trip tests.
 */
export function translateFromTokens(tokens: Token[]): bigint {
  let value = 0n;
  for (const t of tokens) value |= t.encodingValue;
  return value;
}
