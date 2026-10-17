#!/usr/bin/env python3
"""Generate defs/tokens/nd500-tokens.yaml from the C# file ND500Tokens.cs.

Usage:
    python3 tools/generate_tokens_yaml_nd500.py <ND500Tokens.cs> <ND500Fields.cs> [out.yaml]

The C# files are passed as arguments (no hard-coded paths). Default output
is defs/tokens/nd500-tokens.yaml next to this tools/ folder.

Each AddToken call has the shape
    AddToken("NAME", f1, f2, f3, f4, f5, f6, f7, f8, f9, "comment");
with f1..f9 = control store parts CS8..CS0, octal strings, CS8 first.

Category rule: the partition field (ND500Fields.Partition) that holds all
bits of the token; ZERO when no bit is set; ARG when any bit is below
bit 32; MULTI when the bits lie in more than one partition field.
"""
import json
import os
import re
import sys

PART_COUNT = 9

FIELD_RE = re.compile(
    r'new ND500Field\("([A-Z0-9_]+)",\s*(\d+),\s*(\d+)\)')
TOKEN_RE = re.compile(
    r'AddToken\("((?:[^"\\]|\\.)*)",\s*'
    + r',\s*'.join(['"([0-7]{6})"'] * PART_COUNT)
    + r',\s*"((?:[^"\\]|\\.)*)"\)\s*;')


def unescape(text):
    return text.replace('\\"', '"').replace('\\\\', '\\')


def read_partition(path):
    """Return the partition list [(name, high, low)], highest bit first."""
    text = open(path, encoding='utf-8-sig').read()
    start = text.index('Partition =')
    end = text.index('Subfields =')
    return [(m.group(1), int(m.group(2)), int(m.group(3)))
            for m in FIELD_RE.finditer(text[start:end])]


def read_tokens(path):
    text = open(path, encoding='utf-8-sig').read()
    tokens = []
    for m in TOKEN_RE.finditer(text):
        tokens.append((unescape(m.group(1)),
                       [m.group(i) for i in range(2, 2 + PART_COUNT)],
                       unescape(m.group(2 + PART_COUNT))))
    calls = text.count('AddToken(')
    if calls != len(tokens):
        raise SystemExit('AddToken calls %d but parsed %d' % (calls, len(tokens)))
    return tokens


def parts_to_value(parts):
    v = 0
    for p in parts:
        v = (v << 16) | int(p, 8)
    return v


def category(value, partition):
    if value == 0:
        return 'ZERO'
    if value & 0xFFFFFFFF:
        return 'ARG'
    hit = set()
    for name, high, low in partition:
        mask = ((1 << (high - low + 1)) - 1) << low
        if value & mask:
            hit.add(name)
    if len(hit) == 1:
        return hit.pop()
    return 'MULTI'


def main():
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    tokens_cs, fields_cs = sys.argv[1], sys.argv[2]
    here = os.path.dirname(os.path.abspath(__file__))
    out = sys.argv[3] if len(sys.argv) > 3 else os.path.join(
        here, '..', 'defs', 'tokens', 'nd500-tokens.yaml')

    partition = read_partition(fields_cs)
    tokens = read_tokens(tokens_cs)

    lines = [
        '# ND-500 Microcode Token Definitions',
        '# Generated from ND110Compile/ND110Compile/ND500Tokens.cs',
        '# (which is generated from docs/ND500-MNEMONIC-VALUES.md, Appendix A of ND-30.013.02)',
        '# DO NOT EDIT MANUALLY - regenerate via tools/generate_tokens_yaml_nd500.py',
        '# Encoding: parts is 9 octal strings, MSB part first: CS8 (bits 143-128) ... CS0 (bits 15-0).',
        '# Tokens are OR\'d together to produce the final microinstruction word.',
        '',
        'model: ND-500',
        'word_size_bits: 144',
        'part_count: %d' % PART_COUNT,
        'token_count: %d' % len(tokens),
        'source: "ND110Compile/ND110Compile/ND500Tokens.cs"',
        '',
        'tokens:',
    ]
    for name, parts, comment in tokens:
        cat = category(parts_to_value(parts), partition)
        lines.append('  - token: %s' % json.dumps(name))
        lines.append('    category: %s' % cat)
        lines.append('    encoding: { parts: [%s] }'
                     % ', '.join('"%s"' % p for p in parts))
        lines.append('    description: %s' % json.dumps(comment))
    with open(out, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines) + '\n')
    print('nd500: wrote %d tokens to %s' % (len(tokens), out))


if __name__ == '__main__':
    main()
