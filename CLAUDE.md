# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

MoonHID (`We1chan/moonhid`) is a pure MoonBit library that parses USB HID report descriptors, compiles them into bit-level field layouts, and decodes raw reports offline. A browser inspector runs the same MoonBit code compiled to JS. `AGENTS.md` has the general MoonBit conventions; the main points are repeated below. README, ROADMAP and `docs/` are written in Simplified Chinese, and so is the web UI. Keep new text in those places in Chinese.

## Commands

On this machine `moon` lives in `~/.moon/bin`, which may not be on `PATH` in a non-interactive shell. If it isn't, run `export PATH="$HOME/.moon/bin:$PATH"` first.

```sh
moon check --target all --deny-warn    # CI treats warnings as errors (the pre-commit hook runs `moon check --deny-warn`)
moon test                              # default target is wasm (preferred_target in moon.mod)
moon test --target js                  # CI also runs wasm-gc, js and native
moon test layout_test.mbt              # one test file
moon test -f "*README*"                # tests whose name matches a glob
moon test -p We1chan/moonhid/examples  # one package
moon test --update                     # refresh snapshot expectations
moon run cmd/main                      # print the decoded mouse/keyboard/gamepad fixtures
moon info && moon fmt                  # final step: regenerate .mbti and format
```

CI fails if `moon fmt --check` fails or if `moon info` changes any `*.mbti` (`git diff --exit-code -- '*.mbti'`). Commit the regenerated `pkg.generated.mbti` files with any public API change. Enable the git hook with `git config core.hooksPath .githooks`.

Browser inspector (needs Node 22+ and Python 3):

```sh
node scripts/build-web.mjs   # moon build browser --target js --release → copies to web/moonhid-core.js
node scripts/test-web.mjs    # Node assertions against the built ESM bridge (also run in CI)
python3 scripts/serve-web.py # serves web/ on 127.0.0.1:8765 (MOONHID_PORT to change)
```

`web/moonhid-core.js` is generated and gitignored. Rebuild it after any MoonBit change before testing the web UI.

## Architecture

**Core package (repo root, `We1chan/moonhid`).** A linear pipeline. Each stage returns `Result[_, Diagnostic]` and never raises:

1. `hex.mbt` `parse_hex`: strict hex text to `Bytes`. Diagnostic offsets here are UTF-16 indices into the text.
2. `items.mbt` `parse_items`: tokenizes short and long items. `values.mbt` reads little-endian item payloads.
3. `layout.mbt` `compile_descriptor`: the HID state machine. It tracks `GlobalState` with a Push/Pop stack, local usages that are cleared after every Main item, a collection stack, and one bit cursor per `(Main tag, report_id)`, so Input, Output and Feature reports for each ID get independent offsets. It produces a `Layout` of `Field`s (Constant/padding fields included) and a `Collection` tree. Any semantics it doesn't support are rejected with an explicit diagnostic code, never silently ignored.
4. `decode.mbt` `report_length` / `decode_report`: validates the exact wire length and extracts values with `bits.mbt` `extract_bits` (LSB-first). Decoding skips Constant fields, maps array values via `value - logical_min`, and keeps out-of-range values, flagging them with `in_logical_range` and `is_null`.
5. `units.mbt` handles Unit/Physical metadata. `json.mbt` produces JSON schema v2.

Cross-cutting invariants:
- `Field.bit_offset` is a **payload** offset that excludes the Report ID byte. The decoder adds the 8-bit prefix when `layout.has_report_ids`.
- Diagnostic `code` strings are a contract. Blackbox tests, `scripts/test-web.mjs` and the web UI all match on them.
- Size limits (descriptor 65536 B, 4096 fields, 1..32 bits/integer or opaque Variable fields, 1024 values/field, 65536 bits/report, 1024 usages, 4096 collections, stack depth 64) are enforced in `compile_descriptor`. `report_length` re-checks them because callers can build `Layout` values by hand.
- JSON v2 (`docs/json-v2.md`) is versioned. An incompatible change to fields or semantics must bump `schema_version`. Encode `Int64` with `number64` (`Json::number`), because the default `ToJson` emits strings.

