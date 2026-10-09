///|
test "RX-021 RX-021A positive negated empty and full classes" {
  assert_true("b" =~ re"^[abc]$")
  assert_true(!("d" =~ re"^[abc]$"))
  assert_true("d" =~ re"^[^abc]$")
  assert_true(!("b" =~ re"^[^abc]$"))
  assert_true(!("a" =~ re"^[]$"))
  assert_true("a" =~ re"^[^]$")
  assert_true("😀" =~ re"^[^]$")
  assert_true("\n" =~ re"^[^]$")
}

///|
test "RX-022 scalar range endpoints and Unicode ranges" {
  assert_true("a" =~ re"^[a-z]$")
  assert_true("z" =~ re"^[a-z]$")
  assert_true(!("A" =~ re"^[a-z]$"))
  assert_true("α" =~ re"^[α-ω]$")
  assert_true("ω" =~ re"^[α-ω]$")
  assert_true(!("Α" =~ re"^[α-ω]$"))
  assert_true("😀" =~ re"^[😀-🙏]$")
  assert_true("🙏" =~ re"^[😀-🙏]$")
}

///|
test "RX-022A literal colon ranges and escaped hyphen distinction" {
  for scalar in [":", ";", "<", "=", ">", "?", "@"] {
    assert_true(scalar =~ re"^[:-@]$")
  }
  assert_true(!("/" =~ re"^[:-@]$"))
  assert_true(!("A" =~ re"^[:-@]$"))
  assert_true(!("-" =~ re"^[:-@]$"))
  for scalar in [":", "-", "@"] {
    assert_true(scalar =~ re"^[:\-@]$")
  }
  assert_true(!(";" =~ re"^[:\-@]$"))
}

///|
test "RX-024A scalar range crossing the surrogate interval" {
  assert_true("\u{d7ff}" =~ re"^[\u{d7ff}-\u{e000}]$")
  assert_true("\u{e000}" =~ re"^[\u{d7ff}-\u{e000}]$")
  assert_true(!("\u{d7fe}" =~ re"^[\u{d7ff}-\u{e000}]$"))
  assert_true(!("\u{e001}" =~ re"^[\u{d7ff}-\u{e000}]$"))
}

///|
test "RX-025 RX-026 all POSIX classes and ASCII boundaries" {
  assert_true("\u{0}" =~ re"^[[:ascii:]]$")
  assert_true("\u{7f}" =~ re"^[[:ascii:]]$")
  assert_true(!("é" =~ re"^[[:ascii:]]$"))
  assert_true("A" =~ re"^[[:upper:]]$")
  assert_true(!("a" =~ re"^[[:upper:]]$"))
  assert_true("z" =~ re"^[[:lower:]]$")
  assert_true("Q" =~ re"^[[:alpha:]]$")
  assert_true(!("é" =~ re"^[[:alpha:]]$"))
  assert_true("7" =~ re"^[[:alnum:]]$")
  assert_true("0" =~ re"^[[:digit:]]$")
  assert_true("F" =~ re"^[[:xdigit:]]$")
  assert_true("f" =~ re"^[[:xdigit:]]$")
  assert_true(!("g" =~ re"^[[:xdigit:]]$"))
  assert_true(" " =~ re"^[[:blank:]]$")
  assert_true("\t" =~ re"^[[:blank:]]$")
  assert_true(!("\n" =~ re"^[[:blank:]]$"))
  for whitespace in ["\t", "\n", "\u{b}", "\u{c}", "\r", " "] {
    assert_true(whitespace =~ re"^[[:space:]]$")
  }
  assert_true("_" =~ re"^[[:word:]]$")
  assert_true("9" =~ re"^[[:word:]]$")
  assert_true(!("é" =~ re"^[[:word:]]$"))
}

///|
test "RX-025A class unions literals and negated POSIX classes" {
  assert_true("A" =~ re"^[a-zA-Z0-9_]$")
  assert_true("7" =~ re"^[a-zA-Z0-9_]$")
  assert_true("^" =~ re"^[a^]$")
  assert_true(":" =~ re"^[:]$")
  assert_true("x" =~ re"^[^[:digit:]]$")
  assert_true(!("7" =~ re"^[^[:digit:]]$"))
  assert_true("\u{8}" =~ re"^[\b]$")
  assert_true("-" =~ re"^[\-a]$")
  assert_true("-" =~ re"^[a\-]$")
  assert_true("B" =~ re"^[\x41-\x43]$")
}

