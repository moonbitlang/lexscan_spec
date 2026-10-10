///|
test "RX-031B runtime parser rejects surrogate escapes and accepts scalar escapes" {
  for
    pattern in [
      "\\uD800", "\\uDFFF", "\\u{D800}", "\\u{DFFF}", "^\\uD83D\\uDE00$", "^[\\uD83D\\uDE00]$",
      "[\\uD800]", "[\\u{DFFF}]",
    ] {
    let rejected = try {
      ignore(@string.Regex(pattern))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  for pattern in ["^\\u{1F600}$", "^😀$", "^[\\u{1F600}]$"] {
    let regex = @string.Regex(pattern)
    guard regex.execute("😀") is Some(m) else {
      fail("Expected a non-BMP scalar match")
    }
    assert_eq(m.content().to_owned(), "😀")
  }
}
