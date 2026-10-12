# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

MoonHID (`We1chan/moonhid`) is a pure MoonBit library that parses USB HID report descriptors, compiles them into bit-level field layouts, and decodes raw reports offline. A browser inspector runs the same MoonBit code compiled to JS. `AGENTS.md` has the general MoonBit conventions; the main points are repeated below. README, ROADMAP and `docs/` are written in Simplified Chinese, and so is the web UI. Keep new text in those places in Chinese.

## Commands

`toolchain.json` pins the MoonBit, moon, Node and hid-tools versions that CI installs (`.github/actions/setup-moon`). A separate CI job also runs check/test on js with the latest MoonBit. The installer puts `moon` in `~/.moon/bin`, which may not be on `PATH` in a non-interactive shell. If `moon` isn't found, prepend that directory.

```sh
moon check --target all --deny-warn    # CI treats warnings as errors (the pre-commit hook runs `moon check --deny-warn`)
moon test                              # default target is wasm (preferred_target in moon.mod)
moon test --target js                  # CI also runs wasm-gc, js and native
moon test src/layout_test.mbt          # one test file
moon test -f "*README*"                # tests whose name matches a glob
moon test -p We1chan/moonhid/examples  # one package
moon test --update                     # refresh snapshot expectations
moon run src/cmd/main                  # print the decoded mouse/keyboard/gamepad fixtures
moon info && moon fmt                  # final step: regenerate .mbti and format
```

CI fails if `moon fmt --check` fails or if `moon info` or `moon info --target native` changes any `*.mbti` (`git diff --exit-code -- '*.mbti'`). Commit the regenerated `pkg.generated.mbti` files with any public API change. Enable the git hook with `git config core.hooksPath .githooks`.

Browser inspector and Node-side checks (need Node 22+). CI's js job runs every script below except `serve-web.py`:

```sh
node scripts/build-web.mjs                 # moon build src/browser --target js --release → copies to web/moonhid-core.js
node scripts/test-web.mjs                  # assertions against the built ESM bridge
node scripts/test-webhid.mjs               # web/hid-live.js wire framing against the bridge
node scripts/test-usability.mjs            # lesson, lint UI and reference-descriptor flows
node scripts/test-cli.mjs [js|native]      # builds src/cmd/moonhid --release, checks output and exit codes
node scripts/firmware-ci.mjs [js|native]   # runs examples/firmware-ci through the CLI (docs/firmware-ci.md)
node scripts/package-inspector.mjs         # offline bundle → _build/distribution/moonhid-inspector
node scripts/test-offline.mjs              # serves that bundle and checks it (run package-inspector first)
node scripts/test-inspector.mjs            # DOM checks in headless Chrome (CHROME_BIN overrides the binary)
node --expose-gc scripts/benchmark.mjs     # timing observations, not pass/fail
python3 scripts/serve-web.py               # serves web/ on 127.0.0.1:8765 (MOONHID_PORT to change)
```

`web/moonhid-core.js` is generated and gitignored. Rebuild it after any MoonBit change before testing the web UI or running the `test-*.mjs` scripts that import it.

External cross-check (CI uses Python 3.13): `pip install hid-tools==0.12`, then `python scripts/compare-hid-tools.py` and `python scripts/compare-codec-hid-tools.py`. The codec script builds and runs the native CLI.

## Architecture

**Core package (`src/`, `We1chan/moonhid`).** `moon.mod` sets `source = "src"`; package names and imports exclude that prefix. Run commands from the repo root and use actual paths (`src/cmd/main`, `src/layout_test.mbt`) when selecting packages or files. A linear pipeline. Each stage returns `Result[_, Diagnostic]` and never raises:

1. `hex.mbt` `parse_hex`: strict hex text to `Bytes`. Diagnostic offsets here are UTF-16 indices into the text.
2. `items.mbt` `parse_items`: tokenizes short and long items. `values.mbt` reads little-endian item payloads.
3. `layout.mbt` `compile_descriptor`: the HID state machine. It tracks `GlobalState` with a Push/Pop stack, local Usage spans that are cleared after every Main item, a collection stack, and one bit cursor per `(Main tag, report_id)`, so Input, Output and Feature reports for each ID get independent offsets. It produces a `Layout` of `Field`s (Constant/padding fields included) and a `Collection` tree. Any semantics it doesn't support are rejected with an explicit diagnostic code, never silently ignored.
4. `decode.mbt` `report_length` / `decode_report`: validates the exact wire length and extracts values with `bits.mbt` `extract_bits` (LSB-first). Decoding skips Constant fields, maps array values via `value - logical_min`, and keeps out-of-range values, flagging them with `in_logical_range` and `is_null`.
5. `units.mbt` handles Unit/Physical metadata and `physical_value` / `logical_from_physical` scaling (Physical range, then 10^Unit Exponent; rounding is implemented by hand, half away from zero, because core `Double::round` sends halves toward +∞ and would make negative values asymmetric). `json.mbt` produces JSON schema v2.
   `lint.mbt` `lint_descriptor` is a side branch. It runs `compile_descriptor` and returns that `Diagnostic` unchanged on failure. On success it returns `Lint`s (item-prefix `offset`, `code`, `level` Warning/Info, optional `field_index` into `Layout.fields`) sorted by offset, then code. Lints never alter the layout or decoding. Inspect JSON carries them as `lints`, and Warnings don't make `ok` false. CLI `lint` exits 3 when a Warning is present, 1 on file, input or compile errors, and 2 on bad arguments.
