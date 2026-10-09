# Conformance Coverage Matrix

## 1. Purpose

This matrix defines the scope of the executable spec test suite. The test names
and diagnostic fixtures contain these IDs, and `scripts/check_coverage_ids.sh`
checks that every row is represented.

Each row identifies one independently testable requirement. The suite gives
every row at least one positive or negative test as appropriate and adds
cross-product cases where interactions are likely to hide defects.

Priority labels:

- **P0**: fundamental syntax, observable semantics, or safety;
- **P1**: required edge case or dedicated diagnostic;
- **P2**: secondary compatibility, formatting, or regression coverage.

## 2. Shared regex syntax

| ID | Priority | Requirement | Expected test kind |
| --- | --- | --- | --- |
| RX-001 | P0 | literal scalar values and concatenation | runtime |
| RX-001A | P1 | unterminated and newline-containing regex literals are rejected by the surface syntax | parse negative |
| RX-002 | P0 | `.` matches one ASCII scalar value and newline | runtime |
| RX-003 | P0 | `.` matches one non-BMP scalar value and captures `Char` | runtime + typing |
| RX-004 | P0 | alternation order under first match | runtime |
| RX-004A | P1 | empty alternatives and empty groups | runtime |
| RX-005 | P0 | `+` concatenates regex constants | typing + runtime |
| RX-006 | P0 | `|` alternates regex constants | typing + runtime |
| RX-006A | P1 | a regex constant may itself be defined by compile-time `+` or `|` composition and then referenced as one pattern atom | typing + runtime |
| RX-007 | P0 | unqualified regex constant reference | typing + runtime |
| RX-008 | P1 | qualified regex constant reference | typing + runtime |
| RX-009 | P0 | local runtime `Regex` is not a pattern constant | negative typing |
| RX-010 | P0 | non-`Regex` constant in pattern position | E4014 |
| RX-011 | P0 | unbound constant reference | E4022 |
| RX-011A | P1 | `Regex` and regex literals are available through the prelude without a direct `moonbitlang/core/string` import | typing |
| RX-012 | P0 | `*`, `+`, `?`, `{n}`, `{n,}`, `{n,m}` | runtime |
| RX-012A | P1 | quantifiers apply to literals, classes, and groups; greedy paths backtrack when required; zero bounds and leading-zero counts are accepted | runtime |
| RX-012B | P1 | repetition of empty and nullable groups terminates and preserves first-match greediness without inventing progress | runtime |
| RX-014 | P1 | a quantifier without an operand, a repeated quantifier, and malformed bounded-quantifier spellings are rejected | E4172 |
| RX-014A | P1 | stray regex metacharacters that cannot begin an atom are rejected | E4172 |
| RX-015 | P1 | minimum greater than maximum rejected | E4172 |
| RX-016 | P0 | greedy and non-greedy captures differ in first mode | runtime |
| RX-016A | P1 | ordered alternatives and greedy or non-greedy repetitions retry later paths or repetition counts when the preferred path cannot satisfy the remaining suffix, and captures describe the final successful path | runtime |
| RX-017 | P0 | every non-greedy quantifier spelling is rejected in longest-mode `lexmatch` and `lexscan` patterns | E4172 |
| RX-018 | P0 | a referenced constant containing a non-greedy quantifier is rejected in longest-mode `lexmatch` and `lexscan` patterns | E4172 |
| RX-019 | P0 | `^` and `$` match logical input boundaries | runtime |
| RX-020 | P1 | anchors are not multiline | runtime |
| RX-020A | P1 | `^` and `$` assert their exact positions even when written inside a concatenation rather than at its textual edges | runtime |
| RX-021 | P0 | positive and negated character classes | runtime |
| RX-021A | P1 | `[]` is empty and `[^]` is the full scalar-value set | runtime |
| RX-022 | P0 | scalar ranges, including non-ASCII ranges | runtime |
| RX-022A | P1 | a literal colon can start a scalar range; its endpoints and interior match, while escaping the hyphen instead makes it a literal class atom | runtime |
| RX-023 | P1 | descending range rejected | E4172 |
| RX-024 | P1 | class-set endpoint range rejected | E4172 |
| RX-024A | P1 | a scalar range crossing the surrogate interval contains only valid scalar values at and outside the interval | runtime |
| RX-025 | P0 | all supported POSIX classes | runtime |
| RX-025A | P1 | character-class union, negated POSIX classes, non-leading caret, literal colon, backspace, and escaped hyphen positions | runtime |
| RX-025B | P1 | regex punctuation that is legal as a class atom, including escaped brackets, backslash, anchors, grouping punctuation, quantifier punctuation, alternation, slash, and quote, matches literally inside a class | runtime |
| RX-026 | P0 | POSIX classes are ASCII-only | runtime |
| RX-027 | P1 | bare POSIX class rejected | E4172 |
| RX-028 | P1 | unsupported POSIX class rejected | E4172 |
| RX-028A | P1 | an unclosed POSIX character class is rejected | E4172 |
| RX-029 | P1 | `\d`/`\s`/`\w` families accepted with E0027 | warning + runtime |
| RX-030 | P0 | control, character-class NUL, hex, fixed Unicode, and braced Unicode escapes | runtime |
| RX-031 | P1 | malformed escape variants rejected with precise primary error | E4172 |
| RX-031A | P1 | incomplete, non-hex, unclosed, empty, overflow, and invalid-control escape variants are rejected | E4172 |
| RX-031B | P1 | isolated-surrogate Unicode escapes are rejected while well-formed non-BMP scalars remain valid | E4172 + runtime |
| RX-031C | P1 | scalar boundary values U+D7FF, U+E000, and U+10FFFF are expressible, while both fixed and braced isolated-surrogate forms are rejected | runtime + E4172 |
| RX-031D | P1 | regex interpolation is not a pattern feature; an attempted interpolation is rejected rather than evaluated | parse/typing negative |
| RX-031E | P1 | empty, digit-leading, punctuation-containing, and unclosed named-capture identifiers are rejected | E4172 |
| RX-031F | P1 | `\0` outside a class is an unsupported numeric backreference, while an isolated-surrogate escape is invalid inside a class as well as outside it | E4172 |
| RX-032 | P1 | unsupported lookaround/backreference/boundary constructs | E4172 |
| RX-032A | P1 | positive and negative lookahead, positive and negative lookbehind, numeric and named backreferences, and both boundary assertions are rejected individually | E4172 |
| RX-032B | P1 | both character-class intersection and subtraction spellings are rejected as unsupported class-set expressions | E4172 |
| RX-033 | P0 | `(?i:...)` folds ASCII letters | runtime |
| RX-034 | P1 | `(?i:...)` does not perform Unicode case folding | runtime |
| RX-034A | P1 | case-insensitive scope applies inside classes and nested groups and ends at the group boundary | runtime |
| RX-035 | P0 | anonymous groups in direct pattern do not bind | typing |
| RX-036 | P0 | named group in direct pattern rejected | E4181 |
| RX-037 | P1 | named/anonymous capture metadata in a referenced constant is stripped while matching structure remains effective | typing + runtime |
| RX-037A | P1 | unqualified, qualified, composed, anchored, and hidden-capture constants work consistently in `=~`, `lexmatch`, and `lexscan` | typing + runtime |
| RX-037B | P1 | a capture name hidden inside a referenced constant is not in MoonBit scope in any of the three expressions | negative typing |
| RX-037C | P1 | stripping capture metadata at a pattern reference does not remove greediness or mutate the first-class constant's own capture metadata | runtime |
| RX-037D | P1 | first-class optional captures are absent when their path is not taken, and repeated captures expose the final participating iteration before reference-site metadata stripping | runtime |
| RX-038 | P0 | `as` capture is `Char` for exactly one scalar value | typing |
| RX-039 | P0 | `as` capture is `StringView` otherwise | typing |
| RX-040 | P1 | zero-width terms do not change single-scalar capture classification | typing |
| RX-040A | P1 | one-scalar alternations, exact-one repetitions, and one-scalar referenced constants capture as `Char`; nullable or mixed-width alternatives capture as `StringView` | typing + runtime |
| RX-041 | P0 | nested and multiple sequence captures | runtime |
| RX-041A | P1 | pattern-level `+`, `|`, parentheses, and `as` obey their documented precedence and alias-placement grammar | parse + runtime |
| RX-041B | P1 | an alias participating in a sequence or alternation requires the documented parentheses, and `as _` is not a discard form | parse negative |
| RX-042 | P0 | duplicate pattern binder rejected | E4081 |
| RX-043 | P0 | alias inside alternation rejected | E4210 |
| RX-044 | P0 | alias around complete alternation accepted | typing + runtime |
| RX-045 | P1 | empty language `[]` never matches | runtime + warning interaction |
| RX-046 | P1 | direct `^` and `$` assertions cannot be quantified, while grouped zero-width forms such as `(^){2}` remain valid | E4172 + runtime |
| RX-047 | P1 | `[{]` and `[}]` match literal braces; class hyphen uses `\-`; incompatible left-brace and hyphen forms are rejected | runtime + E4172/parse negative |

