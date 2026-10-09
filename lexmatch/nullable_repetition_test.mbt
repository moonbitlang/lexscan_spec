///|
#warnings("-unused_lexcase")
test "RX-012C nullable repetition preserves empty-first priority" {
  for input in ["", "a", "ab", "aa", "b"] {
    lexmatch input {
      (re"^(?:|a)*" as word, after=rest) => {
        assert_eq(word, "")
        assert_eq(rest, input)
      }
      _ => fail("nullable repetition did not match")
    }
    lexmatch input {
      (re"^(?:|ab)*" as word, after=rest) => {
        assert_eq(word, "")
        assert_eq(rest, input)
      }
      _ => fail("nullable multi-character repetition did not match")
    }
    lexmatch input {
      (re"^(?:|a)+" as word, after=rest) => {
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
test "RX-012C nullable repetition retains consuming-first priority" {
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
    _ => fail("non-greedy repetition did not match")
  }
}

///|
#warnings("-unused_lexcase")
test "RX-012C nullable loop stops after an empty iteration after progress" {
  lexmatch "aab!" {
    (re"^(?:a?|b)*" as word, after=rest) => {
      assert_eq(word, "aa")
      assert_eq(rest, "b!")
    }
    _ => fail("nullable loop did not stop after its empty iteration")
  }
  lexmatch "aab!" {
    (re"^(?:a?|b)+" as word, after=rest) => {
      assert_eq(word, "aa")
      assert_eq(rest, "b!")
    }
    _ => fail("nullable plus did not stop after its empty iteration")
  }
  lexmatch "aabb!" {
    ((re"^(?:a?|b){2,}" as word) + re"b", after=rest) => {
      assert_eq(word, "aa")
      assert_eq(rest, "b!")
    }
    _ => fail("nullable minimum repetition did not retry its suffix")
  }
  lexmatch "ab" {
    (re"^(?:a?|b)*$" as word, after=rest) => {
      assert_eq(word, "ab")
      assert_eq(rest, "")
    }
    _ => fail("nullable repetition did not retry after its EOF suffix failed")
  }
}

///|
#warnings("-unused_lexcase")
test "RX-012C nullable repetition retries consuming paths for a suffix" {
  lexmatch "aab!" {
    ((re"^(?:|a)*" as word) + re"b", after=rest) => {
      assert_eq(word, "aa")
      assert_eq(rest, "!")
    }
    _ => fail("nullable repetition did not retry for its suffix")
  }
  lexmatch "aab!" {
    ((re"^(?:|a)*?" as word) + re"b", after=rest) => {
      assert_eq(word, "aa")
      assert_eq(rest, "!")
    }
    _ => fail("non-greedy repetition did not retry for its suffix")
  }
  lexmatch "aa!" {
    (re"^a*" as word, after=rest) => {
      assert_eq(word, "aa")
      assert_eq(rest, "!")
    }
    _ => fail("nonnullable repetition did not match")
  }
}

///|
test "RX-012D nullable composite loop finishes before its successful suffix" {
  lexmatch "baaa" {
    (re"^(?:a*?b*?)*a" as word, after=rest) => {
      assert_eq(word, "ba")
      assert_eq(rest, "aa")
    }
    _ => fail("nullable composite repetition did not match")
  }
  lexmatch "baaa" {
    ((re"^(?:a*?b*?)*" as word) + (re"a" as tail), after=rest) => {
      assert_eq(word, "b")
      assert_eq(tail, 'a')
      assert_eq(rest, "aa")
    }
    _ => fail("nullable composite repetition lost its capture boundaries")
  }
  lexmatch "baaa" {
    (re"^(?:a*?b*?)+a" as word, after=rest) => {
      assert_eq(word, "ba")
      assert_eq(rest, "aa")
    }
    _ => fail("nullable composite plus did not match")
  }
  lexmatch "baaa" {
    (re"^(?:a*?b*?){2,}a" as word, after=rest) => {
      assert_eq(word, "ba")
      assert_eq(rest, "aa")
    }
    _ => fail("nullable composite lower bound did not match")
  }
}

///|
#warnings("-unused_lexcase")
test "RX-012D nullable repetitions preserve inner lazy and empty alternatives" {
  lexmatch "ab" {
    (re"^(?:a?b??)*" as word, after=rest) => {
      assert_eq(word, "a")
      assert_eq(rest, "b")
    }
    _ => fail("nullable repetition lost its inner lazy choice")
  }
  lexmatch "aab" {
    (re"^(?:a?b??){2,}" as word, after=rest) => {
      assert_eq(word, "aa")
      assert_eq(rest, "b")
    }
    _ => fail("nullable repetition lost its lower bound or inner lazy choice")
  }
  lexmatch "abb" {
    (re"^(?:(?:|a)(?:|b))*b" as word, after=rest) => {
      assert_eq(word, "ab")
      assert_eq(rest, "b")
    }
    _ => fail("nullable repetition reordered its empty alternatives")
  }
  lexmatch "ab" {
    ((re"^(?:a?b??)*" as body) + (re"b*" as tail), after=rest) => {
      assert_eq(body, "a")
      assert_eq(tail, "b")
      assert_eq(rest, "")
    }
    _ => fail("nullable repetition changed captures without changing the match")
  }
}

///|
test "RX-012D empty iterations satisfy mandatory and finite repetition counts" {
  assert_true("a" =~ re"^(?:){3,}a$")
  assert_true("a" =~ re"^(?:){3,}?a$")
  assert_true("a" =~ re"^(?:){3}a$")
  lexmatch "aab!" {
    ((re"^(?:|a){2}" as word) + re"b", after=rest) => {
      assert_eq(word, "aa")
      assert_eq(rest, "!")
    }
    _ =>
      fail("mandatory nullable iterations did not retry consuming alternatives")
  }
  let zero : Regex = re"^(?<item>a?){0}"
  guard zero.execute("a") is Some(result) else {
    fail("zero iterations did not match")
  }
  assert_eq(result.content(), "")
  assert_eq(result.named_group("item"), None)
}

///|
test "RX-012D empty-iteration priority also applies to regex match expressions" {
  if "baaa" =~ (re"^(?:a*?b*?)*a" as word, after=rest) {
    assert_eq(word, "ba")
    assert_eq(rest, "aa")
  } else {
    fail("regex match expression did not match the nullable composite loop")
  }
  let slice = "--baaa++"[2:6]
  lexmatch slice {
    (re"^(?:a*?b*?)*a" as word, after=rest) => {
      assert_eq(word, "ba")
      assert_eq(rest, "aa")
    }
    _ => fail("sliced target changed nullable repetition priority")
  }
}

///|
test "RX-012D first-class regex captures the final empty iteration" {
  let repeated : Regex = re"^(?<iteration>a?)*"
  guard repeated.execute("aa!") is Some(result) else {
    fail("first-class nullable repetition did not match")
  }
  assert_eq(result.content(), "aa")
  assert_eq(result.after(), "!")
  assert_eq(result.named_group("iteration"), Some(""))

  let composite : Regex = re"^(?<body>(?:a*?b*?)*)a"
  guard composite.execute("baaa") is Some(composite_result) else {
    fail("first-class nullable composite repetition did not match")
  }
  assert_eq(composite_result.content(), "ba")
  assert_eq(composite_result.named_group("body"), Some("b"))
  assert_eq(composite_result.after(), "aa")
}
