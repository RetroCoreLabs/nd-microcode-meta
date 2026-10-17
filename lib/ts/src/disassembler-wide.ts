/**
 * Lossless disassemblers for the wide-word models: ND-500, ND-5000, NORD-10.
 *
 * Ports of ND500Disassembler.cs, ND5000Disassembler.cs and
 * ND10Disassembler.cs (project ND110Compile). Each returns the list of
 * source items for one word; assembling the items with assembleWide gives
 * back exactly the same word (bits without a mnemonic come out as
 * FIELD=octal or as an octal number).
 */

import type { WideField, WidePack } from "./wide-defs.js";
import { extractBits, octal } from "./word.js";

// ---------------------------------------------------------------------------
// ND-500 and ND-5000 share the field walk and the (field, value) lookup.
// ---------------------------------------------------------------------------

interface ReverseMap {
  /** "FIELD:value" -> token name. */
  byFieldValue: Map<string, string>;
}

const reverseMaps = new WeakMap<WidePack, ReverseMap>();

function fieldIndexOfBit(partition: readonly WideField[], bit: number): number {
  for (let i = 0; i < partition.length; i++) {
    if (bit <= partition[i].high && bit >= partition[i].low) return i;
  }
  throw new Error(`Bit ${bit} not covered by the field partition`);
}

/**
 * ND-500: a token enters the map when all its set bits lie in ONE partition
 * field and none is below bit 32. When tokens share an encoding the
 * alphabetically first name (ordinal compare) is kept.
 */
function buildNd500Map(pack: WidePack): ReverseMap {
  const byFieldValue = new Map<string, string>();
  for (const token of pack.tokens) {
    let fieldIndex = -1;
    let eligible = true;
    let anyBit = false;
    for (let bit = pack.wordBits - 1; bit >= 0 && eligible; bit--) {
      if (((token.value >> BigInt(bit)) & 1n) === 0n) continue;
      anyBit = true;
      if (bit < 32) {
        eligible = false;
        break;
      }
      const idx = fieldIndexOfBit(pack.partition, bit);
      if (fieldIndex < 0) fieldIndex = idx;
      else if (fieldIndex !== idx) eligible = false;
    }
    if (!eligible || !anyBit || fieldIndex < 0) continue;
    const f = pack.partition[fieldIndex];
    const key = `${f.name}:${extractBits(token.value, f.high, f.low)}`;
    const existing = byFieldValue.get(key);
    if (existing === undefined || token.name < existing) {
      byFieldValue.set(key, token.name);
    }
  }
  return { byFieldValue };
}

/**
 * ND-5000: the map is keyed by the (field, value) pair of AddToken, and by
 * ("MEM", code) for AddMemToken. A duplicate pair is an error, as in C#.
 */
function buildNd5000Map(pack: WidePack): ReverseMap {
  const byFieldValue = new Map<string, string>();
  for (const token of pack.tokens) {
    let key: string;
    if (token.memCode !== undefined) key = `MEM:${token.memCode}`;
    else if (token.field !== undefined && token.fieldValue !== undefined) {
      key = `${token.field}:${token.fieldValue}`;
    } else {
      throw new Error(`ND-5000 token ${token.name} has neither field/value nor mem_code`);
    }
    if (byFieldValue.has(key)) {
      throw new Error(`Duplicate ND-5000 (field,value) ${key}`);
    }
    byFieldValue.set(key, token.name);
  }
  return { byFieldValue };
}

function reverseMapFor(pack: WidePack): ReverseMap {
  let map = reverseMaps.get(pack);
  if (!map) {
    map = pack.model === "nd500" ? buildNd500Map(pack) : buildNd5000Map(pack);
    reverseMaps.set(pack, map);
  }
  return map;
}

/** The token whose contribution is exactly `value` in `field`, or undefined. */
export function lookupFieldToken(
  pack: WidePack,
  fieldName: string,
  value: number,
): string | undefined {
  return reverseMapFor(pack).byFieldValue.get(`${fieldName}:${value}`);
}

function disassembleNd500(pack: WidePack, word: bigint): string[] {
  const m: string[] = [];
  const map = reverseMapFor(pack);
  for (const f of pack.partition) {
    const v = extractBits(word, f.high, f.low);
    if (v === 0) continue;
    m.push(map.byFieldValue.get(`${f.name}:${v}`) ?? `${f.name}=${octal(v)}`);
  }
  const hi = extractBits(word, 31, 16);
  const lo = extractBits(word, 15, 0);
  if (hi !== 0) m.push(`${octal(hi)},${octal(lo)}`);
  else if (lo !== 0) m.push(octal(lo));
  return m;
}

