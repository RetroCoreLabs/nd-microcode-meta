#!/usr/bin/env python3
"""Generate defs/tokens/nd10-tokens.yaml from the C# file ND10Tokens.cs.

Usage:
    python3 tools/generate_tokens_yaml_nd10.py <ND10Tokens.cs> [out.yaml]

The C# file is passed as an argument (no hard-coded path). Default output
is defs/tokens/nd10-tokens.yaml next to this tools/ folder.

Every call has the shape
    Add("NAME", <expression>, "comment");
where the expression uses Bit(n), At(low, value), the constants declared in
the file (OP_INTB, OP_JUMP, OP_LOOP, LOG, MOST, COND), | and plain numbers.
The two for-loops (LE0..LE17 and B,B0..B,B17) are expanded here.

parts is 2 octal strings, MSB part first: bits 31-16, bits 15-0.
Category comes from the section header comment ("// ---- Title ---") that
precedes the Add call.
"""
import json
import os
import re
import sys

SECTION_CATEGORY = [
    ('Instruction mnemonics', 'format'),
    ('Test conditions', 'test'),
    ('Cycle specification', 'cycle'),
    ('Bit 20, 19', 'bit20_19'),
    ('OR specification', 'or'),
    ('ALU function select', 'alu'),
    ('LOOP: alternative ALU', 'loop_alt'),
    ('LOOP: shift control', 'loop_shift'),
    ('INTERBLOCK program level', 'level'),
    ('Destination register', 'dest'),
    ('B operand', 'b_operand'),
    ('A operand', 'a_operand'),
]

HEADER_RE = re.compile(r'//\s*-{3,}\s*(.*?)\s*-{2,}\s*$', re.M)
CONST_RE = re.compile(r'const uint (\w+)\s*=\s*([^;]+);')
ADD_RE = re.compile(
    r'\bAdd\("((?:[^"\\]|\\.)*)",\s*(.*?),\s*"((?:[^"\\]|\\.)*)"\);')
LOOP_LE = re.compile(r'Add\("LE"\s*\+')
LOOP_BB = re.compile(r'Add\("B,B"\s*\+')


def unescape(text):
    return text.replace('\\"', '"').replace('\\\\', '\\')


def c_expr(text, env):
    """Evaluate a C# uint expression made of numbers, | << and names."""
    text = re.sub(r'\b(\d+)u\b', r'\1', text)
    return eval(text, {'__builtins__': {}}, env) & 0xFFFFFFFF


def build_env(source):
    env = {
        'Bit': lambda n: 1 << n,
        'At': lambda low, value: (value << low) & 0xFFFFFFFF,
    }
    for m in CONST_RE.finditer(source):
        env[m.group(1)] = c_expr(m.group(2), env)
    return env


def category_at(headers, pos):
    title = None
    for hpos, htitle in headers:
        if hpos < pos:
            title = htitle
    for prefix, cat in SECTION_CATEGORY:
        if title is not None and title.startswith(prefix):
            return cat
    raise SystemExit('no category for section %r' % title)


def read_tokens(path):
    source = open(path, encoding='utf-8-sig').read()
    start = source.index('public void InitializeTokens()')
    body_start = start
    env = build_env(source)
    headers = [(m.start() + 0, m.group(1)) for m in HEADER_RE.finditer(source)
               if m.start() > body_start]

    items = []   # (position, name, value, comment)
    for m in ADD_RE.finditer(source, body_start):
        items.append((m.start(), unescape(m.group(1)),
                      c_expr(m.group(2), env), unescape(m.group(3))))

    m = LOOP_LE.search(source, body_start)
    for level in range(16):
        name = 'LE%o' % level
        items.append((m.start() + level * 1e-3, name, level << 12,
                      'Program level %o (INTERBLOCK)' % level))
    m = LOOP_BB.search(source, body_start)
    for bit in range(16):
        name = 'B,B%o' % bit
        items.append((m.start() + bit * 1e-3, name, (10 << 4) | (bit << 12),
                      'Bit mask with bit %o set as B operand' % bit))

    calls = len(re.findall(r'\bAdd\("', source[body_start:]))
    plain = len(items) - 32
    if calls != plain + 2:
        raise SystemExit('Add calls %d but parsed %d plain + 2 loops' % (calls, plain))
    items.sort(key=lambda x: x[0])

    tokens = []
    seen = set()
    for pos, name, value, comment in items:
        if name in seen:
            raise SystemExit('duplicate token ' + name)
        seen.add(name)
        tokens.append((name, category_at(headers, pos), value, comment))
    return tokens


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    here = os.path.dirname(os.path.abspath(__file__))
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(
        here, '..', 'defs', 'tokens', 'nd10-tokens.yaml')
    tokens = read_tokens(sys.argv[1])

    lines = [
        '# NORD-10 Microcode Token Definitions (MICMAC mnemonics, 32-bit word)',
        '# Generated from ND110Compile/ND110Compile/ND10Tokens.cs',
        '# Sources: ND-06.010.01 section 3.1; bit positions from the MICMAC reconstruction',
        '# by Anders Magnusson, checked by round trip against two real PROM dumps.',
        '# DO NOT EDIT MANUALLY - regenerate via tools/generate_tokens_yaml_nd10.py',
        '# Encoding: parts is 2 octal strings, MSB part first: bits 31-16, bits 15-0.',
        '# Tokens are OR\'d together to produce the final microinstruction word.',
        '',
        'model: NORD-10',
        'word_size_bits: 32',
        'part_count: 2',
        'token_count: %d' % len(tokens),
        'source: "ND110Compile/ND110Compile/ND10Tokens.cs"',
        '',
        'tokens:',
    ]
    for name, cat, value, comment in tokens:
        lines.append('  - token: %s' % json.dumps(name))
        lines.append('    category: %s' % cat)
        lines.append('    hex: "0x%08X"' % value)
        lines.append('    encoding: { parts: ["%06o", "%06o"] }'
                     % (value >> 16, value & 0xFFFF))
        lines.append('    description: %s' % json.dumps(comment))
    with open(out, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines) + '\n')
    print('nd10: wrote %d tokens to %s' % (len(tokens), out))


if __name__ == '__main__':
    main()
