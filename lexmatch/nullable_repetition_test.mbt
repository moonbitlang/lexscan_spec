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
test "RX-012C nullable loop retries consuming alternatives after progress" {
  lexmatch "aab!" {
    (re"^(?:a?|b)*" as word, after=rest) => {
      assert_eq(word, "aab")
      assert_eq(rest, "!")
    }
    _ => fail("nullable loop lost a consuming alternative")
  }
  lexmatch "aab!" {
    (re"^(?:a?|b)+" as word, after=rest) => {
      assert_eq(word, "aab")
      assert_eq(rest, "!")
    }
    _ => fail("nullable plus lost a consuming alternative")
  }
  lexmatch "aabb!" {
    ((re"^(?:a?|b){2,}" as word) + re"b", after=rest) => {
      assert_eq(word, "aab")
      assert_eq(rest, "!")
    }
    _ => fail("nullable minimum repetition lost a consuming alternative")
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
