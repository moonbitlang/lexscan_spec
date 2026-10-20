///|
test "RX-049A braced escapes take one to six hexadecimal digits" {
  assert_true("A" =~ re"^\u{41}$")
  assert_true("A" =~ re"^\u{000041}$")
  assert_true("\u{10ffff}" =~ re"^\u{10FFFF}$")
  assert_true("A" =~ re"^[\u{000041}]$")
}

///|
test "RX-049B escaped ampersand and colon in a class" {
  assert_true("&" =~ re"^[\&]$")
  assert_true(":" =~ re"^[\:]$")
  assert_true("a&&b" =~ re"^[a\&\&b]+$")
  assert_true(!("\\" =~ re"^[\&\:]$"))
  // The range from & to : holds both and what is between.
  assert_true("&0:" =~ re"^[\&-\:]+$")
  assert_true(!("%" =~ re"^[\&-\:]$"))
  // An escaped colon at either end does not make a bare POSIX class.
  assert_true(":a:" =~ re"^[\:a\:]+$")
  assert_true(":a" =~ re"^[:a\:]+$")
}

///|
test "RX-049C ampersands that are not a class set operation" {
  assert_true("&" =~ re"^[&&a]$")
  assert_true("a" =~ re"^[&&a]$")
  assert_true(!("&" =~ re"^[^&&a]$"))
  assert_true("&" =~ re"^[a&b]$")
  assert_true("&" =~ re"^[a&]$")
}

///|
test "RX-049E classes that are not a bare POSIX class" {
  assert_true(":" =~ re"^[::]$")
  assert_true("a" =~ re"^[^::]$")
  assert_true(!(":" =~ re"^[^::]$"))
  assert_true("b" =~ re"^[:a-z]$")
  assert_true(":" =~ re"^[:a-z]$")
  assert_true("!" =~ re"^[:!-:]$")
  assert_true(":" =~ re"^[:-:]$")
}
