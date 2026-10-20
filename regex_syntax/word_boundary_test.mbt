///|
test "RX-048 word boundary assertion" {
  // A boundary is between a word character and anything else.
  assert_true("a cat sat" =~ re"\bcat\b")
  assert_true(!("concat" =~ re"\bcat\b"))
  assert_true(!("cats" =~ re"\bcat\b"))
  // The start and the end of the input count as non-word characters.
  assert_true("cat" =~ re"^\bcat\b$")
  assert_true(!("" =~ re"\b"))
  assert_true(!(" " =~ re"\b"))
  // Word characters are ASCII letters, digits, and underscore only.
  assert_true("_x9" =~ re"^\b[[:word:]]+\b$")
  assert_true("é" =~ re"^\B.\B$")
  assert_true("café" =~ re"^caf\bé$")
  assert_true("😀a" =~ re"^😀\ba$")
  // Case-insensitive groups do not change which characters are word characters.
  assert_true("Cat" =~ re"(?i:\bcat\b)")
  // A sliced view is the whole input: characters outside it are not seen.
  let view = "xcatx"[1:4]
  assert_true(view =~ re"^\bcat\b$")
  // A grouped boundary may be quantified, and it consumes no input.
  assert_true("a" =~ re"^(?:\b)*a(?:\b){2}$")
}

///|
test "RX-048A non-word-boundary assertion" {
  assert_true("concat" =~ re"\Bcat\b")
  assert_true(!("a cat" =~ re"\Bcat"))
  assert_true("" =~ re"^\B$")
  assert_true("  " =~ re"^ \B $")
  assert_true("ab" =~ re"^a\Bb$")
}

///|
test "RX-048 boundaries in lexmatch and in Regex values" {
  let classify = fn(s : String) -> String {
    lexmatch s {
      (re"^if\b", after=_) => "keyword"
      (re"^[a-z_]+" as id, after=_) => "identifier \{id}"
      _ => "other"
    }
  }
  assert_eq(classify("if (x)"), "keyword")
  assert_eq(classify("if"), "keyword")
  assert_eq(classify("iffy"), "identifier iffy")
  assert_eq(classify("if_"), "identifier if_")
  let value : Regex = re"\bcat\b"
  assert_true(value.execute("a cat sat") is Some(m) && m.before() == "a ")
  assert_true(value.execute("concat") is None)
  // Inside a character class, \b is backspace.
  assert_true("\u{8}" =~ re"^[\b]$")
}
