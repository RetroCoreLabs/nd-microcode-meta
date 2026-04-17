cmake_minimum_required(VERSION 3.16)
project(nd-microcode-meta NONE)

# This CMakeLists.txt provides targets to regenerate the TypeScript
# definitions from YAML sources. It does not compile C/C++ code.
#
# Usage:
#   cmake -B build && cmake --build build --target generate
#   cmake --build build --target build-ts
#   cmake --build build --target test-ts

find_program(NODE node REQUIRED)
find_program(NPM npm REQUIRED)

set(YAML_DIR ${CMAKE_SOURCE_DIR}/defs)
set(TS_DIR ${CMAKE_SOURCE_DIR}/lib/ts)
set(GENERATED ${TS_DIR}/src/generated-defs.ts)
set(GENERATOR ${TS_DIR}/scripts/generate-defs.mjs)

# Regenerate TypeScript definitions from YAML
add_custom_target(generate
    COMMAND ${NODE} ${GENERATOR}
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    COMMENT "Generating TypeScript definitions from YAML"
    SOURCES ${GENERATOR}
)

# Build the TypeScript library
add_custom_target(build-ts
    COMMAND ${NPM} install
    COMMAND ${NPM} run build
    WORKING_DIRECTORY ${TS_DIR}
    COMMENT "Building TypeScript library"
    DEPENDS generate
)

# Run tests
add_custom_target(test-ts
    COMMAND ${NPM} test
    WORKING_DIRECTORY ${TS_DIR}
    COMMENT "Running TypeScript tests"
    DEPENDS build-ts
)
