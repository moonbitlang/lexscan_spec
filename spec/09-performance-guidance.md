# Performance Guidance

This chapter is informative. It records how released compilers compile regex
match expressions and `lexmatch`, so that programs, and the tools and agents
that write them, can choose the form that runs fastest. It does not constrain
conforming implementations: every form below has the result specified in the
other chapters, however it is compiled.

## 1. Matches compiled without an automaton

`moonc v0.10.16` and `v0.10.17` compile a match to a plain string comparison,
with no regex automaton, when all of these hold:

1. It is a regex match expression (`=~`), or a `lexmatch` with exactly one
   regex case followed by a catch-all case (`_` or a binder such as
   `rest => ...`). A `lexmatch` with several regex cases, and every `lexscan`,
   uses an automaton.
2. The case has no pattern-level `as` binding. `before` and `after` bindings do
   not matter.
3. The pattern is one literal string between an optional leading `^` and an
   optional trailing `$`. Every character of it must stand for exactly one
   character: an ordinary or escaped character such as `\.`, a character
   class with one member such as `[.]`, or a character in a case-insensitive
   group that has no other case, such as the digit in `(?i:0)`. Parentheses
   that only group are ignored.

| Pattern | Compiled as |
| --- | --- |
| `^text$` | `input == "text"` |
| `^text` | `input.has_prefix("text")` |
| `text$` | `input.has_suffix("text")` |
| `text` | `input.find("text")` |

`before` and `after` are then views computed from the match position and the
literal's length, with no further scan.

Every other match uses an automaton. That includes, in these releases, an
alternation of strings such as `^(if|else)`, a character class with more than
one member such as `[0-9]`, `.`, a letter in a case-insensitive group such as
`(?i:if)`, repetition, and assertions other than the outer `^` and `$`, such
as `\b`.

## 2. Literal sets in the next release

This section describes compiler behavior that is not in a released compiler as
of `v0.10.17`, and is expected in the release after it. Compilers from then on
also compile a small set of literal strings without an automaton: an
alternation of literals, possibly nested, such as
`^(if|else|while)$`, `^(return|break|continue)` or `(\.mbt|\.mbti)$`, when the
match meets conditions 1 and 2 above and the pattern

- is anchored with `^`, `$` or both (a search for several literals still uses
  an automaton);
- expands to at most 8 strings; and
- needs at most 64 code-unit comparisons in the generated code (not
  comparisons executed at run time). One comparison is generated per UTF-16
  code unit, a code unit that several literals share at the start (at the end
  for a `$` pattern) counts once, and a `^...$` pattern counts its literals of
  each length separately.

The input is compared code unit by code unit. Code units shared by several
literals are compared once, and the comparison branches where the literals
differ. A `^...$` pattern compares the input's length first.

## 3. Choosing a form

To test for a fixed string, use `=~`, or a single-case `lexmatch` when the
result is not `Bool`, with an anchored literal:

```moonbit
let is_comment = line =~ re"^#"                  // has_prefix
let module_name = if path =~ (re"\.mbt$", before=stem) {
  stem.to_owned()                                // has_suffix, stem by length
} else {
  path
}
let value = lexmatch token {
  (re"^0x", after=digits) => parse_hex(digits)   // has_prefix
  _ => parse_decimal(token)
}
```

Anchor the pattern when a prefix, a suffix or the whole input is meant. An
unanchored pattern is a search through the input, even for one literal.

Bind the matched pieces with `before` and `after` rather than `as` when they
determine what is needed. An `as` binding makes the match use an automaton,
even when the bound text is a literal known in advance:

```moonbit
// Uses an automaton: the `as` binding.
let a = if s =~ (re"^0x" as prefix, after=digits) {
  prefix.length() + digits.length()
} else {
  0
}
// One has_prefix call; the prefix is "0x" anyway.
let b = if s =~ (re"^0x", after=digits) { 2 + digits.length() } else { 0 }
```

A `lexmatch` with several regex cases always uses an automaton, which reads
the input once whatever the number of cases. Rewriting it as a chain of `=~`
tests gives one comparison per case, but whether that is faster depends on the
literals, the inputs and the target, so measure before choosing it. A chain
also follows first-match order: it can select a different case than a
`lexmatch ... with longest`, as for the input `"ab"` with cases `^a` and
`^ab`.

When only a few spellings can occur, list them as literal alternatives, such
as `re"^(true|false)$"`, rather than writing a pattern that also accepts other
strings, such as `re"^[a-z]+$"`, and checking the result again. From the
release after `v0.10.17`, the alternatives are compared directly.

`s =~ re"^abc"` and `s.has_prefix("abc")` compile to the same call. Choose
between them for readability; the regex form also gives `before` and `after`.
