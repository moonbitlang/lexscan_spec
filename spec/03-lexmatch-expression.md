# `lexmatch` Expression

## 1. Purpose

`lexmatch` selects one of several regex cases for an in-memory string-like
input and evaluates the selected case body.

```moonbit
lexmatch input [with first|longest] {
  regex_case => expression
  ...
  [catch_all => fallback_expression]
}
```

Unlike `=~`, `lexmatch` is not restricted to `Bool`: its result is the common
type of its case bodies.

## 2. Syntax

```text
lexmatch-expression ::= "lexmatch" expression strategy? "{"
                          lexical-case*
                        "}"

strategy            ::= "with" identifier

lexical-case        ::= lexical-case-pattern "=>" expression-statement
                      | "..."

lexical-case-pattern ::= regex-pattern
                       | "(" regex-pattern ["," match-bindings] [","] ")"
                       | binder
                       | "_"
```

The only valid strategies are `first` and `longest`. Omitting the strategy is
equivalent to `with first`.

Cases are separated by the normal semicolon-insertion rules. An empty case list
parses but is rejected by exhaustiveness analysis with E4224.

The placeholder case `...` is formal language syntax. It is equivalent to a
wildcard catch-all `_` whose body is a TODO hole expression. It is therefore
subject to ordinary catch-all ordering and TODO-hole typing rules.

## 3. Target typing

The target MUST have type `String` or `StringView`.

A `String` target is implicitly converted to a `StringView`. All captures and
unmatched pieces of type `StringView` denote the corresponding target ranges;
this specification does not require a particular allocation strategy or
observable backing-storage identity.

For a sliced `StringView`, all ranges remain bounded by the slice. For a
temporary `String` target, returned captures, `before`, `after`, and a binder
catch-all remain valid views for as long as those views are reachable.

`Bytes`, `BytesView`, lexbuf types, `StringScanner`, and arbitrary user-defined
types are invalid `lexmatch` targets.

## 4. Regex cases

Each regex case uses the shared pattern language from
[Regex Patterns and Matching Model](01-regex-patterns.md).

The body may use:

- `as` binders introduced by the regex pattern;
- `before` and `after` binders allowed by the chosen strategy; and
- ordinary bindings from the surrounding scope.

All case bodies MUST type-check against one common expression result type.
Only the selected body is evaluated.

Lexical cases do not support an `if` guard between the pattern and `=>`.
Additional conditions MUST be handled inside the case body.

## 5. First strategy

The default and `with first` forms use first-match semantics.

```moonbit
lexmatch input {
  ...
}

lexmatch input with first {
  ...
}
```

### 5.1 Selection

Cases are considered in source order from top to bottom. The first regex case
that has any successful match is selected. Only after a case is selected do its
single-regex priorities apply: the earliest match start for that case wins,
followed by ordered alternatives and quantifier greediness.

A case that has only a partial prefix match, or whose regex fails at every
possible start, is not selected. Matching then proceeds to the next source case
from the same original target. Failed earlier cases do not consume or truncate
the target.

Source case order is therefore stronger than both the start position and the
match length offered by a later case.

```moonbit
lexmatch "ab" {
  (re"^a", after=_) => 1
  (re"^ab", after=_) => 2
  _ => 0
}
// => 1
```

For unanchored cases, each case performs its own leftmost search when it is
considered. A successful earlier case prevents later cases from being tried,
even if a later case could match at an earlier input position:

```moonbit
lexmatch "ba" {
  (re"a", before=_, after=_) => "a-case"
  (re"b", before=_, after=_) => "b-case"
  _ => "none"
}
// => "a-case"
```

Within one case, the regex is leftmost-first and respects alternation order,
greedy quantifiers, and non-greedy quantifiers.

### 5.2 Anchoring

A first-strategy case may be unanchored. If it is not start-anchored, the
matching is equivalent to prepending a non-greedy match of any scalar value.

It may also leave an unmatched suffix unless `$` requires the logical end.

### 5.3 `before` and `after`

Both `before` and `after` are supported.

- `before` is the target prefix before the selected match.
- `after` is the target suffix after the selected match.
- `before=_` or `after=_` explicitly discards the piece.
- `before~` or `after~` binds a variable of the same name.

Both binding types are `StringView`.

### 5.4 Boundary-intent warnings

The compiler warns when the syntax does not make unmatched text explicit:

- E0080 if a pattern is not start-anchored and has no `before` binding; and
- E0081 if a pattern is not end-anchored and has no `after` binding.

These warnings do not change matching semantics. They are removed by adding
the relevant anchor or by binding or explicitly discarding the corresponding
piece.

