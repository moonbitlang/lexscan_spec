///|
const PREFIX = re"ab"

///|
fn expect_bool(_value : Bool) -> Unit {
  ()
}

///|
test "RM-001 RM-002 RM-004 RM-008A String and sliced StringView targets" {
  let string_result : Bool = "zabc" =~ re"abc"
  let view_result : Bool = "--abc++"[2:5] =~ re"^abc$"
  expect_bool(string_result)
  expect_bool(view_result)
  assert_true(string_result)
  assert_true(view_result)

  let backing = "--xaby++"
  let slice = backing[2:6]
  if slice =~ (re"ab", before=before, after=after) {
    assert_eq(before, "x")
    assert_eq(after, "y")
  } else {
    fail("slice-boundary match failed")
  }
}

///|
test "RM-005 RM-006 RM-007 first-match search priorities" {
  if "xxababa!" =~ (re"ab" as selected, before=before, after=after) {
    assert_eq(before, "xx")
    assert_eq(selected, "ab")
    assert_eq(after, "aba!")
  } else {
    fail("unanchored search did not select earliest start")
  }
  if "ab" =~ (re"(a|ab)" as selected, before=_, after=_) {
    assert_eq(selected, "a")
  } else {
    fail("ordered alternative did not match")
  }
  if "aaaa" =~ (re"a+" as greedy, before=_, after=_) {
    assert_eq(greedy, "aaaa")
  } else {
    fail("greedy match failed")
  }
  if "aaaa" =~ (re"a+?" as shortest, before=_, after=_) {
    assert_eq(shortest, "a")
  } else {
    fail("lazy match failed")
  }
}

///|
test "RM-006A earliest start dominates alternative order" {
  if "ba" =~ (re"a|b" as selected, before=before, after=after) {
    assert_eq(before, "")
    assert_eq(selected, 'b')
    assert_eq(after, "a")
  } else {
    fail("earliest alternative start was not selected")
  }
}

///|
test "RM-008 RM-009 RM-010 RM-011 match bindings" {
  if "xaby" =~ (PREFIX as whole, before=before, after=after) {
    assert_eq(before, "x")
    assert_eq(whole, "ab")
    assert_eq(after, "y")
  } else {
    fail("before/after binding failed")
  }
  if "ab" =~ (re"^ab$", before=before, after=after) {
    assert_eq(before, "")
    assert_eq(after, "")
  } else {
    fail("anchored empty boundaries failed")
  }
  assert_true("xaby" =~ (PREFIX, before=_, after=_))
  if "xaby" =~ (PREFIX, before~, after~) {
    assert_eq(before, "x")
    assert_eq(after, "y")
  } else {
    fail("binding shorthand failed")
  }
}

///|
test "RM-011A binding tuple grammar and label order" {
  if "xaby" =~ (PREFIX, after~, before~) {
    assert_eq(before, "x")
    assert_eq(after, "y")
  } else {
    fail("reordered shorthand bindings failed")
  }
  if "xaby" =~ (PREFIX, before~) {
    assert_eq(before, "x")
  } else {
    fail("before shorthand failed")
  }
  if "xaby" =~ (PREFIX, after~) {
    assert_eq(after, "y")
  } else {
    fail("after shorthand failed")
  }
  assert_true("ab" =~ PREFIX)
  assert_true("ab" =~ PREFIX)
}

///|
test "RM-015 RM-016 conditional binding scope" {
  assert_true(
    "abc" =~ (re"^a" as head, after=tail) && head == 'a' && tail == "bc",
  )
  if "abc" =~ (re"^a" as head, after=tail) {
    assert_eq(head, 'a')
    assert_eq(tail, "bc")
  } else {
    fail("true if branch not selected")
  }
}

///|
test "RM-015A multiple regex bindings in nested conjunctions" {
  if "ab" =~ (re"^a" as first, after=tail) &&
    tail =~ (re"^b$" as second) &&
    first == 'a' &&
    second == 'b' {
    assert_eq(first, 'a')
    assert_eq(second, 'b')
  } else {
    fail("conjoined regex bindings were not jointly available")
  }
}

///|
fn guard_scope(input : String) -> StringView {
  guard input =~ (re"[0-9]+" as digits, before=_, after=_) else { return "" }
  digits
}

///|
test "RM-017 guard and while binding scope" {
  assert_eq(guard_scope("x123y"), "123")
  let mut iterations = 0
  while iterations == 0 && "ab" =~ (re"^a" as head, after=tail) {
    assert_eq(head, 'a')
    assert_eq(tail, "b")
    iterations += 1
  }
  assert_eq(iterations, 1)
}

///|
test "RM-017A for condition update and body scope" {
  let mut observed = ""
  for i = 0
      i < 1 && "ab" =~ (re"^a" as head, after=tail)
      i = i + head.to_int() - 96 {
    observed = tail.to_owned()
    assert_eq(head, 'a')
  }
  assert_eq(observed, "b")
}

///|
test "RM-019 RM-020 target evaluation and failure paths" {
  let mut evaluations = 0
  fn target() -> String {
    evaluations += 1
    "abc"
  }
  assert_true(target() =~ re"b")
  assert_eq(evaluations, 1)

  assert_true(!(target() =~ re"^z"))
  assert_eq(evaluations, 2)

  let mut success_body_runs = 0
  if "abc" =~ re"^z" {
    success_body_runs += 1
  }
  assert_eq(success_body_runs, 0)
}

///|
test "RM-020A bindings survive a temporary String target" {
  fn make_target() -> String {
    "xabc!"
  }
  let captured : (StringView, StringView, StringView)? = if make_target() =~ (
      re"abc" as word,
      before=before,
      after=after,
    ) {
    Some((before, word, after))
  } else {
    None
  }
  match captured {
    Some((before, word, after)) => {
      assert_eq(before, "x")
      assert_eq(word, "abc")
      assert_eq(after, "!")
    }
    None => fail("temporary regex-match target did not match")
  }
}

///|
test "RM-022 no direct core string import is required" {
  assert_true("abc" =~ re"abc")
}

///|
test "RM-023 regex-match condition precedence and target grouping" {
  assert_true("a" =~ re"^a$" && true)
  assert_true(!("a" =~ re"^z$") || true)
  assert_true(("a" + "b") =~ re"^ab$")
}