## 3. Regex match expression (`=~`)

| ID | Priority | Requirement | Expected test kind |
| --- | --- | --- | --- |
| RM-001 | P0 | `String` target accepted and implicitly viewed | typing + runtime |
| RM-002 | P0 | `StringView` target accepted, including a slice | runtime |
| RM-003 | P0 | non-text target rejected | E4014 |
| RM-003A | P1 | numeric, `Bytes`, `BytesView`, and scanner targets are all rejected | E4014 |
| RM-004 | P0 | expression result type is `Bool` | typing |
| RM-005 | P0 | unanchored pattern searches and chooses earliest start | runtime |
| RM-006 | P0 | alternative order chooses match at same start | runtime |
| RM-006A | P1 | earliest start dominates alternative order when different alternatives first match at different target positions | runtime |
| RM-007 | P0 | greedy and lazy quantifier behavior | runtime |
| RM-008 | P0 | `before`/`after` bind correct views | runtime |
| RM-008A | P1 | `before` and `after` remain bounded by a sliced `StringView`, not its backing string | runtime |
| RM-009 | P1 | anchored empty `before` and `after` denote the correct target boundaries | runtime |
| RM-010 | P0 | `before=_`/`after=_` create no variables | typing |
| RM-011 | P1 | `before~`/`after~` shorthand | parse + typing + runtime |
| RM-011A | P1 | binding tuples accept either label order, either shorthand independently, nested grouping, and every documented trailing-comma shape | parse + typing + runtime + format |
| RM-012 | P0 | unknown binding label | E4208 |
| RM-013 | P0 | duplicate `before` or `after` | E4209 |
| RM-014 | P0 | name collision among capture/before/after | E4081 |
| RM-015 | P0 | binders available in right side of `&&` | typing + runtime |
| RM-015A | P1 | binders from multiple successful regex matches in a nested `&&` condition are jointly available on the guaranteed-success path | typing + runtime |
| RM-016 | P0 | binders available in true `if` branch | typing + runtime |
| RM-017 | P1 | binders available after `guard` and in `while` body | typing + runtime |
| RM-017A | P1 | binders available in condition-controlled `for` updates and body | typing + runtime |
| RM-018 | P0 | binders unavailable through `||`, negation, and false branch | negative typing |
| RM-018A | P1 | binders are unavailable in a guard failure branch, loop `else` branch, or an `if` true branch reached through `||` | negative typing |
| RM-019 | P1 | target expression evaluated exactly once | runtime side effect |
| RM-020 | P1 | failure returns false without evaluating success path | runtime side effect |
| RM-020A | P1 | captures and boundary views remain valid after a temporary `String` target goes out of scope | runtime regression |
| RM-021 | P2 | formatter preserves canonical binding tuple syntax | format |
| RM-022 | P1 | an `=~` site requires no direct `moonbitlang/core/string` import | typing |
| RM-023 | P2 | `=~` groups as a condition operator before `&&`/`||`, and explicit parentheses preserve the intended target expression | parse + runtime + format |

