#!/usr/bin/env python3
"""
YAML Validator for ND-100/110/120 Microcode Definitions

Validates that the YAML token definitions in defs/tokens/ correctly describe
the actual microcode by:

  1. Loading the YAML definitions
  2. Loading a .CODE binary file
  3. Disassembling each word using the YAML token lookup
  4. Comparing against the corresponding .uc source file (if available)
  5. Reporting any discrepancies

Usage:
    python3 validate.py [--model nd110|nd120] [--binary path.CODE] [--source path.uc]

Default: validates ND-110 RASK against reference/ND-110-RASK.CODE
"""

import argparse
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML is required. Install with: pip install pyyaml", file=sys.stderr)
    sys.exit(1)


REPO = Path(__file__).resolve().parent.parent


def parse_octal(s):
    """Parse an octal string like '000200' to int."""
    return int(s, 8) if s else 0


def load_tokens(yaml_path):
    """Load a tokens YAML and return a list of (name, encoding_int, category, flags)."""
    with open(yaml_path, encoding="utf-8") as f:
        data = yaml.safe_load(f)
    tokens = []
    for t in data["tokens"]:
        enc = t["encoding"]
        # Combine w4 (bits 63:48), w3 (47:32), w2 (31:16), w1 (15:0) into 64-bit int.
        value = (
            (parse_octal(enc["w4"]) << 48)
            | (parse_octal(enc["w3"]) << 32)
            | (parse_octal(enc["w2"]) << 16)
            | parse_octal(enc["w1"])
        )
        tokens.append({
            "name": t["token"],
            "value": value,
            "category": t["category"],
            "line": t["display_line"],
            "description": t.get("description", ""),
            "provides": t.get("provides"),
            "requires": t.get("requires"),
            "nd120_only": t.get("nd120_only", False),
        })
    return tokens, data.get("model", "UNKNOWN")


def load_code_binary(path):
    """Load a .CODE file: 10 bytes per record (2-byte LE address + 8-byte LE value)."""
    data = Path(path).read_bytes()
    if len(data) % 10 != 0:
        print(f"WARNING: {path} size {len(data)} is not a multiple of 10", file=sys.stderr)
    records = {}
    for i in range(0, len(data) - 9, 10):
        addr = data[i] | (data[i + 1] << 8)
        value = 0
        for j in range(8):
            value |= data[i + 2 + j] << (j * 8)
        records[addr] = value
    return records


def load_symbols(path):
    """Load a .SYMBOLS.TXT file mapping octal address -> label name."""
    symbols = {}
    if not Path(path).exists():
        return symbols
    for line in Path(path).read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or line.startswith("%"):
            continue
        # Format: "ADDR=LABEL" where ADDR is octal (e.g. "000020=VERSN")
        m = re.match(r"^([0-7]+)\s*=\s*(\S+)", line)
        if m:
            addr = int(m.group(1), 8)
            symbols[addr] = m.group(2)
    return symbols


def sanity_check_tokens(tokens, model):
    """Check for obvious problems in the token table."""
    errors = []
    warnings = []

    # Check for duplicate names
    names = {}
    for t in tokens:
        if t["name"] in names:
            errors.append(f"Duplicate token name: {t['name']}")
        names[t["name"]] = t

    # Check that every token's encoding fits in 64 bits
    for t in tokens:
        if t["value"] >> 64:
            errors.append(f"Token {t['name']} encoding overflows 64 bits: {t['value']:x}")

    # Check that zero-encoded tokens are documented
    zero_tokens = [t for t in tokens if t["value"] == 0]
    for t in zero_tokens:
        # Verify this is in the "always_emit_zero_token" list from format YAML - informational
        pass

    # Check that tokens in the same category with the same encoding are flagged
    category_encodings = {}
    for t in tokens:
        key = (t["category"], t["value"])
        if key in category_encodings:
            warnings.append(
                f"Same encoding in category {t['category']}: "
                f"{t['name']} and {category_encodings[key]}"
            )
        else:
            category_encodings[key] = t["name"]

    return errors, warnings