///|
test "RX-025B escaped regex punctuation is literal in classes" {
  assert_true("[" =~ re"^[\[]$")
  assert_true("]" =~ re"^[\]]$")
  assert_true("\\" =~ re"^[\\]$")
  assert_true("^" =~ re"^[\^]$")
  assert_true("$" =~ re"^[\$]$")
  assert_true("." =~ re"^[\.]$")
  assert_true("*" =~ re"^[\*]$")
  assert_true("+" =~ re"^[\+]$")
  assert_true("?" =~ re"^[\?]$")
  assert_true("(" =~ re"^[\(]$")
  assert_true(")" =~ re"^[\)]$")
  assert_true("}" =~ re"^[\}]$")
  assert_true("|" =~ re"^[\|]$")
  assert_true("/" =~ re"^[\/]$")
  assert_true("\"" =~ re"^[\"]$")
}

///|
#warnings("-deprecated_syntax")
test "RX-029 deprecated shorthand classes retain matching behavior" {
  assert_true("5" =~ re"^\d$")
  assert_true("x" =~ re"^\D$")
  assert_true("\n" =~ re"^\s$")
  assert_true("x" =~ re"^\S$")
  assert_true("_" =~ re"^\w$")
  assert_true("!" =~ re"^\W$")
}

///|
test "RX-030 RX-031B escapes and non-BMP scalar values" {
  assert_true("\u{c}" =~ re"^\f$")
  assert_true("\n" =~ re"^\n$")
  assert_true("\r" =~ re"^\r$")
  assert_true("\t" =~ re"^\t$")
  assert_true("\u{b}" =~ re"^\v$")
  assert_true("\u{1}" =~ re"^\cA$")
  assert_true("\u{1}" =~ re"^\ca$")
  assert_true("\u{1a}" =~ re"^\cZ$")
  assert_true("\u{0}" =~ re"^[\0]$")
  assert_true("A" =~ re"^\x41$")
  assert_true("A3" =~ re"^\x413$")
  assert_true("\u{4f60}" =~ re"^\u4f60$")
  assert_true("😀" =~ re"^\u{1f600}$")
  assert_true("😀" =~ re"^😀$")
}

///|
test "RX-031C Unicode scalar boundary values" {
  assert_true("\u{d7ff}" =~ re"^\uD7FF$")
  assert_true("\u{e000}" =~ re"^\uE000$")
  assert_true("\u{10ffff}" =~ re"^\u{10FFFF}$")
}

///|
test "RX-030 escaped regex punctuation remains literal" {
  assert_true("^" =~ re"^\^$")
  assert_true("$" =~ re"^\$$")
  assert_true("\\" =~ re"^\\$")
  assert_true("." =~ re"^\.$")
  assert_true("*" =~ re"^\*$")
  assert_true("+" =~ re"^\+$")
  assert_true("?" =~ re"^\?$")
  assert_true("(" =~ re"^\($")
  assert_true(")" =~ re"^\)$")
  assert_true("[" =~ re"^\[$")
  assert_true("]" =~ re"^\]$")
  assert_true("}" =~ re"^\}$")
  assert_true("|" =~ re"^\|$")
  assert_true("/" =~ re"^\/$")
  assert_true("\"" =~ re"^\"$")
}

///|
test "RX-047 MoonBit literal brace and class hyphen spellings" {
  assert_true("{" =~ re"^[{]$")
  assert_true("}" =~ re"^[}]$")
  assert_true("-" =~ re"^[\-]$")
  assert_true("+" =~ re"^[+\-]$")
}

///|
test "RX-034A case-insensitive class nesting and scope" {
  assert_true("F" =~ re"^(?i:[a-f])$")
  assert_true("AbC" =~ re"^(?i:a(?:b))C$")
  assert_true(!("ABC" =~ re"^(?i:a(?:b))c$"))
}