6. `encode.mbt` implements typed `ReportValue` encoding, field reads/writes and Usage lookup. `bits.mbt` also provides copy-based bit insertion. Encoding requires every non-Constant element in field/element order; new Constant/tail bits are zero, while field writes preserve them. Null State accepts representable out-of-range integers; other invalid logical values require explicit `allow_out_of_range=true`.
7. `builder.mbt` provides a fluent `DescriptorBuilder`; `build()` reuses the compiler to validate generated bytes. With a non-negative Minimum, Maximum below 2^31 is encoded in a width that reads the same signed or unsigned (255 → `26 ff 00`), so generated descriptors don't trip `logical_max_sign`. `serialize_items` preserves raw item widths and unknown data without semantic validation. CLI `generate` uses the five templates in `src/examples/templates.mbt`. These features are in the unpublished 0.4.0 repository version.
8. `access.mbt` is the Usage-level layer modelled on Windows `hidpi.h`: `list_reports` (≈ `HidP_GetCaps` lengths), `new_report` (≈ `HidP_InitializeReportForID`: Null values, Array empty values, else zero), `set_usages` / `clear_usages` / `active_usages` (≈ `HidP_SetUsages` / `UnsetUsages` / `GetUsagesEx`), `get/set_usage_value` and `get/set_physical_value`. "Switches" are Data Variable elements with Logical 0..1. An Array element is empty when it is out of range, past the Usage list or selects Usage ID 0. A Usage shared by several elements returns `ambiguous_usage`, so callers fall back to `find_fields` + `read_field`/`write_field`. CLI `encode` takes either the positional JSON array (`encode_report`) or a Usage object `{"values", "physical", "active"}` applied on top of `new_report`.

Cross-cutting invariants:
- `Field.bit_offset` is a **payload** offset that excludes the Report ID byte. The decoder adds the 8-bit prefix when `layout.has_report_ids`.
- Diagnostic `code` strings are a contract. Blackbox tests, `scripts/test-web.mjs` and the web UI all match on them.
- Lint codes and their levels are also a contract (rule table in `docs/lint.md`). `web/lint-ui.js` `lintRules` maps each code to Chinese UI text, and `scripts/test-usability.mjs` asserts how many rules it has. A new lint code needs all three updated.
- `src/real_devices_test.mbt` stores real descriptors as `fn real_device_a() -> String { "..." }` through `real_device_g`. `scripts/export-real-layouts.mjs` and `scripts/benchmark.mjs` extract them with a regex, so keep that exact shape.
- Size limits (descriptor 65536 B, 4096 fields, 1..32 bits/integer or opaque Variable fields, at most 65536 values/field within 65536 bits/report, 1024 Usage spans, 4096 collections, stack depth 64) are enforced in `compile_descriptor`. `report_length` re-checks them because callers can build `Layout` values by hand.
- JSON v2 (`docs/json-v2.md`) is versioned. An incompatible change to fields or semantics must bump `schema_version`. Encode `Int64` with `number64` (`Json::number`), because the default `ToJson` emits strings.
- Use `Json(value)` for primitive JSON conversions. Direct `.to_json()` calls are deprecated by the 0.10.15 toolchain and fail the latest-compatible job with `--deny-warn`; `Json(value)` also works with pinned 0.10.14. Keep explicit numeric `number64` conversion for HID Int64 values.

**Other packages:**
- `src/examples/`: synthetic mouse, keyboard and gamepad `Fixture`s shared by `cmd/main`, `browser`, the tests and the web UI. `scripts/test-web.mjs` asserts the fixture names and their order. The keyboard LED output report `03` is hard-coded in `src/browser/bridge.mbt` `examples_json`, not stored in `Fixture`. The toplevel `examples/` directory holds device data and firmware CI examples.
- `src/browser/`: JS ESM exports (`inspect_descriptor`, `decode_wire`, `examples_json`) declared in `src/browser/moon.pkg`. These take plain strings and return JSON strings shaped `{ok, schema_version, ...}`. On failure the result carries a `stage` (`descriptor_hex` | `descriptor` | `report_hex` | `report`) that tells the UI whether the offset counts characters or bytes.
- `src/cmd/main/`: CLI demo that decodes each fixture.
- `src/cmd/moonhid/`: file CLI (`inspect`, `lint`, `decode`, `encode`, `generate`). It supports only the native and js targets (`supported_targets`). `io_native.mbt` and `io_js.mbt` are selected per target, and native stderr goes through the C stub `stderr_native.c`.
- `web/`: vanilla JS/HTML/CSS with no dependencies, no CDN and no bundler. `index.html`/`app.js` is the inspector and `capture.html`/`capture.js` is a real-gamepad capture page. All parsing and decoding goes through `moonhid-core.js`. `app.js` only adds names for common Usages, `hid-live.js` is WebHID transport only, and `lint-ui.js` is presentation only. `browser-descriptor.js` rebuilds a *reference* descriptor from WebHID-visible collections and cannot recover original item encodings, nested collections or local metadata.

## Conventions

- MoonBit code is split into blocks separated by `///|`. Deprecated blocks go in `deprecated.mbt`.
- `moon ide` (`peek-def`, `outline`, `find-references`) navigates code. `moon coverage analyze > uncovered.log` lists uncovered code.
- Blackbox tests are `*_test.mbt` and refer to the root package as `@moonhid`. Other packages import it as `@hid`. Prefer `assert_eq` or `assert_true(x is Pattern(...))`, and use `debug_inspect` with `derive(Debug)` for structural snapshots.
- `src/README.mbt.md` is the module readme and the toplevel `README.md` symlinks to it. Its ` ```mbt check ` blocks run as tests under `moon test`.
- `docs/inspector-validation.md` records manual Chrome checks that CI does not run. Update it when you re-verify UI behavior.
- `submission/` is gitignored and holds the competition proposal. The README says the contestant must write it themselves, so do not author it.
