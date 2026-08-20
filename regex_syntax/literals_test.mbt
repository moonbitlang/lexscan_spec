///|
const LOCAL_A = re"a"

///|
const LOCAL_B = re"b"

///|
const LOCAL_AB = re"ab"

///|
const LOCAL_CHAR = re"."

///|
const LOCAL_PAIR : Regex = LOCAL_A + LOCAL_B

///|
const LOCAL_EITHER : Regex = LOCAL_A | LOCAL_B

///|
fn expect_char(_value : Char) -> Unit {
  ()
}

///|
fn expect_view(_value : StringView) -> Unit {
  ()
}

///|
test "RX-001 RX-002 RX-003 literals dot and scalar boundaries" {
  assert_true("abc" =~ re"abc")
  assert_true(!("ab" =~ re"abc"))
  assert_true("\n" =~ re"^.$")
  lexmatch "A" {
    (re"^." as ch, after=_) => {
      expect_char(ch)
      assert_eq(ch, 'A')
    }
    _ => fail("dot must match one ASCII scalar")
  }
  lexmatch "😀!" {
    (re"^." as ch, after=tail) => {
      expect_char(ch)
      assert_eq(ch, '😀')
      assert_eq(tail, "!")
    }
    _ => fail("dot must match one non-BMP scalar")
  }
}

///|
#warnings("-unused_lexcase")
test "RX-004 RX-004A ordered and empty alternatives" {
  lexmatch "ab" {
    (re"^(a|ab)" as selected, after=_) => assert_eq(selected, "a")
    _ => fail("ordered alternative did not match")
  }
  lexmatch "x" {
    (re"^(|x)" as selected, after=_) => assert_eq(selected, "")
    _ => fail("empty first alternative did not match")
  }
  assert_true("" =~ re"^()$")
  assert_true("" =~ re"^(?:)$")
  assert_true("" =~ re"^(a|)$")
}

///|
test "RX-005 RX-006 RX-007 RX-008 constant composition" {
  assert_true("ab" =~ (LOCAL_A + LOCAL_B))
  assert_true("a" =~ (LOCAL_A | LOCAL_B))
  assert_true("b" =~ (LOCAL_A | LOCAL_B))
  assert_true("ab" =~ LOCAL_AB)
  assert_true("word" =~ @patterns.QUALIFIED_WORD)
  assert_true(!("123" =~ @patterns.QUALIFIED_WORD))
}

///|
test "RX-006A composed regex constants are pattern atoms" {
  assert_true("ab" =~ LOCAL_PAIR)
  assert_true("a" =~ LOCAL_EITHER)
  assert_true("b" =~ LOCAL_EITHER)
  assert_true("ab" =~ @patterns.QUALIFIED_PAIR)
  assert_true("b" =~ @patterns.QUALIFIED_EITHER)
}

///|
test "RX-011A Regex is available from the prelude" {
  let value : Regex = re"abc"
  assert_true(value.execute("zabc") is Some(_))
}

///|
test "RX-012 all quantifier forms and boundary counts" {
  assert_true("" =~ re"^a*$")
  assert_true("aaaa" =~ re"^a*$")
  assert_true("a" =~ re"^a+$")
  assert_true(!("" =~ re"^a+$"))
  assert_true("" =~ re"^a?$")
  assert_true("a" =~ re"^a?$")
  assert_true(!("aa" =~ re"^a?$"))
  assert_true("aaa" =~ re"^a{3}$")
  assert_true(!("aa" =~ re"^a{3}$"))
  assert_true("aa" =~ re"^a{2,}$")
  assert_true("aaaaaaaa" =~ re"^a{2,}$")
  assert_true("aa" =~ re"^a{2,4}$")
  assert_true("aaaa" =~ re"^a{2,4}$")
  assert_true(!("a" =~ re"^a{2,4}$"))
  assert_true(!("aaaaa" =~ re"^a{2,4}$"))
  assert_true("" =~ re"^a{0,0}$")
  assert_true("a" =~ re"^a{1,1}$")
}

///|
test "RX-012A quantifier operands backtracking and decimal counts" {
  assert_true("abab" =~ re"^(?:ab){2}$")
  assert_true("abba" =~ re"^[ab]+$")
  assert_true("a" =~ re"^a{01}$")
  lexmatch "aaab" {
    (re"^a{2,4}" as prefix) + re"b$" => assert_eq(prefix, "aaa")
    _ => fail("greedy bounded repetition did not backtrack")
  }
}

///|
#warnings("-unused_lexcase")
test "RX-012B repetition of empty and nullable groups terminates" {
  assert_true("" =~ re"^(?:)*$")
  assert_true("" =~ re"^(?:a?)*$")
  assert_true("aaa" =~ re"^(?:a?)*$")
  lexmatch "aaa" {
    (re"^(?:a?)*" as captured, after=_) => assert_eq(captured, "aaa")
    _ => fail("nullable repetition did not terminate")
  }
}

