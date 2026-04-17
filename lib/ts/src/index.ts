/**
 * Public API for the ND-100/110/120 microcode library.
 */

export * from "./types.js";
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
  findDefsRoot,
  parseOctal,
  encodingToBigInt,
  parseTokensYaml,
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
