# MoonBit Regex Matching and Scanning Specification

This repository specifies the MoonBit language behavior of:

- regex match expressions using `=~`;
- `lexmatch` expressions over `String` and `StringView`; and
- `lexscan` expressions over `@lexbuf.Lexbuf`, `@lexbuf.AsyncLexbuf`, and
  `@lexbuf.StringScanner`.

The specification targets `moon 0.1.20261023` and `moonc
v0.10.17+d971670cd`.

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
- [Performance guidance](spec/09-performance-guidance.md) (informative)

## Writing fast matches

For code generators and agents, in short (details and measurements in
[Performance guidance](spec/09-performance-guidance.md)):

- Test for a fixed string with `=~` and an anchored literal: `s =~ re"^#"`,
  `s =~ (re"\.mbt$", before=stem)`. It compiles to one `==`, `has_prefix`,
  `has_suffix` or `find` call, with no automaton.
- Anchor with `^` and `$` when a prefix, suffix or whole input is meant; an
  unanchored pattern is a search.
- Use `before` and `after` instead of an `as` binding when they give what is
  needed: any `as` binding makes the match use an automaton.
- A `lexmatch` with several regex cases always uses an automaton. A single
  regex case followed by a catch-all compiles like `=~`.
- From the release after `v0.10.17`, small anchored sets of literals, such as
  `s =~ re"^(if|else|while)$"`, are also compared without an automaton.

## Project status

The specification and executable conformance suite are both present. Runtime,
typing, diagnostic, warning, formatting, multi-backend, Unicode, streaming, and
coverage-audit tests correspond directly to the IDs in the conformance matrix.

The current matrix contains 252 independently testable requirements. The
ordinary runtime/type layer contains 137 tests; diagnostic fixtures and format
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
