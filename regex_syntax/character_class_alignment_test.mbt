///|
test "RX-025B compiled escaped class punctuation stays literal" {
  assert_true(":" =~ re"^[\:]$")
  assert_true("&" =~ re"^[a&b]$")
  assert_true("&" =~ re"^[!-\&&]$")
  assert_true("[" =~ re"^[!-\[]$")
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
test "RX-050 runtime unterminated ranges raise instead of aborting" {
  for pattern in ["[a-", "[a-b", "[\\:z-"] {
    assert_true(runtime_pattern_rejected(pattern))
  }
}
