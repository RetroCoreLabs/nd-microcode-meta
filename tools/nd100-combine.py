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

# Chip role mapping. Order matters: first entry in each list = LOW nibble
# (bits 0-3) of the output word.
#
# The PCB column number is inversely related to bit position: the chip
# at the HIGHEST-numbered column (d20 / c20 / b20) produces the LOWEST
# nibble, and the chip at the lowest-numbered column (d5 / c5 / b18)
# produces the HIGHEST nibble.
#
# Confirmed 100% bit-exact against Frode's independently-stitched ND-100
# images (both 3033S and 3033E-CX banks + Map PLAs) on 2026-04-17.
LAYOUTS = {
    "3033S": {
        # 64-bit microword built from 16 chips (12 data d5-d16 + 4
        # "sequencer" d17-d20). Column order is reversed wrt bit order:
        # d20 = bits 0-3 (low nibble), d5 = bits 60-63 (high nibble).
        "microcode": [
            ("01500P", "d20"),
            ("01501P", "d19"),
            ("01502Q", "d18"),
            ("01503Q", "d17"),
            ("01504N", "d16"),
            ("01505N", "d15"),
            ("01506N", "d14"),
            ("01507N", "d13"),
            ("01508N", "d12"),
            ("01509N", "d11"),
            ("01510N", "d10"),
            ("01511N", "d9"),
            ("01512N", "d8"),
            ("01513N", "d7"),
            ("01514N", "d6"),
            ("01515N", "d5"),
        ],
        # Decode PLA: 12-bit microaddress output. b20 = low nibble,
        # b18 = high nibble (column-reversed, same as data chips).
        "decode": [
            ("01600N", "b20"),
            ("01601N", "b19"),
            ("01602N", "b18"),
        ],
    },
    "3033E-CX": {
        # Base bank (d15 replaced with 01705N).
        "microcode": [
            ("01500P", "d20"),
            ("01501P", "d19"),
            ("01502Q", "d18"),
            ("01503Q", "d17"),
            ("01504N", "d16"),
            ("01705N", "d15"),  # patched in CX variant
            ("01506N", "d14"),
            ("01507N", "d13"),
            ("01508N", "d12"),
            ("01509N", "d11"),
            ("01510N", "d10"),
            ("01511N", "d9"),
            ("01512N", "d8"),
            ("01513N", "d7"),
            ("01514N", "d6"),
            ("01515N", "d5"),
        ],
        # Extension bank (row c), same 16-chip 64-bit layout.
        "microcode_ext": [
            ("08500D", "c20"),
            ("08501D", "c19"),
            ("08502D", "c18"),
            ("08503D", "c17"),
            ("08504D", "c16"),
            ("08505D", "c15"),
            ("08506D", "c14"),
            ("08507D", "c13"),
            ("08508D", "c12"),
            ("08509D", "c11"),
            ("08510D", "c10"),
            ("08511D", "c9"),
            ("08512D", "c8"),
            ("08513E", "c7"),
            ("08514E", "c6"),
            ("08515E", "c5"),
        ],
        "decode": [
            ("08600D", "b20"),
            ("08601D", "b19"),
            ("08602D", "b18"),
        ],
    },
}

PROM_DEPTH = 2048  # 82S185 addresses

# ND-100 XOR mask: bits 22-27 are stored inverted in the PROMs, relative to
# the canonical (active high) form of the assembler tokens. Same mask as the
# ND-110. Source: ND-06.018.01 EN "NORD-100 Microprogramming Description",
# "Writing the Microprogram": "bits 22 - 27 are inverted after the word is
# assembled"; the word description calls bits 22 to 27 active low.
# This tool does not apply the mask: the .CODE files it writes hold the words
# as they come from the chips (PROM form), like the ND-110 .CODE files.
# Readers flip them with this mask (parseCodeBytes with nd100XorFlip).
# Earlier versions of this comment gave 0x01800000 (bits 23-24) from bit
# statistics; that disagrees with the manual.
ND100_XOR_MASK = 0x0FC00000

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


def write_code(
    words: list[int],
    path: Path,
    width_bits: int,
    addr_offset: int = 0,
) -> None:
    """Write in the .CODE format: 2-byte LE address + 8-byte LE word
    per record. Skip all-zero words. Matches the ND110Compile convention
    so the TS library can parse it with parseCodeFile().

    ``addr_offset`` is added to each chip-local address so that the
    stored record represents the real microaddress on the CPU (e.g. the
    ND-100 extension bank is chip-addresses 0..2047 but those sit at
    microaddresses 0o4000..0o7777 in the 12-bit uaddr space).
    """
    bytes_per_word = 8  # always 8 bytes per record (same as ND-110/120)
    records = bytearray()
    for addr, word in enumerate(words):
        if word == 0:
            continue
        stored = addr + addr_offset
        records.append(stored & 0xFF)
        records.append((stored >> 8) & 0xFF)
        for i in range(bytes_per_word):
            records.append((word >> (i * 8)) & 0xFF)
    path.write_bytes(records)
    print(
        f"Wrote {len(records)} bytes ({len(records)//10} records) to {path}, "
        f"{width_bits}-bit microcode"
        + (f" (uaddr offset 0o{addr_offset:04o})" if addr_offset else ""),
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

        # The ND-100 CX extension bank (row c) sits at microaddresses
        # 0o4000..0o7777 in the 12-bit uaddr space. Its chips only have
        # 2K addresses (0..0o3777), so we need to add the 0o4000 offset
        # when writing the .CODE file so the stored record addresses
        # reflect the real microaddress the CPU sees. Same applies to
        # the extension sequencer role.
        addr_offset = 0
        if role.endswith("_ext"):
            addr_offset = 0o4000

        write_code(words, code_path, width, addr_offset=addr_offset)
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
