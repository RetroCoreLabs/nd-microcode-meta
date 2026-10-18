# Contributing

## Documentation site

The site is built with MkDocs and the Material theme and published on GitHub
Pages: <https://retrocorelabs.github.io/nd-microcode-meta/>

| What | Where |
|------|-------|
| Pages written by hand | `index.md`, `CHANGELOG.md`, `docs/yaml-format.md`, `docs/library.md`, `docs/special-bits.md`, `docs/nd100-prom-layout.md`, `docs/integration-plan.md`, `reference/README.md`, `reference/roms/ND100/README.md` |
| Pages made from the repository | `docs/variants/`, `docs/definitions/`, `docs/api/`, `docs/tools.md` |
| Navigation | `docs-site/mkdocs.yml` (made by the script) |
| Settings of the site | `docs-site/base.yml` |
| Link rewriting | `docs-site/hooks.py` |
| Pinned packages | `docs-site/requirements.txt` |

### Regenerate the pages

From the repository root, with Python 3.10 or newer and PyYAML:

```bash
python3 tools/gen_docs.py            # write the generated pages and docs-site/mkdocs.yml
python3 tools/gen_docs.py --check    # write nothing; exit 1 if a file is out of date
```

The script reads `defs/`, `lib/ts/src/*.ts` and `tools/*.py`. Run it again
after any of them changed, and commit the result.

### Build and look at the site

From the repository root:

```bash
python3 -m venv docs-site/.venv
docs-site/.venv/bin/pip install -r docs-site/requirements.txt
docs-site/.venv/bin/mkdocs build --strict -f docs-site/mkdocs.yml -d "$SITE_OUT"
```

`SITE_OUT` is a folder outside the checkout (MkDocs refuses an output folder
inside the docs folder, and the docs folder here is the repository root).
`--strict` turns every warning, such as a broken link, into an error.
`mkdocs serve -f docs-site/mkdocs.yml` shows the site while editing.

### Publish

`.github/workflows/docs.yml` runs on each push to `main`: it checks that the
generated pages are up to date, builds the site with `--strict` and
deploys it. In the repository settings, Pages > Source must be
**GitHub Actions**.

### Files that are not on the site

The README of the repository, the README of `lib/ts`, the YAML files, the
source, the tests, the binary reference files and the PDF are not pages. A
link to one of them goes to the file on GitHub.