## 6. Longest strategy

`with longest` performs maximal-munch selection from the beginning of the
target.

```moonbit
lexmatch input with longest {
  ...
}
```

### 6.1 Required start anchoring

Every regex case MUST be start-anchored. In ordinary source this is normally
written with `^`.

Anchoring is checked semantically on the complete pattern. For alternation,
every alternative must be anchored. A positive mandatory repetition of an
anchored subpattern remains anchored; a nullable repetition does not establish
anchoring.

### 6.2 Selection

Among all cases that match at the beginning, the case consuming the longest
prefix is selected. Equal-length matches are resolved by source order.

A case that follows some input transitions but never reaches a successful
accepting path is not a candidate. Such a partial-prefix failure does not stop a
later case from matching at the target beginning.

```moonbit
lexmatch "ifx" with longest {
  (re"^if", after=_) => "keyword"
  (re"^[a-z]+", after=_) => "identifier"
  _ => "other"
}
// => "identifier"
```

The complete match length and case tie rule do not define a unique capture
decomposition when one case has several successful paths that reach the same
maximal end. In that situation, the choice among those paths is unspecified.
All captures produced by the selected case MUST nevertheless come from one
single successful maximal path; an implementation MUST NOT combine endpoints
from different paths. Programs MUST NOT depend on which coherent decomposition
is chosen. The choice may differ between compiler versions, targets, or
optimization modes.

For example, both of these capture results are permitted for the following
case on input `"aa"`:

```moonbit
((re"^(a|aa)" as left) + (re"a?" as right), after=_) => ...
```

```text
left == "a",  right == "a"
left == "aa", right == ""
```

The complete match is still required to consume the same maximal prefix in
both outcomes.

### 6.3 Quantifiers

Non-greedy quantifiers are invalid in longest-strategy patterns. This includes
non-greedy quantifiers contained in a referenced regex constant.

### 6.4 `before` and `after`

`before` is invalid because every match starts at the target beginning.
`after` is supported and contains the unmatched suffix.

If a case is not end-anchored and has no `after` binding, the compiler emits
E0081. Add `after=_` to state that the suffix is intentionally discarded, or
add `$` to require a whole-input match.

## 7. Catch-all cases

A catch-all has one of these forms:

```moonbit
rest => fallback(rest)
_ => fallback()
...
```

The `...` form is the wildcard form with a TODO hole body. A catch-all MUST be
the last case.

A binder written before the final case is rejected with E4171, the same
catch-all-ordering diagnostic used for a non-final wildcard catch-all.

When no regex case is selected:

- a binder catch-all receives the original target, viewed as a `StringView`;
  and
- a wildcard catch-all discards the target.

The catch-all does not receive a cursor, attempted match position, partially
scanned suffix, or any other matcher state. It receives the complete input
presented to this `lexmatch` expression. For a sliced `StringView`, this means
the complete slice rather than its backing string.

A catch-all may be the only case. A binder-only `lexmatch` therefore evaluates
its body with the entire target bound as a `StringView`.

## 8. Exhaustiveness

A catch-all is not syntactically mandatory. Exhaustiveness analysis determines
whether any input, including empty input, can reach the implicit catch-all
without a selected regex case.

- If such an input exists and no catch-all body is present, compilation fails
  with E4224 and a shortest counterexample expressed as UTF-16 code units.
- If no such input exists, the catch-all may be omitted.
- If a written catch-all can never be reached, it produces E0090.

An unreachable catch-all body is still type-checked.

This means an exhaustive regex case such as `re"^.*$"` can stand alone:

```moonbit
lexmatch input {
  re"^.*$" => 1
}
```

## 9. Unreachable cases

The compiler emits E0090 for a regex case that can never be selected because:

- earlier priority shadows it for all of its inputs;
- another case always replaces it before dispatch under longest matching; or
- its regex denotes the empty language, for example `re"^[]"`.

Unreachable regex-case and catch-all bodies are still type-checked. A name or
type error inside such a body remains an error.

## 10. Empty matches

An empty regex match is a normal successful case. Captures may be empty views,
and `before` and `after` meet at the same offset.

Because `lexmatch` does not mutate the target, an empty match has no progress
implication beyond the expression itself.

## 11. Legacy incompatibility

The following old forms are not part of this specification:

```moonbit
// Removed string-piece lexical pattern
lexmatch text {
  (before, "a" ("b*" as b), after) => ...
}

// Removed boolean form
text lexmatch? "a"
```

Use regex constant patterns and `=~` instead.
