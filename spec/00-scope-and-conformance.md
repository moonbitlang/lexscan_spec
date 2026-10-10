# Scope and Conformance

## 1. Status and version

This document set specifies the MoonBit language contract for existing syntax.
It uses the following publicly identifiable toolchain versions as its review
baseline:

| Item | Baseline |
| --- | --- |
| `moon` | `0.1.20260814` |
| `moonc` | `v0.10.8+8606a5800` |

It does not claim to describe later MoonBit releases unless they preserve the
same behavior. Confirmed divergences in the baseline implementation are kept in
[Known Implementation Issues and Limitations](08-known-implementation-issues.md)
and are not normative. Non-public development materials are intentionally
excluded from this specification.

## 2. Normative terminology

The words **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT**, and **MAY** are
normative requirements.

An implementation conforms to this specification when it:

1. accepts every program identified as valid;
2. produces the specified observable result and state changes;
3. rejects every program identified as invalid; and
4. emits the specified dedicated diagnostic code where one is listed.

Exact diagnostic prose and source ranges are informative unless a rule says
otherwise. The future spec test suite may choose to pin them more tightly.

## 3. Features in scope

This specification covers:

- the regex pattern syntax shared by `=~`, `lexmatch`, and `lexscan`;
- regex literal and regex constant references in pattern position;
- matching strategies and branch priority;
- anchoring and unmatched-prefix/suffix bindings;
- substring capture and capture types;
- target typing and expression typing;
- catch-all and exhaustiveness behavior;
- streaming and cursor behavior for `lexscan`;
- compile-time restrictions, errors, and warnings; and
- Unicode and UTF-16 behavior visible to MoonBit programs.

First-class `Regex` values and runtime methods such as `Regex::execute` are in
scope only where their construction or capture metadata affects a regex pattern
used by one of the three expressions.

## 4. Features out of scope

The following are not specified here:

- non-public compiler internals;
- performance, allocation count, and code-size guarantees;
- runtime `Regex` APIs unrelated to pattern use;
- the removed string-piece lexical-pattern syntax; and
- the removed `lexmatch?` boolean expression.

The old forms are not compatibility aliases. A conforming implementation MUST
parse current code using `re"..."` patterns and `=~`; removed legacy examples
MUST NOT be treated as current syntax.

## 5. Shared semantic model

### 5.1 Text domain

The target input domain of this specification is well-formed UTF-16. For
well-formed UTF-16 input, the surface regex language denotes sequences of
Unicode scalar values. Literal characters, `.`, character classes, repetition,
alternation, and captures are defined at that level.

The regex language cannot express a UTF-16 surrogate as a pattern atom. Each
Unicode escape MUST denote a Unicode scalar value; escapes in U+D800 through
U+DFFF are invalid, even when a high-surrogate escape is immediately followed
by a low-surrogate escape. Non-BMP scalars are written as literal characters or
braced scalar escapes such as `\u{1f600}`. A valid surrogate pair in the input
string represents one non-BMP scalar; it does not make surrogate escapes valid
in the pattern.

MoonBit strings and string views are indexed internally in UTF-16 code units.
The following UTF-16 and character-matching behavior is observable:

- a non-BMP scalar value consumes two UTF-16 code units;
- `.` treats a valid surrogate pair as one non-BMP scalar value and does not
  match only half of that pair;
- a capture known to match exactly one scalar value has type `Char`; and
- lexbuf and `StringScanner` cursor positions are UTF-16 code-unit offsets.

The logical target presented to a scanner MUST be well-formed UTF-16. A
streaming source MAY split one valid surrogate pair across chunk boundaries;
well-formedness is assessed after the chunks are concatenated in logical input
order. Ill-formed logical targets constructed programmatically with isolated
surrogates are outside the specified input domain. This specification does not
define matching, capture, cursor, refill, or error behavior for such targets.
A conforming implementation is not required to provide portable behavior for
them, and conformance tests MUST NOT depend on such behavior. This does not
change the separate rule that a regex itself cannot express an isolated
surrogate.

### 5.2 Input boundaries

`^` denotes the beginning of the logical input presented to the expression:

- offset zero of the `String` or `StringView` for `=~` and `lexmatch`;
- the cursor position at which a `lexscan` expression starts; or
- the current `StringScanner.cursor` position within its `data` view.

`$` denotes the end of that logical input. For a streaming lexbuf, a chunk
boundary is not end of input. The scanner MUST refill until the source reports
EOF before `$` can succeed at the end of the stream.

The anchors are not multiline anchors. Newline has no special effect on `^` or
`$`.

### 5.3 Evaluation

The target expression of `=~`, `lexmatch`, or `lexscan` is evaluated exactly
once.

Pattern compilation is a compile-time operation. Regex cases cannot depend on
arbitrary runtime `Regex` values.

Only the selected action body is evaluated at runtime. In an otherwise valid
expression that reaches case analysis, all action bodies, including statically
unreachable bodies, are still type-checked. A fatal target or case-structure
error may suppress secondary body diagnostics as part of compiler recovery.

## 6. Compatibility note

The published MoonBit v0.10.7 page says that `lexscan` temporarily accepts
`String` and `StringView`. Direct scanning of those targets has since migrated
to `lexmatch`. They are invalid `lexscan` targets, and
`@lexbuf.StringScanner` is the in-memory scanner target when persistent cursor
state is required.