**Other packages:**
- `examples/`: synthetic mouse, keyboard and gamepad `Fixture`s shared by `cmd/main`, `browser`, the tests and the web UI. `scripts/test-web.mjs` asserts the fixture names and their order. The keyboard LED output report `03` is hard-coded in `browser/bridge.mbt` `examples_json`, not stored in `Fixture`.
- `browser/`: JS ESM exports (`inspect_descriptor`, `decode_wire`, `examples_json`) declared in `browser/moon.pkg`. These take plain strings and return JSON strings shaped `{ok, schema_version, ...}`. On failure the result carries a `stage` (`descriptor_hex` | `descriptor` | `report_hex` | `report`) that tells the UI whether the offset counts characters or bytes.
- `cmd/main/`: CLI demo that decodes each fixture.
- `web/`: vanilla JS/HTML/CSS with no dependencies, no CDN and no bundler. `app.js` dynamically imports `./moonhid-core.js` and adds names for common Usages only.

## Conventions

- MoonBit code is split into blocks separated by `///|`. Deprecated blocks go in `deprecated.mbt`.
- Blackbox tests are `*_test.mbt` and refer to the root package as `@moonhid`. Other packages import it as `@hid`. Prefer `assert_eq` or `assert_true(x is Pattern(...))`, and use `debug_inspect` with `derive(Debug)` for structural snapshots.
- `README.mbt.md` is the module readme and `README.md` symlinks to it. Its ` ```mbt check ` blocks run as tests under `moon test`.
- `docs/inspector-validation.md` records manual Chrome checks that CI does not run. Update it when you re-verify UI behavior.
- `submission/` is gitignored and holds the competition proposal. The README says the contestant must write it themselves, so do not author it.

<!-- imported-from: codex:project:instructions -->
# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project.

You can browse and install extra skills here:
<https://github.com/moonbitlang/skills>

## Project Structure

- MoonBit packages are organized per directory; each directory contains a
  `moon.pkg` file listing its dependencies. Each package has its files and
  blackbox test files (ending in `_test.mbt`) and whitebox test files (ending in
  `_wbtest.mbt`).

- In the toplevel directory, there is a `moon.mod` file listing module
  metadata.

## Coding convention

- MoonBit code is organized in block style, each block is separated by `///|`,
  the order of each block is irrelevant. In some refactorings, you can process
  block by block independently.

- Try to keep deprecated blocks in file called `deprecated.mbt` in each
  directory.

## Tooling

- `moon fmt` is used to format your code properly.

- `moon ide` provides project navigation helpers like `peek-def`, `outline`, and
  `find-references`. See $moonbit-agent-guide for details.

- `moon info` is used to update the generated interface of the package, each
  package has a generated interface file `.mbti`, it is a brief formal
  description of the package. If nothing in `.mbti` changes, this means your
  change does not bring the visible changes to the external package users, it is
  typically a safe refactoring.

- In the last step, run `moon info && moon fmt` to update the interface and
  format the code. Check the diffs of `.mbti` file to see if the changes are
  expected.

- Run `moon test` to check tests pass. MoonBit supports snapshot testing; when
  changes affect outputs, run `moon test --update` to refresh snapshots.

- Prefer `assert_eq` or `assert_true(pattern is Pattern(...))` for results that
  are stable or very unlikely to change. For snapshot tests that record
  structured debugging output, derive `Debug` and use `debug_inspect`, rather
  than deriving `Show` for debugging. For solid, well-defined results (e.g.
  scientific computations), prefer assertion tests. You can use
  `moon coverage analyze > uncovered.log` to see which parts of your code are
  not covered by tests.
