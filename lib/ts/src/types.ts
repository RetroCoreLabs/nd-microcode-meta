/**
 * Core type definitions for the ND-100/110/120 microcode library.
 *
 * These types mirror the YAML canonical definitions under defs/ and
 * are the public surface of the library.
 */

/**
 * Supported ND-1x0 microcode model (64-bit word handled by the original
 * assembler/disassembler code). "nd120-dly" is the ND-120 table with the
 * three register-select tokens B,P / B,B / B,X without the DLY1 bit (the
 * C# ND120Tokens.AdjustTokensForVersionL() values); see
 * defs/tokens/nd120-tokens.yaml `variant_overrides`.
 */
export type Model = "nd100" | "nd110" | "nd120" | "nd120-dly";

/** Wide-word models handled by the *-wide modules (NORD-10, ND-500, ND-5000). */
export type WideModel = "nd10" | "nd500" | "nd5000";

/** Every model name the library knows (canonical spelling). */
export type AnyModel = Model | WideModel;

/** All canonical model names, in display order. */
export const ALL_MODELS: readonly AnyModel[] = [
  "nd10",
  "nd100",
  "nd110",
  "nd120",
  "nd120-dly",
  "nd500",
  "nd5000",
];

const MODEL_ALIASES: Readonly<Record<string, AnyModel>> = {
  nd10: "nd10",
  nord10: "nd10",
  "nord-10": "nd10",
  "nd-10": "nd10",
  nd100: "nd100",
  "nd-100": "nd100",
  nd110: "nd110",
  "nd-110": "nd110",
  nd120: "nd120",
  "nd-120": "nd120",
  "nd120-dly": "nd120-dly",
  "nd-120-dly": "nd120-dly",
  nd120l: "nd120-dly",
  "nd120-l": "nd120-dly",
  "nd-120-l": "nd120-dly",
  nd500: "nd500",
  "nd-500": "nd500",
  nd5000: "nd5000",
  "nd-5000": "nd5000",
};

/**
 * Turn the text of a model name (directive, setting, command line) into the
 * canonical model name. Case does not matter. Returns undefined for text
 * that is not a known name. Every place that reads a model name uses this.
 */
export function normaliseModelName(text: string | undefined): AnyModel | undefined {
  if (text === undefined) return undefined;
  return MODEL_ALIASES[text.trim().toLowerCase()];
}

/** True for the models the 64-bit assembler/disassembler code handles. */
export function isNd1x0Model(model: AnyModel): model is Model {
  return (
    model === "nd100" ||
    model === "nd110" ||
    model === "nd120" ||
    model === "nd120-dly"
  );
}

/** True for NORD-10, ND-500 and ND-5000. */
export function isWideModel(model: AnyModel): model is WideModel {
  return model === "nd10" || model === "nd500" || model === "nd5000";
}

/** Token category - maps directly to the `category` field in token YAML. */
export type TokenCategory =
  | "A_REG"
  | "B_REG"
  | "AB_REG"
  | "PIC"
  | "ALUF"
  | "ALUD"
  | "ALUM"
  | "STS"
  | "CRY"
  | "MIS"
  | "IDBS"
  | "COMM"
  | "T_SEQ"
  | "T_STK"
  | "F_SEQ"
  | "F_STK"
  | "COND"
  | "SPECIAL"
  | "UNKNOWN";

/** Line number in the 3-line assembly format. */
export type DisplayLine = 1 | 2 | 3;

/**
 * A single microcode token - e.g. "ALUF,PASSD", "IDBS,ALU", "T,JMP".
 *
 * `encodingOctal` holds the 4 octal strings (w4, w3, w2, w1) as they
 * appear in the C# source and YAML. `encodingValue` is the combined
 * 64-bit integer as a BigInt.
 */
export interface Token {
  /** Token name as it appears in .uc source, e.g. "ALUF,PASSD". */
  name: string;
  /** Which category of the microinstruction this token affects. */
  category: TokenCategory;
  /** Which line of the 3-line format this token appears on. */
  displayLine: DisplayLine;
  /** Human-readable description (from the original C# source). */
  description: string;
  /** 4 octal strings: (w4, w3, w2, w1). */
  encodingOctal: readonly [string, string, string, string];
  /** Combined 64-bit value: (w4<<48) | (w3<<32) | (w2<<16) | w1. */
  encodingValue: bigint;
  /** Models this token is available in. */
  models: readonly Model[];
  /** True if this token only exists on ND-120 (not ND-110). */
  nd120Only: boolean;
  /** Which operand slot this token "provides" (A, B, AB, PIC, ...). */
  provides?: string;
  /** Which operand slot this token requires (A, B, AB, PIC, ...). */
  requires?: string;
}

