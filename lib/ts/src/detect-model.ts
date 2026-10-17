/**
 * Guess the microcode variant of a source file from the words in it.
 *
 * The guess is only shown to the user (status bar); it is never written to a
 * file or setting. Rule:
 *   1. Remove comments ('%', and '#' at the start of a line or after a
 *      space or tab), the ';' marks, label definitions and uses, address
 *      items and numbers in every dialect (octal, d123, 0x1F, $1F, o17,
 *      177B, n,n, *n). What is left are the "items".
 *   2. NORD-10 is the only variant whose source has no ';'. A source with at
 *      least one ';' is never NORD-10; a source without ';' can only be
 *      NORD-10.
 *   3. For each remaining candidate the score is
 *      (items that are a token of that variant) / (all items).
 *   4. The best family (nd1x0, nd500, nd5000, nd10) must score at least 0.60
 *      and beat the best score of another family by at least 0.10.
 *   5. Inside the ND-1x0 family (nd100, nd110, nd120) the variant with the
 *      most hits wins; equal hits leave the choice open (`candidates`).
 */

import type { AnyModel } from "./types.js";

export interface ModelScore {
  model: AnyModel;
  hits: number;
  items: number;
  score: number;
}

export interface DetectResult {
  /** The variant, or undefined when the words do not settle it. */
  model?: AnyModel;
  /** The variants that fit equally well (more than one when undecided). */
  candidates: AnyModel[];
  scores: ModelScore[];
  /** Number of items that were scored. */
  items: number;
  /** One line that says why. */
  note: string;
}

/** Token names per model: a Set or anything with `has`. */
export type TokenNameSets = Partial<Record<AnyModel, { has(name: string): boolean }>>;

const MIN_SCORE = 0.6;
const MIN_MARGIN = 0.1;
const FAMILY: Partial<Record<AnyModel, string>> = {
  nd10: "nd10",
  nd100: "nd1x0",
  nd110: "nd1x0",
  nd120: "nd1x0",
  nd500: "nd500",
  nd5000: "nd5000",
};

function stripComments(line: string): string {
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (c === "%") return line.slice(0, i);
    if (c === "#" && (i === 0 || line[i - 1] === " " || line[i - 1] === "\t")) {
      return line.slice(0, i);
    }
  }
  return line;
}

const NUMBER_RE =
  /^(\d+|[0-7]+[Bb]?|[dD]\d+|0[xX][0-9A-Fa-f]+|\$[0-9A-Fa-f]+|[oO][0-7]+|[0-7]+,[0-7]+|\*[+-]?[0-7]*)$/;

function isNumber(item: string): boolean {
  return NUMBER_RE.test(item);
}

/** Choose the variant for `source`. `names` holds the token names per model. */
export function detectModel(source: string, names: TokenNameSets): DetectResult {
  let hasSemicolon = false; // a ';' outside comments
  const lines = source.replace(/\r/g, "").split("\n");

  // Pass 1: label names (first item ending in ':' or ',').
  const labels = new Set<string>();
  const itemLists: string[][] = [];
  for (const raw of lines) {
    const code = stripComments(raw);
    if (code.includes(";")) hasSemicolon = true;
    const line = code
      .split(" ,").join(",")
      .split(", ").join(",")
      .replace(/;/g, " ");
    const parts = line.split(/\s+/).filter((p) => p.length > 0);
    // 'nnnn/' may stand alone or in front of the first item.
    while (parts.length > 0) {
      const first = parts[0];
      if (/^[0-7]+\/$/.test(first)) {
        parts.shift();
        continue;
      }
      const slash = /^([0-7]+)\/(.+)$/.exec(first);
      if (slash) {
        parts[0] = slash[2];
        continue;
      }
      break;
    }
    // Label definitions: NAME: (ND-1x0, ND-500, ND-5000), NAME, (NORD-10).
    while (parts.length > 0) {
      const first = parts[0];
      const m = /^([A-Za-z][A-Za-z0-9_.$]*)[:,]$/.exec(first);
      if (m) {
        labels.add(m[1]);
        parts.shift();
        continue;
      }
      const inner = /^([A-Za-z][A-Za-z0-9_.$]*):(.+)$/.exec(first);
      if (inner) {
        labels.add(inner[1]);
        parts[0] = inner[2];
        continue;
      }
      if (/^[0-7]+:$/.test(first)) {
        parts.shift();
        continue;
      }
      break;
    }
    itemLists.push(parts);
  }

  // Pass 2: count.
  const candidates = (Object.keys(names) as AnyModel[]).filter((m) =>
    m === "nd10" ? !hasSemicolon : hasSemicolon,
  );
  const hits = new Map<AnyModel, number>(candidates.map((m) => [m, 0]));
  let items = 0;
  for (const parts of itemLists) {
    for (const item of parts) {
      if (isNumber(item)) continue;
      if (item.includes("=")) continue; // FIELD=octal
      if (item.endsWith(":") || item.endsWith(",")) continue;
      if (labels.has(item)) continue;
      const off = /^([A-Za-z][A-Za-z0-9_.$]*)[+-][0-7]+$/.exec(item);
      if (off && labels.has(off[1])) continue;
      items++;
      for (const m of candidates) {
        if (names[m]!.has(item)) hits.set(m, hits.get(m)! + 1);
      }
    }
  }

  const scores: ModelScore[] = candidates.map((m) => ({
    model: m,
    hits: hits.get(m)!,
    items,
    score: items === 0 ? 0 : hits.get(m)! / items,
  }));

  if (items === 0 || scores.length === 0) {
    return { candidates: [], scores, items, note: "no mnemonics to look at" };
  }

  // Best score per family.
  const bestOfFamily = new Map<string, ModelScore>();
  for (const s of scores) {
    const fam = FAMILY[s.model]!;
    const cur = bestOfFamily.get(fam);
    if (!cur || s.score > cur.score) bestOfFamily.set(fam, s);
  }
  const ranked = [...bestOfFamily.values()].sort((a, b) => b.score - a.score);
  const top = ranked[0];
  const second = ranked[1];
  if (top.score < MIN_SCORE) {
    return {
      candidates: [],
      scores,
      items,
      note: `best score ${top.score.toFixed(2)} (${top.model}) is below ${MIN_SCORE}`,
    };
  }
  if (second && top.score - second.score < MIN_MARGIN) {
    return {
      candidates: [top.model, second.model],
      scores,
      items,
      note: `${top.model} ${top.score.toFixed(2)} and ${second.model} ${second.score.toFixed(2)} are too close`,
    };
  }

  // Inside the family: most hits wins, a tie stays open.
  const fam = FAMILY[top.model]!;
  const inFamily = scores.filter((s) => FAMILY[s.model] === fam);
  const maxHits = Math.max(...inFamily.map((s) => s.hits));
  const best = inFamily.filter((s) => s.hits === maxHits).map((s) => s.model);
  if (best.length === 1) {
    return {
      model: best[0],
      candidates: best,
      scores,
      items,
      note: `${best[0]} ${scores.find((s) => s.model === best[0])!.score.toFixed(2)}`,
    };
  }
  return {
    candidates: best,
    scores,
    items,
    note: `${best.join(" and ")} fit equally well (${top.score.toFixed(2)})`,
  };
}
