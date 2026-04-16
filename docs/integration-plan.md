# Integrating nd-microcode-meta into consumer repos

This doc describes how to wire `nd-microcode-meta` as a git submodule into:

1. **nd100uc** — TypeScript toolchain, VSCode extension, ROM combiner CLI
2. **ND110Compile** — C# assembler (+ embedded CPU emulator)

Both steps assume this repo has been pushed to GitHub (or another
reachable git remote) and you have the clone URL handy.

## Step 0 — push this repo

```bash
cd ~/repos/nd-microcode-meta
git remote add origin https://github.com/<user>/nd-microcode-meta.git
git push -u origin main
# optional: tag the release
git tag -a v1.0.0 -m "Initial extraction"
git push origin v1.0.0
```

From here, replace `<META_URL>` below with the clone URL.

---

## Step 1 — wire into nd100uc

**Goal:** replace the in-tree `nd100uc/defs/` directory with the
submodule, so nd100uc no longer owns its own copy of the metadata.

### 1a. Stash the local edits (if any)

```bash
cd ~/repos/nd100uc
git status          # confirm clean working tree; commit first if not
```

### 1b. Remove the in-tree defs/ and reference files

```bash
git rm -r defs/
git rm -r microcode/roms/
git rm microcode/ND-110-RASK.CODE microcode/ND-110-RASK.SYMBOLS.TXT microcode/ND-110-RASK.uc
git rm microcode/ND-120-DELILAH.CODE microcode/ND-120-DELILAH-L.CODE microcode/ND-120-DELILAH-L.SYMBOLS.TXT
git rm -r docs/    # docs/special-bits.md + PDF moved to meta repo
git rm -r tools/yaml-validator/  # moved to meta/tools/
git commit -m "Remove content moved to nd-microcode-meta submodule"
```

### 1c. Add the submodule

```bash
git submodule add <META_URL> external/meta
git submodule update --init
```

### 1d. Re-establish the expected paths with symlinks

This is the zero-code-change approach: existing generators and
loaders that reference `defs/`, `microcode/`, `docs/` keep working.

```bash
ln -s external/meta/defs defs
ln -s external/meta/docs docs
mkdir -p microcode
ln -s ../external/meta/reference/ND-110-RASK.CODE       microcode/ND-110-RASK.CODE
ln -s ../external/meta/reference/ND-110-RASK.SYMBOLS.TXT microcode/ND-110-RASK.SYMBOLS.TXT
ln -s ../external/meta/reference/ND-110-RASK.uc         microcode/ND-110-RASK.uc
ln -s ../external/meta/reference/ND-120-DELILAH.CODE    microcode/ND-120-DELILAH.CODE
ln -s ../external/meta/reference/ND-120-DELILAH-L.CODE  microcode/ND-120-DELILAH-L.CODE
ln -s ../external/meta/reference/ND-120-DELILAH-L.SYMBOLS.TXT microcode/ND-120-DELILAH-L.SYMBOLS.TXT
ln -s ../external/meta/reference/roms                   microcode/roms
git add external/meta defs docs microcode .gitmodules
git commit -m "Add nd-microcode-meta as submodule at external/meta + symlinks"
```

### 1e. Verify

```bash
cd lib/ts
npm run build
npm test            # should remain 81/81 passing
cd ../../vscode-extension
npm run build
```

### 1f. Update the documentation references

A handful of READMEs mention `defs/` as a first-party path. They
still resolve through the symlink so nothing breaks, but it's worth
a one-liner note that the YAML is now sourced from the submodule:

```bash
# Search for "defs/" in READMEs to add a note about the submodule.
grep -l "defs/" README.md defs/README.md vscode-extension/README.md
```

### 1g. Bumping the metadata version later

```bash
cd ~/repos/nd100uc/external/meta
git fetch
git checkout <new-commit-or-tag>
cd ../..
git add external/meta
git commit -m "Bump nd-microcode-meta to vX.Y.Z"
```

