/**
 * Definition packs for the wide-word models: NORD-10 (32 bits), ND-500
 * (144 bits) and ND-5000 (128 bits).
 *
 * The data comes from defs/tokens/nd10|nd500|nd5000-tokens.yaml and
 * defs/fields/nd10|nd500|nd5000-fields.yaml (generated from the C# files
 * ND10Tokens.cs, ND500Tokens.cs, ND5000Tokens.cs and the *Fields.cs files).
 * Token encodings are `encoding: { parts: [...] }`, 6-digit octal, most
 * significant 16-bit part first.
 */

import { readFileSync } from "node:fs";
import { join } from "node:path";
import { load as yamlLoad } from "js-yaml";

import { findDefsRoot } from "./yaml-loader.js";
import type { WideModel } from "./types.js";
import { partsToValue } from "./word.js";

/** One token of a wide-word model. */
export interface WideToken {
  name: string;
  /** Category from the YAML (field name for nd5000, section for nd10, ...). */
  category: string;
  description: string;
  /** 16-bit parts, most significant first (length = pack.partCount). */
  parts: readonly number[];
  /** The whole contribution as one number. */
  value: bigint;
  /** nd5000: the FIELD argument of AddToken. */
  field?: string;
  /** nd5000: the value of AddToken (decimal). */
  fieldValue?: number;
  /** nd5000: the code of AddMemToken. */
  memCode?: number;
}

/** One named bit field. */
export interface WideField {
  name: string;
  high: number;
  low: number;
  description: string;
  /** nd10 only: formats the field is used in, e.g. ["ARITHMETIC", "INTERBLOCK"]. */
  formats?: readonly string[];
}

/** Definition pack of a wide-word model. */
export interface WidePack {
  model: WideModel;
  /** Display name, e.g. "ND-500". */
  displayName: string;
  wordBits: number;
  partCount: number;
  /** Words in the control store (nd10: 1024 or 4096, the larger is given). */
  controlStoreWords: number;
  tokens: readonly WideToken[];
  tokensByName: ReadonlyMap<string, WideToken>;
  /** nd500/nd5000: the non-overlapping partition, highest bit first. */
  partition: readonly WideField[];
  /** nd500/nd5000: fields that overlap the partition. */
  subfields: readonly WideField[];
  /** nd10: every field (they overlap on purpose). */
  allFields: readonly WideField[];
  /** Every field by name (partition, subfields and nd10 fields). */
  fieldsByName: ReadonlyMap<string, WideField>;
}

interface RawWideToken {
  token: string;
  category: string;
  description?: string;
  encoding: { parts: string[] };
  field?: string;
  value?: number;
  mem_code?: number;
}

interface RawWideField {
  name: string;
  high_bit: number;
  low_bit: number;
  description?: string;
  format?: string;
}

interface RawWideFields {
  word_size_bits: number;
  part_count: number;
  control_store_words: number | number[];
  partition?: RawWideField[];
  subfields?: RawWideField[];
  fields?: RawWideField[];
}

interface RawWideTokens {
  model: string;
  word_size_bits: number;
  part_count: number;
  tokens: RawWideToken[];
}

const DISPLAY_NAME: Record<WideModel, string> = {
  nd10: "NORD-10",
  nd500: "ND-500",
  nd5000: "ND-5000",
};

function toField(raw: RawWideField): WideField {
  return {
    name: raw.name,
    high: raw.high_bit,
    low: raw.low_bit,
    description: raw.description ?? "",
    formats: raw.format ? raw.format.split("|") : undefined,
  };
}

function toToken(raw: RawWideToken, partCount: number): WideToken {
  const parts = raw.encoding.parts.map((p) => {
    const n = parseInt(p, 8);
    if (Number.isNaN(n) || n < 0 || n > 0xffff) {
      throw new Error(`Token ${raw.token}: bad part "${p}"`);
    }
    return n;
  });
  if (parts.length !== partCount) {
    throw new Error(
      `Token ${raw.token}: ${parts.length} parts, expected ${partCount}`,
    );
  }
  return {
    name: raw.token,
    category: raw.category,
    description: raw.description ?? "",
    parts,
    value: partsToValue(parts),
    field: raw.field,
    fieldValue: raw.value,
    memCode: raw.mem_code,
  };
}

/**
 * Build a pack from the parsed token and field documents (the js-yaml
 * result, or the matching entries of generated-defs.json).
 */
export function buildWidePack(
  model: WideModel,
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  tokensDoc: any,
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  fieldsDoc: any,
): WidePack {
  const td = tokensDoc as RawWideTokens;
  const fd = fieldsDoc as RawWideFields;
  if (!td?.tokens) throw new Error(`${model}: tokens document has no 'tokens'`);
  if (td.part_count !== fd.part_count || td.word_size_bits !== fd.word_size_bits) {
    throw new Error(`${model}: tokens and fields disagree on the word size`);
  }
  const tokens = td.tokens.map((t) => toToken(t, td.part_count));
  const tokensByName = new Map<string, WideToken>();
  for (const t of tokens) {
    if (tokensByName.has(t.name)) {
      throw new Error(`${model}: duplicate token ${t.name}`);
    }
    tokensByName.set(t.name, t);
  }
  const partition = (fd.partition ?? []).map(toField);
  const subfields = (fd.subfields ?? []).map(toField);
  const allFields = (fd.fields ?? []).map(toField);
  const fieldsByName = new Map<string, WideField>();
  for (const f of [...partition, ...subfields, ...allFields]) {
    fieldsByName.set(f.name, f);
  }
  const cs = fd.control_store_words;
  return {
    model,
    displayName: DISPLAY_NAME[model],
    wordBits: td.word_size_bits,
    partCount: td.part_count,
    controlStoreWords: Array.isArray(cs) ? Math.max(...cs) : cs,
    tokens,
    tokensByName,
    partition,
    subfields,
    allFields,
    fieldsByName,
  };
}

/**
 * Build a wide pack from pre-generated JSON (generated-defs.json). No YAML,
 * no filesystem.
 */
export function loadWideDefinitionsFromJSON(
  model: WideModel,
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  generatedData: Record<string, any>,
): WidePack {
  const data = generatedData[model];
  if (!data) throw new Error(`No generated definitions for model "${model}"`);
  return buildWidePack(model, data.tokens, data.fields);
}

/** Load a wide pack from the YAML files in defs/ (Node only). */
export function loadWideDefinitions(
  model: WideModel,
  defsRoot?: string,
): WidePack {
  const root = findDefsRoot(defsRoot);
  const read = (rel: string): unknown =>
    yamlLoad(readFileSync(join(root, rel), "utf8"));
  return buildWidePack(
    model,
    read(`tokens/${model}-tokens.yaml`),
    read(`fields/${model}-fields.yaml`),
  );
}
