# Review Questions

## 1. Status

This document collects behaviors that may be accidental, underspecified, or
too implementation-sensitive to place directly into the normative
specification without an explicit decision.

Each question records only publicly reproducible behavior and the proposed
specification choice. It intentionally contains no non-public development
materials.

RQ-001 through RQ-016 are resolved. The specification deliberately limits its
target-input domain to well-formed UTF-16.

## 2. Decision summary

| ID | Status | Decision area |
| --- | --- | --- |
| RQ-001 | Resolved | A regex cannot express an isolated surrogate |
| RQ-002 | Resolved | Direct anchors cannot be quantified |
| RQ-003 | Resolved | Non-final `lexmatch` binder catch-all uses E4171 |
| RQ-004 | Resolved | Source case order precedes per-case leftmost matching |
| RQ-005 | Resolved | Refill count and read-ahead amount are unspecified |
| RQ-006 | Resolved | `Regex` is available through the prelude |
| RQ-007 | Resolved | `...` is formal syntax with TODO-hole semantics |
| RQ-008 | Resolved | Empty matches neither warn nor implicitly advance |
| RQ-009 | Resolved | Direct string scanning migrated from `lexscan` to `lexmatch` |
| RQ-010 | Resolved | A `lexmatch` binder catch-all binds the complete target view |
| RQ-011 | Resolved | Referenced constants strip capture metadata |
| RQ-012 | Resolved | Brace and hyphen spellings are stable MoonBit syntax |
| RQ-013 | Resolved | The bound of 256 is an implementation limit |
| RQ-014 | Resolved | Direct assertions cannot be quantified; grouped zero-width regexes can be quantified |
| RQ-015 | Resolved | Capture decomposition among equal-end maximal paths is unspecified but must be coherent |
| RQ-016 | Resolved | Targets are well-formed UTF-16; ill-formed targets are outside the spec |

## RQ-001: Unpaired UTF-16 surrogates

Resolved: a regex cannot express an isolated UTF-16 surrogate. A Unicode escape
sequence that denotes a lone surrogate is invalid. A well-formed surrogate pair
continues to denote one non-BMP Unicode scalar value.

The target-input boundary for ill-formed strings is resolved separately by
RQ-016: such logical targets are outside this specification.

## RQ-002: Quantifiers applied to anchors

Resolved: a direct zero-width assertion `^` or `$` cannot be quantified. A
group containing an assertion is a valid quantifier operand, even when the
group remains zero-width. Therefore `(^){2}` is valid, while acceptance of
direct `^+` is an implementation defect rather than language syntax.

## RQ-003: Non-final binder diagnostic

A bare binder is a catch-all in `lexmatch`, just as `_` is. Both forms are valid
when final and invalid when followed by another case.

For example, the final binder form is valid and binds the complete target:

```moonbit
lexmatch input {
  rest => rest
}
```

Current toolchain behavior differs by spelling:

```moonbit
lexmatch input {
  _ => 0
  re"^a" => 1
}
```

This reports E4171: the catch-all must be last.

```moonbit
lexmatch input {
  rest => 0
  re"^a" => 1
}
```

This instead reports E4216 with the wording “Binder pattern in lexscan
catch-all case is not supported.” The same E4216 is appropriate for a binder
catch-all in `lexscan`, where binder catch-alls are invalid even when final. It
does not accurately describe this `lexmatch` program: `rest` is supported as a
`lexmatch` catch-all, and its problem here is only its position.

The resulting diagnostic classification treats the binder form as unsupported
rather than classifying the actual violation as catch-all ordering. No internal
matching state or compiler architecture is part of this question.

Expected design options:

1. Report E4171 for both non-final `_` and non-final binder catch-alls in
   `lexmatch`. Retain E4216 for binder catch-alls in `lexscan`.
2. Introduce a general catch-all-order diagnostic and use it for both
   `lexmatch` forms.

Resolved: use E4171 for both non-final `lexmatch` forms. E4216 remains specific
to binder catch-alls in `lexscan`.

Test impact:

- a final binder catch-all is tested as valid;
- a non-final wildcard catch-all is tested for E4171;
- a non-final binder catch-all is tested for E4171; and
- a binder catch-all in `lexscan` remains tested for E4216 independently.

## RQ-004: First-strategy priority across cases

Resolved: `lexmatch with first` gives priority to source case order.

1. Consider cases from top to bottom.
2. For each case, perform that case's leftmost-first regex search.
3. Select the first case that has any successful match; do not consider later
   cases.
4. Within that selected case, the earliest start position wins, followed by
   ordered alternatives and greedy or non-greedy quantifier priority.

Thus an earlier `re"a"` case beats a later `re"b"` case on input `"ba"`, even
though `re"b"` could match at offset zero. Likewise, an earlier `re"^a"` case
beats a later `re"^ab"` case on input `"ab"`, even though the later case is
longer.

## RQ-005: Streaming read-ahead side effects

Resolved: the selected case, captures, committed cursor, and EOF semantics are
normative. The exact number and timing of refill callback invocations and the
amount of buffered read-ahead are unspecified. Tests must not assert an exact
source-call count as an expression-level guarantee.

## RQ-006: Package visibility for regex match

Resolved: the `Regex` type is re-exported by the prelude. Users do not need to
import `moonbitlang/core/string` directly to use regex literals or `=~`.

## RQ-007: Placeholder case

