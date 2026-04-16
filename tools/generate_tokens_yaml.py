#!/usr/bin/env python3
"""
Generate YAML token definitions from the existing ND110Compile C# source files.

This tool reads ND110Tokens.cs and ND120Tokens.cs and produces:
  - defs/tokens/nd110-tokens.yaml
  - defs/tokens/nd120-tokens.yaml

Tokens present only in ND-120 are marked with `nd120_only: true` in nd120-tokens.yaml.
Tokens whose encoding matches between ND-110 and ND-120 are marked as `models: [nd110, nd120]`.

The encoding is preserved as octal strings to match the original C# source.

Token category inference rules (derived from the token name prefix):
  A,*   -> A_REG
  B,*   -> B_REG
  AB,*  -> AB_REG
  PIC,* -> PIC
  ALUF,* -> ALUF
  ALUD,* -> ALUD
  ALUM,* -> ALUM
  STS,* -> STS
  CRY,* -> CRY
  MIS,* -> MIS
  IDBS,* -> IDBS
  COMM,* -> COMM
  T,*   -> T_SEQ or T_STK based on suffix
  F,*   -> F_SEQ or F_STK based on suffix
  COND,* -> COND
  LCOUNT/CONDENABL/XRF -> SPECIAL
"""

import argparse
import re
import sys
from pathlib import Path

# Map C# Constants.IsXxx flags to category/requirement hints.
FLAG_MAP = {
    "Constants.IsA":          {"provides": "A"},
    "Constants.IsB":          {"provides": "B"},
    "Constants.IsA_B":        {"provides": "AB"},
    "Constants.IsPIC":        {"provides": "PIC"},
    "Constants.RequireA":     {"requires": "A"},
    "Constants.RequireB":     {"requires": "B"},
    "Constants.RequireA_B":   {"requires": "AB"},
    "Constants.RequirePIC":   {"requires": "PIC"},
    "Constants.IsIDBS":       {"provides": "IDBS"},
    "Constants.IsTrueAddr":   {"provides": "T_SEQ"},
    "Constants.IsTrueStack":  {"provides": "T_STK"},
    "Constants.IsFalseAddr":  {"provides": "F_SEQ"},
    "Constants.IsFalseStack": {"provides": "F_STK"},
    "Constants.IsCond":       {"provides": "COND"},
}

# Regex to parse AddToken("name", "w4", "w3", "w2", "w1", @"description", flags)
# The flags argument is optional.
TOKEN_RE = re.compile(
    r'AddToken\(\s*'
    r'"([^"]+)"\s*,\s*'        # 1: token name
    r'"([^"]*)"\s*,\s*'        # 2: w4
    r'"([^"]*)"\s*,\s*'        # 3: w3
    r'"([^"]*)"\s*,\s*'        # 4: w2
    r'"([^"]*)"\s*,\s*'        # 5: w1
    r'@?"([^"]*)"'             # 6: description
    r'(?:\s*,\s*(.+?))?'       # 7: optional flags (rest)
    r'\s*\)\s*;',
    re.DOTALL
)

T_SEQ_TOKENS = {"T,JMP", "T,JMP0-3", "T,JMPAOPR", "T,RETURN", "T,NEXT"}
T_STK_TOKENS = {"T,HOLD", "T,POP", "T,LOAD", "T,PUSH"}
F_SEQ_TOKENS = {"F,JMP", "F,RETURN", "F,NEXT"}
F_STK_TOKENS = {"F,HOLD", "F,POP", "F,LOAD", "F,PUSH"}


def categorise(name, flags):
    """Return (category, display_line) for a token name."""
    if name in T_SEQ_TOKENS:
        return "T_SEQ", 2
    if name in T_STK_TOKENS:
        return "T_STK", 2
    if name in F_SEQ_TOKENS:
        return "F_SEQ", 3
    if name in F_STK_TOKENS:
        return "F_STK", 3
    if name.startswith("AB,"):
        return "AB_REG", 1
    if name.startswith("A,"):
        return "A_REG", 1
    if name.startswith("B,"):
        return "B_REG", 1
    if name.startswith("PIC,"):
        return "PIC", 1
    if name.startswith("ALUF,"):
        return "ALUF", 1
    if name.startswith("ALUD,"):
        return "ALUD", 1
    if name.startswith("ALUM,"):
        return "ALUM", 1
    if name.startswith("STS,"):
        return "STS", 1
    if name.startswith("CRY,"):
        return "CRY", 1
    if name.startswith("MIS,"):
        return "MIS", 1
    if name.startswith("IDBS,"):
        return "IDBS", 2
    if name.startswith("COMM,"):
        return "COMM", 2
    if name.startswith("COND,"):
        return "COND", 3
    if name in ("CONDENABL", "LCOUNT", "XRF", "CONT"):
        return "SPECIAL", 3 if name == "CONDENABL" else (2 if name == "LCOUNT" else 1)
    return "UNKNOWN", 1


def parse_flags(flags_str):
    """Parse the optional flags argument, returning a merged dict of hints."""
    if not flags_str:
        return {}
    result = {}
    # Strip (ushort)(...) wrapper if present
    cleaned = re.sub(r'\(ushort\)\(([^)]*)\)', r'\1', flags_str)
    parts = re.findall(r'Constants\.\w+', cleaned)
    for p in parts:
        hint = FLAG_MAP.get(p, {})
        for k, v in hint.items():
            # provides/requires should not conflict; keep last
            result[k] = v
    return result


