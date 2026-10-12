///|
test "RX-030 RX-031F compiled NUL and class control escapes" {
  assert_true("\u{0}" =~ re"^\0$")
  assert_true("\u{b}" =~ re"^[\v]$")
  assert_true("\u{1}" =~ re"^[\cA]$")
  assert_true("\u{1a}" =~ re"^[\cz]$")
  assert_true("é" =~ re"^[\xE9]$")
  assert_true(!("\\" =~ re"^[\v\0\cA]$"))
  assert_true(!("v" =~ re"^[\v\0\cA]$"))
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
test "RX-031 RX-031A RX-031F runtime invalid escapes raise normally" {
  for
    pattern in [
      "[\\q]", "[\\p{L}]", "[\\00]", "\\00", "\\01", "[\\01]", "[\\x4]", "[\\c1]",
      "\\c1",
    ] {
    assert_true(runtime_pattern_rejected(pattern))
  }
}
