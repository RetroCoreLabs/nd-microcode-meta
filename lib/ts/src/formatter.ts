/**
 * 3-line assembly formatter.
 *
 * Takes a disassembled instruction and produces up to 3 lines of text
 * following the conventions in defs/format/assembly-format.yaml.
 *
 * Line 1 = register operands + ALU operation
 * Line 2 = IDB bus + command + true-path sequencing
 * Line 3 = branch target OR condition test (+ false-path sequencing)
 */

import { toOctal } from "./bitfield.js";
import type {
  DisassembledInstruction,
  DisplayLine,
  EmittedToken,
  FormattedInstruction,
} from "./types.js";

/** Options controlling the formatter output. */
export interface FormatOptions {
  /** Indentation for continuation lines (default: 10 spaces). */
  continuationIndent?: string;
  /** Column alignment for tokens within a line (default: false). */
  alignColumns?: boolean;
  /** Include the statement terminator ";" at end of last line (default: true). */
  includeTerminator?: boolean;
  /** If an instruction fits on one line, collapse (default: true). */
  collapseSingleLine?: boolean;
  /** Target model. Affects branch-address handling (ND-100 has 12-bit
   *  addresses with no bit-20 extension). */
  model?: "nd100" | "nd110" | "nd120";
}

const DEFAULTS: FormatOptions = {
  continuationIndent: "          ", // 10 spaces - matches RASK source
  alignColumns: false,
  includeTerminator: true,
  collapseSingleLine: true,
};

/**
 * Group emitted tokens by their assigned line (1, 2, or 3).
 */
function groupByLine(tokens: EmittedToken[]): Map<DisplayLine, EmittedToken[]> {
  const groups = new Map<DisplayLine, EmittedToken[]>([
    [1, []],
    [2, []],
    [3, []],
  ]);
  for (const t of tokens) {
    groups.get(t.line)!.push(t);
  }
  return groups;
}

/**
 * Render a group of tokens as a single line string.
 * Separates tokens by a single space.
 */
function renderLine(tokens: EmittedToken[]): string {
  return tokens.map((t) => t.text).join(" ");
}

/**
 * Format a disassembled instruction into display lines.
 */
export function formatInstruction(
  instr: DisassembledInstruction,
  options: FormatOptions = {},
): FormattedInstruction {
  const opts = { ...DEFAULTS, ...options };
  const groups = groupByLine(instr.tokens);

  const line1 = renderLine(groups.get(1)!);
  const line2 = renderLine(groups.get(2)!);
  const line3 = renderLine(groups.get(3)!);

  const nonEmpty = [line1, line2, line3].filter((l) => l.length > 0);
  if (nonEmpty.length === 0) {
    // Nothing visible - emit a placeholder comment so the address is tracked.
    return {
      address: instr.address,
      lines: [opts.includeTerminator ? ";" : ""],
      label: instr.label,
    };
  }

  // Collapse to single line if only one non-empty line exists.
  if (opts.collapseSingleLine && nonEmpty.length === 1) {
    const text = nonEmpty[0]! + (opts.includeTerminator ? ";" : "");
    return {
      address: instr.address,
      lines: [text],
      label: instr.label,
    };
  }

  // Multi-line: first line has no indent (caller may prefix label), rest indent.
  const lines: string[] = [];
  if (line1) lines.push(line1);
  if (line2) lines.push((lines.length === 0 ? "" : opts.continuationIndent) + line2);
  if (line3) lines.push((lines.length === 0 ? "" : opts.continuationIndent) + line3);

  if (opts.includeTerminator && lines.length > 0) {
    lines[lines.length - 1] = lines[lines.length - 1]! + ";";
  }

  return {
    address: instr.address,
    lines,
    label: instr.label,
  };
}

/**
 * Format an entire list of instructions as a .uc-style source file.
 *
 * Sets address markers (`NNN/`) at discontinuities or at the start.
 * Emits labels on their own line.
 *
 * Defense-in-depth on bit 20
 * ---------------------------
 * The assembler's `translateInstruction` performs context-aware numeric
 * splitting (a plain numeric in a T,JMP context is split across bit 20
 * and bits 11:0). As a second safety net, the formatter ALSO synthesises
 * labels for branch targets at addresses >= 0x1000 that don't already
 * have a user-provided symbol. Either mechanism on its own produces
 * correct round-tripping; having both is harmless (a synthesised label
 * is resolved by label lookup, not by numeric splitting) and gives the
 * user control over output style.
 */
export function formatProgram(
  instructions: DisassembledInstruction[],
  options: FormatOptions = {},
): string {
  const opts = { ...DEFAULTS, ...options };
  const out: string[] = [];
  let expectedAddr = -1;

  // Pass 1: find branch-target addresses >= 0x1000 (i.e. those that need
  // bit 20 set) that do not already have a user label. Assign each a
  // synthesised name so the formatted output uses labels instead of
  // numerics for them.
  // Skip for ND-100: bit 20 is TC0 (timing), not a branch extension.
  // ND-100 branch addresses are 12 bits only.
  const syntheticLabels = new Map<number, string>();
  if (opts.model !== "nd100") {
    for (const instr of instructions) {
      const target = instr.fields.branchAddress;
      if (target >= 0x1000 && instr.fields.scond === 0) {
        if (!syntheticLabels.has(target)) {
          syntheticLabels.set(target, `_L${toOctal(target).padStart(6, "0")}`);
        }
      }
    }
  }
  const workingInstrs = instructions.map((instr) => {
    const synth = syntheticLabels.get(instr.address);
    const workingLabel = instr.label ?? synth;
    let workingTokens = instr.tokens;
    // If this instruction has a high branch target and we haven't seen
    // a user symbol for it, rewrite the numeric BRANCH token to use
    // the synthesised label name.
    if (instr.fields.scond === 0 && instr.fields.branchAddress >= 0x1000) {
      const synthTargetName = syntheticLabels.get(instr.fields.branchAddress);
      if (synthTargetName) {
        workingTokens = instr.tokens.map((t) => {
          if (t.field === "BRANCH" && /^[0-7]+$/.test(t.text)) {
            return { ...t, text: synthTargetName };
          }
          return t;
        });
      }
    }
    return { ...instr, label: workingLabel, tokens: workingTokens };
  });

  for (const instr of workingInstrs) {
    // Address marker at the start or on a gap.
    if (instr.address !== expectedAddr) {
      out.push("");
      out.push(toOctal(instr.address) + "/");
    }

    // Label on its own line.
    if (instr.label) {
      out.push(instr.label + ":");
    }

    const formatted = formatInstruction(instr, opts);
    for (const line of formatted.lines) {
      // First line gets a standard indent so everything lines up.
      // If the line is already indented from the multi-line path, leave as-is.
      if (line.startsWith(opts.continuationIndent ?? "")) {
        out.push(line);
      } else {
        out.push(opts.continuationIndent + line);
      }
    }

    expectedAddr = instr.address + 1;
  }

  return out.join("\n");
}
