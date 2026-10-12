# Known Implementation Issues and Limitations

## 1. Purpose

This document separates the normative language contract from behavior that is
publicly reproducible in the baseline toolchain but is known not to define the
language. A conforming implementation follows the normative specification,
not a divergent behavior listed here.

This document contains no non-public implementation evidence. Design questions
belong in [Review Questions](07-review-questions.md) rather than being
classified here as defects.

## 2. Confirmed semantic divergences

### KI-001: A direct quantified start anchor is accepted

**Status:** Resolved in the publicly released compiler
`moonc v0.10.14+7d59c7ec9 (2026-09-18)`, verified against the existing diagnostic
fixtures. This is a verified fixed version, not a claim about the first release
containing the fix. The original `v0.10.8+8606a5800` baseline behavior below is
retained for historical context.

The original baseline toolchain accepted direct quantified `^` forms including `^+`,
`^*`, `^?`, and bounded repetition. The language rule is that a direct
zero-width assertion cannot be quantified; the corresponding `$` forms are
also invalid. A group containing an anchor, such as `(^){2}`, is valid and
is not an instance of this issue.

The verified compiler rejects all four direct quantified `^` forms with E4172,
consistent with the specification, and still accepts quantified groups containing
an anchor. The conformance fixtures continue to require these rejections.
Acceptance of `^+` by older compilers was an implementation defect and must not
be used as a portable way to establish semantic anchoring.

### KI-002: Valid surrogate escapes can trigger an internal compiler error

Surrogate escapes are valid under the shared escape contract. An unpaired
escape matches no scalar; adjacent fixed high/low escapes match one non-BMP
scalar. On the baseline toolchain,
`input =~ re"\uD800"` and `input =~ re"^\uD83D\uDE00$"` can instead trigger
an internal UTF-8 decoding error in the literal matching optimization.

The baseline runtime parser rejects these escapes. Core PR #4373 updates the
runtime parser to the shared contract. The compiler must also handle them
without an internal decoding error; rejecting a valid surrogate escape is no
longer the required remedy.

### KI-003: An empty braced Unicode escape is accepted

The regex grammar requires at least one hexadecimal digit in `\u{H...}`. The
baseline toolchain accepts `\u{}` instead of rejecting it as an invalid regex.

Acceptance of `\u{}` is an implementation defect. The conformance suite keeps
this case as a required E4172 rejection.

## 3. Implementation limits

### IL-001: Repetition bounds are limited to 256

The baseline toolchain rejects a written repetition bound greater than 256.
This is a compilation limit, not a language-level regex limit. Other conforming
implementations are not required to use the same number, and the conformance
suite must not use 256 versus 257 as a semantic boundary.
