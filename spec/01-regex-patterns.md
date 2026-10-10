# Regex Patterns and Matching Model

## 1. Overview

The right-hand side of `=~` and every regex case of `lexmatch` or `lexscan`
uses a regex pattern. This is a compile-time pattern language whose atoms are
regex literals and regex constants.

The grammar below is descriptive. Parentheses may be inserted wherever needed
to resolve grouping.

```text
regex-pattern     ::= regex-alternation
                    | regex-atom "as" binder
regex-alternation ::= regex-sequence ("|" regex-sequence)*
regex-sequence    ::= regex-atom ("+" regex-atom)*
regex-atom        ::= REGEX_LITERAL
                    | qualified-constant-name
                    | "(" regex-pattern ")"
```

In source code, `REGEX_LITERAL` is written `re"..."`.

At pattern level, `+` binds more tightly than `|`. The `as` form is more
restricted than an ordinary infix or postfix operator: it may follow only one
regex atom, where a parenthesized complete pattern counts as an atom. An alias
that participates in a sequence or alternation must therefore be parenthesized.

```moonbit
(re"a" as first) + re"b"       // capture only "a"
(re"a" + re"b") as both       // capture "ab"
```

Nested parentheses allow captures at several sequence positions.

## 2. Regex literals and constants

### 2.1 Literal syntax

A regex literal is written `re"source"` and has first-class type `Regex` in an
ordinary expression context. `Regex` is re-exported by the prelude, so using
the type or a regex literal does not require a direct
`moonbitlang/core/string` import.

Regex literals use regex escaping directly. Backslashes are not subject to the
double escaping required by ordinary MoonBit string literals.

```moonbit
let slash_star = re"/\*"
let newline = re"\n"
let unicode = re"\u{1f600}"
```

Regex interpolation is not part of the accepted expression or pattern syntax.
In particular, the surface lexer treats `\{` as the start of interpolation, so
it cannot be used as an escape for a literal left brace in `re"..."`.

### 2.2 Constant references

A regex pattern MAY refer to an unqualified or package-qualified constant.
The referenced declaration MUST resolve to a compile-time constant whose value
is a `Regex`.

```moonbit
const IDENT_START = re"[A-Za-z_]"
const IDENT_CONT = re"[A-Za-z0-9_]*"

fn is_ident(text : String) -> Bool {
  text =~ (re"^" + IDENT_START + IDENT_CONT + re"$")
}
```

A local variable of type `Regex` is not a regex-pattern atom. The syntax in
pattern position resolves an identifier as a constant, not as an arbitrary
runtime value.

A referenced constant may itself be defined by a compile-time expression that
uses the regex `+` or `|` intrinsics. A type annotation may be required by
ordinary constant inference. At the use site, the composed constant is still
one regex-pattern atom.

```moonbit
const LETTER = re"[A-Za-z]"
const DIGIT = re"[0-9]"
const ALNUM : Regex = LETTER | DIGIT
const PAIR : Regex = LETTER + DIGIT
```

### 2.3 Captures inside referenced constants

Named and anonymous capture groups contained inside a referenced regex constant
retain their grouping and matching behavior, but their capture metadata is
removed when the constant is used as a regex pattern. They do not introduce
MoonBit binders, and a hidden named group does not place its name in scope.

Pattern-level `as` around the constant reference binds the complete text matched
by that constant, not any hidden subgroup. Only capture metadata is removed;
other regex properties, including greediness, remain effective.

## 3. Regex literal language

### 3.1 Atoms

The following atoms are supported:

| Form | Meaning |
| --- | --- |
| ordinary scalar value | matches itself |
| `.` | any one Unicode scalar value, including newline |
| `[abc]` | one member of the class |
| `[^abc]` | one code point outside the class |
| `[a-z]` | one code point in the inclusive range |
| `(...)` | anonymous capture group in a first-class `Regex`; grouping only in a regex pattern |
| `(?:...)` | non-capturing group |
| `(?<name>...)` | named capture in a first-class `Regex`; invalid directly inside a regex pattern |
| `(?i:...)` | ASCII case-insensitive scoped group |
| `^` | beginning of logical input |
| `$` | end of logical input |

The case-insensitive modifier folds only ASCII `A`-`Z` and `a`-`z`. It is not
full Unicode case folding.

### 3.2 Alternation and concatenation

Inside a regex literal, juxtaposition concatenates terms and `|` separates
alternatives. Alternation has lower precedence than concatenation.

```moonbit
re"ab|cd"       // (ab) | (cd)
re"a(b|c)d"     // abd | acd
```

An alternative may be empty. For example, `re"a|"` contains an `"a"`
alternative and an empty alternative, and `re"()"` is an empty anonymous
group. Under first-match semantics, the earlier alternative still has
priority when both can lead to a successful match.

