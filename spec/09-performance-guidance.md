# Performance Guidance

This chapter is informative. It records how `moonc v0.10.19+bee578715`, the
pre-release toolchain of 2026-11-02, compiles regex match expressions and
`lexmatch`, so that programs, and the tools and agents that write them, can
choose the form that runs fastest. It does not constrain
conforming implementations: every form below has the result specified in the
other chapters, however it is compiled.

The lowerings below are chosen before the regex backend, so they apply in the
same way whether the package selects the `table`, `block`, or `runtime`
backend. They apply to text regexes (`re"..."`) and bytes regexes
(`reb"..."`) alike; section 5 lists what differs for bytes.

## 1. Summary

A match compiles to direct comparisons, with no regex automaton, in these
forms:

| Form | Example | Compiled as | Section |
| --- | --- | --- | --- |
| one literal | `s =~ re"^#"` | one `==`, prefix, suffix, or `find` test | 2.3 |
| a small anchored set of literals | `s =~ re"^(if\|else\|while)$"` | a trie of code units | 2.4 |
| anchored literals ignoring ASCII case | `s =~ re"^(?i:content-length):"` | a trie that folds letters | 2.5 |
| several literal `lexmatch` cases | `(re"^GET ", after=r) => ...` beside `(re"^POST ", after=r) => ...` | one trie for all cases | 3 |

Every other match uses an automaton, and so does every `lexscan`. Section 6
lists the common reasons.

## 2. A single case

### 2.1 Which matches

A match takes the lowerings of this section when all of these hold:

1. It is a regex match expression (`=~`), or a `lexmatch` with exactly one
   regex case followed by a catch-all case (`_` or a binder such as
   `rest => ...`), with the `first` or the `longest` strategy.
2. The case has no pattern-level `as` binding. `before` and `after` bindings do
   not matter.
3. The pattern is a literal set (section 2.2).

### 2.2 Literal sets

A pattern is a literal set when, between an optional leading `^` and an
optional trailing `$`, it is built only from literal characters, concatenation
and alternation, and expands to at most 8 strings, counting duplicates.
Parentheses that only group are ignored, and the groups of a regex literal do
not capture in a pattern.

A literal character is a character that stands for exactly one character: an
ordinary or escaped character such as `\.`, a character class with one member
such as `[.]`, or a character in a case-insensitive group that has no other
case, such as the digit in `(?i:0)`. An ASCII letter in a case-insensitive
group, or a class of the two cases of one letter such as `[Hh]` or `(H|h)`, is
a folded letter (section 2.5).

Any other alternation of single characters is a character class, not a set of
literals: `(a|b)` is `[ab]`, so `^(a|b)$` and `^x(a|b)$` are not literal sets,
while `^(ab|cd)$` is.

### 2.3 One literal

When the set has one string and no folded letter, the match is one test:

| Pattern | Text target | Bytes target |
| --- | --- | --- |
| `^text$` | `input == "text"` | `input == b"text"`, or byte by byte (section 5) |
| `^text` | a range comparison at offset 0, like `has_prefix` | `input.has_prefix(b"text")`, or byte by byte |
| `text$` | `input.has_suffix("text")` | `input.has_suffix(b"text")`, or byte by byte |
| `text` | `input.find("text")` | `input.find(b"text")` |

There is no length limit. `before` and `after` are then views computed from the
match position and the literal's length, with no further scan.

### 2.4 Several literals

A set of several strings is compared without an automaton when, in addition:

- it is anchored with `^`, `$` or both (a search for several literals uses an
  automaton); and
- its tries compare at most 64 code units, counted before alternatives that can
  never decide the match are dropped (section 2.7). One comparison is counted
  per code unit, a code unit that several literals share at the start (at the
  end for a `$` pattern) counts once, and a `^...$` pattern counts its literals
  of each length separately. A literal longer than 64 code units disqualifies
  the set. So `^(a|aaa...)` with a second literal of 65 units uses an
  automaton, although under first-match only `a` can decide it.

| Pattern | Lowered | Why |
| --- | --- | --- |
| `^(if\|else\|while)$` | yes | three literals, branched by length first |
| `^(return\|break\|continue)` | yes | prefix test |
| `(\.mbt\|\.mbti\|\.md)$` | yes | suffix test, compared from the end |
| `^x(a\|bc)(d\|ef)$` | yes | expands to `xad`, `xaef`, `xbcd`, `xbcef` |
| `^(abcd\|abce\|abx)$` | yes | `abc` is compared once for `abcd` and `abce` |
| `^(😀a\|😁b)` | yes | the shared high surrogate is compared once |
| `^(\|a)` | yes | the empty string is a literal |
| `^(?i:if\|else)` | yes | folded letters (section 2.5) |
| `(if\|else)` | no | a search |
| `^(a\|b)`, `^x(a\|b)$` | no | `(a\|b)` is the class `[ab]` |
| `(a\|bb)(c\|dd)(e\|ff)(g\|hh)$` | no | 16 strings |
| `^(ab\|ab\|ab\|ab\|ab\|ab\|ab\|ab\|ab)` | no | 9 strings, counting duplicates |

