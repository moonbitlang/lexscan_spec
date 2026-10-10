///|
#warnings("-unused_lexcase")
test "RX-012C empty-first nullable repetition retains alternative priority" {
  for input in ["", "a", "ab", "aa", "b"] {
    lexmatch input {
      (re"^(?:|a)*" as word, after=rest) => {
        assert_eq(word, "")
        assert_eq(rest, input)
      }
      _ => fail("nullable star did not match")
    }
    lexmatch input {
      (re"^(?:|ab)+" as word, after=rest) => {
        assert_eq(word, "")
        assert_eq(rest, input)
      }
      _ => fail("nullable plus did not match")
    }
    lexmatch input {
      (re"^(?:|a){2,}" as word, after=rest) => {
        assert_eq(word, "")
        assert_eq(rest, input)
      }
      _ => fail("nullable minimum repetition did not match")
    }
    lexmatch input {
      (re"^(?:|a){0,2}" as word, after=rest) => {
        assert_eq(word, "")
        assert_eq(rest, input)
      }
      _ => fail("bounded nullable repetition did not match")
    }
  }
}

///|
#warnings("-unused_lexcase")
test "RX-012C consuming-first and lazy nullable loops preserve their modes" {
  lexmatch "aa!" {
    (re"^(?:a|)*" as word, after=rest) => {
      assert_eq(word, "aa")
      assert_eq(rest, "!")
    }
    _ => fail("consuming-first repetition did not match")
  }
  lexmatch "aa!" {
    (re"^(?:a|)*?" as word, after=rest) => {
      assert_eq(word, "")
      assert_eq(rest, "aa!")
    }
    _ => fail("lazy star did not match")
  }
  lexmatch "aa!" {
    (re"^(?:a|)+?" as word, after=rest) => {
      assert_eq(word, "a")
      assert_eq(rest, "a!")
    }
    _ => fail("lazy plus lost its mandatory body")
  }
  lexmatch "aab!" {
    (re"^(?:a?|b)*" as word, after=rest) => {
      assert_eq(word, "aab")
      assert_eq(rest, "!")
    }
    _ => fail("empty path reordered a later consuming alternative")
  }
}

///|
#warnings("-unused_lexcase")
test "RX-012C composite nullable loops use ordered automaton priority" {
  lexmatch "baaa" {
    (re"^(?:a*?b*?)*a" as word, after=rest) => {
      assert_eq(word, "baa")
      assert_eq(rest, "a")
    }
    _ => fail("nullable star did not match its suffix")
  }
  lexmatch "baaa" {
    (re"^(?:a*?b*?)+a" as word, after=rest) => {
      assert_eq(word, "baa")
      assert_eq(rest, "a")
    }
    _ => fail("nullable plus did not match its suffix")
  }
  lexmatch "baaa" {
    (re"^(?:a*?b*?){2,}a" as word, after=rest) => {
      assert_eq(word, "baa")
      assert_eq(rest, "a")
    }
    _ => fail("nullable lower bound did not match its suffix")
  }
  lexmatch "baaa" {
    (re"^(?:a*?b*?){3,}a" as word, after=rest) => {
      assert_eq(word, "baa")
      assert_eq(rest, "a")
    }
    _ => fail("mandatory empty iterations changed the selected match")
  }
  lexmatch "baaa" {
    (re"^(?:a*?b*?)*?a" as word, after=rest) => {
      assert_eq(word, "ba")
      assert_eq(rest, "aa")
    }
    _ => fail("lazy nullable star did not preserve its exit priority")
  }
  lexmatch "ab" {
    ((re"^(?:a?b??)*" as body) + (re"b*" as tail), after=rest) => {
      assert_eq(body, "a")
      assert_eq(tail, "b")
      assert_eq(rest, "")
    }
    _ => fail("nullable repetition changed its operand's lazy choice")
  }
}

///|
#warnings("-unused_lexcase")
test "RX-012C failed continuations retry permitted consuming paths" {
  lexmatch "aab!" {
    ((re"^(?:|a)*" as word) + re"b", after=rest) => {
      assert_eq(word, "aa")
      assert_eq(rest, "!")
    }
    _ => fail("nullable star did not retry for its suffix")
  }
  lexmatch "aab!" {
    ((re"^(?:|a)*?" as word) + re"b", after=rest) => {
      assert_eq(word, "aa")
      assert_eq(rest, "!")
    }
    _ => fail("lazy nullable star did not retry for its suffix")
  }
  lexmatch "ab" {
    (re"^(?:a?|b)*$" as word, after=rest) => {
      assert_eq(word, "ab")
      assert_eq(rest, "")
    }
    _ => fail("nullable repetition did not retry its EOF suffix")
  }
  lexmatch "aa" {
    (re"^(?:$|a)+?" as word, after=rest) => {
      assert_eq(word, "a")
      assert_eq(rest, "a")
    }
    _ => fail("EOF alternative invented an empty successful match")
  }
}