At the MoonBit pattern level, `+` and `|` combine regex constants using the
same semantic operations:

```moonbit
(re"ab" + re"cd")
(re"ab" | re"cd")
```

### 3.3 Quantifiers

The following greedy quantifiers are supported:

| Form | Repetition count |
| --- | --- |
| `x*` | zero or more |
| `x+` | one or more |
| `x?` | zero or one |
| `x{n}` | exactly `n` |
| `x{n,}` | at least `n` |
| `x{n,m}` | between `n` and `m`, inclusive |

The operand `x` MUST be a regex atom or group. A direct zero-width assertion
`^` or `$` is not a valid quantifier operand, so `^+`, `$?`, and similar forms
are invalid. A group is a valid operand even when its contents are zero-width;
therefore grouped forms such as `(^){2}`, `(?:^)+`, and `(?i:^)?` are valid.
Repeating such a group still consumes no input. As with every nullable
repetition, evaluation MUST terminate without inventing input progress.

The language does not define 256 as a maximum repetition bound. An
implementation may impose ordinary compilation resource limits, but such a
limit is not part of regex matching semantics. For a bounded repetition, `n`
MUST NOT exceed `m`.

Appending `?` produces the non-greedy form: `*?`, `+?`, `??`, `{n}?`,
`{n,}?`, or `{n,m}?`.

Non-greedy quantifiers are valid with first-match semantics, including `=~`,
ordinary first-class `Regex` values, `lexmatch`, and `lexscan` with the default
or explicit `first` strategy. They are invalid in a pattern compiled with the
`longest` strategy, including when the non-greedy quantifier is hidden in a
referenced regex constant.

### 3.4 Character classes

Character classes support scalar literals, inclusive ranges, union by
juxtaposition, negation with a leading `^`, escapes, and these POSIX classes:

| Class | Set |
| --- | --- |
| `[[:ascii:]]` | U+0000 through U+007F |
| `[[:upper:]]` | ASCII `A`-`Z` |
| `[[:lower:]]` | ASCII `a`-`z` |
| `[[:alpha:]]` | ASCII letters |
| `[[:alnum:]]` | ASCII letters and digits |
| `[[:digit:]]` | ASCII `0`-`9` |
| `[[:xdigit:]]` | ASCII hexadecimal digits |
| `[[:blank:]]` | tab and space |
| `[[:space:]]` | tab, newline, vertical tab, form feed, carriage return, and space |
| `[[:word:]]` | ASCII letters, digits, and underscore |

POSIX classes are ASCII-based. For example, `[[:alpha:]]` does not match `é`
or a CJK character.

A POSIX class MUST occur inside an outer character class. `[:digit:]` is
invalid; `[[:digit:]]` is valid.

The empty class `[]` matches no scalar value. Its negation `[^]` matches any
scalar value.

The shorthand escapes `\d`, `\D`, `\s`, `\S`, `\w`, and `\W` are currently
accepted but emit warning E0027 (`deprecated_syntax`). Their replacements are
the corresponding POSIX classes and negated POSIX classes.

Within a character class, `-` starts a range. A literal hyphen MUST be written
`\-`. Placing an unescaped hyphen at the beginning or end of a class is invalid.
Other supported regex-punctuation escapes remain literal class atoms. For
example, `[\[]`, `[\]]`, and `[\\]` match a left bracket, right bracket, and
backslash respectively. A colon is ordinary unless it participates in the
complete `[:name:]` syntax of a POSIX class.

### 3.5 Escapes

Supported character escapes include:

- `\f`, `\n`, `\r`, `\t`, and `\v`;
- `\cA` through `\cZ` and their lowercase forms for control characters;
- `\0` when used as a character-class escape and not followed by a decimal
  digit; outside a character class, `\0` is parsed as an unsupported numeric
  backreference;
- `\xHH` with exactly two hexadecimal digits;
- `\uHHHH` with exactly four hexadecimal digits;
- `\u{H...}` for a scalar value no greater than U+10FFFF; and
- escapes for regex punctuation such as `^ $ \\ . * + ? ( ) [ ] } | / "`.

An escape of an otherwise ordinary character is invalid. A literal `{` MUST be
written `[{]`; `\{` begins MoonBit regex interpolation rather than denoting a
regex escape. `[}]` is the unambiguous spelling for a literal `}`. These are
intentional MoonBit surface-syntax rules rather than compatibility aliases for
another regex dialect.

Regex interpolation is not a supported expression or pattern feature. If
`\{` is followed by source that forms an interpolation, the resulting
interpolated-regex token is rejected rather than evaluating that source to
construct a regex dynamically.

Inside a character class, `\b` denotes backspace and `\-` denotes a literal
hyphen.

