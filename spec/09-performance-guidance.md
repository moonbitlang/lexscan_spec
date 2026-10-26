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
   regex case followed by a catch-all `_` case. A `lexmatch` with several regex
   cases, and every `lexscan`, uses an automaton.
2. The case has no pattern-level `as` binding. `before` and `after` bindings do
   not matter.
3. The pattern is one literal string between an optional leading `^` and an
   optional trailing `$`. Escaped characters such as `\.` and character
   classes with one member such as `[.]` count as literal characters, and
   parentheses that only group are ignored.

| Pattern | Compiled as |
| --- | --- |
| `^text$` | `input == "text"` |
| `^text` | `input.has_prefix("text")` |
| `text$` | `input.has_suffix("text")` |
| `text` | `input.find("text")` |

`before` and `after` are then views computed from the match position and the
literal's length, with no further scan.

Every other match uses an automaton. That includes an alternation of strings
such as `^(if|else)` in these releases, any character class with more than one
member such as `[0-9]`, `.`, case-insensitive groups `(?i:...)`, repetition,
and assertions other than the outer `^` and `$`, such as `\b`.

## 2. Literal sets in later compilers

Compilers after `v0.10.17` also compile a small set of literal strings without
an automaton: an alternation of literals, possibly nested, such as
`^(if|else|while)$`, `^(return|break|continue)` or `(\.mbt|\.mbti)$`, when the
match meets conditions 1 and 2 above and the pattern

- is anchored with `^`, `$` or both (a search for several literals still uses
  an automaton);
- expands to at most 8 strings; and
- needs at most 64 UTF-16 code-unit comparisons in total. Literals that share
  leading code units (trailing ones for a `$` pattern) count them once, and a
  `^...$` pattern counts each length separately.

The input is compared code unit by code unit. Code units shared by several
literals are compared once, and the comparison branches where the literals
differ. A `^...$` pattern compares the input's length first.

## 3. Choosing a form

To test for a fixed string, use `=~`, or a single-case `lexmatch` when the
result is not `Bool`, with an anchored literal:

```moonbit
if line =~ re"^#" { ... }                        // has_prefix
if path =~ (re"\.mbt$", before=stem) { ... }     // has_suffix, stem by length
lexmatch token {
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
if s =~ (re"^0x" as prefix, after=digits) { ... }
// One has_prefix call; the prefix is "0x" anyway.
if s =~ (re"^0x", after=digits) { ... }
```

For two or three literal cases with different results, a chain of `=~` tests
is two or three direct comparisons, while a `lexmatch` with several cases runs
an automaton:

```moonbit
let kind = if line =~ re"^#" {
  Hash
} else if line =~ re"^//" {
  Slash
} else {
  Other
}
```

Measured against a two- or three-case `lexmatch` over the same literals, such
a chain took 0.38 to 0.72 of the time on js, 0.21 to 0.38 on wasm-gc and 0.20
to 0.42 on native. A `lexmatch` with several cases reads the input once
whatever the number of cases. Use it when there are many cases, or when the
cases are not literal strings.

When only a few spellings can occur, list them as literal alternatives, such
as `re"^(true|false)$"`, rather than writing a pattern that also accepts other
strings, such as `re"^[a-z]+$"`, and checking the result again. Compilers after
`v0.10.17` compare the alternatives directly.

`s =~ re"^abc"` and `s.has_prefix("abc")` compile to the same call. Choose
between them for readability; the regex form also gives `before` and `after`.