def parse_tokens_cs(path):
    text = Path(path).read_text(encoding="utf-8", errors="replace")
    tokens = []
    for m in TOKEN_RE.finditer(text):
        name, w4, w3, w2, w1, desc, flags = m.groups()
        # Skip placeholder "NOT USED" entries
        if name == "NOT USED":
            continue
        # Skip commented-out entries (lines starting with //)
        line_start = text.rfind("\n", 0, m.start()) + 1
        if text[line_start:m.start()].lstrip().startswith("//"):
            continue
        tokens.append({
            "name": name,
            "w4": w4,
            "w3": w3,
            "w2": w2,
            "w1": w1,
            "description": desc,
            "flags": parse_flags(flags),
        })
    return tokens


def yaml_escape(s):
    """Minimal YAML string escaping - quote if has special chars."""
    if any(c in s for c in ':#&*![]{},|>?%@`"\'\\'):
        return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'
    if s and (s[0] in '-? ' or s.strip() != s):
        return '"' + s + '"'
    return s


def emit_yaml(tokens, model, header, out_path, nd120_only_names=None):
    """Write tokens to a YAML file."""
    nd120_only_names = nd120_only_names or set()
    lines = [header, "", f"model: {model}", f"token_count: {len(tokens)}", "", "tokens:"]
    for t in tokens:
        cat, line = categorise(t["name"], t["flags"])
        lines.append(f'  - token: {yaml_escape(t["name"])}')
        lines.append(f'    category: {cat}')
        lines.append(f'    display_line: {line}')
        lines.append(f'    encoding: {{ w4: "{t["w4"]}", w3: "{t["w3"]}", w2: "{t["w2"]}", w1: "{t["w1"]}" }}')
        lines.append(f'    description: {yaml_escape(t["description"])}')
        if t["flags"]:
            provides = t["flags"].get("provides")
            requires = t["flags"].get("requires")
            if provides:
                lines.append(f'    provides: {provides}')
            if requires:
                lines.append(f'    requires: {requires}')
        if t["name"] in nd120_only_names:
            lines.append(f'    nd120_only: true')
            lines.append(f'    models: [nd120]')
        else:
            if model == "ND-110":
                lines.append(f'    models: [nd100, nd110, nd120]')
            else:
                lines.append(f'    models: [nd100, nd110, nd120]')
    Path(out_path).write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {len(tokens)} tokens to {out_path}")


def main():
    # Writes into this repo (nd-microcode-meta).
    repo = Path(__file__).resolve().parent.parent

    ap = argparse.ArgumentParser(
        description="Regenerate defs/tokens/*.yaml from the reference C# source.",
    )
    ap.add_argument(
        "--nd110-cs",
        required=True,
        help="Path to ND110Tokens.cs (e.g. ~/repos/ND110Compile/ND110Compile/ND110Tokens.cs).",
    )
    ap.add_argument(
        "--nd120-cs",
        required=True,
        help="Path to ND120Tokens.cs.",
    )
    # Short-circuit argparse to use the already-collected CLI args.
    args, _ = ap.parse_known_args()
    src_nd110 = args.nd110_cs
    src_nd120 = args.nd120_cs

    nd110_tokens = parse_tokens_cs(src_nd110)
    nd120_tokens = parse_tokens_cs(src_nd120)

    nd110_names = {t["name"] for t in nd110_tokens}
    nd120_names = {t["name"] for t in nd120_tokens}

    nd120_only = nd120_names - nd110_names
    nd110_only = nd110_names - nd120_names
    common = nd110_names & nd120_names

    print(f"ND-110 tokens: {len(nd110_tokens)}")
    print(f"ND-120 tokens: {len(nd120_tokens)}")
    print(f"Common: {len(common)}")
    print(f"ND-110-only: {sorted(nd110_only)}")
    print(f"ND-120-only: {sorted(nd120_only)}")

    emit_yaml(
        nd110_tokens,
        "ND-110",
        "# ND-110 Microcode Token Definitions\n"
        "# Generated from ND110Compile/ND110Compile/ND110Tokens.cs\n"
        "# DO NOT EDIT MANUALLY - regenerate via tools/yaml-validator/generate_tokens_yaml.py\n"
        "# Encoding format: octal strings in w1 (bits 15:0), w2 (31:16), w3 (47:32), w4 (63:48)\n"
        "# Tokens are OR'd together to produce the final microinstruction word.",
        repo / "defs/tokens/nd110-tokens.yaml",
    )

    emit_yaml(
        nd120_tokens,
        "ND-120",
        "# ND-120 Microcode Token Definitions\n"
        "# Generated from ND110Compile/ND110Compile/ND120Tokens.cs\n"
        "# DO NOT EDIT MANUALLY - regenerate via tools/yaml-validator/generate_tokens_yaml.py\n"
        "# Tokens marked `nd120_only: true` are NOT present in ND-110.",
        repo / "defs/tokens/nd120-tokens.yaml",
        nd120_only_names=nd120_only,
    )


if __name__ == "__main__":
    main()