A Unicode escape sequence MUST NOT denote an isolated value in the surrogate
range U+D800 through U+DFFF because such a value is not a Unicode scalar value.
A well-formed high-surrogate/low-surrogate pair, and the equivalent scalar-value
escape such as `\u{1f600}`, denote one non-BMP scalar value.

### 3.6 Unsupported constructs

The following constructs are rejected by the current regex parser:

- word-boundary and non-word-boundary assertions `\b` and `\B` outside a
  character class;
- numeric and named backreferences;
- positive or negative lookahead;
- positive or negative lookbehind;
- character-class set expressions; and
- ranges whose endpoints are character sets rather than individual scalar
  values.

### 3.7 Semantic anchoring

Start and end anchoring are properties of the complete compiled regex, not
textual checks for the first or last character of a literal.

A regex is semantically start-anchored according to these rules:

- `^` is start-anchored; ordinary characters, the empty regex, and `$` are not;
- a concatenation is start-anchored if any constituent is start-anchored;
- an alternation is start-anchored only if every alternative is start-anchored;
- a repetition is start-anchored only if its minimum count is positive and its
  repeated regex is start-anchored; and
- captures preserve the anchoring property of their contents.

End anchoring is defined symmetrically using `$`: a concatenation is
end-anchored if any constituent is end-anchored, an alternation only if every
alternative is end-anchored, and a repetition only if its minimum count is
positive and its repeated regex is end-anchored.

Consequently, an anchor may be introduced by a referenced constant or a nested
group. For example, a constant containing `^` remains start-anchored when it is
concatenated with another pattern. Quantifying the anchor itself is invalid and
is not a way to establish anchoring.

## 4. Pattern-level capture with `as`

`pattern as name` binds the substring consumed by `pattern`.

```moonbit
if (text =~ ((re"[A-Za-z]+" as word), before=_, after=_)) {
  consume(word)
}
```

The parentheses around an alias are often syntactically necessary when the
alias participates in `+`, `|`, or a binding tuple.

### 4.1 Capture type

The type of an `as` binder is determined statically:

- `Char` if the captured regex is known to match exactly one Unicode scalar
  value; or
- `StringView` otherwise.

Examples of `Char` captures include `re"." as ch`, `re"[abc]" as ch`, and a
one-character alternation whose alternatives are all one scalar value. An
exact-one repetition such as `re"a{1}"` and a referenced constant known to
match one scalar value are also `Char` captures. A nullable or mixed-width
alternative is `StringView`, even when a particular run consumes one scalar.

Anchors and other zero-width terms do not by themselves prevent a capture from
being a `Char`. For example, `re"^.$" as ch` has type `Char`.

### 4.2 Capture restrictions

Binder names within one regex pattern MUST be pairwise distinct. They also MUST
be distinct from `before` and `after` binder names in the surrounding match.

An alias MUST NOT occur inside either branch of a pattern-level alternation,
because the binder would not be defined by every alternative.

```moonbit
// Invalid
text =~ ((re"a" as left) | re"b")

// Valid
text =~ ((re"a" | re"b") as either)
```

Aliases inside sequences and nested aliases are allowed when all binder names
are distinct.

### 4.3 Captures written inside `re"..."`

When a regex literal appears directly in a regex pattern, all anonymous groups
are treated only as grouping and their capture metadata is removed.

A named group such as `re"(?<word>[a-z]+)"` is a compile-time error in direct
pattern use. It MUST be replaced with pattern-level `as`, for example:

```moonbit
(re"[a-z]+" as word)
```

When a named or anonymous group occurs inside a referenced regex constant, its
capture metadata is removed as specified in Section 2.3. The named group is not
an error at the reference site and does not introduce a MoonBit binder.

Before that metadata is removed, first-class `Regex` capture participation has
the usual path meaning: a group that does not participate in the selected path
is absent, while a group repeated several times denotes its final participating
iteration. These details remain observable through the runtime `Regex` value
itself, but not through a pattern reference after capture stripping.

## 5. First-match semantics

The first-match strategy is leftmost-first with ordered alternatives.

For a single regex:

1. the earliest possible start position wins;
2. at that position, alternation order and quantifier greediness determine the
   selected path;
3. greedy quantifiers prefer more repetitions when that still permits the rest
   of the regex to match; and
4. non-greedy quantifiers prefer fewer repetitions when that still permits the
   rest of the regex to match.

These priorities select among successful complete paths; they do not commit to
a path that later fails. If an earlier alternative or a preferred repetition
count cannot satisfy the remaining suffix, matching MUST retry the next
permitted alternative or repetition count. Any exposed captures describe the
eventual successful path, not an abandoned attempt.

For several lexical cases under the `first` strategy, source case order has
priority. Cases are considered from top to bottom, and the first case whose
regex has any successful match is selected. The selected case then applies the
single-regex rules above: its earliest match start wins, followed by ordered
alternatives and quantifier greediness.

