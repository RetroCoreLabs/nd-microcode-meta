/**
 * Public API for the ND-100/110/120 microcode library.
 */

export * from "./types.js";
export * from "./word.js";
export * from "./binary-formats.js";
export * from "./nd100-proms.js";
export { detectModel } from "./detect-model.js";
export type { DetectResult, ModelScore, TokenNameSets } from "./detect-model.js";
export type { WideToken, WideField, WidePack } from "./wide-defs.js";
export {
  buildWidePack,
  loadWideDefinitions,
  loadWideDefinitionsFromJSON,
} from "./wide-defs.js";
export {
  assembleWide,
  preprocessGeneric,
  parseOctalGeneric,
  parseOctalNd10,
  stripCommentGeneric,
} from "./assembler-wide.js";
export type {
  WideAssembleOptions,
  WideAssemblyResult,
  WideDiagnostic,
  WideInstruction,
  WideLabel,
} from "./assembler-wide.js";
export { disassembleWide, lookupFieldToken } from "./disassembler-wide.js";
export { formatProgramWide, parseLabeBytes } from "./formatter-wide.js";
export type { LabelMap, WideFormatOptions } from "./formatter-wide.js";
export {
  extractField,
  decodeFields,
  parseCodeFile,
  parseCodeBytes,
  parseSymbolsFile,
  parseSymbolsText,
  toOctal,
  ND110_XOR_MASK,
  ND100_XOR_MASK,
} from "./bitfield.js";
export type { ParseCodeOptions } from "./bitfield.js";
export {
  loadDefinitions,
  loadDefinitionsFromJSON,
  findDefsRoot,
  parseOctal,
  encodingToBigInt,
  parseTokensYaml,
  parseVariantOverridesYaml,
  parseFieldsYaml,
  buildDefinitionPack,
} from "./yaml-loader.js";
export {
  compileDisassemblerPack,
  disassembleWord,
  disassembleMap,
} from "./disassembler.js";
export type { DisassemblerPack } from "./disassembler.js";
export {
  formatInstruction,
  formatProgram,
} from "./formatter.js";
export type { FormatOptions } from "./formatter.js";
export {
  assembleSource,
  preprocess,
  translateInstruction,
  translateFromTokens,
  parseNumericLiteral,
  binaryToCodeBytes,
  recordsToCodeBytes,
} from "./assembler.js";
export {
  combineRoms,
  combineRomFiles,
  splitRoms,
  splitCodeFile,
  detectChipOrder,
  detectForm,
  readMicrocodeVersion,
  ROM_WORDS,
  ROM_SIZE_BYTES,
} from "./rom-combiner.js";
export type {
  CombineRomsOptions,
  SplitRomsOptions,
  DetectChipOrderResult,
  DetectFormResult,
} from "./rom-combiner.js";
export type {
  AssembleOptions,
  AssemblyResult,
  AssemblyDiagnostic,
  LabelDef,
  ParsedInstruction,
  SourceMap,
} from "./assembler.js";