### 2.5 Ignoring case

A literal set with folded letters is compared as a trie that folds each ASCII
letter of the input, as in section 2.4 and with the same limits, even when it
has one string. It must be anchored, and every letter of the set must be
folded:

| Pattern | Lowered | Why |
| --- | --- | --- |
| `^(?i:host):` | yes | the colon has no case |
| `^(?i:get\|post) ` | yes | two folded literals |
| `^[Hh][Oo][Ss][Tt]:`, `^(H\|h)(O\|o)(S\|s)(T\|t):` | yes | the same folded literal as `^(?i:host):` |
| `^[Hh]ost` | no | `ost` is exact while `[Hh]` is folded |
| `^(?i:if)x` | no | `x` is exact while `if` is folded |
| `(?i:if)` | no | a search |

### 2.6 Generated code

The input is compared code unit by code unit as a trie: each code unit of the
input is read at most once, a code unit shared by several literals is compared
once, and a `match` branches where the literals differ. A length test appears
only where a remaining literal needs more code units than an earlier test
checked. The following shows the shape of the code for some patterns, written
in MoonBit with `input` for the matched view.

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
halves are compared as integers, such as `0xD83D`. A folded letter is compared
as `input.unsafe_get(i).to_int() | 0x20` against its lowercase code.

### 2.7 `before` and `after`

When a binding depends on where the match ends (`after` for a prefix test) or
begins (`before` for a suffix test), and the literals that can be the match
differ in length, the code computes the length of the match, or -1 for no
match, and the case body appears once. Otherwise the boundary is known
without it: `before` of a prefix test is empty, `after` of a suffix test is
empty, and an exact test spans the whole input. Which literal is the match
follows the matching model:

- A prefix test under first-match takes the earliest alternative that matches,
  in source order.
- A prefix test under `with longest` takes the longest one.
- A suffix test takes the longest one: every match ends at the end of the
  input, so the leftmost match is the longest. Suffix tests occur only under
  first-match, because `with longest` requires a pattern that starts with `^`
  (error E4218).

`(re"^(abc|a)", after=rest)`, where `abc` is tried first:

```moonbit
let length = if input.length() >= 1 && input.unsafe_get(0) == 'a' {
  if input.length() >= 3 && input.unsafe_get(1) == 'b' && input.unsafe_get(2) == 'c' { 3 } else { 1 }
} else {
  -1
}
if length >= 0 {
  let rest = input[length:]
  ...
}
```

A literal that can never be the match is dropped first. With
`(re"^(a|abc)", after=rest)` under first-match, `a` is tried first and matches
whenever `abc` does, so the match is a prefix test for `a`, as for a single
literal. When only whether a literal matches is observed, a literal that
extends another one is dropped in the same way.

## 3. Several cases

A `lexmatch` with several regex cases compares all of them in one trie when:

1. it uses the `first` strategy and has a catch-all case;
2. no case has a pattern-level `as` binding (`before` and `after` are allowed);
3. every case is a literal set (section 2.2) anchored with `^` and not with
   `$`, each within the limits of sections 2.4 and 2.5;
4. no case with folded letters sits beside a case with exact letters; a case
   without letters, such as `^\r\n`, can sit beside either; and
5. the trie compares at most 1024 code units, with at most 1024 literals in
   all, none longer than 1024 code units, and at most 16,384 code units in all
   literals together.

```moonbit
lexmatch request {
  (re"^GET ", after=rest) => get(rest)
  (re"^(POST|PUT) ", after=rest) => post(rest)
  re"^\r\n" => end_of_headers()
  _ => other(request)
}
```

The trie gives the selected case, and the length of the match when `after` is
observed and a case has several lengths; each case body appears once. A
literal of a later case is dropped when a literal of an earlier case is a
prefix of it, since the earlier case always wins on such an input. The deepest
literal that matches is then the match, as first-match case order requires.
Coverage analysis, E0090, and E4224 are the same as with the automaton.

With this lowering the case bodies are type-checked in source order, as the
arms of a `match` are. Without an expected type, a `lexmatch` that mixes
bodies of different but compatible types, such as a string literal and a
`StringView`, can type-check differently from the same match compiled to an
automaton. Annotate the result type when the bodies mix types.

## 4. Measured effect

The following was measured on an Apple M2 Ultra running macOS 26.4, with Node
v25.8.2 for js and wasm-gc.

### 4.1 Literal sets in a single case

