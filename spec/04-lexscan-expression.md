# `lexscan` Expression

## 1. Purpose

`lexscan` selects a regex case at a scanner's current cursor. A successful
regex case advances the scanner to the selected match end before evaluating the
case body.

```moonbit
lexscan scanner [with first|longest] {
  regex_case => expression
  ...
  [catch_all => fallback_expression]
}
```

It is intended for tokenization and repeated scanning. It supports both
refillable lexbufs and an in-memory mutable `StringScanner`.

## 2. Syntax and result typing

`lexscan` uses the same surface case grammar as `lexmatch`:

- a regex pattern case;
- an optional parenthesized binding tuple;
- a final binder or wildcard catch-all; and
- the default/explicit `first` or explicit `longest` strategy.

The placeholder case `...` is formal language syntax. It is equivalent to a
wildcard catch-all `_` whose body is a TODO hole expression. It is subject to
ordinary catch-all ordering and TODO-hole typing rules.

Surface syntax accepts a binder catch-all, but it is a semantic error for every
valid `lexscan` target. A conforming program uses `_ => expression` or `...`
for a `lexscan` catch-all.

All case bodies MUST type-check against one common expression result type.
Only the selected body is evaluated.

Case guards are not supported.

## 3. Valid targets

The target MUST have exactly one of these concrete types:

| Target | Mode | Refill | Cursor persists |
| --- | --- | --- | --- |
| `@lexbuf.Lexbuf` | synchronous streaming | yes | yes |
| `@lexbuf.AsyncLexbuf` | asynchronous streaming | yes | yes |
| `@lexbuf.StringScanner` | non-streaming scanner | no | yes |

`String`, `StringView`, `Bytes`, `BytesView`, numeric types, and user-defined
lexbuf-shaped types are invalid.

Direct scanning of `String` and `StringView` has migrated to `lexmatch`.
`StringScanner` is the in-memory `lexscan` target for clients that require a
persistent mutable cursor across successive expressions.

This is an intentional nominal restriction. Implementing methods with names
similar to the hidden lexbuf protocol does not make a user type a valid target.

The package `moonbitlang/core/lexbuf` MUST be a direct import of the package
containing the `lexscan` expression, unless that package is itself
`moonbitlang/core/lexbuf`. Receiving a lexbuf through another imported package
does not satisfy this requirement.

## 4. Target evaluation and scan origin

The target expression is evaluated exactly once. The scanner cursor at that
point becomes the scan origin for this expression.

The scanner object produced by that evaluation is the object whose cursor is
committed. Reassigning an outer variable that was used as the target does not
redirect an in-progress expression to a different scanner.

For `Lexbuf` and `AsyncLexbuf`, cursor positions are absolute UTF-16 code-unit
offsets in the logical stream.

For `StringScanner`, `cursor` is a UTF-16 code-unit offset relative to the
beginning of its `data : StringView`. A sliced `StringView` remains bounded by
that slice; scanning MUST NOT read outside it.

A `StringScanner` presented to `lexscan` MUST satisfy
`0 <= cursor && cursor <= data.length()`. The scanner API establishes this
invariant for initially valid scanners. Behavior for a manually constructed or
mutated scanner outside this range is not specified by this document.

The meaning of `^` is “the scan origin,” not necessarily offset zero of the
underlying full string or stream.

## 5. Required anchoring

Every `lexscan` regex case MUST be start-anchored under both strategies.

```moonbit
lexscan input {
  re"^[A-Za-z]+" as word => Word(word)
  _ => Other
}
```

An unanchored `lexscan` regex is a compile-time error even for a
`StringScanner`.

`$` refers to the end of the complete logical scanner input. A lexbuf chunk
boundary is not end of input.

## 6. Matching strategies

### 6.1 First

The default and `with first` forms use source-order first-match priority.

An earlier accepted case may commit immediately and shadow a later, longer
case:

```moonbit
lexscan scanner {
  re"^a" => Short
  re"^ab" => Long
  _ => Other
}
```

