#!/usr/bin/env node
/**
 * Generate a self-contained JSON definitions file from the YAML
 * token/field sources.
 *
 * Output: lib/ts/src/generated-defs.json
 *
 * This file contains all NORD-10, ND-100/110/120, ND-500 and ND-5000 token and field definitions
 * as pre-parsed JSON, eliminating the need for YAML files or js-yaml
 * at runtime. Consumers import it and pass to loadDefinitionsFromJSON().
 *
 * Run from the submodule root:
 *   node lib/ts/scripts/generate-defs.mjs
 *   # or: make generate
 */

import { readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { load as yamlLoad } from "js-yaml";

const here = dirname(fileURLToPath(import.meta.url));
const LIB_ROOT = resolve(here, "..");
const META_ROOT = resolve(LIB_ROOT, "..", "..");
const DEFS = resolve(META_ROOT, "defs");

function loadYaml(relPath) {
  return yamlLoad(readFileSync(resolve(DEFS, relPath), "utf8"));
}

const output = {
  generatedAt: new Date().toISOString(),
  nd10: {
    tokens: loadYaml("tokens/nd10-tokens.yaml"),
    fields: loadYaml("fields/nd10-fields.yaml"),
  },
  nd100: {
    tokens: loadYaml("tokens/nd100-tokens.yaml"),
    fields: loadYaml("fields/nd100-fields.yaml"),
  },
  nd110: {
    tokens: loadYaml("tokens/nd110-tokens.yaml"),
    fields: loadYaml("fields/nd110-fields.yaml"),
  },
  nd120: {
    tokens: loadYaml("tokens/nd120-tokens.yaml"),
    fields: loadYaml("fields/nd120-fields.yaml"),
  },
  nd500: {
    tokens: loadYaml("tokens/nd500-tokens.yaml"),
    fields: loadYaml("fields/nd500-fields.yaml"),
  },
  nd5000: {
    tokens: loadYaml("tokens/nd5000-tokens.yaml"),
    fields: loadYaml("fields/nd5000-fields.yaml"),
  },
};

const outPath = resolve(LIB_ROOT, "src", "generated-defs.json");
writeFileSync(outPath, JSON.stringify(output));

const tokenCounts = {
  nd10: output.nd10.tokens.tokens?.length ?? 0,
  nd100: output.nd100.tokens.tokens?.length ?? 0,
  nd110: output.nd110.tokens.tokens?.length ?? 0,
  nd120: output.nd120.tokens.tokens?.length ?? 0,
  nd500: output.nd500.tokens.tokens?.length ?? 0,
  nd5000: output.nd5000.tokens.tokens?.length ?? 0,
};
const size = (readFileSync(outPath).length / 1024).toFixed(1);
console.log(`Generated ${outPath}`);
console.log(`  NORD-10: ${tokenCounts.nd10} tokens`);
console.log(`  ND-100: ${tokenCounts.nd100} tokens`);
console.log(`  ND-110: ${tokenCounts.nd110} tokens`);
console.log(`  ND-120: ${tokenCounts.nd120} tokens`);
console.log(`  ND-500: ${tokenCounts.nd500} tokens`);
console.log(`  ND-5000: ${tokenCounts.nd5000} tokens`);
console.log(`  Size: ${size} KB`);
