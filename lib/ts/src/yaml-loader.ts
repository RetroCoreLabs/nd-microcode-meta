/**
 * YAML canonical definition loader.
 *
 * Loads the token, field, and format YAML files from defs/ and produces
 * a DefinitionPack ready for consumption by the disassembler/assembler.
 */

import { readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { load as yamlLoad } from "js-yaml";

import type {
  DefinitionPack,
  FieldDef,
  Model,
  Token,
  TokenCategory,
} from "./types.js";

/**
 * Parse an octal string like "000200" or "012" into a number.
 * Empty or missing strings yield 0.
 */
export function parseOctal(s: string | undefined): number {
  if (!s) return 0;
  const n = parseInt(s, 8);
  if (Number.isNaN(n)) {
    throw new Error(`Invalid octal string: "${s}"`);
  }
  return n;
}

/**
 * Combine four 16-bit octal strings (w4, w3, w2, w1) into a 64-bit BigInt.
 * w4 occupies bits 63:48, w1 occupies bits 15:0.
 */
export function encodingToBigInt(
  w4: string,
  w3: string,
  w2: string,
  w1: string,
): bigint {
  return (
    (BigInt(parseOctal(w4)) << 48n) |
    (BigInt(parseOctal(w3)) << 32n) |
    (BigInt(parseOctal(w2)) << 16n) |
    BigInt(parseOctal(w1))
  );
}

// ---------------------------------------------------------------------------
// Raw YAML shape - what js-yaml gives us after parsing the files.
// ---------------------------------------------------------------------------

interface RawTokenEncoding {
  w4: string;
  w3: string;
  w2: string;
  w1: string;
}

interface RawToken {
  token: string;
  category: string;
  display_line: number;
  encoding: RawTokenEncoding;
  description?: string;
  provides?: string;
  requires?: string;
  nd120_only?: boolean;
  models?: string[];
}

interface RawTokensDocument {
  model: string;
  token_count?: number;
  tokens: RawToken[];
}

interface RawFieldDef {
  bits: [number, number];
  width: number;
  description: string;
  default?: number;
}

interface RawFieldsDocument {
  model: string;
  word_size_bits: number;
  byte_count: number;
  byte_order: string;
  fields?: Record<string, RawFieldDef>;
  inherits_from?: string;
}

// ---------------------------------------------------------------------------
// Path resolution - find defs/ relative to the repo root.
// ---------------------------------------------------------------------------

/**
 * Resolve the path to the canonical defs/ directory.
 *
 * Climbs upwards from this module looking for the `nd-microcode-meta`
 * submodule at `external/meta/defs/`. The submodule MUST be
 * initialised; there is no fallback to an in-tree copy. Callers may
 * pass an explicit path to skip the search.
 *
 * If this throws, run `git submodule update --init --recursive` in
 * the containing repo and try again.
 */
export function findDefsRoot(explicit?: string): string {
  if (explicit) return resolve(explicit);

  // Search for the defs/ directory by climbing parent directories.
  // Two layouts are supported:
  //   1. Library inside submodule:  lib/ts/src/ -> ../../defs/
  //   2. Consumer repo:            external/meta/defs/
  let dir = dirname(fileURLToPath(import.meta.url));
  for (let i = 0; i < 10; i++) {
    // Try submodule-internal layout: defs/ is a sibling of lib/
    for (const candidate of [
      join(dir, "defs"),
      join(dir, "external", "meta", "defs"),
    ]) {
      try {
        readFileSync(join(candidate, "tokens", "nd110-tokens.yaml"), "utf8");
        return candidate;
      } catch {
        // Try next candidate.
      }
    }
    const parent = dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  throw new Error(
    "Could not locate microcode definitions (defs/tokens/nd110-tokens.yaml). " +
      "Run `git submodule update --init --recursive` in the repo root.",
  );
}

// ---------------------------------------------------------------------------
// Loading.
// ---------------------------------------------------------------------------

function normaliseCategory(raw: string): TokenCategory {
  const valid: TokenCategory[] = [
    "A_REG",
    "B_REG",
    "AB_REG",
    "PIC",
    "ALUF",
    "ALUD",
    "ALUM",
    "STS",
    "CRY",
    "MIS",
    "IDBS",
    "COMM",
    "T_SEQ",
    "T_STK",
    "F_SEQ",
    "F_STK",
    "COND",
    "SPECIAL",
    "UNKNOWN",
  ];
  if (valid.includes(raw as TokenCategory)) return raw as TokenCategory;
  return "UNKNOWN";
}

function normaliseModels(raw: string[] | undefined): Model[] {
  if (!raw) return ["nd100", "nd110", "nd120"];
  return raw.filter((m): m is Model =>
    m === "nd100" || m === "nd110" || m === "nd120",
  );
}

function toToken(raw: RawToken): Token {
  const enc = raw.encoding;
  const displayLine = raw.display_line;
  if (displayLine !== 1 && displayLine !== 2 && displayLine !== 3) {
    throw new Error(
      `Token ${raw.token} has invalid display_line: ${displayLine}`,
    );
  }
  return {
    name: raw.token,
    category: normaliseCategory(raw.category),
    displayLine,
    description: raw.description ?? "",
    encodingOctal: [enc.w4, enc.w3, enc.w2, enc.w1],
    encodingValue: encodingToBigInt(enc.w4, enc.w3, enc.w2, enc.w1),
    models: normaliseModels(raw.models),
    nd120Only: raw.nd120_only === true,
    provides: raw.provides,
    requires: raw.requires,
  };
}

/**
 * Parse YAML tokens text into an array of Token objects.
 * Browser-safe - does not touch the filesystem.
 */
export function parseTokensYaml(text: string, sourceLabel = "<yaml>"): Token[] {
  const doc = yamlLoad(text) as RawTokensDocument;
  if (!doc?.tokens) {
    throw new Error(`${sourceLabel} has no 'tokens' array`);
  }
  return doc.tokens.map(toToken);
}

/**
 * Parse YAML fields text into a name->FieldDef map.
 * Browser-safe - does not touch the filesystem.
 */
export function parseFieldsYaml(text: string): Map<string, FieldDef> {
  const doc = yamlLoad(text) as RawFieldsDocument;
  const fields = new Map<string, FieldDef>();
  if (!doc?.fields) return fields;
  for (const [name, raw] of Object.entries(doc.fields)) {
    fields.set(name, {
      name,
      bits: [raw.bits[0], raw.bits[1]],
      width: raw.width,
      description: raw.description,
      default: raw.default ?? 0,
    });
  }
  return fields;
}

/**
 * Build a DefinitionPack from pre-parsed tokens + fields.
 * Browser-safe; used by both the Node file loader and browser callers
 * that have already fetched the YAML text.
 *
 * For ND-120, pass the merged field map (ND-110 base + ND-120 overrides).
 */
export function buildDefinitionPack(
  model: Model,
  tokens: Token[],
  fields: Map<string, FieldDef>,
): DefinitionPack {
  const tokensByName = new Map<string, Token>();
  const tokensByCategory = new Map<TokenCategory, Token[]>();
  for (const t of tokens) {
    tokensByName.set(t.name, t);
    const existing = tokensByCategory.get(t.category);
    if (existing) {
      existing.push(t);
    } else {
      tokensByCategory.set(t.category, [t]);
    }
  }
  return {
    model,
    tokens,
    tokensByName,
    tokensByCategory,
    fields,
  };
}

function loadTokensFile(path: string): Token[] {
  const text = readFileSync(path, "utf8");
  return parseTokensYaml(text, path);
}

function loadFieldsFile(path: string): Map<string, FieldDef> {
  const text = readFileSync(path, "utf8");
  return parseFieldsYaml(text);
}

/**
 * Load the canonical definition pack for a given model.
 *
 * For ND-120, this loads the ND-120 tokens YAML (which contains all ND-110
 * tokens plus ND-120-only additions) and the ND-120 fields YAML merged
 * with ND-110 base fields.
 */
export function loadDefinitions(
  model: Model,
  defsRoot?: string,
): DefinitionPack {
  const root = findDefsRoot(defsRoot);

  // Tokens:
  //   ND-100: dedicated nd100-tokens.yaml (296 tokens, authoritative list).
  //   ND-110: dedicated nd110-tokens.yaml (356 tokens).
  //   ND-120: dedicated nd120-tokens.yaml (= ND-110 + ND-120-only extras).
  const tokensPath =
    model === "nd100"
      ? join(root, "tokens", "nd100-tokens.yaml")
      : model === "nd120"
      ? join(root, "tokens", "nd120-tokens.yaml")
      : join(root, "tokens", "nd110-tokens.yaml");
  const tokens = loadTokensFile(tokensPath);

  // Fields: ND-110 is the base. ND-100 and ND-120 overlay their own
  // deltas (differing bit widths, field positions, renames).
  const fields = loadFieldsFile(join(root, "fields", "nd110-fields.yaml"));
  if (model === "nd120") {
    const nd120Fields = loadFieldsFile(
      join(root, "fields", "nd120-fields.yaml"),
    );
    for (const [name, def] of nd120Fields) {
      fields.set(name, def);
    }
  } else if (model === "nd100") {
    const nd100Fields = loadFieldsFile(
      join(root, "fields", "nd100-fields.yaml"),
    );
    for (const [name, def] of nd100Fields) {
      fields.set(name, def);
    }
  }

  return buildDefinitionPack(model, tokens, fields);
}
