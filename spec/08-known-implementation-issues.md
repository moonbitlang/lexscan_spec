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

### KI-002: An isolated-surrogate regex escape may not fail normally

An isolated surrogate is not a Unicode scalar value and cannot be expressed by
the regex language. Such a regex must be rejected as invalid.

The baseline toolchain accepts isolated surrogate escapes rather than issuing a
normal invalid-regex diagnostic. A high-surrogate escape followed by a
low-surrogate escape also fails to match the corresponding non-BMP scalar.

Both behaviors are implementation defects. They do not make an isolated
surrogate a valid regex value, and a well-formed pair remains one scalar value
under the specification.

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
