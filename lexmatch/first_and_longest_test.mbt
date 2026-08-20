///|
test "LM-001 String and StringView targets" {
  inspect(
    lexmatch "abc" {
      re"^abc$" => 1
      _ => 0
    },
    content="1",
  )
  inspect(
    lexmatch "--abc++"[2:5] {
      re"^abc$" => 1
      _ => 0
    },
    content="1",
  )
}

///|
test "LM-003 LM-004 omitted and explicit first are equivalent" {
  let omitted = lexmatch "ab" {
    (re"^a", after=_) => 1
    _ => 0
  }
  let explicit = lexmatch "ab" with first {
    (re"^a", after=_) => 1
    _ => 0
  }
  assert_eq(omitted, explicit)
}

///|
#warnings("-unused_lexcase")
test "LM-006 LM-007 source case order dominates length and position" {
  inspect(
    lexmatch "ab" {
      (re"^a", after=_) => "short"
      (re"^ab", after=_) => "long"
      _ => "none"
    },
    content="short",
  )
  inspect(
    lexmatch "ba" {
      (re"a", before=_, after=_) => "first-case"
      (re"b", before=_, after=_) => "earlier-position"
      _ => "none"
    },
    content="first-case",
  )
}

///|
test "LM-008 LM-009 LM-010 unanchored lazy search and bindings" {
  lexmatch "xxaaabyy" {
    ((re"a*?" as prefix) + re"b", before=before, after=after) => {
      assert_eq(before, "xx")
      assert_eq(prefix, "aaa")
      assert_eq(after, "yy")
    }
    _ => fail("first-mode unanchored search failed")
  }
}

///|
test "LM-008A first retries later cases after complete failure" {
  inspect(
    lexmatch "b" {
      (re"^a", after=_) => "a"
      re"^b$" => "b"
      _ => "none"
    },
    content="b",
  )
  inspect(
    lexmatch "xxb" {
      (re"a", before=_, after=_) => "a"
      (re"b", before=_, after=_) => "b"
      _ => "none"
    },
    content="b",
  )
}

///|
test "LM-010A first binding tuple grammar and longest shorthand" {
  lexmatch "xaby" with first {
    (re"ab", after~, before~) => {
      assert_eq(before, "x")
      assert_eq(after, "y")
    }
    _ => fail("reordered first bindings failed")
  }
  lexmatch "aby" with longest {
    (re"^ab", after~) => assert_eq(after, "y")
    _ => fail("longest after shorthand failed")
  }
}

///|
test "LM-014 semantic anchoring through constants and alternatives" {
  inspect(
    lexmatch "abc" with longest {
      (@patterns.QUALIFIED_ANCHORED_WORD | re"^[0-9]+", after=_) => 1
      _ => 0
    },
    content="1",
  )
  inspect(
    lexmatch "aa" with longest {
      (re"(^a)+", after=_) => 1
      _ => 0
    },
    content="1",
  )
}

///|
#warnings("-unused_lexcase")
test "LM-015 LM-016 LM-018 longest selection and tie order" {
  inspect(
    lexmatch "ifx!" with longest {
      (re"^if", after=_) => "keyword"
      (re"^[a-z]+", after=tail) => "identifier:\{tail}"
      _ => "other"
    },
    content="identifier:!",
  )
  inspect(
    lexmatch "ab" with longest {
      (re"^a.", after=_) => "first"
      (re"^ab", after=_) => "second"
      _ => "none"
    },
    content="first",
  )
}

///|
#warnings("-unused_lexcase")
test "LM-015A longest prefers consuming candidates and preserves captures" {
  lexmatch "aaa" with longest {
    (re"^", after=_) => fail("empty match won over consuming match")
    ((re"^aa" as left) + (re"a" as right), after=_) => {
      assert_eq(left, "aa")
      assert_eq(right, 'a')
    }
    _ => fail("longest consuming case did not match")
  }
}