On input beginning with `"ab"`, `Short` is selected and exactly `"a"` is
consumed.

Greedy and non-greedy quantifiers are both supported in first mode.

An earlier case that reads a partial prefix but never accepts does not consume
input and does not shadow later cases. Later cases are matched from the same
scan origin, including when deciding that the earlier case failed required one
or more refills.

### 6.2 Longest

`with longest` selects the matching case whose end is farthest from the scan
origin. Source order breaks equal-length ties.

Only successful accepting paths are candidates. A case that partially matches
across buffered or refilled input and then fails does not prevent another case
from matching at the original scan origin.

The complete token length and case tie rule do not define a unique capture
decomposition when one case has several successful paths that reach the same
maximal end. In that situation, the choice among those paths is unspecified.
All captures MUST come from one single successful maximal path, and programs
MUST NOT depend on the selected decomposition. The choice may differ between
compiler versions, targets, or optimization modes.

Non-greedy quantifiers are invalid.

Longest scanning is the usual strategy for maximal-munch tokenizers.

## 7. Regex captures

Pattern-level `as` captures are supported.

- A statically single-code-point capture has type `Char`.
- Every other capture has type `StringView`.

For streaming lexbufs, the scanner retains all input required to
materialize captures across refills. A token may span any number of chunks, and
its capture is one logical `StringView` regardless of chunk boundaries. The
captured value is not required to share storage with any individual source
chunk; a cross-chunk capture may be materialized in joined storage.

`before` and `after` bindings are invalid in all `lexscan` modes and for all
three valid target types. Use an `as` capture for consumed token text. The
scanner state represents the remaining input.

## 8. Successful regex case

When a regex case is selected, the expression MUST perform these observable
steps:

1. materialize all captures needed by the case body;
2. commit the scanner cursor to the selected match end; and
3. evaluate the selected case body.

Therefore, recursive or subsequent `lexscan` calls made by the body begin after
the consumed token.

These steps do not reserve ownership of the scanner state after the body
begins. In particular, a selected `StringScanner` body may explicitly mutate
its public `cursor`; that mutation occurs after the automatic commit and is not
overwritten when the expression returns.

For `StringScanner`, the stored cursor is updated to the match end relative to
`data`.

If the target expression constructs a temporary `StringScanner`, or its `data`
view is backed by a temporary `String`, a capture returned from the selected
body remains valid for as long as that capture remains reachable.

For `Lexbuf` and `AsyncLexbuf`, committing also ends the retention window and
allows earlier chunks to be released when the buffer is next compacted.
Cursor positions remain absolute logical-stream offsets across any such
compaction.

## 9. Refill and end of input

### 9.1 `Lexbuf`

`Lexbuf` obtains chunks from `() -> String?`.

- `Some(nonempty_chunk)` appends more UTF-16 input.
- `Some("")` is ignored and the source is queried again.
- `None` marks end of input.

Any finite run of empty chunks before, between, or after nonempty chunks has no
effect on the logical input. In particular, an end-anchored case continues
through trailing empty chunks until `None` establishes true EOF.

When the scan cursor reaches the buffered end and EOF is not known, scanning
refills and continues. A pattern may cross chunk boundaries.

The selected case, captures, committed cursor, and EOF behavior are observable.
The exact number and timing of source callback invocations and the amount of
buffered read-ahead are unspecified. An implementation may read beyond the end
of the ultimately selected token, provided this does not change those logical
results. Restoring or retaining the logical cursor does not undo callback side
effects that already occurred.

### 9.2 `AsyncLexbuf`

`AsyncLexbuf` has the same semantics, with an `async () -> String?` source and
an asynchronous refill operation. The unspecified callback-count and read-ahead
rules above apply equally to asynchronous refills.

An expression that may call the async refill protocol must occur in an async
typing context. There is no separate `await` syntax at the `lexscan` site.

### 9.3 `StringScanner`

`StringScanner` never refills. Its logical end is `data.length()` relative to
the view, and it may be passed to successive `lexscan` expressions.