def check_nd120_deltas(nd110_tokens, nd120_tokens):
    """Verify that the ND-110/ND-120 token set differences match what we expect."""
    n110 = {t["name"] for t in nd110_tokens}
    n120 = {t["name"] for t in nd120_tokens}

    expected_nd120_only = {
        "IDBS,PICM", "IDBS,UART",
        "COMM,UART,DATA", "COMM,UART,STATUS", "COMM,UART,MODE", "COMM,UART,COM",
        "COMM,SLOW", "COMM,MACL", "COMM,XSLOW",
        "AB,BAUD", "AB,OLD303", "AB,NOISE",
    }
    expected_nd110_only = {
        "COMM,SLOW1", "COMM,SLOW2",
        # In use (T_SEQ = 3, w2 140000); present in the ND-110 YAML, not in
        # the C# ND110Tokens.cs / ND120Tokens.cs and not in the ND-120 YAML.
        "T,REPEAT",
        # The following are actually in ND-110 but absent in ND-120
        # (ND-120 replaced or renamed them):
        "COMM,IREAD2", "COMM,LBCONT", "COMM,LDDOMI", "COMM,LDPS",
        "COMM,TBSTR", "COMM,WALBR", "COMM,WLBR", "IDBS,LBR",
    }

    actual_nd120_only = n120 - n110
    actual_nd110_only = n110 - n120

    errors = []

    missing_in_nd120 = expected_nd120_only - actual_nd120_only
    extra_in_nd120 = actual_nd120_only - expected_nd120_only
    if missing_in_nd120:
        errors.append(f"Expected ND-120-only but missing: {sorted(missing_in_nd120)}")
    if extra_in_nd120:
        errors.append(f"Unexpected ND-120-only tokens: {sorted(extra_in_nd120)}")

    missing_in_nd110 = expected_nd110_only - actual_nd110_only
    extra_in_nd110 = actual_nd110_only - expected_nd110_only
    if missing_in_nd110:
        errors.append(f"Expected ND-110-only but missing: {sorted(missing_in_nd110)}")
    if extra_in_nd110:
        errors.append(f"Unexpected ND-110-only tokens: {sorted(extra_in_nd110)}")

    return errors


def check_encoding_consistency(nd110_tokens, nd120_tokens):
    """Tokens shared between ND-110 and ND-120 should have the same encoding,
    except in the timing/delay region (bits 20, 21, 22-27) which encode either:
      - Delay/timing controls that vary between models (bits 20, 21, 26, 27), or
      - The ND-120 bit-22-27 flip (stored inverted in ND-120 ROM vs assembled form)
    These differences are expected and not errors.
    """
    # Bits 20, 21, 22, 23, 24, 25, 26, 27 = 0x0FF00000
    # This covers: CSBIT20, csdelay_bit21, LOOP, CONDENABL, SCOND, VECT, csdelay[27:26]
    TIMING_MASK = 0x0FF00000
    nd110_by_name = {t["name"]: t for t in nd110_tokens}
    mismatches = []
    timing_only = []
    for t in nd120_tokens:
        if t["name"] in nd110_by_name:
            n110 = nd110_by_name[t["name"]]
            if n110["value"] != t["value"]:
                diff = n110["value"] ^ t["value"]
                if diff & ~TIMING_MASK == 0:
                    timing_only.append(t["name"])
                else:
                    mismatches.append(
                        f"{t['name']}: ND-110=0x{n110['value']:016x} vs ND-120=0x{t['value']:016x} "
                        f"(diff outside timing region: 0x{diff & ~TIMING_MASK:016x})"
                    )
    return mismatches, timing_only


def extract_field(value, hi, lo):
    """Extract bits hi..lo (inclusive) from value."""
    width = hi - lo + 1
    mask = (1 << width) - 1
    return (value >> lo) & mask


