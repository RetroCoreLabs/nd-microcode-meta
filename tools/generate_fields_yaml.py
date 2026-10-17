#!/usr/bin/env python3
"""Generate defs/fields/nd10-fields.yaml, nd500-fields.yaml, nd5000-fields.yaml
from the C# field files ND10Fields.cs, ND500Fields.cs, ND5000Fields.cs.

Usage:
    python3 tools/generate_fields_yaml.py nd10   <ND10Fields.cs>   [out.yaml]
    python3 tools/generate_fields_yaml.py nd500  <ND500Fields.cs>  [out.yaml]
    python3 tools/generate_fields_yaml.py nd5000 <ND5000Fields.cs> [out.yaml]

The C# file is passed as an argument (no hard-coded path). Default output is
defs/fields/<model>-fields.yaml next to this tools/ folder.

nd500 and nd5000: `partition:` lists the non-overlapping fields, highest bit
first; `subfields:` lists the fields that overlap the partition.
nd10: `fields:` lists every named field; the fields overlap on purpose, and
`format:` says which of the four micro instruction formats the field is used
in (ARITHMETIC, INTERBLOCK, JUMP, LOOP, joined with |, or ALL).
"""
import json
import os
import re
import sys

HEADERS = {
    'nd10': {
        'model': 'NORD-10', 'word_size_bits': 32, 'byte_count': 4,
        'byte_order': 'big-endian', 'part_count': 2,
        'control_store_words': '[1024, 4096]', 'binary_format': 'prom-hex',
        'source': 'ND110Compile/ND110Compile/ND10Fields.cs',
        'class': 'ND10Field',
    },
    'nd500': {
        'model': 'ND-500', 'word_size_bits': 144, 'byte_count': 18,
        'byte_order': 'big-endian', 'part_count': 9,
        'control_store_words': '8192', 'binary_format': 'packed18',
        'source': 'ND110Compile/ND110Compile/ND500Fields.cs',
        'class': 'ND500Field',
    },
    'nd5000': {
        'model': 'ND-5000', 'word_size_bits': 128, 'byte_count': 16,
        'byte_order': 'big-endian', 'part_count': 8,
        'control_store_words': '16384', 'binary_format': 'be16x8',
        'source': 'ND110Compile/ND110Compile/ND5000Fields.cs',
        'class': 'ND5000Field',
    },
}

ND10_GROUPS = [('// ARITHMETIC / INTERBLOCK', 'ARITHMETIC|INTERBLOCK'),
               ('// JUMP', 'JUMP'), ('// LOOP', 'LOOP')]


def field_re(cls):
    return re.compile(
        r'new %s\("([A-Z0-9_]+)",\s*(\d+),\s*(\d+)\)\s*,?\s*(?://\s*(.*))?$'
        % cls, re.M)


def entry(name, high, low, desc, fmt=None):
    out = ['  - name: %s' % name,
           '    high_bit: %d' % high,
           '    low_bit: %d' % low]
    if fmt:
        out.append('    format: %s' % fmt)
    if desc:
        out.append('    description: %s' % json.dumps(desc))
    return out


def gen_nd10(text, hdr):
    # Keep only the field declarations, stop before the lookup table.
    text = text[text.index('public static class ND10Fields'):
                text.index('static readonly Dictionary')]
    fmt = 'ALL'
    lines = []
    names = []
    for raw in text.splitlines():
        s = raw.strip()
        for marker, group in ND10_GROUPS:
            if s == marker:
                fmt = group
        m = re.search(r'new ND10Field\("([A-Z0-9_]+)",\s*(\d+),\s*(\d+)\)', s)
        if m:
            names.append(m.group(1))
            lines += entry(m.group(1), int(m.group(2)), int(m.group(3)),
                           None, fmt)
    return ['fields:'] + lines, len(names)


def gen_partitioned(text, hdr):
    a = text.index('Partition =')
    b = text.index('Subfields =')
    c = text.index('static readonly Dictionary')
    rx = field_re(hdr['class'])
    out = []
    counts = []
    for title, chunk in (('partition', text[a:b]), ('subfields', text[b:c])):
        items = []
        for m in rx.finditer(chunk):
            items += entry(m.group(1), int(m.group(2)), int(m.group(3)),
                           (m.group(4) or '').strip())
            counts.append(m.group(1))
        out += ['%s:' % title] + items + ['']
    return out, len(counts)


def main():
    if len(sys.argv) < 3 or sys.argv[1] not in HEADERS:
        raise SystemExit(__doc__)
    key, path = sys.argv[1], sys.argv[2]
    hdr = HEADERS[key]
    here = os.path.dirname(os.path.abspath(__file__))
    out = sys.argv[3] if len(sys.argv) > 3 else os.path.join(
        here, '..', 'defs', 'fields', '%s-fields.yaml' % key)
    text = open(path, encoding='utf-8-sig').read()
    body, count = (gen_nd10 if key == 'nd10' else gen_partitioned)(text, hdr)

    lines = [
        '# %s Microinstruction Word Field Definitions' % hdr['model'],
        '# Generated from %s' % hdr['source'],
        '# DO NOT EDIT MANUALLY - regenerate via tools/generate_fields_yaml.py',
        '# Bit positions are numbered LSB-first (bit 0 is the least significant bit).',
        '',
        'model: %s' % hdr['model'],
        'word_size_bits: %d' % hdr['word_size_bits'],
        'byte_count: %d' % hdr['byte_count'],
        'byte_order: %s' % hdr['byte_order'],
        'part_count: %d' % hdr['part_count'],
        'control_store_words: %s' % hdr['control_store_words'],
        'binary_format: %s' % hdr['binary_format'],
        '',
    ] + body
    with open(out, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines).rstrip('\n') + '\n')
    print('%s: wrote %d fields to %s' % (key, count, out))


if __name__ == '__main__':
    main()
