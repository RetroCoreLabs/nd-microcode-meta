#!/usr/bin/env python3
"""Check defs/tokens/nd10|nd500|nd5000-tokens.yaml and defs/fields/*-fields.yaml
against the C# files they were generated from.

Usage:
    python3 tools/validate_new_models.py <folder with the C# files>

The folder holds ND10Tokens.cs, ND10Fields.cs, ND500Tokens.cs, ND500Fields.cs,
ND5000Tokens.cs, ND5000Fields.cs. Nothing is written. Exit code 1 on any
difference in name, bits, count, category or description.

The C# files are read with the parsers of the three generator scripts in this
folder. On top of that the checks below do not use the generators' own output
path: they recompute every value from the C# data and compare it to what
PyYAML reads back from the YAML files.
"""
import os
import sys

try:
    import yaml
except ImportError:
    raise SystemExit('PyYAML is required: pip install pyyaml')

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ROOT = os.path.join(HERE, '..')

import generate_tokens_yaml_nd10 as g10          # noqa: E402
import generate_tokens_yaml_nd500 as g500        # noqa: E402
import generate_tokens_yaml_nd5000 as g5000      # noqa: E402

errors = []


def err(msg):
    errors.append(msg)


def load(rel):
    with open(os.path.join(ROOT, rel), encoding='utf-8') as f:
        return yaml.safe_load(f)


def check_header(doc, label, model, bits, parts, count):
    for key, want in (('model', model), ('word_size_bits', bits),
                      ('part_count', parts), ('token_count', count)):
        if doc.get(key) != want:
            err('%s: header %s is %r, expected %r' % (label, key, doc.get(key), want))
    if len(doc['tokens']) != count:
        err('%s: %d tokens in YAML, %d in C#' % (label, len(doc['tokens']), count))


def parts_of(token):
    return list(token['encoding']['parts'])


def check_partition(label, fields_doc, top, bottom):
    """The partition must name every bit from top down to bottom once."""
    seen = {}
    for f in fields_doc['partition']:
        for b in range(f['low_bit'], f['high_bit'] + 1):
            if b in seen:
                err('%s: bit %d in both %s and %s' % (label, b, seen[b], f['name']))
            seen[b] = f['name']
    for b in range(bottom, top + 1):
        if b not in seen:
            err('%s: bit %d is in no partition field' % (label, b))
    return len(fields_doc['partition'])


def compare_fields(label, cs_path, regex_cls, doc):
    import re
    text = open(cs_path, encoding='utf-8-sig').read()
    rx = re.compile(r'new %s\("([A-Z0-9_]+)",\s*(\d+),\s*(\d+)\)' % regex_cls)
    c_fields = [(m.group(1), int(m.group(2)), int(m.group(3)))
                for m in rx.finditer(text)]
    if 'fields' in doc:
        y_fields = doc['fields']
    else:
        y_fields = doc['partition'] + doc['subfields']
    y = [(f['name'], f['high_bit'], f['low_bit']) for f in y_fields]
    if c_fields != y:
        err('%s: field list differs (C# %d, YAML %d)' % (label, len(c_fields), len(y)))
    return len(c_fields)


def validate_nd500(cs_dir):
    tokens = g500.read_tokens(os.path.join(cs_dir, 'ND500Tokens.cs'))
    partition = g500.read_partition(os.path.join(cs_dir, 'ND500Fields.cs'))
    doc = load('defs/tokens/nd500-tokens.yaml')
    check_header(doc, 'nd500', 'ND-500', 144, 9, len(tokens))
    names = set()
    for (name, parts, comment), y in zip(tokens, doc['tokens']):
        if name in names:
            err('nd500: duplicate token %s' % name)
        names.add(name)
        if y['token'] != name:
            err('nd500: order/name %r vs %r' % (y['token'], name))
        if parts_of(y) != parts:
            err('nd500: %s parts differ' % name)
        if y['description'] != comment:
            err('nd500: %s description differs' % name)
        if y['category'] != g500.category(g500.parts_to_value(parts), partition):
            err('nd500: %s category differs' % name)
    fdoc = load('defs/fields/nd500-fields.yaml')
    n = compare_fields('nd500 fields', os.path.join(cs_dir, 'ND500Fields.cs'),
                       'ND500Field', fdoc)
    check_partition('nd500 fields', fdoc, 143, 32)
    return len(tokens), n