/** Emit order of ND5000Disassembler.Disassemble: field names and how to emit. */
const ND5000_ORDER: readonly string[] = [
  "COND_ALU", "ALU_OP", "ALU_CRY", "ALUF_OP", "ALUF_CRY", "EXUC",
  "Q_REG", "AAP_CTRL", "TIMING", "DATATYPE",
  "OR_ENABLE", "A_OP", "B_OP", "DEST",
  "STATUS", "IXC_INCR", "LC_DECR",
  "COND_SEQ", "SEQT_TYPE", "SEQT_STACK", "SEQF_TYPE", "SEQF_STACK", "INVSEQ", "CSAVE", "TESTOBJ",
  "ABR", "TBC", "GET", "STOP", "AAPSYNC",
  "@MEM",
  "AD_ARTI", "EA_SAVE", "MEMOT", "RESERVED_36", "ADACT",
  "!ABS_ADDR", "!AA", "!AB", "!SCAL", "!ORCON",
];

function disassembleNd5000(pack: WidePack, word: bigint): string[] {
  const m: string[] = [];
  const map = reverseMapFor(pack);
  const field = (name: string): WideField => {
    const f = pack.fieldsByName.get(name);
    if (!f) throw new Error(`Unknown ND-5000 field ${name}`);
    return f;
  };
  for (const item of ND5000_ORDER) {
    if (item === "@MEM") {
      const memBit3 = extractBits(word, 41, 41);
      const memBits20 = extractBits(word, 34, 32);
      const mem = (memBit3 << 3) | memBits20;
      if (mem !== 0) {
        const tok = map.byFieldValue.get(`MEM:${mem}`);
        if (tok !== undefined) m.push(tok);
        else {
          if (memBit3 !== 0) m.push("MEM_BIT3=1");
          if (memBits20 !== 0) m.push(`MEM_BITS20=${octal(memBits20)}`);
        }
      }
    } else if (item.startsWith("!")) {
      const name = item.slice(1);
      const f = field(name);
      const v = extractBits(word, f.high, f.low);
      if (v !== 0) m.push(`${name}=${octal(v)}`);
    } else {
      const f = field(item);
      const v = extractBits(word, f.high, f.low);
      if (v === 0) continue;
      m.push(map.byFieldValue.get(`${item}:${v}`) ?? `${item}=${octal(v)}`);
    }
  }
  return m;
}

// ---------------------------------------------------------------------------
// NORD-10
// ---------------------------------------------------------------------------

const CondNames = ["ZERO", "SPOS", "POS", "POSM", "NZERO", "SNEG", "NEG", "NEGM"];
const CycleNames = ["", "CEATR", "CPTR", "CFC", "CWR1", "CW", "CRR1", "CR"];
const OrNames = ["", "ORBWO", "", "ORBW", "ORSKP", "ORROP", "ORSW2", "ORSW3"];
const LogicalNames = ["BDIRC", "ANDC", "ORCB", "ONE", "ORC", "ADIRC", "EXORC", "ORCA", "ANDCB", "EXOR", "ADIR", "OR", "", "ANDCA", "AND", "BDIR"];
const ArithFunction = ["BM1", "PLUS", "BMAM1", "BDI"];
const AltNames = ["BM1A", "PLUSA", "", "BDIA", "", "", "", "", "", "", "", "", "", "", "BMAA", ""];
const DestNames = ["", "D,D", "D,P", "D,B", "D,L", "D,A", "D,T", "D,X", "D,S", "D,SH", "D,IO", "D,SC", "D,SCR", "", "D,SP", "D,SS"];
const BNames = ["", "B,D", "B,P", "B,B", "B,L", "B,A", "B,T", "B,X", "B,SC", "B,SH", "B,IO", "B,AC", "B,HAC", "B,2AC", "", ""];
const BWriteNames = ["B,PAC", "B,S", "B,LMP", "B,PCR", "B,MIS", "B,IIE", "B,PID", "B,PIE", "", "", "", "B,CAR", "B,IR", "", "B,BIO", "B,IR3"];
const BReadNames = ["B,PAS", "B,S", "B,OPR", "B,PGS", "B,PVL", "B,IIC", "B,PID", "B,PIE", "", "B,PIM", "B,ALD", "B,PES", "B,MPC", "B,PEA", "B,BIO", "B,BIR3"];
const ANames = ["", "A,D", "A,P", "A,B", "A,L", "A,A", "A,T", "A,X", "A,S", "A,DH", "A,IO", "A,H", "A,SCR", "A,R", "A,SP", "A,SS"];
const ShtNames = ["", "SHRO", "SHZE", ""];
const TgNames = ["", "TGSH0", "TGAC0", "TGS0"];
const TermNames = ["TSC0", "", "TSH31", "TSH22"];
const SPECIAL = 10; // octal 12 in the A, B or D field selects a special case

