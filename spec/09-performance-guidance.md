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
of `v0.10.17`, and is expected in the release after it.

### 2.1 Which patterns

Compilers from then on also compile a small set of literal strings without an
automaton: an alternation of literals, possibly nested, when the match meets
conditions 1 and 2 of section 1 and the pattern

- is anchored with `^`, `$` or both (a search for several literals still uses
  an automaton);
- has no alternation of single characters, at any level: `(a|b)` is the
  character class `[ab]`, so `^(a|b)$` and `^x(a|b)$` still use an automaton,
  while `^(ab|cd)$` does not;
- expands to at most 8 strings, counting duplicates; and
- needs at most 64 code-unit comparisons for the whole set, counted before
  alternatives that can never decide the match are dropped (section 2.3).
  One comparison is counted per UTF-16 code unit, a code unit that several
  literals share at the start (at the end for a `$` pattern) counts once, and
  a `^...$` pattern counts its literals of each length separately. So
  `^(a|aaa...)` with a second literal of 65 units uses an automaton, although
  under first-match only `a` can decide it.

| Pattern | Lowered | Why |
| --- | --- | --- |
| `^(if\|else\|while)$` | yes | three literals, branched by length first |
| `^(return\|break\|continue)` | yes | prefix test |
| `(\.mbt\|\.mbti\|\.md)$` | yes | suffix test, compared from the end |
| `^x(a\|bc)(d\|ef)$` | yes | expands to `xad`, `xaef`, `xbcd`, `xbcef` |
| `^(abcd\|abce\|abx)$` | yes | `abc` is compared once for `abcd` and `abce` |
| `^(😀a\|😁b)` | yes | the shared high surrogate is compared once |
| `^(\|a)` | yes | the empty string is a literal |
| `(if\|else)` | no | a search |
| `^(a\|b)`, `^x(a\|b)$` | no | `(a\|b)` is the class `[ab]` |
| `^(?i:if\|else)` | no | case-insensitive letters are classes |
| `(a\|bb)(c\|dd)(e\|ff)(g\|hh)$` | no | 16 strings |
| `^(ab\|ab\|ab\|ab\|ab\|ab\|ab\|ab\|ab)` | no | 9 strings, counting duplicates |

### 2.2 Generated code

The input is compared code unit by code unit as a trie: each code unit of the
input is read at most once, a code unit shared by several literals is compared
once, and a `match` branches where the literals differ. A length test appears
only where a remaining literal needs more code units than an earlier test
checked. The following shows the shape of the code for some patterns, written
in MoonBit with `input` for the matched `StringView`.

`s =~ re"^(return|break|continue)"`:

```moonbit
input.length() >= 5 &&
(match input.unsafe_get(0) {
  'r' => input.length() >= 6 && input.unsafe_get(1) == 'e' && ... && input.unsafe_get(5) == 'n'
  'b' => input.unsafe_get(1) == 'r' && ... && input.unsafe_get(4) == 'k'
  'c' => input.length() >= 8 && input.unsafe_get(1) == 'o' && ... && input.unsafe_get(7) == 'e'
  _ => false
})
```

A `^...$` pattern branches on the length first, then compares the literals of
that length. `s =~ re"^(abcd|abce|abx)$"`:

```moonbit
match input.length() {
  4 => input.unsafe_get(0) == 'a' && input.unsafe_get(1) == 'b' && input.unsafe_get(2) == 'c' &&
       (match input.unsafe_get(3) { 'd' | 'e' => true; _ => false })
  3 => input.unsafe_get(0) == 'a' && input.unsafe_get(1) == 'b' && input.unsafe_get(2) == 'x'
  _ => false
}
```

A `$` pattern compares from the end, `input.unsafe_get(input.length() - 1)`
first. A character outside the Basic Multilingual Plane is two code units; its
halves are compared as integers, such as `0xD83D`.

### 2.3 `before` and `after`

When `before` or `after` is bound and the literals differ in length, the code
computes the length of the match, or -1 for no match, and the case body appears
once. Which literal is the match follows the matching model:

- A prefix test under first-match takes the earliest alternative that matches,
  in source order.
- A prefix test under `with longest` takes the longest one.
- A suffix test takes the longest one, under either strategy: every match ends
  at the end of the input, so the leftmost match is the longest.

`(re"^(abc|a)", after=rest)`, where `abc` is tried first:

```moonbit
let length = if input.length() >= 1 && input.unsafe_get(0) == 'a' {
  if input.length() >= 3 && input.unsafe_get(1) == 'b' && input.unsafe_get(2) == 'c' { 3 } else { 1 }
} else {
  -1
}
if length >= 0 {
  let rest = input.view(start_offset=length)
  ...
}
```

A literal that can never be the match is dropped first. With
`(re"^(a|abc)", after=rest)` under first-match, `a` is tried first and matches
whenever `abc` does, so the match is `input.has_prefix("a")`, as for a single
literal. When only whether a literal matches is observed, a literal that extends
another one is dropped in the same way.

### 2.4 Measured effect

The following was measured on an Apple M2 Ultra running macOS 26.4, with Node
v25.8.2 for js and wasm-gc and clang 22 at `-O3` for native. The baseline is
the same match compiled with the table automaton. Inputs were built at run
time, half of them matching; each figure is the median of five samples of at
least 35 ms each. The sets were the first 1 to 8 of the keywords `return`,
`break`, `continue`, `else`, `while`, `match`, `struct` and `trait` as prefix,
exact and suffix tests; 2 to 8 literals of 8 code units sharing up to 7
leading units; and four literals of 4 to 32 code units.

For every one of the 153 sets that is lowered, the trie was faster than the
automaton on every target:

| Target | Median time, relative to the automaton | Slowest set |
| --- | ---: | ---: |
| js | 0.58 | 0.99 |
| wasm-gc | 0.35 | 0.71 |
| native | 0.12 | 0.31 |

The code is also smaller. The compiled output of a program whose only function
matches `^(return|break|continue)`:

| Target | Automaton | Trie |
| --- | ---: | ---: |
| js | 2,455 bytes | 1,075 bytes |
| wasm-gc | 1,398 bytes | 484 bytes |
| native | 1,240 bytes | 372 bytes |

Native sizes count object code and constants, not the linked runtime.

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
