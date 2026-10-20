# MoonBit Regex Matching and Scanning Specification

This repository specifies the MoonBit language behavior of:

- regex match expressions using `=~`;
- `lexmatch` expressions over `String` and `StringView`; and
- `lexscan` expressions over `@lexbuf.Lexbuf`, `@lexbuf.AsyncLexbuf`, and
  `@lexbuf.StringScanner`.

The specification targets `moon 0.1.20261016` and `moonc
v0.10.16+b1a0e846e`.

The [published MoonBit v0.10.7 documentation](https://docs.moonbitlang.com/en/latest/language/fundamentals.html#lexscan)
is linked for comparison. Version differences and publicly reproducible
implementation divergences are recorded separately without exposing non-public
compiler materials.

## Documents

- [Scope and conformance](spec/00-scope-and-conformance.md)
- [Regex patterns and matching model](spec/01-regex-patterns.md)
- [Regex match expression (`=~`)](spec/02-regex-match-expression.md)
- [`lexmatch` expression](spec/03-lexmatch-expression.md)
- [`lexscan` expression](spec/04-lexscan-expression.md)
- [Diagnostics](spec/05-diagnostics.md)
- [Conformance coverage matrix](spec/06-conformance-matrix.md)
- [Review questions](spec/07-review-questions.md)
- [Known implementation issues and limitations](spec/08-known-implementation-issues.md)

## Project status

The specification and executable conformance suite are both present. Runtime,
typing, diagnostic, warning, formatting, multi-backend, Unicode, streaming, and
coverage-audit tests correspond directly to the IDs in the conformance matrix.

The current matrix contains 244 independently testable requirements. The
ordinary runtime/type layer contains 133 tests; diagnostic fixtures and format
fixtures cover the remaining compile-time requirements and interactions.

Run the complete suite with:

```sh
bash scripts/test_all.sh
```

The full command performs:

- formatting and warning-free project checks;
- debug and release tests across all supported MoonBit backends;
- compile-fail and warning fixtures with diagnostic-code assertions;
- a canonical formatter fixture; and
- a coverage-ID audit that fails if any matrix row lacks a test.

With the baseline stable toolchain, `--target all` runs `wasm`, `wasm-gc`,
`js`, and `native`. The separately listed `llvm` target is experimental and is
not runnable unless the toolchain installation includes its LLVM core bundle.

Individual layers can also be run with `moon test`,
`bash diagnostics/run.sh`, `bash scripts/check_format_fixture.sh`, and
`bash scripts/check_coverage_ids.sh`.

GitHub Actions runs explicit `table`, `block`, and `runtime` regex backends on
`wasm`, `wasm-gc`, `js`, and `native`, in debug and release mode. Each backend
has a separate build directory. Formatting, warning-free type checks, coverage
IDs, the formatter fixture, and diagnostic fixtures are also checked.

Temporary expected failures are versioned in [FIXME.json](FIXME.json). Every
listed test is still compiled and run in each applicable backend, target, and
mode. A matching failure is `XFAIL` and does not block CI. A successful test is
`XPASS` and **fails CI**, prompting removal or narrowing of its FIXME entry.
Unlisted failures and failures with a different signature remain blocking.
Unknown or renamed test identities and malformed list entries also fail CI.

The CI runner isolates each listed test in a temporary project, preserving
helper declarations, so a compiler error in one FIXME cannot prevent ordinary
tests from executing. Type checks cover the ordinary project; all isolated
FIXME cases are checked by the debug/release test jobs. The tracked sources and
test expectations are unchanged by the runner. Local strict commands above
continue to run the entire suite without expected-failure allowances.

To reproduce the CI policy locally:

```sh
node scripts/ci.mjs check
node scripts/ci.mjs test table js debug
node scripts/ci.mjs test runtime wasm-gc release
bash diagnostics/run.sh --fixme
```

The diagnostic runner is intentionally strict. A baseline compiler that still
has a divergence listed in
[Known implementation issues and limitations](spec/08-known-implementation-issues.md)
will fail the corresponding fixture until that compiler fix is available in
the invoked toolchain.

To test a locally built compiler while keeping the installed `moon` driver,
set `SPEC_MOONC_OVERRIDE`:

```sh
SPEC_MOONC_OVERRIDE=/path/to/moonc bash scripts/test_all.sh
```