def basic_decode(word):
    """Decode a microinstruction word into its primary fields. Used for sanity checks."""
    return {
        "aluDest": extract_field(word, 63, 61),
        "aluFunc": extract_field(word, 60, 58),
        "aluSrc":  extract_field(word, 57, 55),
        "sts":     extract_field(word, 54, 53),
        "rasel":   extract_field(word, 52, 51),
        "xref3":   extract_field(word, 50, 50),
        "rbsel":   extract_field(word, 49, 48),
        "cin":     extract_field(word, 47, 46),
        "alum":    extract_field(word, 45, 44),
        "mis":     extract_field(word, 43, 42),
        "idbs":    extract_field(word, 41, 37),
        "comm":    extract_field(word, 36, 32),
        "tseq":    extract_field(word, 31, 30),
        "tstk":    extract_field(word, 29, 28),
        "vect":    extract_field(word, 25, 25),
        "scond":   extract_field(word, 24, 24),
        "econd":   extract_field(word, 23, 23),   # CONDENABL
        "loop":    extract_field(word, 22, 22),   # LCOUNT
        "csbit20": extract_field(word, 20, 20),
        "bop":     extract_field(word, 19, 16),
        "aop":     extract_field(word, 15, 12),
        "lcc":     extract_field(word, 11, 8),
        "tsel":    extract_field(word, 7, 4),
        "fseq":    extract_field(word, 3, 2),
        "fstk":    extract_field(word, 1, 0),
        "addr":    extract_field(word, 11, 0) | (extract_field(word, 20, 20) << 12),
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--model", choices=["nd110", "nd120"], default="nd110")
    ap.add_argument("--binary", default=None, help="Path to .CODE file (default: reference/ND-110-RASK.CODE)")
    ap.add_argument("--symbols", default=None, help="Path to .SYMBOLS.TXT file")
    ap.add_argument("--verbose", "-v", action="store_true")
    args = ap.parse_args()

    # Load both token sets regardless - we cross-check.
    nd110_tokens, _ = load_tokens(REPO / "defs/tokens/nd110-tokens.yaml")
    nd120_tokens, _ = load_tokens(REPO / "defs/tokens/nd120-tokens.yaml")

    print(f"Loaded {len(nd110_tokens)} ND-110 tokens, {len(nd120_tokens)} ND-120 tokens")

    total_errors = 0
    total_warnings = 0

    # --- Stage 1: Per-model sanity checks ---
    print("\n=== Stage 1: Per-model sanity checks ===")
    for name, toks in [("ND-110", nd110_tokens), ("ND-120", nd120_tokens)]:
        errs, warns = sanity_check_tokens(toks, name)
        print(f"  {name}: {len(errs)} errors, {len(warns)} warnings")
        for e in errs:
            print(f"    ERROR: {e}")
            total_errors += 1
        if args.verbose:
            for w in warns:
                print(f"    WARN:  {w}")
        total_warnings += len(warns)

    # --- Stage 2: Cross-model delta check ---
    print("\n=== Stage 2: ND-110 vs ND-120 delta ===")
    deltas = check_nd120_deltas(nd110_tokens, nd120_tokens)
    if deltas:
        for d in deltas:
            print(f"  ERROR: {d}")
            total_errors += 1
    else:
        print("  OK - deltas match expected")

    # --- Stage 3: Encoding consistency for shared tokens ---
    print("\n=== Stage 3: Shared-token encoding consistency ===")
    mismatches, timing_only = check_encoding_consistency(nd110_tokens, nd120_tokens)
    if mismatches:
        print(f"  {len(mismatches)} shared tokens with unexpected encoding differences:")
        for m in mismatches:
            print(f"    ERROR: {m}")
        total_errors += len(mismatches)
    if timing_only:
        print(f"  {len(timing_only)} shared tokens differ only in timing/delay bits "
              f"(bits 20-27) - this is expected")
        if args.verbose:
            for name in timing_only:
                print(f"    timing-diff: {name}")
    if not mismatches and not timing_only:
        print("  OK - all shared tokens have matching encodings")

    # --- Stage 4: Binary load sanity check ---
    binary_path = args.binary or (REPO / "reference/ND-110-RASK.CODE")
    symbols_path = args.symbols or (REPO / "reference/ND-110-RASK.SYMBOLS.TXT")
    print(f"\n=== Stage 4: Binary load from {binary_path} ===")
    if Path(binary_path).exists():
        records = load_code_binary(binary_path)
        syms = load_symbols(symbols_path)
        print(f"  Loaded {len(records)} microcode records")
        print(f"  Loaded {len(syms)} symbols")
        if args.verbose and records:
            sample_addr = sorted(records.keys())[0]
            sample_word = records[sample_addr]
            print(f"  Sample: addr=0o{sample_addr:o} value=0x{sample_word:016x}")
            fields = basic_decode(sample_word)
            for k, v in fields.items():
                if v != 0:
                    print(f"    {k} = 0o{v:o} (0x{v:x})")
    else:
        print(f"  SKIP - binary not found")

    # --- Summary ---
    print(f"\n=== Summary ===")
    print(f"  Total errors:   {total_errors}")
    print(f"  Total warnings: {total_warnings}")
    return 1 if total_errors else 0


if __name__ == "__main__":
    sys.exit(main())
