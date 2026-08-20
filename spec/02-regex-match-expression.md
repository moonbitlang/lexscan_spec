# Regex Match Expression (`=~`)

## 1. Purpose

A regex match expression performs one boolean regex search. It is the current
replacement for the removed `lexmatch?` form.

```moonbit
input =~ regex_pattern
```

Its result type is `Bool`.

Use `lexmatch` instead when several regex cases must produce different values.

## 2. Syntax

```text
regex-match-expression ::= expression "=~" regex-match-rhs

regex-match-rhs        ::= regex-atom-pattern
                         | "(" regex-pattern ["," match-bindings] [","] ")"

match-bindings         ::= match-binding ("," match-binding)*

match-binding          ::= label "=" binder
                         | label "=" "_"
                         | post-label
```

Only the labels `before` and `after` are valid.

Examples:

```moonbit
text =~ re"abc"
text =~ ((re"[0-9]+" as digits), before=head, after=tail)
text =~ (re"b", before~, after~)
text =~ (re"^prefix", after=_)
```

`before~` is shorthand for `before=before`; `after~` is shorthand for
`after=after`.

Parentheses are required when bindings follow the regex pattern. A trailing
comma is permitted. Because the unparenthesized right-hand side accepts only a
regex atom, a pattern-level sequence, alternation, or alias also requires an
outer pair of parentheses even when it has no `before` or `after` entries.
Parentheses used only for grouping may be nested inside that outer pair.

## 3. Target typing

The left operand MUST have type `String` or `StringView`.

A `String` is implicitly viewed as a `StringView`. Captures and unmatched
pieces have type `StringView` over the corresponding target ranges. This
specification does not require a particular allocation strategy or observable
backing-storage identity.

For a sliced `StringView`, `before`, captures, and `after` are all bounded by
the slice. They do not include text from the backing string outside the view.

Other types, including `Bytes`, `BytesView`, and numeric types, are invalid.

The regex pattern is compiled from literals and constants. The `Regex` type is
re-exported by the prelude, so neither a regex literal nor `=~` requires the
user package to import `moonbitlang/core/string` directly.

## 4. Matching semantics

`=~` uses first-match search semantics as defined in
[Regex Patterns and Matching Model](01-regex-patterns.md#5-first-match-semantics).
There is no strategy clause and no longest-match variant.

An unanchored pattern searches the whole input:

```moonbit
assert_true("zabc!" =~ re"abc")
assert_true(!("zabc!" =~ re"^abc"))
```

The search chooses the earliest start position. Regex alternative order and
quantifier greediness then choose the match at that position.

The expression returns `true` if the pattern matches and `false` otherwise.

## 5. Bindings

### 5.1 `as` bindings

A pattern-level `as` binds the text consumed by the aliased subpattern. Its
type is `Char` for a statically single-scalar regex and `StringView`
otherwise.

```moonbit
if (source =~ (re"." as ch, after=rest)) {
  // ch   : Char
  // rest : StringView
}
```

### 5.2 `before`

`before=name` binds the input range from the logical beginning of the input to
the selected match start. Its type is `StringView`.

For a start-anchored match, `before` is an empty view at the beginning of the
input.

### 5.3 `after`

`after=name` binds the input range from the selected match end to the logical
end of the input. Its type is `StringView`.

For an end-anchored match, `after` is an empty view at the end of the input.

### 5.4 Discarding pieces

`before=_` and `after=_` explicitly discard the corresponding piece. They do
not create a binding.

Omitting `before` or `after` also discards that piece. Unlike `lexmatch`, `=~`
does not emit the missing-before or missing-after warnings.

### 5.5 Name restrictions

Each of `before` and `after` MAY appear at most once. Any other binding label is
invalid.

All binders introduced by the pattern, `before`, and `after` MUST have distinct
local names. Reusing a name is a non-linear-pattern error.

## 6. Binding scope and boolean flow

Bindings exist only on the successful path of the boolean match. They follow
the same conditional-flow discipline as binders introduced by `is`.

They are available in:

- the right operand of `&&` when introduced by its left operand;
- the true branch of an `if` whose condition guarantees the match;
- the body following a successful `guard` condition; and
- the body of a `while` whose condition guarantees the match; and
- the update expressions and body of a `for` loop whose condition guarantees
  the match.

```moonbit
if (input =~ ((re"[A-Za-z]+" as word), after=rest)) && word.length() > 0 {
  consume(word, rest)
}
```

They are not available through `||`, logical negation, a false branch, a
`guard` failure branch, or a loop `else` branch, because those paths do not
guarantee that the regex match succeeded.

## 7. Evaluation order

The left operand is evaluated exactly once before matching begins.

The regex pattern is resolved and compiled at compile time. No runtime `Regex`
expression on the right-hand side is evaluated.

Bindings are materialized only on success. On failure the expression produces
`false`, and no successful-path binder is evaluated or made available.

When the target expression produces a temporary `String`, any capture or
boundary view returned from the successful path remains a valid `StringView`
for as long as that view remains reachable.

## 8. Examples

### 8.1 Search with all pieces

```moonbit
fn split_ident(input : String) -> (StringView, StringView, StringView)? {
  if (input =~ (
      (re"[A-Za-z_][A-Za-z0-9_]*" as ident),
      before=head,
      after=tail,
    )) {
    Some((head, ident, tail))
  } else {
    None
  }
}
```

For `" let_name = 42 "`, the result is `Some((" ", "let_name", " = 42 "))`.

### 8.2 Character capture

```moonbit
if ("😋tail" =~ (re"^." as face, after=tail)) {
  // face == '😋'
  // tail == "tail"
}
```

Although the emoji occupies two UTF-16 code units, `face` has type `Char` and
contains one Unicode scalar value.
