# nd-microcode-meta

Data, a library and reference files for the microcode of six Norsk Data
machines: NORD-10, ND-100, ND-110, ND-120, ND-500 and ND-5000.

## What is in the repository

- **Token and field definitions** in YAML: every mnemonic with its bits, and the bit fields of the microinstruction word.
  In `defs/tokens` and `defs/fields`. Pages: [YAML format](docs/yaml-format.md), [Variants](docs/variants/index.md).
- **Runtime data flow, registers, conditions and assembly format** in YAML.
  In `defs/runtime`, `defs/common` and `defs/format`. Page: [Definitions](docs/definitions/data-flow.md).
- **A TypeScript library** (`@nd100uc/microcode`): assemble, disassemble, read and write the image formats, guess the variant of a source file.
  In `lib/ts`. Pages: [Using the library](docs/library.md), [Library API](docs/api/index.md).
- **Reference files**: ROM dumps from real cards, and the output of the C# compiler that the library is checked against.
  In `reference`. Page: [Reference material](reference/README.md).
- **Python tools** that make the YAML from the C# files, check it, and combine ND-100 PROM images.
  In `tools`. Page: [Tools](docs/tools.md).
- **Hardware notes** in `docs`. Pages: [Special bits](docs/special-bits.md), [ND-100 PROM layout](docs/nd100-prom-layout.md).

## The variants

| Name | Machine | Page |
|------|---------|------|
| `nd10` | NORD-10 | [NORD-10](docs/variants/nd10.md) |
| `nd100` | ND-100 | [ND-100](docs/variants/nd100.md) |
| `nd110` | ND-110 | [ND-110](docs/variants/nd110.md) |
| `nd120` | ND-120, version K | [ND-120](docs/variants/nd120.md) |
| `nd120-dly` | ND-120, version L | [ND-120 (version L)](docs/variants/nd120-dly.md) |
| `nd500` | ND-500 | [ND-500](docs/variants/nd500.md) |
| `nd5000` | ND-5000 | [ND-5000](docs/variants/nd5000.md) |

## Who uses it

- The [VS Code extension](https://retrocorelabs.github.io/vs-extension-nd110-uc/) for `.uc` files. It has this repository as a git submodule (`external/meta`) and bundles the library.
- The C# compiler `ND110Compile`. The tools in `tools/` read its token and field files (`ND10Tokens.cs`, `ND500Tokens.cs` and so on) and write the YAML here.

The library tests assemble the sources in `reference/` and compare the result
with files made by the C# compiler. They also disassemble real ROM images
and assemble the text again. Details are in
[Reference material](reference/README.md) and in the tests under `lib/ts/tests`.

## Other files

- [`README.md`](https://github.com/RetroCoreLabs/nd-microcode-meta/blob/main/README.md): the front page of the repository.
- [Changelog](CHANGELOG.md)