---

## Step 2 — wire into ND110Compile

**Goal:** have the C# assembler regenerate its `ND110Tokens.cs` /
`ND120Tokens.cs` from the meta repo's YAML, so the meta YAML
becomes the single source of truth for token encodings on the C#
side as well.

### 2a. Add the submodule

```bash
cd ~/repos/ND110Compile    # or wherever the C# repo lives
git submodule add <META_URL> external/meta
git submodule update --init
```

### 2b. (Optional but recommended) Write a C# generator

Mirror `nd-microcode-meta/tools/generate_tokens_yaml.py` in reverse —
a script that reads the YAML and writes `ND110Tokens.cs` /
`ND120Tokens.cs`. Run it as a pre-build step.

Skeleton in Python for clarity (could be a T4 template or a small
dotnet tool instead):

```python
# tools/generate-cs-from-yaml.py
import yaml
from pathlib import Path

REPO  = Path(__file__).resolve().parent.parent
META  = REPO / "external" / "meta"
NDxx0 = ("nd110", REPO / "ND110Compile" / "ND110Tokens.cs",
         META / "defs" / "tokens" / "nd110-tokens.yaml")
# ...similar for nd120...

for model, out_cs, yaml_path in [NDxx0, ...]:
    data = yaml.safe_load(yaml_path.read_text())
    lines = [
        "// AUTO-GENERATED from nd-microcode-meta/defs/tokens/...-tokens.yaml",
        "// Do not edit - run tools/generate-cs-from-yaml.py instead.",
        f"namespace ND110Compile {{",
        f"    internal class {'ND110Tokens' if model == 'nd110' else 'ND120Tokens'} : TokensBase {{",
        "        internal override void InitializeTokens() {",
        "            Clear();",
    ]
    for t in data["tokens"]:
        e = t["encoding"]
        desc = t["description"].replace('"', '\\"')
        flags = []   # derive from provides/requires, see original .cs flags
        lines.append(
            f'            AddToken("{t["token"]}", "{e["w4"]}", "{e["w3"]}", "{e["w2"]}", "{e["w1"]}", @"{desc}"{", ".join(flags)});'
        )
    lines += ["        }", "    }", "}", ""]
    out_cs.write_text("\n".join(lines))
```

### 2c. Alternative: leave C# hand-maintained, add a drift check

If rewriting the C# generator is too invasive, keep the hand-written
`.cs` files but add a CI check that diffs the C# against what the
YAML would produce. Fail the build on drift.

### 2d. Verify

```bash
dotnet build
# and validate the assembler still produces byte-identical RASK.CODE:
dotnet run --project ... # assemble external/meta/reference/ND-110-RASK.uc
diff <produced>.CODE external/meta/reference/ND-110-RASK.CODE
```

---

## Step 3 — consumer cloning experience

Anyone cloning either repo fresh needs `--recurse-submodules`:

```bash
git clone --recurse-submodules <CONSUMER_URL>
# or, after cloning without:
git submodule update --init --recursive
```

Document this in each consumer repo's README.

---

## Rollback

If the migration hits issues:

```bash
# In nd100uc:
git submodule deinit external/meta
git rm external/meta
rm -rf .git/modules/external/meta
git checkout HEAD~2 -- defs/ microcode/ docs/ tools/yaml-validator/
git commit -m "Revert: restore in-tree defs/"
```

---

## After migration - keep-in-sync etiquette

- **Edit metadata** → commit in `nd-microcode-meta`, tag, push.
- **Bump in consumers** → `git checkout <tag>` inside the submodule,
  commit the new pointer in the consumer repo.
- **C# drift** → run the C# generator after every YAML change, commit
  the regenerated `.cs` files alongside the submodule bump.
- **Never edit the submodule files from inside a consumer repo** —
  they'll be ignored on the next submodule update.