If establishing an end assertion or rejecting a longer candidate requires
read-ahead through additional chunks, a later overall failure still restores
the logical cursor to the scan origin. Empty chunks encountered during that
read-ahead have the same no-op meaning as elsewhere. Source callback side
effects that already occurred remain subject to the unspecified read-ahead
rule above.

## 10. Catch-all behavior

A `lexscan` catch-all MUST be written `_ => expression` or as the equivalent
placeholder case `...`. A bare binder catch-all is invalid.

It is selected when the scan reaches the implicit failure state without any
accepted regex candidate. This includes:

- a current input character for which no regex can begin; and
- end of input when no regex case accepts EOF or an empty match there.

The catch-all does not consume input and leaves the cursor at the scan origin.

Consequences:

- repeated calls on the same unmatched character select the catch-all again;
- a caller that wants recovery must explicitly change its control flow or use a
  regex such as `re"^."` to consume one scalar value; and
- the same catch-all can serve as an EOF branch, but it cannot distinguish EOF
  from an unmatched character solely through a bound remainder.

A binder catch-all is invalid because no matched substring is defined for this
branch and streaming input may not have a materialized complete remainder.

A wildcard catch-all may be the only case. Such an expression evaluates the
catch-all body immediately and leaves the cursor unchanged; it does not need to
refill because there is no regex candidate to investigate.

## 11. Exhaustiveness and unreachable cases

As with `lexmatch`, the compiler performs exhaustiveness and reachability
analysis.

- If the implicit catch-all is reachable and no catch-all body exists, E4224
  is emitted with a shortest UTF-16 witness.
- If the implicit catch-all is unreachable, it may be omitted.
- A written but unreachable catch-all emits E0090.
- A regex case that can never be selected emits E0090.

Unreachable regex-case and catch-all bodies are still type-checked.

The analysis includes EOF. A set of cases that covers all ordinary characters
but not EOF is not exhaustive unless some case accepts EOF or an empty match at
EOF.

## 12. Empty matches and progress

A zero-length regex case succeeds without advancing the cursor.

```moonbit
lexscan scanner {
  re"^" => Empty
  _ => Other
}
```

After selecting `Empty`, the scanner cursor is unchanged. The language does not
enforce a progress invariant. A recursive scanner whose selected case can
always match empty input may recurse forever.

An empty successful match does not produce a progress warning, and the scanner
does not implicitly consume or skip one scalar value. Progress remains under
program control.

A catch-all case is not mandatory when the regex cases are exhaustive. In a
scanner loop, an explicit end-of-input case can therefore terminate the loop
without relying on catch-all behavior:

```moonbit
while true {
  lexscan scanner {
    re"^$" => break
    re"^[[:space:]]+" => continue
    re"^." => continue
  }
}
```

Here `re"^$"` is a successful zero-length match only at logical end of input.
It leaves the cursor unchanged and transfers control through the written body.
The other cases cover non-empty input, so no catch-all is required.

## 13. Examples

### 13.1 Synchronous token scanner

```moonbit
enum Token {
  Word(StringView)
  Integer(StringView)
  Punctuation(Char)
  Eof
}

fn next_token(input : @lexbuf.Lexbuf) -> Token {
  lexscan input with longest {
    re"^[[:space:]]+" => next_token(input)
    (re"^[[:alpha:]]+" as word) => Word(word)
    (re"^[[:digit:]]+" as digits) => Integer(digits)
    (re"^." as mark) => Punctuation(mark)
    _ => Eof
  }
}
```

### 13.2 Mutable in-memory scanner

```moonbit
fn next_piece(scanner : @lexbuf.StringScanner) -> String {
  lexscan scanner {
    (re"^[a-z]+" as word) => "word:\{word}"
    re"^[0-9]+" => "integer"
    _ => "other"
  }
}

fn demo {
  let scanner = @lexbuf.StringScanner::{ data: "abc123"[:], cursor: 0 }
  let first = next_piece(scanner)   // "word:abc", cursor == 3
  let second = next_piece(scanner)  // "integer", cursor == 6
}
```
