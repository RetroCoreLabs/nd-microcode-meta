#!/usr/bin/env python3
"""
Combine/split ND-100 PROM images.

The ND-100 CPU uses many small 82S185 PROMs (2K x 8-bit, of which only
the low 4 bits are used) instead of the ND-110/120's two large EPROMs.
Each PROM provides 4 bits of the 48-bit microinstruction word at a
single slot position on the PCB.

Card variants in reference/roms/ND100/
--------------------------------------
3033S (base)   — 19 PROMs:
    d5..d16  (12 chips, 01504-01515 N rev)  = 48-bit microcode  data
    d17..d20 ( 4 chips, 01500-01503 P/Q)    = sequencer / next-address
    b18..b20 ( 3 chips, 01600-01602 N)      = instruction-decode PLA
                                              (addressed by macro opcode)

3033E-CX (extended)  35 PROMs:
    d5..d16  (12 chips, 01504-01515 N - d15=01705N replacement)
                                            = 48-bit microcode  data (base)
    d17..d20 ( 4 chips, 01500-01503 P/Q)    = sequencer (same as 3033S)
    c5..c16  (12 chips, 08504-08515 D/E)    = 48-bit microcode  (extension)
    c17..c20 ( 4 chips, 08500-08503 D)      = sequencer (extension)
    b18..b20 ( 3 chips, 08600-08602 D)      = decode PLA (CX version)

Every PROM is addressed by an 11-bit microaddress (0..2047) and returns
a 4-bit output. 12 PROMs in parallel form a 48-bit microword per
address. Combining the image is a simple interleave:

    for addr in 0..2047:
        word = 0
        for chip_index in 0..11:
            word |= chip[chip_index][addr] << (chip_index * 4)

Bit ordering convention
-----------------------
Physical bottom (d5 / c5) holds the LOW nibble (bits 0-3); physical top
(d16 / c16) holds the HIGH nibble (bits 44-47). This convention matches
the typical TTL schematic numbering where the lowest-numbered chip maps
to the lowest-weight bit.

Output
------
A `.CODE`-style file with 8 bytes per address (6 bytes of microcode,
little-endian, padded to 8 so it matches the ND-110/120 .CODE layout
used elsewhere in this repo). Preceded by a 2-byte little-endian
address. 10 bytes per record.

Addresses with "empty" (all-zero) microcode are NOT written, matching
the reference ND110Compile compiler output convention.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# Chip role mapping. Order matters: for the `microcode` role the first
# entry in the list = low nibble (bits 0-3) of the output word.
LAYOUTS = {
    "3033S": {
        "microcode": [
            ("01515N", "d5"),
            ("01514N", "d6"),
            ("01513N", "d7"),
            ("01512N", "d8"),
            ("01511N", "d9"),
            ("01510N", "d10"),
            ("01509N", "d11"),
            ("01508N", "d12"),
            ("01507N", "d13"),
            ("01506N", "d14"),
            ("01505N", "d15"),
            ("01504N", "d16"),
        ],
        "sequencer": [
            ("01503Q", "d17"),
            ("01502Q", "d18"),
            ("01501P", "d19"),
            ("01500P", "d20"),
        ],
        "decode": [
            ("01602N", "b18"),
            ("01601N", "b19"),
            ("01600N", "b20"),
        ],
    },
    "3033E-CX": {
        # Base bank (rows d + b - note d15 is replaced with 01705N)
        "microcode": [
            ("01515N", "d5"),
            ("01514N", "d6"),
            ("01513N", "d7"),
            ("01512N", "d8"),
            ("01511N", "d9"),
            ("01510N", "d10"),
            ("01509N", "d11"),
            ("01508N", "d12"),
            ("01507N", "d13"),
            ("01506N", "d14"),
            ("01705N", "d15"),  # patched in CX variant
            ("01504N", "d16"),
        ],
        "sequencer": [
            ("01503Q", "d17"),
            ("01502Q", "d18"),
            ("01501P", "d19"),
            ("01500P", "d20"),
        ],
        # Extension bank (row c)
        "microcode_ext": [
            ("08515E", "c5"),
            ("08514E", "c6"),
            ("08513E", "c7"),
            ("08512D", "c8"),
            ("08511D", "c9"),
            ("08510D", "c10"),
            ("08509D", "c11"),
            ("08508D", "c12"),
            ("08507D", "c13"),
            ("08506D", "c14"),
            ("08505D", "c15"),
            ("08504D", "c16"),
        ],
        "sequencer_ext": [
            ("08503D", "c17"),
            ("08502D", "c18"),
            ("08501D", "c19"),
            ("08500D", "c20"),
        ],
        "decode": [
            ("08602D", "b18"),
            ("08601D", "b19"),
            ("08600D", "b20"),
        ],
    },
}

PROM_DEPTH = 2048  # 82S185 addresses

def load_chip(directory: Path, partno: str, pos: str) -> bytes:
    """Find the chip file by part-number + position suffix."""
    pattern = re.compile(rf"^{re.escape(partno)}\.82s185\.{re.escape(pos)}$")
    matches = [p for p in directory.iterdir() if pattern.match(p.name)]
    if not matches:
        raise FileNotFoundError(
            f"No file matching {partno}.82s185.{pos} in {directory}",
        )
    if len(matches) > 1:
        raise RuntimeError(f"Multiple matches for {partno}/{pos}: {matches}")
    data = matches[0].read_bytes()
    if len(data) != PROM_DEPTH:
        raise RuntimeError(
            f"{matches[0].name} is {len(data)} bytes, expected {PROM_DEPTH}",
        )
    # Sanity-check: high nibbles should all be zero.
    bad = [i for i, b in enumerate(data) if (b >> 4) != 0]
    if bad:
        raise RuntimeError(
            f"{matches[0].name} has non-zero high nibbles at {len(bad)} "
            "addresses; this PROM is not being used as a 4-bit chip",
        )
    return data


def combine_role(directory: Path, chips: list[tuple[str, str]]) -> list[int]:
    """Combine a list of chips (ordered low -> high nibble) into one
    integer per address."""
    chip_data = [load_chip(directory, partno, pos) for partno, pos in chips]
    out: list[int] = [0] * PROM_DEPTH
    for addr in range(PROM_DEPTH):
        word = 0
        for idx, data in enumerate(chip_data):
            nibble = data[addr] & 0x0F
            word |= nibble << (idx * 4)
        out[addr] = word
    return out


def write_code(words: list[int], path: Path, width_bits: int) -> None:
    """Write in the .CODE format: 2-byte LE address + 8-byte LE word
    per record. Skip all-zero words. Matches the ND110Compile convention
    so the TS library can parse it with parseCodeFile()."""
    bytes_per_word = 8  # always 8 bytes per record (same as ND-110/120)
    records = bytearray()
    for addr, word in enumerate(words):
        if word == 0:
            continue
        records.append(addr & 0xFF)
        records.append((addr >> 8) & 0xFF)
        for i in range(bytes_per_word):
            records.append((word >> (i * 8)) & 0xFF)
    path.write_bytes(records)
    print(
        f"Wrote {len(records)} bytes ({len(records)//10} records) to {path}, "
        f"{width_bits}-bit microcode",
    )


def write_raw(words: list[int], path: Path) -> None:
    """Write every address, 8 bytes little-endian, including zeros.
    Useful for binary diffing against emulator/hardware dumps."""
    bytes_per_word = 8
    out = bytearray()
    for word in words:
        for i in range(bytes_per_word):
            out.append((word >> (i * 8)) & 0xFF)
    path.write_bytes(out)
    print(f"Wrote {len(out)} bytes ({len(out)//bytes_per_word} words) to {path}")


def combine(args: argparse.Namespace) -> None:
    in_dir = Path(args.indir)
    variant = args.variant
    if variant not in LAYOUTS:
        raise SystemExit(f"Unknown variant: {variant} (known: {list(LAYOUTS)})")
    layout = LAYOUTS[variant]
    out_dir = Path(args.outdir)
    out_dir.mkdir(parents=True, exist_ok=True)

    for role, chips in layout.items():
        words = combine_role(in_dir, chips)
        code_path = out_dir / f"{variant}-{role}.CODE"
        raw_path = out_dir / f"{variant}-{role}.raw"
        width = 4 * len(chips)
        write_code(words, code_path, width)
        if args.raw:
            write_raw(words, raw_path)


def split(args: argparse.Namespace) -> None:
    # Placeholder: the user can add this symmetric path when they need
    # to burn PROMs. The combine direction is the immediate need.
    raise SystemExit(
        "split is not implemented yet - combine first, then call if needed.",
    )


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="command", required=True)

    c = sub.add_parser("combine", help="Combine PROMs into .CODE files.")
    c.add_argument("--variant", required=True, choices=list(LAYOUTS.keys()))
    c.add_argument(
        "--indir",
        required=True,
        help="Directory containing the PROM files (e.g. reference/roms/ND100/3033S).",
    )
    c.add_argument(
        "--outdir",
        required=True,
        help="Output directory for the combined .CODE files.",
    )
    c.add_argument("--raw", action="store_true", help="Also write .raw dumps (no addr prefix).")
    c.set_defaults(func=combine)

    s = sub.add_parser("split", help="Split a .CODE file back into PROM images.")
    s.add_argument("--variant", required=True, choices=list(LAYOUTS.keys()))
    s.add_argument("--code", required=True)
    s.add_argument("--outdir", required=True)
    s.set_defaults(func=split)

    args = ap.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
