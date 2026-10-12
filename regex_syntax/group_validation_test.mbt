///|
test "RX-049 runtime capture names are unique across sequences alternatives and nesting" {
  for pattern in ["(?<x>a)(?<x>b)", "(?<x>a)|(?<x>b)", "(?<x>(?<x>a))"] {
    assert_true(runtime_pattern_rejected(pattern))
  }
  let distinct = @string.Regex("(?<x>a)(?<y>b)")
  guard distinct.execute("ab") is Some(m) else {
    fail("Expected distinct captures")
  }
  assert_eq(m.named_group("x").unwrap().to_owned(), "a")
  assert_eq(m.named_group("y").unwrap().to_owned(), "b")
}

///|
test "RX-051 runtime group depth counts open groups of every kind" {
  for opening in ["(", "(?:", "(?i:"] {
    let at_limit = opening.repeat(128) + "a" + ")".repeat(128)
    assert_true(@string.Regex(at_limit[:]).execute("a") is Some(_))
    let over_limit = opening.repeat(129) + "a" + ")".repeat(129)
    assert_true(runtime_pattern_rejected(over_limit))
  }
  assert_true(
    runtime_pattern_rejected("(?:".repeat(100_000) + "a" + ")".repeat(100_000)),
  )
  let mut named = "a"
  for i in 0..<128 {
    named = "(?<g\{i}>" + named + ")"
  }
  assert_true(@string.Regex(named[:]).execute("a") is Some(_))
  assert_true(runtime_pattern_rejected("(?<overflow>" + named + ")"))
  let sequential = "(a)".repeat(160)
  let regex = @string.Regex(sequential[:])
  assert_true(regex.execute("a".repeat(160)[:]) is Some(_))
}