The baseline is the same match compiled with the table automaton, and native
code was compiled by clang 22 at `-O3`. Inputs were built at run time, half of
them matching; each figure is the median of five samples of at least 35 ms
each. The sets were the first 1 to 8 of the keywords `return`, `break`,
`continue`, `else`, `while`, `match`, `struct` and `trait` as prefix, exact and
suffix tests; 2 to 8 literals of 8 code units sharing up to 7 leading units;
and four literals of 4 to 32 code units.

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

### 4.2 Several cases

The baseline is the same `lexmatch` compiled with the table automaton, and
native code was compiled with `cc -O2`. Each figure is the best of seven runs,
in milliseconds including process start, for 30 million calls on native and
12 million on wasm-gc and js, on text targets:

| Cases | native | wasm-gc | js |
| --- | ---: | ---: | ---: |
| 8 HTTP methods | 466 → 105 | 301 → 126 | 459 → 258 |
| 3 cases of alternatives of methods | 455 → 105 | 301 → 121 | 442 → 238 |
| 8 headers, ignoring case | 773 → 161 | 530 → 163 | 793 → 317 |
| 20 headers, ignoring case | 910 → 200 | 631 → 223 | 919 → 410 |
| 60 keywords | 552 → 139 | 356 → 140 | 508 → 270 |

The compiled output was 13% to 52% smaller on every target. The same cases on
bytes targets gave similar ratios.

## 5. Bytes

A bytes regex takes the same lowerings, with one byte as one code unit. In
addition, a single literal of 1 to 32 bytes anchored with `^`, `$` or both is
compared byte by byte, as a trie of one literal, instead of with `==`,
`has_prefix`, or `has_suffix`; up to that length this was faster on every
target. A longer literal, and an unanchored one, use the `BytesView` methods of
section 2.3.

A match that uses an automaton uses a byte automaton, whose alphabet is the 256
byte values. `.` and a negated class are one byte, where a text automaton needs
separate paths for a surrogate pair.

When the input is bytes, match it with `reb"..."` rather than decoding it to a
`String` first.

## 6. What uses an automaton

In this toolchain, a match uses an automaton when any of these holds:

- it is a `lexscan`;
- a case has a pattern-level `as` binding, even when the bound text is a
  literal known in advance;
- a pattern contains a character class with more than one member, such as
  `[0-9]` or `(a|b)`, other than the two cases of one ASCII letter; `.`; a
  repetition; or an assertion other than the outer `^` and `$`, such as `\b`;
- a pattern searches for several literals, such as `(if|else)`, or searches
  ignoring case, such as `(?i:if)`;
- a pattern mixes folded and exact letters, such as `^(?i:if)x`;
- a set exceeds the limits of section 2.4;
- a `lexmatch` has several regex cases and one of them is not a literal set
  anchored with `^` only, or it has no catch-all, or it uses `with longest`,
  or it mixes folded and exact letters across cases; or
- a single-case `lexmatch` has no catch-all.

## 7. Choosing a form

To test for a fixed string, use `=~`, or a single-case `lexmatch` when the
result is not `Bool`, with an anchored literal:

```moonbit
let is_comment = line =~ re"^#"                  // prefix test
let module_name = if path =~ (re"\.mbt$", before=stem) {
  stem.to_owned()                                // has_suffix, stem by length
} else {
  path
}
let value = lexmatch token {
  (re"^0x", after=digits) => parse_hex(digits)   // prefix test
  _ => parse_decimal(token)
}
```

Anchor the pattern when a prefix, a suffix or the whole input is meant. An
unanchored pattern is a search through the input, even for one literal.

Bind the matched pieces with `before` and `after` rather than `as` when they
determine what is needed. An `as` binding makes the match use an automaton:

```moonbit
// Uses an automaton: the `as` binding.
let a = if s =~ (re"^0x" as prefix, after=digits) {
  prefix.length() + digits.length()
} else {
  0
}
// One prefix test; the prefix is "0x" anyway.
let b = if s =~ (re"^0x", after=digits) { 2 + digits.length() } else { 0 }
```

When only a few spellings can occur, list them as literal alternatives, such
as `re"^(true|false)$"`, rather than writing a pattern that also accepts other
strings, such as `re"^[a-z]+$"`, and checking the result again.

To dispatch on keywords or fixed prefixes, write one `lexmatch` with a literal
case per outcome and a catch-all (section 3) rather than a chain of `=~`
tests: the `lexmatch` reads each code unit at most once and keeps first-match
case order. A single case anchored with `$`, or one case that is not a literal
set, makes the whole `lexmatch` use an automaton, which also reads the input
once whatever the number of cases.

`s =~ re"^abc"` and `s.has_prefix("abc")` compile to an equivalent test.
Choose between them for readability; the regex form also gives `before` and
`after`.