class Nd10Fields {
  constructor(private readonly pack: WidePack) {}
  private f(name: string): WideField {
    const f = this.pack.fieldsByName.get(name);
    if (!f) throw new Error(`Unknown NORD-10 field ${name}`);
    return f;
  }
  /** Value of the field in the word. */
  get(word: number, name: string): number {
    const f = this.f(name);
    const width = f.high - f.low + 1;
    const max = width === 32 ? 0xffffffff : 2 ** width - 1;
    return (word >>> f.low) & max;
  }
  /** The field value in place, as octal text (ND10Fields.Raw). */
  raw(name: string, value: number): string {
    return octal(BigInt(value) << BigInt(this.f(name).low));
  }
}

function aluName(F: Nd10Fields, word: number, t: string[], logical: boolean): void {
  const alu = F.get(word, "ALU");
  if (logical) {
    if (LogicalNames[alu].length > 0) t.push(LogicalNames[alu]);
    else t.push(F.raw("ALU", alu));
    return;
  }
  const fn = alu & 3;
  const carry = alu >> 2;
  switch (carry) {
    case 0:
      t.push(ArithFunction[fn]);
      break;
    case 1:
      t.push(ArithFunction[fn]);
      t.push("ADDC");
      break;
    case 3:
      if (fn === 2) {
        t.push("BMINA");
      } else {
        t.push(ArithFunction[fn]);
        t.push("ADD1");
      }
      break;
    default:
      t.push(F.raw("ALU", alu));
      break;
  }
}

function nd10Arithmetic(F: Nd10Fields, word: number, t: string[], interblock: boolean): void {
  const logical = F.get(word, "LOG") !== 0;
  const most = F.get(word, "UNIT") !== 0;
  const b = F.get(word, "B");
  const a = F.get(word, "A");
  const d = F.get(word, "DEST");
  const or = F.get(word, "OR");
  let level = F.get(word, "LEVEL");
  const condBit = F.get(word, "COND") !== 0;

  const bitMask = !interblock && b === SPECIAL;
  const conditional = !interblock && condBit && !bitMask;

  t.push((interblock ? "I" : "") + (conditional ? "C" : "") + (logical ? "LOG" : "AR") + (most ? "M" : "L"));
  aluName(F, word, t, logical);

  const cycle = F.get(word, "CYCLE");
  if (cycle !== 0) t.push(CycleNames[cycle]);
  if (F.get(word, "CHLEV") !== 0) t.push(interblock ? "DSPL" : "CHLEV");
  if (F.get(word, "SACO") !== 0) t.push("SACO");

  if (interblock) {
    if ((or === 1 || or === 3) && condBit) {
      t.push(or === 1 ? "ORIN" : "ORIN2");
      level &= 7;
    } else if (or !== 0) {
      if (OrNames[or].length > 0) t.push(OrNames[or]);
      else t.push(F.raw("OR", or));
    }
    if (level !== 0) t.push("LE" + octal(level));
  } else {
    if (or !== 0) {
      if (OrNames[or].length > 0) t.push(OrNames[or]);
      else t.push(F.raw("OR", or));
    }
    if (conditional) {
      t.push(CondNames[level & 7]);
    } else if (!bitMask && level !== 0) {
      t.push(F.raw("TC", level & 7));
    }
  }

  if (d !== 0) {
    if (DestNames[d].length > 0) t.push(DestNames[d]);
    else t.push(F.raw("DEST", d));
  }

  if (d === SPECIAL) {
    if (BWriteNames[b].length > 0) t.push(BWriteNames[b]);
    else t.push(F.raw("B", b));
  } else if (a === SPECIAL) {
    if (BReadNames[b].length > 0) t.push(BReadNames[b]);
    else t.push(F.raw("B", b));
  } else if (bitMask) {
    t.push("B,B" + octal(level));
  } else if (b !== 0) {
    if (BNames[b].length > 0) t.push(BNames[b]);
    else t.push(F.raw("B", b));
  }

  if (a !== 0) t.push(ANames[a]);
}