## 4. `lexmatch`

| ID | Priority | Requirement | Expected test kind |
| --- | --- | --- | --- |
| LM-001 | P0 | `String` and `StringView` targets accepted | typing + runtime |
| LM-002 | P0 | other targets rejected | E4222 |
| LM-002A | P1 | numeric, `Bytes`, `BytesView`, `Lexbuf`, `AsyncLexbuf`, `StringScanner`, and user-defined targets are rejected | E4222 |
| LM-003 | P0 | omitted strategy equals `first` | runtime |
| LM-004 | P0 | explicit `with first` accepted | parse + runtime |
| LM-005 | P0 | unsupported strategy rejected | E4180 |
| LM-006 | P0 | at the same start, an earlier first case beats a later longer case | runtime |
| LM-007 | P0 | an earlier successful case beats a later case that could match at an earlier input position | runtime |
| LM-008 | P0 | first-mode unanchored search | runtime |
| LM-008A | P1 | after an earlier regex case fails everywhere, the next source case is tried normally in both anchored and unanchored first-mode matching | runtime |
| LM-009 | P0 | first mode supports non-greedy quantifiers | runtime |
| LM-010 | P0 | first mode supports `before` and `after` | runtime |
| LM-010A | P1 | first-mode binding tuples support label reordering, independent shorthand, nested grouping, and trailing commas | parse + typing + runtime + format |
| LM-010B | P1 | unknown labels, duplicate labels, and every capture/before/after name-collision pairing are rejected | E4208 + E4209 + E4081 |
| LM-011 | P1 | missing-before warning and all suppression forms | E0080 |
| LM-012 | P1 | missing-after warning and all suppression forms | E0081 |
| LM-012A | P1 | named, discarded, shorthand, and semantic-anchor forms independently suppress the corresponding boundary warning | warning-negative typing |
| LM-013 | P0 | longest mode requires semantic start anchoring | E4218 |
| LM-014 | P1 | anchored alternation accepted only if every arm anchored | typing |
| LM-015 | P0 | longest case consumes maximal prefix | runtime |
| LM-015A | P1 | longest selection prefers a consuming match over an empty match and preserves the selected case's captures | runtime |
| LM-015B | P1 | equal-end maximal paths may produce either coherent capture decomposition, but never a mixture of paths | runtime |
| LM-015C | P1 | longest mode continues after one case's partial-prefix failure and selects a later successful case | runtime |
| LM-016 | P0 | equal-length longest tie uses source order | runtime + E0090 |
| LM-017 | P0 | longest rejects `before` | E4220 |
| LM-018 | P0 | longest supports `after` | runtime |
| LM-019 | P0 | case result types unify | typing positive/negative |
| LM-020 | P0 | only selected body evaluates | runtime side effect |
| LM-020A | P1 | target evaluation occurs exactly once on both regex-selection and catch-all paths | runtime side effect |
| LM-020B | P1 | captures and boundary views remain valid after the target expression's temporary `String` value goes out of scope | runtime regression |
| LM-021 | P0 | case guards are syntactically unavailable | parse negative |
| LM-022 | P0 | wildcard catch-all | runtime |
| LM-023 | P0 | binder catch-all gets the complete original target as a `StringView` | runtime + typing |
| LM-023B | P1 | a binder catch-all view remains valid when the original target was a temporary `String` | runtime regression |
| LM-023A | P1 | binder or wildcard catch-all may be the only case | runtime |
| LM-024 | P0 | wildcard catch-all must be last | E4171 |
| LM-024B | P1 | non-final binder catch-all is rejected with the same ordering diagnostic | E4171 |
| LM-025 | P0 | non-exhaustive expression without catch-all | E4224 |
| LM-026 | P0 | exhaustive expression may omit catch-all | compile + runtime |
| LM-027 | P1 | exhaustive expression makes written catch-all unused | E0090 |
| LM-027A | P1 | unreachable catch-all body remains type-checked | E0090 + body error |
| LM-028 | P0 | shadowed regex case warning | E0090 |
| LM-028A | P1 | a strictly shorter longest-mode case that can never win is reported unused | E0090 |
| LM-028B | P1 | under `first`, an earlier strict-prefix case makes a later longer case unused | E0090 |
| LM-029 | P1 | empty-language case warning | E0090 |
| LM-030 | P0 | unreachable body still type-checked | E0090 + body error |
| LM-031 | P1 | empty target, empty regex, `^`, `$`, and `^$` | runtime |
| LM-031A | P1 | on non-empty input, `^` and an empty regex match at the beginning while `$` matches at the end with correct boundary bindings | runtime |
| LM-032 | P0 | non-BMP capture and correct suffix offsets | runtime |
| LM-033 | P2 | empty case list is rejected as non-exhaustive | E4224 |
| LM-033A | P1 | `...` is a wildcard catch-all with a TODO hole body | parse + typing |
| LM-033B | P1 | a non-final `...` placeholder is rejected by the catch-all ordering rule | E4171 |
| LM-034 | P2 | old string-piece pattern and `lexmatch?` rejected | parse negative |
| LM-035 | P2 | formatter canonicalizes strategies, regex cases, binding tuples, catch-alls, and placeholder cases | format |

