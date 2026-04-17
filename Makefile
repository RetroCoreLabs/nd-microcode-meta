# nd-microcode-meta Makefile
#
# Targets:
#   generate  - Regenerate lib/ts/src/generated-defs.ts from YAML
#   build     - Generate + compile the TS library
#   test      - Build + run tests
#   clean     - Remove build artifacts
#
# Prerequisites: Node.js >= 18, npm

.PHONY: generate build test clean

YAML_SOURCES := $(wildcard defs/tokens/*.yaml) $(wildcard defs/fields/*.yaml)
GENERATED := lib/ts/src/generated-defs.json

# Regenerate TypeScript definitions from YAML sources
generate: $(GENERATED)

$(GENERATED): $(YAML_SOURCES) lib/ts/scripts/generate-defs.mjs
	cd lib/ts && npm install --ignore-scripts 2>/dev/null || true
	node lib/ts/scripts/generate-defs.mjs

# Compile the TypeScript library
build: generate
	cd lib/ts && npm install && npm run build

# Run tests
test: build
	cd lib/ts && npm test

# Remove build artifacts
clean:
	rm -rf lib/ts/dist lib/ts/node_modules