/** A bit-field definition from a fields YAML file. */
export interface FieldDef {
  /** Field name, e.g. "ALUI", "IDBS", "COMM". */
  name: string;
  /** High and low bit positions (inclusive), e.g. [41, 37] for IDBS. */
  bits: readonly [number, number];
  /** Width in bits (derived from bits, but cached for convenience). */
  width: number;
  /** Description of the field. */
  description: string;
  /** Default value (usually 0). */
  default: number;
}

/**
 * A decoded microinstruction - the raw bits split into named fields.
 * All values are small integers (not BigInt).
 */
export interface DecodedFields {
  /** The full 64-bit raw value. */
  raw: bigint;
  /** Address of this microinstruction in the control store. */
  address: number;

  // ALU control (upper bits)
  aluI: number;       // bits 63:55 - ALU function composite
  aluSts: number;     // bits 54:53 - ALU status / shift mode
  rasel: number;      // bits 52:51 - A-operand select
  xrf: number;        // bit 50 - extended register file
  rbsel: number;      // bits 49:48 - B-operand select
  cin: number;        // bits 47:46 - carry input
  alum: number;       // bits 45:44 - ALU mode
  mis: number;        // bits 43:42 - shift mode (when ALUM=MIC)

  // Bus / command
  idbs: number;       // bits 41:37 - IDB source
  comm: number;       // bits 36:32 - command

  // True-path sequencing
  tSeq: number;       // bits 31:30 - true-path sequence
  tStk: number;       // bits 29:28 - true-path stack

  // Timing / control bits
  csdelay27_26: number; // bits 27:26
  vect: number;         // bit 25
  scond: number;        // bit 24 - set condition
  condEnabl: number;    // bit 23 - CONDENABL
  loop: number;         // bit 22 - LCOUNT
  csdelay21: number;    // bit 21
  csbit20: number;      // bit 20 - high bit of branch address

  // Operands
  bop: number;        // bits 19:16 - B-operand register index
  aop: number;        // bits 15:12 - A-operand register index

  // Lower 12 bits (dual meaning - SCOND selects)
  /** When SCOND=0: 12-bit branch address. */
  csbit11_0: number;
  /** When SCOND=1: loop counter compare field. */
  lcc: number;
  /** When SCOND=1: test selector (chooses which condition to test). */
  tsel: number;
  /** When SCOND=1: false-path sequence. */
  fSeq: number;
  /** When SCOND=1: false-path stack. */
  fStk: number;

  /** Effective 13-bit branch address: (csbit20 << 12) | csbit11_0. */
  branchAddress: number;
}

/** A label/symbol in the microcode (from a .SYMBOLS.TXT file). */
export interface Symbol {
  address: number;
  name: string;
}

/** Map from address to symbol name. */
export type SymbolTable = ReadonlyMap<number, string>;

/**
 * A single token emitted by the disassembler - carries both the
 * text representation and metadata for rendering.
 */
export interface EmittedToken {
  /** Text to display, e.g. "ALUF,PASSD" or "0o170". */
  text: string;
  /** Which field this came from (for highlighting). */
  field: TokenCategory | "BRANCH" | "COMMENT";
  /** Which line (1-3) of the 3-line format this goes on. */
  line: DisplayLine;
}

/** A disassembled microinstruction ready to be formatted or rendered. */
export interface DisassembledInstruction {
  address: number;
  raw: bigint;
  label?: string;
  tokens: EmittedToken[];
  fields: DecodedFields;
}

/** Result of formatting an instruction into textual lines. */
export interface FormattedInstruction {
  address: number;
  /** Up to 3 lines of text (may be fewer if collapsed). */
  lines: string[];
  /** Optional label printed before the instruction. */
  label?: string;
}

/** The canonical definition pack loaded from YAML. */
export interface DefinitionPack {
  model: Model;
  tokens: Token[];
  tokensByName: ReadonlyMap<string, Token>;
  /** Tokens grouped by category for fast lookup during decode. */
  tokensByCategory: ReadonlyMap<TokenCategory, Token[]>;
  /** Field definitions keyed by name. */
  fields: ReadonlyMap<string, FieldDef>;
}