///|
test "RX-046 grouped zero-width regexes are quantifiable" {
  assert_true("" =~ re"^(^){2}$")
  assert_true("" =~ re"^(?:^)+$")
  assert_true("" =~ re"^(?i:^)?$")
  assert_true("" =~ re"^((^))+$")
  assert_true("a" =~ re"^(^){2}a$")
  assert_true("" =~ re"^($){2}$")

  let named : Regex = re"(?<start>^){2}"
  guard named.execute("a") is Some(result) else {
    fail("first-class grouped-anchor regex did not match")
  }
  assert_eq(result.content(), "")
  assert_eq(result.named_group("start"), Some(""))
}

///|
#warnings("-unused_lexcase")
test "RX-016 greedy and non-greedy paths" {
  lexmatch "aaaa" {
    (re"^a*" as greedy, after=_) => assert_eq(greedy, "aaaa")
    _ => fail("greedy pattern did not match")
  }
  lexmatch "aaaa" {
    (re"^a*?" as shortest, after=_) => assert_eq(shortest, "")
    _ => fail("non-greedy pattern did not match")
  }
  lexmatch "aaab" {
    ((re"^a*?" as prefix) + re"b", after=_) => assert_eq(prefix, "aaa")
    _ => fail("non-greedy backtracking did not match")
  }
  lexmatch "aaaa" {
    (re"^a+?" as shortest, after=_) => assert_eq(shortest, "a")
    _ => fail("non-greedy plus did not match")
  }
  lexmatch "a" {
    (re"^a??" as shortest, after=_) => assert_eq(shortest, "")
    _ => fail("non-greedy optional did not match")
  }
  lexmatch "aaaa" {
    (re"^a{2}?" as exact, after=_) => assert_eq(exact, "aa")
    _ => fail("non-greedy exact bound did not match")
  }
  lexmatch "aaaa" {
    (re"^a{2,}?" as shortest, after=_) => assert_eq(shortest, "aa")
    _ => fail("non-greedy open bound did not match")
  }
  lexmatch "aaaa" {
    (re"^a{2,4}?" as shortest, after=_) => assert_eq(shortest, "aa")
    _ => fail("non-greedy closed bound did not match")
  }
}

///|
test "RX-016A preferred paths fall back and restore captures" {
  lexmatch "ab" {
    re"^((a|ab)c|ab)$" as selected => assert_eq(selected, "ab")
    _ => fail("ordered alternatives did not retry after suffix failure")
  }
  lexmatch "aab" {
    ((re"^a*" as left) + (re"a" as right) + re"b$") as whole => {
      assert_eq(whole, "aab")
      assert_eq(left, "a")
      assert_eq(right, 'a')
    }
    _ => fail("greedy repetition did not backtrack to a successful count")
  }
  lexmatch "aaab" {
    (re"^a*?" as prefix) + re"ab$" => assert_eq(prefix, "aa")
    _ => fail("non-greedy repetition did not expand to satisfy the suffix")
  }
}

///|
test "RX-019 RX-020 anchors are logical and not multiline" {
  assert_true("abc" =~ re"^abc$")
  assert_true(!("zabc" =~ re"^abc"))
  assert_true(!("abc\nz" =~ re"^z"))
  assert_true(!("z\nabc\n" =~ re"abc$"))
  assert_true("z\nabc" =~ re"abc$")
  assert_true("z\nabc" =~ re"^z")
}

///|
test "RX-020A anchors assert their exact concatenation positions" {
  assert_true(!("a" =~ re"a^"))
  assert_true(!("a" =~ re"$a"))
  assert_true("a" =~ re"^a$")
  assert_true("" =~ re"^$")
}

///|
test "RX-033 RX-034 ASCII-only case folding" {
  assert_true("aBc" =~ re"^(?i:ABC)$")
  assert_true("Z" =~ re"^(?i:z)$")
  assert_true(!("É" =~ re"^(?i:é)$"))
  assert_true(!("Σ" =~ re"^(?i:σ)$"))
  assert_true("ABc" =~ re"^(?i:ab)c$")
  assert_true(!("ABC" =~ re"^(?i:ab)c$"))
}

///|
test "RX-035 RX-037 capture metadata in literals and constants" {
  assert_true("a" =~ re"^(a)$")
  assert_true("ab" =~ @patterns.HIDDEN_ANONYMOUS_CAPTURE)
  assert_true("hello" =~ @patterns.HIDDEN_NAMED_CAPTURE)
  lexmatch "hello!" {
    (@patterns.HIDDEN_NAMED_CAPTURE as whole, before=_, after=tail) => {
      expect_view(whole)
      assert_eq(whole, "hello")
      assert_eq(tail, "!")
    }
    _ => fail("referenced named capture must retain matching structure")
  }
}

///|
test "RX-037A constant forms compose consistently" {
  assert_true("ab" =~ (@patterns.QUALIFIED_A + @patterns.QUALIFIED_B))
  assert_true("b" =~ (@patterns.QUALIFIED_A | @patterns.QUALIFIED_B))
  lexmatch "zab!" {
    (
      (@patterns.QUALIFIED_A + @patterns.QUALIFIED_B) as whole,
      before=before,
      after=after,
    ) => {
      assert_eq(before, "z")
      assert_eq(whole, "ab")
      assert_eq(after, "!")
    }
    _ => fail("qualified composed constants did not match")
  }
}

