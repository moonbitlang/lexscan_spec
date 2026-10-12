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

The baseline toolchain accepts direct quantified `^` forms including `^+`,
`^*`, `^?`, and bounded repetition. The language rule is that a direct
zero-width assertion cannot be quantified; the corresponding `$` forms are
already rejected. A group containing an anchor, such as `(^){2}`, is valid and
is not an instance of this issue.

Acceptance of `^+` is an implementation defect. It must not be used as a
portable way to establish semantic anchoring.

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

### IL-002: Group nesting is limited to 128

The parser referenced by core PR #4373 limits simultaneously open groups to
128. All group forms count, while sequential groups do not accumulate depth.
The 129th open group produces a normal parser error. Other implementations MAY
choose a different resource limit; stack overflow or a process abort is not an
acceptable way to report excessive nesting.

The RX-051 boundary probes check this referenced parser's resource limit;
128 versus 129 is not a portable matching-semantic distinction.

## 4. Shared parser alignment

[Core PR #4373](https://github.com/moonbitlang/core/pull/4373) corrects runtime
parsing of control/NUL/hex escapes, Unicode surrogate escapes, leading zeros in
braced escapes, invalid class escapes and ranges, reserved class punctuation,
duplicate capture names, unterminated ranges, and excessive group nesting.
The associated conformance cases require that change and the corresponding
compiler update. Failures on the baseline toolchain remain visible; the suite
does not reinterpret old parser behavior as the contract.

Case folding of a negated class remains a separate known issue described in
that PR: both implementations can match `a` and `A` with `(?i:[^a])` because
folding occurs after negation. That behavior is not resolved by parser alignment.
