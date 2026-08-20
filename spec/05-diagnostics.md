# Diagnostics

## 1. Conformance policy

This chapter lists diagnostic codes observable with the target toolchain. The
diagnostic code and rejection or warning condition are normative once the
documents are approved. Exact prose and source ranges are informative unless a
future test explicitly pins them.

Some invalid programs may produce an additional shadowed or recovery
diagnostic. For example, an invalid longest-match regex may also produce a
secondary anchoring diagnostic during error recovery. Conformance tests SHOULD
assert the primary diagnostic and tolerate documented recovery noise unless
source-range behavior is itself under test.

## 2. Regex syntax and pattern errors

### E4172 — Invalid regex pattern

The compiler emits E4172 when a regex literal is syntactically or semantically
invalid. Conditions include:

- an unclosed group, character class, or POSIX class;
- a malformed or unsupported escape;
- a quantifier without an atom;
- a quantifier applied to `^` or `$`;
- a Unicode escape for an isolated surrogate;
- a repetition minimum greater than its maximum;
- a descending character range;
- a range over character sets;
- an unsupported POSIX class;
- lookaround, backreferences, or word-boundary assertions;
- character-class set intersection or subtraction;
- a malformed group modifier;
- duplicate named captures in a first-class regex literal; and
- a non-greedy quantifier under the `longest` strategy.

### E4181 — Named capture in a direct lexical regex literal

A regex literal used directly as a pattern MUST NOT contain a named regex group
such as `(?<name>...)`. Pattern bindings use MoonBit's `as` syntax.

This diagnostic applies to `=~`, `lexmatch`, and `lexscan` direct literal
patterns. A named capture hidden inside a referenced regex constant has its
capture metadata removed and does not create a MoonBit binder. Its grouping and
matching behavior remains effective.

### E4210 — Regex alias inside an alternation

A pattern-level `as` binder MUST NOT occur inside an alternation branch.

```moonbit
// E4210
input =~ ((re"a" as left) | re"b")
```

Bind the complete alternation instead.

### E4081 — non-linear pattern

All binders introduced by `as`, `before`, and `after` in one pattern MUST have
distinct local names. Reusing a name emits the ordinary non-linear-pattern
diagnostic E4081.

### E4022 / E4014 — constant resolution and type

A name in regex-pattern atom position is resolved as a constant.

- An unbound constant emits E4022.
- A bound constant whose type is not `Regex` emits E4014.

An arbitrary local `Regex` value is not accepted in this position.

## 3. Match binding errors

### E4208 — Unknown regex match binding

Only `before` and `after` are valid labels in a regex binding tuple. Any other
label emits E4208.

### E4209 — Duplicate regex match binding

`before` and `after` may each appear at most once. A duplicate label emits
E4209 even if one occurrence uses `_`.

### E4220 — Unsupported regex match binding

The availability matrix is:

| Expression and strategy | `before` | `after` |
| --- | --- | --- |
| `=~` | yes | yes |
| `lexmatch` first | yes | yes |
| `lexmatch` longest | no | yes |
| `lexscan` first | no | no |
| `lexscan` longest | no | no |

Using a binding in a `no` cell emits E4220.

## 4. Strategy and anchoring errors

### E4180 — Unsupported match strategy

Only `first` and `longest` are accepted after `with`. The absent strategy is
`first`. Other names, such as `shortest`, emit E4180.

### E4218 — Required start anchoring

E4218 is emitted when a regex case is not semantically start-anchored and the
matching mode requires anchoring:

- every `lexscan` case under either strategy; and
- every `lexmatch` case under `longest`.

An ordinary `^` at the beginning of every alternative is the usual fix.

## 5. Target and package errors

### E4014 — target type mismatch for `=~`

The left operand of `=~` MUST be `String` or `StringView`. Other types emit the
ordinary type-mismatch diagnostic E4014.

### E4222 — Invalid lexical target

E4222 is shared by the two lexical expressions:

- `lexmatch` expects `String` or `StringView`;
- `lexscan` expects `@lexbuf.Lexbuf`, `@lexbuf.AsyncLexbuf`, or
  `@lexbuf.StringScanner`.

The types are nominal. Duck-typed scanner substitutes are invalid.

### E4037 — Required core package not imported

The `Regex` type is re-exported by the prelude. Regex literals and `=~` do not
require a direct `moonbitlang/core/string` import and MUST NOT produce E4037
merely because that package was not imported by the user package.

`lexscan` requires a direct `moonbitlang/core/lexbuf` import in the package
containing the expression.

If `moonbitlang/core/lexbuf` is absent or only available through an indirect
dependency, E4037 is emitted for `lexscan`. This rule does not extend to
`moonbitlang/core/string` for regex literals or `=~`.

## 6. Case-list and exhaustiveness errors

### E4171 — Catch-all must be last

A wildcard catch-all that appears before another case emits E4171. The
catch-all MUST be last.

A non-final `lexmatch` binder is also a catch-all and emits E4171. Binder and
wildcard spellings have the same ordering rule.

### E4216 — Binder catch-all is unsupported by `lexscan`

A `lexscan` catch-all MUST be `_`. A binder such as `rest => ...` emits E4216.

`lexmatch` permits a binder catch-all and gives it the entire input as a
`StringView` when it is final.

### E4224 — Reachable implicit catch-all has no body

E4224 applies to both `lexmatch` and `lexscan`.

It is emitted when exhaustiveness analysis finds an input that reaches the implicit
catch-all and no catch-all body is present. The message contains a shortest
counterexample expressed as UTF-16 code units.

A case list proven exhaustive may omit the catch-all.

## 7. Warnings

### E0080 — Missing `before` intent

For first-strategy `lexmatch`, an unanchored regex without any `before` entry
emits E0080.

Add `^`, `before=name`, or `before=_`.

This warning is not emitted by `=~`.

### E0081 — Missing `after` intent

A `lexmatch` regex not semantically end-anchored and without any `after` entry
emits E0081 under both strategies, provided its start condition is otherwise
supported. A longest-strategy case that already fails start anchoring with
E4218 need not additionally emit E0081.

Add `$`, `after=name`, or `after=_`.

This warning is not emitted by `=~` and cannot apply to `lexscan`, where
`after` is unsupported.

### E0090 — Unused lexical case

E0090 is emitted for a `lexmatch` or `lexscan` case that can never be selected.
It covers:

- priority shadowing by earlier cases;
- a case whose accept candidate is always replaced before dispatch;
- an empty-language regex; and
- a catch-all that is unreachable because regex cases are exhaustive.

The unreachable body remains type-checked.

### E0027 — Deprecated shorthand character-class escape

The shorthand class escapes `\d`, `\D`, `\s`, `\S`, `\w`, and `\W` are
accepted with E0027. Use POSIX character classes instead.

## 8. Removed and unused historical diagnostics

Diagnostics associated only with earlier experimental lexical-pattern designs
MUST NOT be used to infer current syntax. In particular, string-piece pattern
errors and `lexmatch?` diagnostics are outside this specification.