## 5. `lexscan`

| ID | Priority | Requirement | Expected test kind |
| --- | --- | --- | --- |
| LS-001 | P0 | direct-imported `Lexbuf` accepted | typing + runtime |
| LS-002 | P0 | direct-imported `AsyncLexbuf` accepted in async context | typing + runtime |
| LS-003 | P0 | direct-imported `StringScanner` accepted | typing + runtime |
| LS-004 | P0 | `String` and `StringView` rejected; direct string scanning uses `lexmatch` | E4222 |
| LS-005 | P0 | `Bytes`/`BytesView` and numeric targets rejected | E4222 |
| LS-006 | P0 | duck-typed scanner rejected | E4222 |
| LS-007 | P0 | indirect lexbuf dependency without direct import rejected | E4037 |
| LS-008 | P0 | target expression evaluated exactly once | runtime side effect |
| LS-008A | P1 | target evaluation occurs exactly once on both regex-selection and catch-all paths | runtime side effect |
| LS-008B | P1 | the target scanner object is captured before matching; reassignment of an outer variable in a selected body does not redirect the committed cursor | runtime side effect |
| LS-008C | P1 | exactly-once target evaluation holds for `AsyncLexbuf` and `StringScanner` as well as `Lexbuf` | async + runtime side effect |
| LS-009 | P0 | every first-mode case requires `^` | E4218 |
| LS-010 | P0 | every longest-mode case requires `^` | E4218 |
| LS-010A | P1 | omitted and explicit `first` are equivalent, `longest` is accepted, and unsupported strategies are rejected | runtime + E4180 |
| LS-011 | P0 | both `before` and `after` are rejected in both strategies for all three target kinds | E4220 |
| LS-011A | P1 | unknown and duplicate binding labels are diagnosed before or alongside the `lexscan` binding restriction | E4208 + E4209 |
| LS-012 | P0 | first mode earlier shorter case wins | runtime + E0090 |
| LS-012A | P1 | first-mode `lexscan` supports every non-greedy quantifier form and required backtracking | runtime |
| LS-012B | P1 | failure of an earlier partial-prefix case neither consumes input nor prevents a later case from matching at the same origin | runtime |
| LS-012C | P1 | a partial-prefix failure may cross a refill boundary; later first-mode and longest-mode cases still match from the original scan origin with correct captures and commit | runtime |
| LS-013 | P0 | longest mode selects maximal token | runtime |
| LS-013A | P1 | longest selection waits across refill boundaries before committing the maximal token | runtime |
| LS-013B | P1 | longest selection is consistent for `Lexbuf`, `AsyncLexbuf`, and `StringScanner` | async + runtime |
| LS-013C | P1 | equal-end maximal paths may produce either coherent capture decomposition, but never a mixture of paths | runtime + async runtime |
| LS-014 | P0 | equal-length longest tie uses source order | runtime + E0090 |
| LS-015 | P0 | successful `Lexbuf` case commits before body | runtime recursive scan |
| LS-015A | P1 | successful `AsyncLexbuf` and `StringScanner` cases also commit before body evaluation | async + runtime recursive scan |
| LS-016 | P0 | successful `StringScanner` case updates relative cursor | runtime |
| LS-016A | P1 | the cursor commit occurs before the body but does not overwrite an explicit cursor mutation performed by the selected `StringScanner` body | runtime |
| LS-017 | P0 | catch-all leaves `Lexbuf` cursor unchanged | runtime |
| LS-018 | P0 | catch-all leaves `StringScanner` cursor unchanged | runtime |
| LS-019 | P0 | binder catch-all rejected | E4216 |
| LS-019A | P1 | wildcard-only expression leaves cursor unchanged without refill | runtime |
| LS-019C | P1 | wildcard-only behavior is consistent for `Lexbuf`, `AsyncLexbuf`, and `StringScanner` | async + runtime |
| LS-019D | P1 | non-final wildcard, binder, and placeholder catch-alls are rejected; a binder additionally remains unsupported by `lexscan` | E4171 + E4216 |
| LS-019B | P1 | `...` is accepted as a wildcard catch-all with a TODO hole body | parse + typing |
| LS-020 | P0 | catch-all handles EOF | runtime |
| LS-021 | P0 | catch-all handles unmatched character without consuming it | runtime |
| LS-021A | P1 | EOF and unmatched-character catch-all behavior is repeated consistently across all three scanner targets | async + runtime |
| LS-021B | P1 | read-ahead does not change selected case, captures, committed cursor, or EOF semantics; exact refill count is not asserted | runtime |
| LS-022 | P0 | missing catch-all includes EOF/unmatched witness | E4224 |
| LS-023 | P1 | exhaustive cases may omit catch-all | compile + runtime |
| LS-024 | P0 | refill permits a token across two or more chunks | runtime |
| LS-024A | P1 | a token may end exactly at a chunk boundary before later buffered input, without changing its selected capture or committed end | runtime |
| LS-025 | P1 | empty chunks are ignored during refill | runtime |
| LS-025A | P1 | any finite run of empty chunks before, between, or after nonempty chunks is skipped without changing the logical token stream | runtime |
| LS-026 | P0 | captures spanning chunks remain correct | runtime |
| LS-026A | P1 | multiple and nested capture endpoints remain correct when different captures cross different chunk boundaries | runtime |
| LS-027 | P1 | `$` waits for true EOF, not chunk boundary | runtime |
| LS-027A | P1 | `AsyncLexbuf` applies the same true-EOF `$` rule across asynchronous chunk boundaries | async runtime |
| LS-027B | P1 | an end-anchored case may refill through trailing empty chunks before true EOF | runtime + async runtime |
| LS-027C | P1 | a failing end-anchored candidate restores the original cursor even after refilling through nonempty and trailing empty chunks to establish EOF | runtime + async runtime |
| LS-028 | P0 | async refill and cross-chunk token | async runtime |
| LS-029 | P0 | `StringScanner` respects sliced `StringView` bounds | runtime |
| LS-029A | P1 | valid `StringScanner` cursor boundary values `0` and `data.length()` | runtime |
| LS-029B | P1 | a sliced `StringView` and nonzero cursor preserve non-BMP scalar boundaries and relative UTF-16 offsets | runtime |
| LS-030 | P0 | successive `StringScanner` scans resume at stored cursor | runtime |
| LS-031 | P0 | zero-length match leaves cursor unchanged | runtime |
| LS-032 | P1 | zero-length successful case can make catch-all unreachable under ordinary reachability analysis | warning analysis |
| LS-032A | P1 | an empty successful match emits no progress warning and does not implicitly advance | compile + runtime |
| LS-032B | P1 | exhaustive cases including `re"^$"` may omit catch-all and use the EOF case body for loop control | compile + runtime |
| LS-033 | P0 | non-BMP token advances cursor by two UTF-16 code units | runtime |
| LS-034 | P0 | `Char` capture of non-BMP token is one scalar value | typing + runtime |
| LS-034A | P1 | `AsyncLexbuf` recognizes a non-BMP scalar whose surrogate pair is split across asynchronous refills | async runtime |
| LS-034B | P1 | a synchronous `Lexbuf` recognizes a non-BMP scalar whose surrogate pair is split across refills separated by empty chunks | runtime |
| LS-035 | P1 | retained capture survives buffer compaction/refill | runtime regression |
| LS-035A | P1 | a capture returned from `AsyncLexbuf` remains valid after later asynchronous refills and commits | async runtime regression |
| LS-035B | P1 | two simultaneously retained captures from separate tokens remain independently valid after compaction | runtime + async runtime regression |
| LS-035C | P1 | repeated capture/refill/commit cycles may compact the buffer without corrupting later absolute cursor positions | runtime regression |
| LS-035D | P1 | a capture returned from a temporary `StringScanner` target whose data is a temporary `String` remains valid after the expression returns | runtime regression |
| LS-036 | P1 | unreachable regex case warning and body checking | E0090 + body error |
| LS-036A | P1 | unreachable catch-all warning and body checking | E0090 + body error |
| LS-037 | P2 | behavior is consistent across supported compilation targets | multi-target runtime |
| LS-038 | P2 | tail-position and recursive scanner behavior | runtime regression |
| LS-039 | P1 | zero-length success and EOF handling are consistent for `Lexbuf`, `AsyncLexbuf`, and `StringScanner` | async + runtime |
| LS-040 | P1 | case result types unify, only the selected body evaluates, and case guards are rejected | typing + runtime + parse negative |
| LS-041 | P1 | an empty case list is non-exhaustive, and covering every scalar without EOF remains non-exhaustive | E4224 |
| LS-042 | P2 | formatter canonicalizes strategies, regex cases, binding tuples, catch-alls, and placeholder cases | format |

## 6. Cross-cutting test dimensions

The suite SHOULD combine the rows above with these dimensions where relevant:

- target is `String` versus a sliced `StringView`;
- ASCII, BMP non-ASCII, and non-BMP scalar values;
- empty input, one-scalar input, and long input;
- empty, single-scalar, fixed-length multi-scalar, and variable-length captures;
- first versus longest strategy;
- literal pattern versus referenced constant versus composed constants;
- success at start, success in middle, success at end, and no match;
- match ending at buffered boundary versus spanning a refill;
- all supported compilation targets used by the repository; and
- debug versus release where generated scanner structure may differ.

## 7. Suite layout

The executable repository uses this layout:

```text
regex_match/
  basic_test.mbt
lexmatch/
  first_and_longest_test.mbt
  catchall_test.mbt
lexscan/
  helpers.mbt
  lexbuf_test.mbt
  async_lexbuf_test.mbt
  string_scanner_test.mbt
regex_syntax/
  literals_test.mbt
  classes_and_escapes_test.mbt
diagnostics/
  fixtures.tsv
  fixtures/
  run.sh
format/
scripts/
```
