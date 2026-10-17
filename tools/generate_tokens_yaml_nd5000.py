#!/usr/bin/env python3
"""Generate defs/tokens/nd5000-tokens.yaml from the C# file ND5000Tokens.cs.

Usage:
    python3 tools/generate_tokens_yaml_nd5000.py <ND5000Tokens.cs> <ND5000Fields.cs> [out.yaml]

The C# files are passed as arguments (no hard-coded paths). Default output
is defs/tokens/nd5000-tokens.yaml next to this tools/ folder.

Two kinds of C# call:
    AddToken("NAME", "FIELD", value, "comment");   value << lowBit of FIELD
    AddMemToken("NAME", code, "comment");          code bit 3 -> bit 41,
                                                   code bits 2-0 -> bits 34-32

parts is 8 octal strings, MSB part first: bits 127-112 ... bits 15-0. The
part of bit n is 7 - n/16, as ND5000TokensBase.OrValueIntoWords does.
Category is the FIELD argument, or MEM for AddMemToken.
"""
import json
import os
import re
import sys

PART_COUNT = 8

FIELD_RE = re.compile(
    r'new ND5000Field\("([A-Z0-9_]+)",\s*(\d+),\s*(\d+)\)')
TOKEN_RE = re.compile(
    r'AddToken\("((?:[^"\\]|\\.)*)",\s*"([A-Z0-9_]+)",\s*(\d+),\s*'
    r'"((?:[^"\\]|\\.)*)"\)\s*;')
MEM_RE = re.compile(
    r'AddMemToken\("((?:[^"\\]|\\.)*)",\s*(\d+),\s*"((?:[^"\\]|\\.)*)"\)\s*;')


def unescape(text):
    return text.replace('\\"', '"').replace('\\\\', '\\')


def read_fields(path):
    """Return {name: (high, low)} for the partition and the subfields."""
    text = open(path, encoding='utf-8-sig').read()
    return {m.group(1): (int(m.group(2)), int(m.group(3)))
            for m in FIELD_RE.finditer(text)}


def or_value(words, high, low, value):
    for bit in range(low, high + 1):
        if (value >> (bit - low)) & 1:
            words[7 - bit // 16] |= 1 << (bit % 16)


def read_tokens(path, fields):
    """Return the tokens in file order as dicts."""
    text = open(path, encoding='utf-8-sig').read()
    found = []
    for m in TOKEN_RE.finditer(text):
        found.append((m.start(), 'field', m))
    for m in MEM_RE.finditer(text):
        found.append((m.start(), 'mem', m))
    found.sort(key=lambda x: x[0])
    calls = text.count('AddToken("') + text.count('AddMemToken("')
    if calls != len(found):
        raise SystemExit('calls %d but parsed %d' % (calls, len(found)))

    tokens = []
    for _, kind, m in found:
        words = [0] * PART_COUNT
        if kind == 'field':
            name, field, value, comment = (
                unescape(m.group(1)), m.group(2), int(m.group(3)),
                unescape(m.group(4)))
            high, low = fields[field]
            if value >= 1 << (high - low + 1):
                raise SystemExit('%s: value %d too wide for %s' % (name, value, field))
            or_value(words, high, low, value)
            tokens.append({'token': name, 'category': field, 'field': field,
                           'value': value, 'words': words, 'comment': comment})
        else:
            name, code, comment = (
                unescape(m.group(1)), int(m.group(2)), unescape(m.group(3)))
            if code > 15:
                raise SystemExit('%s: memory code %d out of range' % (name, code))
            or_value(words, 41, 41, (code >> 3) & 1)
            or_value(words, 34, 32, code & 7)
            tokens.append({'token': name, 'category': 'MEM', 'mem_code': code,
                           'words': words, 'comment': comment})
    return tokens


def main():
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    tokens_cs, fields_cs = sys.argv[1], sys.argv[2]
    here = os.path.dirname(os.path.abspath(__file__))
    out = sys.argv[3] if len(sys.argv) > 3 else os.path.join(
        here, '..', 'defs', 'tokens', 'nd5000-tokens.yaml')

    fields = read_fields(fields_cs)
    tokens = read_tokens(tokens_cs, fields)

    lines = [
        '# ND-5000 Microcode Token Definitions',
        '# Generated from ND110Compile/ND110Compile/ND5000Tokens.cs',
        '# (which is generated from microcode-5000-def.json, ND-05.022.1 Reference Manual Appendix A)',
        '# DO NOT EDIT MANUALLY - regenerate via tools/generate_tokens_yaml_nd5000.py',
        '# Encoding: parts is 8 octal strings, MSB part first: bits 127-112 ... bits 15-0.',
        '# field + value: the token puts value << lowBit of field (see defs/fields/nd5000-fields.yaml).',
        '# mem_code: memory operation, 4-bit code split: bit 3 -> word bit 41, bits 2-0 -> bits 34-32.',
        '# Tokens are OR\'d together to produce the final microinstruction word.',
        '',
        'model: ND-5000',
        'word_size_bits: 128',
        'part_count: %d' % PART_COUNT,
        'token_count: %d' % len(tokens),
        'source: "ND110Compile/ND110Compile/ND5000Tokens.cs"',
        '',
        'tokens:',
    ]
    for t in tokens:
        lines.append('  - token: %s' % json.dumps(t['token']))
        lines.append('    category: %s' % t['category'])
        if 'field' in t:
            lines.append('    field: %s' % t['field'])
            lines.append('    value: %d' % t['value'])
        else:
            lines.append('    mem_code: %d' % t['mem_code'])
        lines.append('    encoding: { parts: [%s] }'
                     % ', '.join('"%06o"' % w for w in t['words']))
        lines.append('    description: %s' % json.dumps(t['comment']))
    with open(out, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines) + '\n')
    print('nd5000: wrote %d tokens to %s' % (len(tokens), out))


if __name__ == '__main__':
    main()