///|
test "RX-037C pattern references preserve semantics without mutating constants" {
  lexmatch "aaaa" {
    (@patterns.HIDDEN_GREEDY_CAPTURE as whole, before=_, after=_) =>
      assert_eq(whole, "aaaa")
    _ => fail("referenced greedy constant did not stay greedy")
  }
  let value : Regex = @patterns.HIDDEN_GREEDY_CAPTURE
  guard value.execute("aaaa") is Some(result) else {
    fail("first-class regex constant did not match")
  }
  assert_eq(result.named_group("run"), Some("aaaa"))
}

///|
test "RX-037D first-class optional and repeated capture participation" {
  let optional : Regex = re"^(?<item>a)?$"
  guard optional.execute("") is Some(optional_result) else {
    fail("optional capture regex did not match empty input")
  }
  assert_eq(optional_result.named_group("item"), None)

  let repeated : Regex = re"^(?<item>a)+$"
  guard repeated.execute("aaa") is Some(repeated_result) else {
    fail("repeated capture regex did not match")
  }
  assert_eq(repeated_result.named_group("item"), Some("a"))

  assert_true("" =~ @patterns.HIDDEN_OPTIONAL_CAPTURE)
  assert_true("aaa" =~ @patterns.HIDDEN_REPEATED_CAPTURE)
}

///|
test "RX-038 RX-039 RX-040 capture type classification" {
  lexmatch "a" {
    re"^.$" as ch => {
      expect_char(ch)
      assert_eq(ch, 'a')
    }
    _ => fail("single scalar capture failed")
  }
  lexmatch "ab" {
    re"^ab$" as text => {
      expect_view(text)
      assert_eq(text, "ab")
    }
    _ => fail("multi-scalar capture failed")
  }
  lexmatch "z" {
    re"^.$" as anchored => {
      expect_char(anchored)
      assert_eq(anchored, 'z')
    }
    _ => fail("zero-width terms changed capture type")
  }
}

///|
#warnings("-unused_lexcase")
test "RX-040A exact one-scalar capture classification" {
  lexmatch "b" {
    re"^(a|b)$" as alternative => {
      expect_char(alternative)
      assert_eq(alternative, 'b')
    }
    _ => fail("one-scalar alternation did not match")
  }
  lexmatch "a" {
    re"^a{1}$" as exact_one => {
      expect_char(exact_one)
      assert_eq(exact_one, 'a')
    }
    _ => fail("exact-one repetition did not match")
  }
  lexmatch "😀" {
    (LOCAL_CHAR as local_char, before=_, after=_) => {
      expect_char(local_char)
      assert_eq(local_char, '😀')
    }
    _ => fail("local one-scalar constant did not match")
  }
  lexmatch "x" {
    (@patterns.QUALIFIED_CHAR as qualified_char, before=_, after=_) => {
      expect_char(qualified_char)
      assert_eq(qualified_char, 'x')
    }
    _ => fail("qualified one-scalar constant did not match")
  }
  lexmatch "" {
    (re"^a?" as nullable, after=_) => {
      expect_view(nullable)
      assert_eq(nullable, "")
    }
    _ => fail("nullable capture did not match")
  }
  lexmatch "bc" {
    re"^(a|bc)$" as mixed_width => {
      expect_view(mixed_width)
      assert_eq(mixed_width, "bc")
    }
    _ => fail("mixed-width capture did not match")
  }
}

///|
test "RX-041 RX-044 nested captures and complete alternation alias" {
  lexmatch "xabcd!" {
    (
      ((re"ab" as ab) + (re"c" as c) + (re"d" as d)) as whole,
      before=before,
      after=after,
    ) => {
      assert_eq(before, "x")
      assert_eq(ab, "ab")
      assert_eq(c, 'c')
      assert_eq(d, 'd')
      assert_eq(whole, "abcd")
      assert_eq(after, "!")
    }
    _ => fail("nested capture pattern did not match")
  }
  lexmatch "b" {
    ((re"a" | re"b") as either, before=_, after=_) => assert_eq(either, 'b')
    _ => fail("complete alternation alias did not match")
  }
}

///|
test "RX-041A pattern precedence grouping and aliases" {
  assert_true("a" =~ (LOCAL_A | LOCAL_B + re"c"))
  assert_true("bc" =~ (LOCAL_A | LOCAL_B + re"c"))
  assert_true(!("b" =~ (LOCAL_A | LOCAL_B + re"c")))
  lexmatch "abc" {
    (((re"^a" as first) + re"b") as pair) + re"c$" => {
      assert_eq(first, 'a')
      assert_eq(pair, "ab")
    }
    _ => fail("nested alias placement did not match")
  }
}

///|
test "RX-045 empty language never matches" {
  assert_true(!("" =~ re"[]"))
  assert_true(!("a" =~ re"[]"))
}
