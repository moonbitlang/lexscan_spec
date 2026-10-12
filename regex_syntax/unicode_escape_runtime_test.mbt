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
test "RX-031G runtime braced Unicode leading zeros and code point boundaries" {
  for pattern in ["^\\u{00000000041}$", "^[\\u{00000000041}]$"] {
    assert_true(@string.Regex(pattern).execute("A") is Some(_))
  }
  assert_true(
    @string.Regex("^\\u{000010FFFF}$").execute("\u{10ffff}") is Some(_),
  )
  for
    pattern in [
      "\\u{}", "\\u{110000}", "[\\u{110000}]", "\\u{FFFFFFFFFFFFFFFFFFFFFFFF}",
    ] {
    assert_true(runtime_pattern_rejected(pattern))
  }
}