///|
#warnings("-unused_lexcase")
test "RX-012C nullable nested and finite repetitions terminate" {
  assert_true("a" =~ re"^(?:){3,}a$")
  assert_true("a" =~ re"^(?:){3,}?a$")
  assert_true("a" =~ re"^(?:){3}a$")
  lexmatch "aa" {
    (re"^(?:(?:)*)*" as word, after=rest) => {
      assert_eq(word, "")
      assert_eq(rest, "aa")
    }
    _ => fail("nested empty repetition did not terminate")
  }
  lexmatch "aab!" {
    (re"^(?:(?:a?)*)*b" as word, after=rest) => {
      assert_eq(word, "aab")
      assert_eq(rest, "!")
    }
    _ => fail("nested nullable repetition did not match")
  }
  lexmatch "aab!" {
    (re"^(?:|a){2,3}b" as word, after=rest) => {
      assert_eq(word, "aab")
      assert_eq(rest, "!")
    }
    _ => fail("finite nullable copies did not retry for their suffix")
  }
  lexmatch "baaa!" {
    (re"^(?:(?:a*?b*?)*a)*" as word, after=rest) => {
      assert_eq(word, "baaa")
      assert_eq(rest, "!")
    }
    _ => fail("nested composite repetition did not match")
  }
}

///|
test "RX-012D pattern captures describe the selected ordered path" {
  lexmatch "baaa" {
    ((re"^(?:a*?b*?)*" as body) + (re"a" as tail), after=rest) => {
      assert_eq(body, "ba")
      assert_eq(tail, 'a')
      assert_eq(rest, "a")
    }
    _ => fail("nullable repetition lost its capture boundaries")
  }
  if "baaa" =~ (re"^(?:a*?b*?)*a" as word, after=rest) {
    assert_eq(word, "baa")
    assert_eq(rest, "a")
  } else {
    fail("regex match expression did not match")
  }
  let slice = "--baaa++"[2:6]
  lexmatch slice {
    (re"^(?:a*?b*?)*a" as word, after=rest) => {
      assert_eq(word, "baa")
      assert_eq(rest, "a")
    }
    _ => fail("sliced target changed nullable repetition priority")
  }
}

///|
test "RX-012D repeated captures retain the first arrival at shared control points" {
  let repeated : Regex = re"^(?<body>(?<item>a*?b*?))*(?<tail>a)"
  guard repeated.execute("baaa") is Some(result) else {
    fail("first-class nullable repetition did not match")
  }
  assert_eq(result.content(), "baa")
  assert_eq(result.after(), "a")
  assert_eq(result.named_group("body"), Some("a"))
  assert_eq(result.named_group("item"), Some("a"))
  assert_eq(result.named_group("tail"), Some("a"))

  let at_eof : Regex = re"^(?<body>(?<item>a?))*$"
  guard at_eof.execute("a") is Some(eof_result) else {
    fail("nullable repeated capture did not reach EOF")
  }
  assert_eq(eof_result.content(), "a")
  assert_eq(eof_result.after(), "")
  assert_eq(eof_result.named_group("body"), Some("a"))
  assert_eq(eof_result.named_group("item"), Some("a"))

  let after_progress : Regex = re"^(?<iteration>a?)*"
  guard after_progress.execute("aa!") is Some(progress_result) else {
    fail("nullable capture after input progress did not match")
  }
  assert_eq(progress_result.content(), "aa")
  assert_eq(progress_result.after(), "!")
  assert_eq(progress_result.named_group("iteration"), Some("a"))
}

///|
test "RX-012D finite copies keep distinct capture control points" {
  let copies : Regex = re"^(?:(?<item>a*?b*?)*a){2}"
  guard copies.execute("baaaa") is Some(result) else {
    fail("finite copies of a nullable loop did not match")
  }
  assert_eq(result.content(), "baaa")
  assert_eq(result.after(), "a")
  assert_eq(result.named_group("item"), Some(""))

  let no_iterations : Regex = re"^(?<item>a?){0}b"
  guard no_iterations.execute("b!") is Some(zero_result) else {
    fail("zero iterations did not match")
  }
  assert_eq(zero_result.content(), "b")
  assert_eq(zero_result.named_group("item"), None)

  let empty : Regex = re"^(?<body>(?<item>(?:|a)))*"
  guard empty.execute("aa") is Some(empty_result) else {
    fail("empty-first captured repetition did not match")
  }
  assert_eq(empty_result.content(), "")
  assert_eq(empty_result.named_group("body"), Some(""))
  assert_eq(empty_result.named_group("item"), Some(""))
}

///|
test "RX-012D nullable repetition consumes Unicode scalars within sliced bounds" {
  let slice = "--b😀😀😀++"[2:9]
  lexmatch slice {
    (re"^(?:\u{1f600}*?b*?)*\u{1f600}" as word, after=rest) => {
      assert_eq(word, "b😀😀")
      assert_eq(rest, "😀")
      assert_eq(word.length(), 5)
      assert_eq(rest.length(), 2)
    }
    _ => fail("non-BMP scalar changed nullable repetition priority")
  }
  let regex : Regex = re"(?<body>(?:\u{1f600}*?b*?)*)(?<tail>\u{1f600})"
  guard regex.execute("x!b😀😀😀") is Some(result) else {
    fail("unanchored nullable Unicode repetition did not match")
  }
  assert_eq(result.before(), "x!")
  assert_eq(result.content(), "b😀😀")
  assert_eq(result.after(), "😀")
  assert_eq(result.named_group("body"), Some("b😀"))
  assert_eq(result.named_group("tail"), Some("😀"))
}