Resolved: `...` is formal language syntax. It is equivalent to wildcard
catch-all `_` with a TODO hole expression as its body. Catch-all ordering and
ordinary TODO-hole typing semantics apply.

## RQ-008: Empty-match progress in `lexscan`

Resolved: a successful zero-length regex case leaves the scanner cursor
unchanged. It emits no progress warning and does not implicitly advance by one
character. Programs are responsible for control flow and progress.

A catch-all is not mandatory when the regex cases are exhaustive. Scanner loops
may explicitly use a case such as `re"^$" => break` for EOF and cover non-empty
input with other regex cases.

## RQ-009: `lexscan` non-streaming target transition

Resolved: direct `lexscan` on `String` and `StringView` has migrated to
`lexmatch`. The valid `lexscan` targets are `Lexbuf`, `AsyncLexbuf`, and
`StringScanner`.

## RQ-010: Meaning of a `lexmatch` binder catch-all

Resolved: a final binder catch-all receives the original `lexmatch` target as a
`StringView`. It never exposes a cursor, a partially attempted suffix, or any
other internal matching state.

## RQ-011: Captures hidden inside regex constants

Current toolchain behavior is as follows:

- A named group in a regex literal used directly as a lexical pattern is
  rejected with E4181.
- An anonymous group in a direct pattern is accepted as grouping syntax but
  does not create a MoonBit binder.
- A referenced regex constant may contain named or anonymous groups. When the
  constant is used as a pattern, their capture metadata is stripped while
  their grouping and matching structure remains effective.
- A hidden named group does not place its name in MoonBit scope and does not
  implicitly create an `as` binding.
- Duplicate capture names are still checked when the first-class regex constant
  itself is formed.
- Pattern-level `as` around the reference is supported and binds the complete
  text matched by the referenced constant, not a hidden subgroup.
- The rule is the same for `=~`, `lexmatch`, and `lexscan` pattern references.
- Only capture metadata is hidden. Other regex semantics remain visible. For
  example, a non-greedy quantifier inside a referenced constant remains
  non-greedy and makes that reference invalid under `longest`.

For example, if `WORD` contains a named group matching `[a-z]+`, using `WORD`
as a pattern still matches `[a-z]+`, but the group name is unavailable. Using
`WORD as whole` binds the complete word to `whole`.

```moonbit
const WORD = re"(?<word>[a-z]+)"

lexmatch input {
  (WORD as whole, after=_) => whole
  _ => ""[:]
}
```

In the current toolchain, `whole` is a MoonBit binder for the complete text
matched by `WORD`; `word` is not in scope.

Resolved: the specification preserves the current toolchain semantics. Named
and anonymous capture metadata inside a referenced regex constant is stripped.
The grouping and matching structure remains effective, no hidden name enters
MoonBit scope, and pattern-level `as` binds the complete referenced match.

## RQ-012: Literal brace and hyphen spellings

Resolved: these differences are stable MoonBit syntax. Literal `{` uses `[{]`
because `\{` begins regex interpolation. `[}]` is the unambiguous literal `}`
spelling. A literal class hyphen uses `\-`; unescaped beginning or end placement
is invalid.

## RQ-013: Repetition bound limit

Resolved: 256 is an implementation limit, not a language-level repetition
limit. It must not be required of every conforming implementation and is not a
cross-implementation conformance-test boundary.

## RQ-014: Transparent wrappers around a quantified anchor

Resolved: a direct assertion cannot be quantified, but a group is a valid
quantifier operand even when its complete contents are zero-width. Representative
valid forms are:

```moonbit
re"(?:^)+"
re"(?i:^)?"
re"(?<start>^){2}"
re"((^))+"
```

The wrappers add grouping, modifier scope, capture metadata, or nesting, but
they remain groups rather than direct assertion operands. Repeating them does
not consume input; nullable repetition still MUST terminate without implicit
progress. This rule is separate from the restriction on direct forms such as
`^+` and `$?`.

The named-group form is valid as a first-class `Regex` value. Its direct use as
a lexical pattern remains subject to the separate restriction on named capture
groups in lexical pattern syntax.

## RQ-015: Capture endpoints within a longest match

Resolved: `longest` chooses the case whose complete match ends farthest from
the origin, but it does not promise a unique capture decomposition when
several paths through the selected case reach the same maximal end.

For example, on input `"aa"`, both paths through this pattern consume the
complete input but produce different captures:

```moonbit
(re"^(a|aa)" as left) + (re"a?" as right)
```

One path binds `left == "a"` and `right == "a"`; another binds
`left == "aa"` and `right == ""`.

The choice among such paths is unspecified. Every capture exposed by the
selected case MUST collectively correspond to one successful maximal path; the
implementation MUST NOT splice capture endpoints from different paths. The
choice may vary between compiler versions, targets, and optimization modes, so
programs MUST NOT depend on a particular decomposition.

The suite tests the complete maximal end and accepts each coherent capture
outcome rather than pinning one implementation-specific submatch preference.

## RQ-016: Ill-formed UTF-16 target strings

Resolved: the specification assumes that every `String` and `StringView`
target, and every logically concatenated streaming target, is well-formed
UTF-16. A streaming source may split a valid surrogate pair across chunks.
Inputs containing isolated high or low surrogates in the logical target are
outside the language contract. Their matching, capture, cursor, refill, and
error behavior is intentionally not specified, and no conformance test may
depend on it.