function nd10Jump(F: Nd10Fields, word: number, t: string[]): void {
  const conditional = F.get(word, "COND") !== 0;
  const viaCar = F.get(word, "CAR") !== 0;
  t.push(conditional ? (viaCar ? "CJMP,CAR" : "CJMP") : viaCar ? "JMP,CAR" : "JMP");
  if (F.get(word, "PRIV") !== 0) t.push("PRIV");
  const unused = F.get(word, "UNUSED27_16");
  if (unused !== 0) t.push(F.raw("UNUSED27_16", unused));
  const tc = F.get(word, "TC");
  if (conditional) t.push(CondNames[tc]);
  else if (tc !== 0) t.push(F.raw("TC", tc));
  const addr = F.get(word, "ADDR");
  if (addr !== 0 || F.get(word, "CAR") === 0) t.push(octal(addr, 4));
}

function nd10Loop(F: Nd10Fields, word: number, t: string[]): void {
  t.push("LOOP");
  const logical = F.get(word, "LOG") !== 0;
  if (logical) t.push(F.raw("LOG", 1));
  aluName(F, word, t, logical);

  const alt = F.get(word, "ALT");
  if (alt < AltNames.length && AltNames[alt].length > 0) t.push(AltNames[alt]);
  else if (alt !== 0) t.push(F.raw("ALT", alt));
  else t.push("BM1A");

  if (F.get(word, "SACO") !== 0) t.push("SACO");
  const orsht = F.get(word, "ORSHT") !== 0;
  const mbit = F.get(word, "M") !== 0;
  if (orsht && mbit) t.push("ORSHT");
  else if (orsht) t.push(F.raw("ORSHT", 1));
  const unused = F.get(word, "UNUSED17_16");
  if (unused !== 0) t.push(F.raw("UNUSED17_16", unused));

  if (F.get(word, "SHR") !== 0) t.push("SHR");
  const sht = F.get(word, "SHT");
  if (sht !== 0) {
    if (ShtNames[sht].length > 0) t.push(ShtNames[sht]);
    else t.push(F.raw("SHT", sht));
  }
  if (F.get(word, "SH32") !== 0) t.push("SH32");
  if (F.get(word, "UNUSED11") !== 0) t.push(F.raw("UNUSED11", 1));
  if (mbit && !orsht) t.push(F.raw("M", 1));

  const tg = F.get(word, "TG");
  if (tg !== 0) t.push(TgNames[tg]);

  const b = F.get(word, "B");
  if (b !== 0) {
    if (BNames[b].length > 0) t.push(BNames[b]);
    else t.push(F.raw("B", b));
  }

  const term = F.get(word, "TERM");
  if (TermNames[term].length > 0) t.push(TermNames[term]);
  else t.push(F.raw("TERM", term));

  if (F.get(word, "ENDID") !== 0) t.push("ENDID");
  if (F.get(word, "ASH") !== 0) t.push("ASH0");
}

const nd10Fields = new WeakMap<WidePack, Nd10Fields>();

function disassembleNd10(pack: WidePack, word32: bigint): string[] {
  let F = nd10Fields.get(pack);
  if (!F) {
    F = new Nd10Fields(pack);
    nd10Fields.set(pack, F);
  }
  const word = Number(word32 & 0xffffffffn) >>> 0;
  const t: string[] = [];
  switch (word >>> 30) {
    case 0:
      nd10Arithmetic(F, word, t, false);
      break;
    case 1:
      nd10Arithmetic(F, word, t, true);
      break;
    case 2:
      nd10Jump(F, word, t);
      break;
    default:
      nd10Loop(F, word, t);
      break;
  }
  return t;
}

/**
 * Disassemble one word of NORD-10, ND-500 or ND-5000 into source items.
 * ND-500 / ND-5000: an all-zero word gives an empty list.
 */
export function disassembleWide(pack: WidePack, word: bigint): string[] {
  switch (pack.model) {
    case "nd500":
      return disassembleNd500(pack, word);
    case "nd5000":
      return disassembleNd5000(pack, word);
    default:
      return disassembleNd10(pack, word);
  }
}
