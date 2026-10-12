///|
test "RX-031G compiled braced Unicode escapes allow arbitrary leading zeros" {
  assert_true("A" =~ re"^\u{00000000041}$")
  assert_true("A" =~ re"^[\u{00000000041}]$")
  assert_true("\u{10ffff}" =~ re"^\u{000010FFFF}$")
}

///|
test "RX-031B compiled fixed surrogate pairs form one scalar including range endpoints" {
  assert_true("😀" =~ re"^\uD83D\uDE00$")
  assert_true("😀" =~ re"^[\uD83D\uDE00]$")
  assert_true("😀" =~ re"^[\uD83D\uDE00-\uD83D\uDE4F]$")
  assert_true("🙏" =~ re"^[\uD83D\uDE00-\uD83D\uDE4F]$")
  assert_true(!("👐" =~ re"^[\uD83D\uDE00-\uD83D\uDE4F]$"))
}

///|
test "RX-031C compiled unpaired escapes match empty sets and delimit scalar ranges" {
  assert_true(!("a" =~ re"\uD800"))
  assert_true(!("" =~ re"\u{DFFF}"))
  assert_true(!("😀" =~ re"[\uD83D]"))
  assert_true(!("😀" =~ re"\u{D83D}\u{DE00}"))
  assert_true("a" =~ re"^[a\uD83D]$")
  assert_true("\u{d7ff}" =~ re"^[\u0000-\uDFFF]$")
  assert_true(!("\u{e000}" =~ re"^[\u0000-\uDFFF]$"))
  assert_true("\u{e000}" =~ re"^[\uD800-\uFFFF]$")
  assert_true(!("\u{d7ff}" =~ re"^[\uD800-\uFFFF]$"))
  assert_true("😀" =~ re"^[^\uD800]$")
}

///|
test "RX-052 first-class literal serialization preserves surrogate-ended ranges" {
  let regex : Regex = re"^[^\uD7FF]$"
  assert_true(regex.execute("\u{e000}") is Some(_))
  assert_true(regex.execute("😀") is Some(_))
  assert_true(regex.execute("\u{d7ff}") is None)
  let range : Regex = re"^[\u0000-\uDFFF]$"
  assert_true(range.execute("\u{d7ff}") is Some(_))
  assert_true(range.execute("\u{e000}") is None)
}