def validate_nd5000(cs_dir):
    fields_cs = os.path.join(cs_dir, 'ND5000Fields.cs')
    fdoc = load('defs/fields/nd5000-fields.yaml')
    n = compare_fields('nd5000 fields', fields_cs, 'ND5000Field', fdoc)
    check_partition('nd5000 fields', fdoc, 127, 0)
    # Bit positions for the check come from the YAML fields file, the
    # values come from the C# file.
    bounds = {f['name']: (f['high_bit'], f['low_bit'])
              for f in fdoc['partition'] + fdoc['subfields']}
    tokens = g5000.read_tokens(os.path.join(cs_dir, 'ND5000Tokens.cs'),
                               g5000.read_fields(fields_cs))
    doc = load('defs/tokens/nd5000-tokens.yaml')
    check_header(doc, 'nd5000', 'ND-5000', 128, 8, len(tokens))
    names, pairs = set(), set()
    for t, y in zip(tokens, doc['tokens']):
        name = t['token']
        if name in names:
            err('nd5000: duplicate token %s' % name)
        names.add(name)
        key = (t['category'], t.get('value', t.get('mem_code')))
        if key in pairs:
            err('nd5000: duplicate (field,value) %r' % (key,))
        pairs.add(key)
        if y['token'] != name:
            err('nd5000: order/name %r vs %r' % (y['token'], name))
        words = [0] * 8
        if 'field' in t:
            if (y.get('field'), y.get('value')) != (t['field'], t['value']):
                err('nd5000: %s field/value differ' % name)
            high, low = bounds[y['field']]
            g5000.or_value(words, high, low, y['value'])
        else:
            if y.get('mem_code') != t['mem_code']:
                err('nd5000: %s mem_code differs' % name)
            g5000.or_value(words, 41, 41, (y['mem_code'] >> 3) & 1)
            g5000.or_value(words, 34, 32, y['mem_code'] & 7)
        if parts_of(y) != ['%06o' % w for w in words]:
            err('nd5000: %s parts differ from field/value' % name)
        if parts_of(y) != ['%06o' % w for w in t['words']]:
            err('nd5000: %s parts differ from C# value' % name)
        if y['description'] != t['comment']:
            err('nd5000: %s description differs' % name)
        if y['category'] != t['category']:
            err('nd5000: %s category differs' % name)
    return len(tokens), n


def validate_nd10(cs_dir):
    tokens = g10.read_tokens(os.path.join(cs_dir, 'ND10Tokens.cs'))
    doc = load('defs/tokens/nd10-tokens.yaml')
    check_header(doc, 'nd10', 'NORD-10', 32, 2, len(tokens))
    names = set()
    for (name, cat, value, comment), y in zip(tokens, doc['tokens']):
        if name in names:
            err('nd10: duplicate token %s' % name)
        names.add(name)
        if y['token'] != name:
            err('nd10: order/name %r vs %r' % (y['token'], name))
        hi, lo = (int(p, 8) for p in parts_of(y))
        if (hi << 16) | lo != value:
            err('nd10: %s parts differ' % name)
        if int(y['hex'], 16) != value:
            err('nd10: %s hex differs' % name)
        if y['description'] != comment:
            err('nd10: %s description differs' % name)
        if y['category'] != cat:
            err('nd10: %s category differs' % name)
    fdoc = load('defs/fields/nd10-fields.yaml')
    n = compare_fields('nd10 fields', os.path.join(cs_dir, 'ND10Fields.cs'),
                       'ND10Field', fdoc)
    return len(tokens), n


def main():
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    cs_dir = sys.argv[1]
    results = []
    for label, fn in (('nd10', validate_nd10), ('nd500', validate_nd500),
                      ('nd5000', validate_nd5000)):
        before = len(errors)
        count, fields = fn(cs_dir)
        status = 'OK' if len(errors) == before else 'FAILED'
        results.append('%s: %d tokens, %d fields %s' % (label, count, fields, status))
    for line in results:
        print(line)
    for e in errors[:50]:
        print('ERROR: ' + e)
    if errors:
        print('%d errors' % len(errors))
        sys.exit(1)


if __name__ == '__main__':
    main()