///|
test "LM-015B ambiguous maximal captures form one coherent path" {
  lexmatch "aa" with longest {
    (((re"^(a|aa)" as left) + (re"a?" as right)) as whole) + re"$" => {
      assert_eq(whole, "aa")
      assert_true(
        (left == "a" && right == "a") || (left == "aa" && right == ""),
      )
    }
    _ => fail("ambiguous maximal capture pattern did not match")
  }
}

///|
test "LM-015C longest retries after a partial-prefix failure" {
  inspect(
    lexmatch "ac" with longest {
      (re"^ab", after=_) => "ab"
      re"^ac$" => "ac"
      _ => "none"
    },
    content="ac",
  )
}

///|
test "LM-019 LM-020 LM-020A result typing body and target evaluation" {
  let mut first_runs = 0
  let mut second_runs = 0
  let result : Int = lexmatch "a" {
    re"^a$" => {
      first_runs += 1
      10
    }
    re"^b$" => {
      second_runs += 1
      20
    }
    _ => 30
  }
  assert_eq(result, 10)
  assert_eq(first_runs, 1)
  assert_eq(second_runs, 0)

  let mut target_runs = 0
  fn target() -> String {
    target_runs += 1
    "a"
  }
  inspect(
    lexmatch target() {
      re"^a$" => 1
      _ => 0
    },
    content="1",
  )
  assert_eq(target_runs, 1)

  fn missing_target() -> String {
    target_runs += 1
    "missing"
  }
  inspect(
    lexmatch missing_target() {
      re"^a$" => 1
      _ => 0
    },
    content="0",
  )
  assert_eq(target_runs, 2)
}

///|
test "LM-020B captures survive a temporary String target" {
  fn make_target() -> String {
    "xabc!"
  }
  let captured : (StringView, StringView, StringView)? = lexmatch
    make_target() {
    (re"abc" as word, before=before, after=after) => Some((before, word, after))
    _ => None
  }
  match captured {
    Some((before, word, after)) => {
      assert_eq(before, "x")
      assert_eq(word, "abc")
      assert_eq(after, "!")
    }
    None => fail("temporary target did not match")
  }
}

///|
#warnings("-unused_lexcase")
test "LM-031 empty input and zero-width anchors" {
  inspect(
    lexmatch "" {
      (re"", before=_, after=_) => 1
      _ => 0
    },
    content="1",
  )
  inspect(
    lexmatch "" {
      (re"^", after=_) => 1
      _ => 0
    },
    content="1",
  )
  inspect(
    lexmatch "" {
      (re"$", before=_) => 1
      _ => 0
    },
    content="1",
  )
  inspect(
    lexmatch "" {
      re"^$" => 1
      _ => 0
    },
    content="1",
  )
  inspect(
    lexmatch "x" {
      re"^$" => 1
      _ => 0
    },
    content="0",
  )
}

///|
#warnings("-unused_lexcase")
test "LM-031A zero-width matches on non-empty input" {
  lexmatch "abc" {
    (re"^" as start, after=after) => {
      assert_eq(start, "")
      assert_eq(after, "abc")
    }
    _ => fail("start anchor did not match")
  }
  lexmatch "abc" {
    (re"$" as end_, before=before) => {
      assert_eq(before, "abc")
      assert_eq(end_, "")
    }
    _ => fail("end anchor did not match")
  }
  lexmatch "abc" {
    (re"" as empty, before=before, after=after) => {
      assert_eq(before, "")
      assert_eq(empty, "")
      assert_eq(after, "abc")
    }
    _ => fail("empty regex did not match")
  }
}

///|
test "LM-032 non-BMP capture and UTF-16 suffix boundaries" {
  lexmatch "x😀y" {
    (re"😀" as face, before=before, after=after) => {
      assert_eq(before, "x")
      assert_eq(face, '😀')
      assert_eq(after, "y")
      assert_eq(before.length(), 1)
      assert_eq(after.length(), 1)
    }
    _ => fail("non-BMP lexmatch failed")
  }
}
