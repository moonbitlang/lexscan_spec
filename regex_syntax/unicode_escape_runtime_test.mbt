///|
test "RX-031B runtime fixed surrogate pairs form one scalar" {
  for
    pattern in [
      "^\\uD83D\\uDE00$", "^[\\uD83D\\uDE00]$", "^\\u{1F600}$", "^😀$",
    ] {
    let regex = @string.Regex(pattern)
    guard regex.execute("😀") is Some(m) else {
      fail("Expected a non-BMP scalar match")
    }
    assert_eq(m.content().to_owned(), "😀")
    assert_true(regex.execute("") is None)
    assert_true(regex.execute("a") is None)
  }
  let range = @string.Regex("^[\\uD83D\\uDE00-\\uD83D\\uDE4F]$")
  assert_true(range.execute("😀") is Some(_))
  assert_true(range.execute("🙏") is Some(_))
  assert_true(range.execute("👐") is None)
}

///|
test "RX-031C runtime unpaired surrogate escapes match no scalar or empty string" {
  for
    pattern in [
      "\\uD800", "\\uDFFF", "\\u{D800}", "\\u{DFFF}", "[\\uD800]", "[\\u{DFFF}]",
      "\\u{D83D}\\u{DE00}",
    ] {
    let regex = @string.Regex(pattern)
    for input in ["", "a", "😀", "\u{d7ff}", "\u{e000}"] {
      assert_true(regex.execute(input) is None)
    }
  }
}

///|
test "RX-024A RX-031C runtime surrogate range endpoints retain only scalars" {
  let low = @string.Regex("^[\\u0000-\\uDFFF]$")
  assert_true(low.execute("\u{0}") is Some(_))
  assert_true(low.execute("\u{d7ff}") is Some(_))
  assert_true(low.execute("\u{e000}") is None)
  let high = @string.Regex("^[\\uD800-\\uFFFF]$")
  assert_true(high.execute("\u{e000}") is Some(_))
  assert_true(high.execute("\u{ffff}") is Some(_))
  assert_true(high.execute("\u{d7ff}") is None)
  assert_true(high.execute("😀") is None)
  let negated = @string.Regex("^[^\\uD800]$")
  for input in ["\u{0}", "\u{d7ff}", "\u{e000}", "😀", "\u{10ffff}"] {
    assert_true(negated.execute(input) is Some(_))
  }
  let mixed = @string.Regex("^[a\\uD83D]$")
  assert_true(mixed.execute("a") is Some(_))
  assert_true(mixed.execute("😀") is None)
}

///|
test "RX-030 RX-031F runtime control NUL and hex escapes agree inside and outside classes" {
  let cases = [
    ("\\v", "\u{b}"),
    ("\\0", "\u{0}"),
    ("\\cA", "\u{1}"),
    ("\\cz", "\u{1a}"),
    ("\\x41", "A"),
    ("\\xE9", "é"),
  ]
  for pair in cases {
    let (escape, input) = pair
    for pattern in ["^" + escape + "$", "^[" + escape + "]$"] {
      let regex = @string.Regex(pattern)
      assert_true(regex.execute(input) is Some(_))
      assert_true(regex.execute("\\") is None)
      assert_true(regex.execute("v") is None)
    }
  }
}

///|
test "RX-031G runtime braced Unicode leading zeros and code point boundaries" {
  for pattern in ["^\\u{00000000041}$", "^[\\u{00000000041}]$"] {
    assert_true(@string.Regex(pattern).execute("A") is Some(_))
  }
  assert_true(
    @string.Regex("^\\u{000010FFFF}$").execute("\u{10ffff}") is Some(_),
  )
}

///|
fn runtime_pattern_rejected(pattern : String) -> Bool {
  try {
    ignore(@string.Regex(pattern))
    false
  } catch {
    _ => true
  }
}

///|
test "RX-031 RX-031A RX-031F RX-031G runtime invalid escapes raise normally" {
  for
    pattern in [
      "[\\q]", "[\\p{L}]", "[\\00]", "\\00", "\\01", "[\\01]", "[\\x4]", "[\\c1]",
      "\\c1", "\\u{}", "\\u{110000}", "[\\u{110000}]", "\\u{FFFFFFFFFFFFFFFFFFFFFFFF}",
    ] {
    assert_true(runtime_pattern_rejected(pattern))
  }
}

///|
test "RX-032B RX-048 runtime invalid class punctuation and stray hyphens raise" {
  for
    pattern in [
      "[-a]", "[a-]", "[a-b-c]", "[[:digit:]-a]", "[[:digit:]-]", "[&&]", "[a&&b]",
      "[a--b]", "[!-&&]", "[&-&&]", "[!-[]", "[a-[:digit:]]", "[\\uDFFF-\\uD800]",
    ] {
    assert_true(runtime_pattern_rejected(pattern))
  }
}

///|
test "RX-025B runtime escaped class punctuation stays literal" {
  for input in [":", "&", "-"] {
    assert_true(@string.Regex("^[\\:\\&\\-]$").execute(input) is Some(_))
  }
  assert_true(@string.Regex("^[a&b]$").execute("&") is Some(_))
  assert_true(@string.Regex("^[!-\\[]$").execute("[") is Some(_))
  assert_true(@string.Regex("^[!-\\&&]$").execute("&") is Some(_))
}

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
test "RX-050 runtime unterminated ranges raise instead of aborting" {
  for pattern in ["[a-", "[a-b", "[\\:z-"] {
    assert_true(runtime_pattern_rejected(pattern))
  }
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
