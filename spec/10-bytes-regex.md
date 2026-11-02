# Bytes Regex Patterns

## 1. Overview

A bytes regex literal `reb"..."` matches `Bytes` and `BytesView` in regex
match expressions (`=~`) and `lexmatch`, as `re"..."` matches `String` and
`StringView`:

```moonbit
if line =~ reb"^(GET|POST|PUT) " {
  ...
}

lexmatch header {
  (reb"^Content-Length: " + (reb"[0-9]+" as n), after=rest) => ...
  _ => ...
}
```

Its atoms are bytes, not Unicode scalar values. There is no encoding: a bytes
regex never decodes UTF-8 or any other encoding, and its input domain is every
sequence of bytes.

Everything this chapter does not state is as specified for text regexes in
[Regex Patterns and Matching Model](01-regex-patterns.md),
[Regex Match Expression](02-regex-match-expression.md) and
[`lexmatch` Expression](03-lexmatch-expression.md), reading "byte" for
"scalar value" and "UTF-16 code unit".

## 2. Literal syntax

```text
bytes-regex-literal ::= 'reb"' regex-body '"'
```

`reb"` is one token, as `re"` is. `reb` not immediately followed by `"` is an
ordinary identifier, so `re b"x"`, with a space, is the identifier `re`
followed by the bytes literal `b"x"`.

The body is read as the body of `re"..."` is: it is raw, a backslash and the
character after it are kept together, so the body ends at the first `"` that
does not follow an unpaired backslash (`reb"\\"` is the one escaped
backslash), it cannot contain a line break, and no escape is processed before
the regex parser reads it. Interpolation is not accepted:
`\{` is rejected as it is in `re"..."`. Write a literal left brace as `[{]`.

In an ordinary expression, `reb"..."` has type `BytesRegex`. `BytesRegex` is
re-exported by the prelude, so neither the type, a bytes regex literal, nor a
match on bytes requires a direct `moonbitlang/core/bytes` import.

## 3. Bytes pattern language

