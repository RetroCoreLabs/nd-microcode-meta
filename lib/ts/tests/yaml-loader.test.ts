import { describe, it, expect } from "vitest";
import {
  loadDefinitions,
  parseOctal,
  encodingToBigInt,
} from "../src/yaml-loader.js";

describe("parseOctal", () => {
  it("parses octal strings", () => {
    expect(parseOctal("000000")).toBe(0);
    expect(parseOctal("000001")).toBe(1);
    expect(parseOctal("000200")).toBe(0o200);
    expect(parseOctal("170000")).toBe(0o170000);
  });

  it("handles missing/empty", () => {
    expect(parseOctal(undefined)).toBe(0);
    expect(parseOctal("")).toBe(0);
  });
});

describe("encodingToBigInt", () => {
  it("combines w4,w3,w2,w1 into 64-bit value", () => {
    // CONDENABL has w2="000200", others "000000"
    // Expected: 0x200 << 16 = 0x00800000 = bit 23
    expect(encodingToBigInt("000000", "000000", "000200", "000000")).toBe(
      1n << 23n,
    );
  });

  it("places w4 at bits 63:48", () => {
    // w4="000001" -> bit 48
    expect(encodingToBigInt("000001", "000000", "000000", "000000")).toBe(
      1n << 48n,
    );
  });
});

describe("loadDefinitions", () => {
  it("loads ND-110 pack", () => {
    const pack = loadDefinitions("nd110");
    expect(pack.model).toBe("nd110");
    expect(pack.tokens.length).toBeGreaterThan(300);
    expect(pack.tokensByName.get("A,Z")).toBeDefined();
    expect(pack.tokensByName.get("ALUF,PASSD")).toBeDefined();
    expect(pack.tokensByName.get("CONDENABL")).toBeDefined();
  });

  it("loads ND-120 pack with extra tokens", () => {
    const pack = loadDefinitions("nd120");
    expect(pack.model).toBe("nd120");
    expect(pack.tokensByName.get("COMM,MACL")).toBeDefined();
    expect(pack.tokensByName.get("IDBS,UART")).toBeDefined();
    expect(pack.tokensByName.get("COMM,MACL")?.nd120Only).toBe(true);
  });

  it("CONDENABL encoding matches expected bit 23", () => {
    const pack = loadDefinitions("nd110");
    const t = pack.tokensByName.get("CONDENABL");
    expect(t).toBeDefined();
    expect(t!.encodingValue).toBe(1n << 23n);
  });

  it("ALUD,NONE encoding sets bit 61", () => {
    const pack = loadDefinitions("nd110");
    const t = pack.tokensByName.get("ALUD,NONE");
    // ALUD,NONE w4="020000" = 0x2000 -> bit 13 of w4 = bit 61 overall
    expect(t!.encodingValue).toBe(1n << 61n);
  });

  it("categorises tokens correctly", () => {
    const pack = loadDefinitions("nd110");
    expect(pack.tokensByName.get("A,D")?.category).toBe("A_REG");
    expect(pack.tokensByName.get("B,R7")?.category).toBe("B_REG");
    expect(pack.tokensByName.get("AB,PGS")?.category).toBe("AB_REG");
    expect(pack.tokensByName.get("ALUF,PASSD")?.category).toBe("ALUF");
    expect(pack.tokensByName.get("COMM,EWRF")?.category).toBe("COMM");
    expect(pack.tokensByName.get("T,JMP")?.category).toBe("T_SEQ");
    expect(pack.tokensByName.get("T,HOLD")?.category).toBe("T_STK");
    expect(pack.tokensByName.get("F,JMP")?.category).toBe("F_SEQ");
    expect(pack.tokensByName.get("COND,FETCH")?.category).toBe("COND");
  });
});