Repetition of an empty or nullable group is permitted. It must terminate, and
it does not create input progress beyond the scalar values actually consumed.

Examples:

```moonbit
lexmatch "ab" {
  (re"^a", after=_) => "earlier-shorter"
  (re"^ab", after=_) => "later-longer"
  _ => "none"
}
// => "earlier-shorter"

lexmatch "ba" {
  (re"a", before=_, after=_) => "a"
  (re"b", before=_, after=_) => "b"
  _ => "none"
}
// => "a"

lexmatch "ab" {
  (re"^(a|ab)" as x, after=_) => x
  _ => ""
}
// x == "a"
```

### 5.1 Nullable repetition priority

A nullable operand can match without consuming a scalar. Its unbounded
repetition uses ordered-automaton priority, including the match end and all
captures. The following conceptual construction defines that priority; an
implementation MAY use any representation that selects the same result.

- Alternatives are explored from left to right.
- A greedy repeat/exit choice explores the repeat edge first. A non-greedy
  choice explores the exit edge first.
- `R+` enters one mandatory copy of `R`, then reaches its repeat/exit choice.
- If `R` is nullable, `R*` is constructed as `(R+)?`; `R*?` is constructed as
  `(R+?)??`. The inner and outer operators both preserve the written mode.
- For `n >= 1`, `R{n,}` consists of `n - 1` mandatory copies followed by
  `R+`; `R{n,}?` uses `R+?` for the last part. `R{0,}` and `R{0,}?` use the
  corresponding star construction.
- Finite bounds consist of separate mandatory copies and a finite chain of
  ordered optional copies. Their control points are distinct, even if two
  copies have identical contents.

At each input position, empty transitions are explored in priority order. Each
control point is entered at most once at that position. The first arrival
keeps its capture state; later arrivals at that same control point and position
are discarded. Consuming a scalar creates a new input position with a fresh
set of entered control points. This suppresses empty cycles without adding
input progress or moving lower-priority paths ahead of remaining preferred
paths.

Reaching an empty iteration does not universally force an immediate exit or
replace the last captured iteration with an empty capture. A continuation
which fails still leaves the other permitted paths available. Captures belong
to the selected complete path after the control-point rule above is applied.
These rules apply equally to `=~`, `lexmatch`, `lexscan` with `first`, and
first-class `Regex` execution. `longest` retains Section 6's separate contract.

For example:

| Pattern | Input | Match | Remaining input | Captures |
| --- | --- | --- | --- | --- |
| `^(?:\|a)*` | `aa` | empty | `aa` | none |
| `^(?:a\|)*` | `aa!` | `aa` | `!` | none |
| `^(?:a*?b*?)*a` | `baaa` | `baa` | `a` | none |
| `^(?<body>(?<item>a*?b*?))*(?<tail>a)` | `baaa` | `baa` | `a` | `body`, `item`, and `tail` are `a` |
| `^(?<item>a?)*$` | `a` | `a` | empty | `item` is `a` |
| `^(?:(?<item>a*?b*?)*a){2}` | `baaaa` | `baaa` | `a` | `item` is empty |

In the last example, the final empty capture belongs to a distinct finite copy;
it is not suppressed as another arrival at the first copy's control point.
The policy is the one used for nullable repetition by Go's `regexp` package,
but it does not adopt unrelated Go syntax, Unicode, or longest-match behavior.
The reference construction and closure order can be inspected in Go's
[regexp compiler](https://go.dev/src/regexp/syntax/compile.go) and
[regexp execution](https://go.dev/src/regexp/exec.go).

## 6. Longest-match semantics

The longest strategy is maximal munch from the beginning of the logical input.
Every participating regex is required to be start-anchored.

The selected case is the one whose match end is farthest from the starting
position. If several cases consume the same number of UTF-16 code units, the
earliest case in source order wins.

```moonbit
lexmatch "ab" with longest {
  (re"^a", after=_) => "short"
  (re"^ab", after=_) => "long"
  _ => "none"
}
// => "long"
```

If the selected case has several successful paths that reach the same maximal
end, the choice among those paths is unspecified. All captures MUST
collectively correspond to one such path; an implementation MUST NOT combine
capture endpoints from different paths. Programs MUST NOT depend on which
coherent maximal-path decomposition is chosen.

Longest-match selection compares complete case matches. It does not change the
meaning of `$`: a case ending in `$` still matches only at the logical end of
input.

## 7. Empty matches

Regexes may match the empty string, including `re""`, `re"^"`, `re"$"`, and
nullable repetitions.

An empty match is a successful match whose start and end offsets are equal. In
`lexscan`, selecting such a case leaves the scanner cursor unchanged. Repeated
scanning with an always-empty successful case can therefore fail to make
progress; the language does not add an implicit one-character advance.