The body of `reb"..."` uses the regex language of section 3 of
[Regex Patterns and Matching Model](01-regex-patterns.md#3-regex-literal-language),
read over bytes, with these differences:

| Form | In `re"..."` | In `reb"..."` |
| --- | --- | --- |
| ordinary character | that scalar value | that byte; the character MUST be ASCII |
| `.` | any scalar value, including newline | any byte `0x00` to `0xFF`, including newline |
| `[^...]` | any scalar value outside the class | any byte outside the class, `0x80` to `0xFF` included |
| `[]`, `[^]` | no scalar value, any scalar value | no byte, any byte |
| `\xHH` | invalid | the byte `0xHH`, also in classes and as a range endpoint |
| `\uHHHH`, `\u{H...}` | that scalar value | invalid |
| non-ASCII character in the body | that scalar value | invalid |
| `[[:ascii:]]` | U+0000 through U+007F | bytes `0x00` through `0x7F` |
| `(?i:...)` | folds ASCII letters | folds ASCII letters; a byte above `0x7F` is never folded |
| `\b`, `\B`, `[[:word:]]` | ASCII word characters | ASCII word bytes; every byte above `0x7F` is a non-word byte |

`\xHH` takes exactly two hexadecimal digits, in either case: `\xff` and `\xFF`
are the same byte. A range compares byte values, so `[\x80-\xff]` is the bytes
`0x80` through `0xFF` and `[\x80-\x7f]` is a descending range.

All other forms are the same: the escapes `\f \n \r \t \v`, `[\b]` and the
escaped punctuation denote the corresponding ASCII bytes; groups, quantifiers,
anchors, the other POSIX classes, and the rules for classes, hyphens, colons
and `&&` are unchanged. The control escape `\cX`, the NUL escape `\0` and the
shorthand class escapes `\d`, `\D`, `\s`, `\S`, `\w` and `\W` remain invalid;
write `\x01`, `\x00` or a POSIX class instead.

An invalid bytes pattern is rejected with E4172, as an invalid text pattern
is.

```moonbit
reb"^GET /"                  // the bytes G E T space /
reb"\xef\xbb\xbf"            // a UTF-8 byte order mark
reb"[\x80-\xff]+"            // a run of bytes above 0x7F
reb"(?i:content-length): "   // ASCII case-insensitive
reb"é"                       // E4172: write \xc3\xa9
reb"\u{e9}"                  // E4172: a Unicode escape
```

## 4. Regex kinds

Every regex atom of a pattern has a kind:

- **text**: a `re"..."` literal or a constant of type `Regex`;
- **bytes**: a `reb"..."` literal or a constant of type `BytesRegex`.

A `BytesRegex` constant is a pattern atom under the rules of section 2.2 of
[Regex Patterns and Matching Model](01-regex-patterns.md#22-constant-references):
it may be qualified, and it may be defined with the `+` and `|` intrinsics of
two bytes regexes.

```moonbit
const HIGH = reb"[\x80-\xff]"
const HIGH_THEN_A : BytesRegex = HIGH + reb"a"
const X_OR_Y : BytesRegex = reb"x" | reb"y"
```

The kind of every atom MUST agree with the target: text for `String` and
`StringView`, bytes for `Bytes` and `BytesView`. Consequently, all atoms of one
`=~` pattern, and all regex cases of one `lexmatch`, have one kind. Each atom
whose kind disagrees with the target is rejected with E4234; the message names
the literal to use.

```moonbit
fn f(data : Bytes, text : String) -> Unit {
  data =~ re"a"               // E4234: use reb"..."
  text =~ reb"a"              // E4234: use re"..."
  data =~ (reb"a" + re"b")    // E4234 at re"b"
}
```

## 5. Targets

### 5.1 `=~` and `lexmatch`

`=~` and `lexmatch` accept a target of type `Bytes` or `BytesView` with bytes
patterns. A `Bytes` target is viewed as a `BytesView`. For a sliced
`BytesView`, the input is the slice: `^`, `$`, `\b`, `before`, captures,
`after` and a binder catch-all are all bounded by it.

Other target types remain invalid: E4014 for `=~` and E4222 for `lexmatch`,
including `Array[Byte]` and `FixedArray[Byte]`.

### 5.2 `lexscan`

`lexscan` targets are text scanners. A bytes regex in a `lexscan` case is
rejected with E4234. There is no bytes scanner target.

## 6. Matching

Matching follows sections 5 to 7 of
[Regex Patterns and Matching Model](01-regex-patterns.md#5-first-match-semantics)
with bytes as the unit:

- `=~` and a first-strategy `lexmatch` are leftmost-first with ordered
  alternatives and source-order case priority;
- `lexmatch ... with longest` selects the case consuming the most bytes, ties
  going to the earlier case; every case MUST be start-anchored (E4218), and
  non-greedy quantifiers are invalid (E4172);
- `^` and `$` denote the beginning and end of the target, and semantic
  anchoring is as in section 3.7 of that chapter;
- `\b` holds where exactly one of the bytes before and after the position is
  a word byte, the ends of the input counting as non-word bytes; and
- an empty match is a normal successful match.

A byte above `0x7F` is a byte like any other. `.` matches the first byte of a
multi-byte UTF-8 sequence, not the whole sequence:

```moonbit
if b"\xc3\xa9" =~ (reb"^." as first, after=rest) {
  // first == b'\xc3'
  // rest  == the one byte 0xa9
}
```

## 7. Bindings

The type of a pattern-level `as` binder is determined statically:

- `Byte` if the captured regex is known to match exactly one byte; or
- `BytesView` otherwise.

The rules of section 4.1 of
[Regex Patterns and Matching Model](01-regex-patterns.md#41-capture-type) apply
with "byte" for "scalar value": `reb"." as b`, `reb"[\x80-\xff]" as b` and
`reb"^.$" as b` are `Byte` captures, and a nullable or mixed-width regex is a
`BytesView` capture.

`before` and `after` have type `BytesView`. A `lexmatch` binder catch-all
receives the complete target as a `BytesView`.

All other binding rules are unchanged: the restrictions of section 4.2 of that
chapter, E0080 and E0081 for a `lexmatch` case that leaves its unmatched
prefix or suffix implicit, the label and duplicate rules of `=~`, and the
boolean flow of its binders.

## 8. Exhaustiveness and reachability

Exhaustiveness analysis of a bytes `lexmatch` is over sequences of bytes. When
an input reaches a missing catch-all, E4224 reports a shortest counterexample
written as bytes, with `\xHH` for bytes outside printable ASCII:

```moonbit
lexmatch data {
  reb"^[\x00-\xfe]" => 1
  reb"^$" => 2
} // E4224: the input "\xFF" reaches the implicit catch-all
```

A bytes regex can cover every input on its own: `reb"^[\x00-\xff]*$"` and
`reb"^.*$"` are exhaustive. E0090 reports an unreachable bytes case or
catch-all as it does for text.
