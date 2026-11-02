///|
const HIGH = reb"[\x80-\xff]"

///|
const HIGH_THEN_A : BytesRegex = HIGH + reb"a"

///|
const X_OR_Y : BytesRegex = reb"x" | reb"y"

///|
fn expect_bytes_view(_value : BytesView) -> Unit {
  ()
}

///|
fn expect_byte(_value : Byte) -> Unit {
  ()
}

///|
test "BX-001 reb literals are BytesRegex values without a bytes import" {
  let regex : BytesRegex = reb"a+"
  ignore(regex)
  let composed : BytesRegex = HIGH_THEN_A
  ignore(composed)
}

///|
test "BX-002 =~ on Bytes and sliced BytesView targets" {
  let data : Bytes = b"zGET /x"
  let found : Bool = data =~ reb"GET"
  assert_true(found)
  assert_true(!(data =~ reb"^GET"))
  let backing = b"--xaby++"
  let slice : BytesView = backing[2:6]
  if slice =~ (reb"ab", before~, after~) {
    expect_bytes_view(before)
    expect_bytes_view(after)
    assert_eq(before, b"x")
    assert_eq(after, b"y")
  } else {
    fail("slice match failed")
  }
  assert_true(backing[2:5] =~ reb"^xab$")
  assert_true(!(backing[2:5] =~ reb"^-"))
}

///|
test "BX-003 first-strategy lexmatch over bytes" {
  let first = fn(input : BytesView) -> Int32 {
    lexmatch input {
      (reb"^a", after=_) => 1
      (reb"^(ab|b)", after=_) => 2
      _ => 0
    }
  }
  assert_eq(first(b"ab"), 1)
  assert_eq(first(b"b"), 2)
  assert_eq(first(b"c"), 0)
  let search = fn(input : Bytes) -> (String, BytesView, BytesView) {
    lexmatch input {
      (reb"a", before~, after~) => ("a-case", before, after)
      (reb"b", before~, after~) => ("b-case", before, after)
      whole => ("none", whole, whole)
    }
  }
  assert_eq(search(b"bab"), ("a-case", b"b", b"b"))
  assert_eq(search(b"zbxb"), ("b-case", b"z", b"xb"))
  assert_eq(search(b"z"), ("none", b"z", b"z"))
}

///|
test "BX-004 longest-strategy lexmatch over bytes" {
  let longest = fn(input : BytesView) -> Int32 {
    lexmatch input with longest {
      (reb"^if", after=_) => 1
      (reb"^[a-z]+", after=_) => 2
      (reb"^[0-9]", after=_) => 3
      _ => 0
    }
  }
  assert_eq(longest(b"if"), 1)
  assert_eq(longest(b"ifx"), 2)
  assert_eq(longest(b"ab"), 2)
  assert_eq(longest(b"9"), 3)
  assert_eq(longest(b"-"), 0)
}

///|
test "BX-005 dot and classes match single bytes" {
  assert_true(b"\xff" =~ reb"^.$")
  assert_true(b"\n" =~ reb"^.$")
  assert_true(!(b"\xc3\xa9" =~ reb"^.$"))
  assert_true(b"\x80" =~ reb"^[^a]$")
  assert_true(b"\x00" =~ reb"^[^]$")
  assert_true(!(b"a" =~ reb"[]"))
  assert_true(!(b"" =~ reb"[]"))
}

///|
test "BX-006 hexadecimal byte escapes" {
  assert_true(b"\xef\xbb\xbf" =~ reb"^\xef\xbb\xbf$")
  assert_true(b"\xEF" =~ reb"^\xEF$")
  assert_true(b"\xef" =~ reb"^\xEF$")
  if b"\xff\x80a" =~ (reb"^[\x80-\xff]+" as run, after=rest) {
    assert_eq(run, b"\xff\x80")
    assert_eq(rest, b"a")
  } else {
    fail("byte range failed")
  }
  assert_true(b"A" =~ reb"^\x41$")
}

///|
test "BX-007 ASCII-only case folding and word bytes" {
  assert_true(b"Content-LENGTH: 1" =~ reb"^(?i:content-length): ")
  assert_true(!(b"\xc9" =~ reb"(?i:\xe9)"))
  assert_true(b"\xe9" =~ reb"(?i:\xe9)")
  if b"\xe9a!" =~ (reb"\ba\b", before~, after~) {
    assert_eq(before, b"\xe9")
    assert_eq(after, b"!")
  } else {
    fail("word boundary after a high byte failed")
  }
  assert_true(b"a" =~ reb"^\ba\b$")
  assert_true(!(b"" =~ reb"\b"))
  assert_true(b"a\xff" =~ reb"^[[:word:]][^[:word:]]$")
  assert_true(b"\x7f" =~ reb"^[[:ascii:]]$")
  assert_true(!(b"\x80" =~ reb"^[[:ascii:]]$"))
}

///|
test "BX-008 Byte and BytesView captures" {
  if b"zz\xffq" =~ (reb"[\x80-\xff]" as high, before~, after~) {
    expect_byte(high)
    assert_eq(high, b'\xff')
    assert_eq(before, b"zz")
    assert_eq(after, b"q")
  } else {
    fail("single-byte class capture failed")
  }
  if b"\xc3\xa9" =~ (reb"^." as first, after=rest) {
    expect_byte(first)
    assert_eq(first, b'\xc3')
    assert_eq(rest, b"\xa9")
  } else {
    fail("dot capture failed")
  }
  if b"ab" =~ (reb"^.$" as one) {
    expect_byte(one)
    fail("^.$ matched two bytes")
  }
  if b"GET /" =~ (reb"^(GET|POST)" as verb, after=_) {
    expect_bytes_view(verb)
    assert_eq(verb, b"GET")
  } else {
    fail("multi-byte capture failed")
  }
  if b"a" =~ (reb"^a?" as maybe, after=_) {
    expect_bytes_view(maybe)
    assert_eq(maybe, b"a")
  } else {
    fail("nullable capture failed")
  }
  let catchall = fn(input : Bytes) -> BytesView {
    lexmatch input {
      (reb"^[0-9]+" as digits, after=_) => digits
      whole => whole
    }
  }
  assert_eq(catchall(b"12x"), b"12")
  assert_eq(catchall(b"ab"), b"ab")
}

///|
test "BX-009 BytesRegex constants as pattern atoms" {
  assert_true(b"y" =~ X_OR_Y)
  assert_true(!(b"z" =~ X_OR_Y))
  if b"\x90a!" =~ (HIGH_THEN_A as pair, after=rest) {
    assert_eq(pair, b"\x90a")
    assert_eq(rest, b"!")
  } else {
    fail("composed constant failed")
  }
  if b"\xffz" =~ (@patterns.QUALIFIED_HIGH_BYTE as high, after=_) {
    expect_byte(high)
    assert_eq(high, b'\xff')
  } else {
    fail("qualified constant failed")
  }
  assert_true(b"POST" =~ (reb"^" + @patterns.QUALIFIED_BYTES_VERB + reb"$"))
}

///|
test "BX-018 literal forms keep the matching model" {
  let evaluated = Ref(0)
  let target = fn(bytes : Bytes) -> Bytes {
    evaluated.val += 1
    bytes
  }
  // One literal: exact, prefix, suffix and search, short and long.
  assert_true(target(b"GET") =~ reb"^GET$")
  assert_true(!(target(b"GETX") =~ reb"^GET$"))
  assert_eq(evaluated.val, 2)
  let long = b"0123456789012345678901234567890123456789"
  assert_true(long =~ reb"^0123456789012345678901234567890123456789$")
  assert_true(long[1:] =~ reb"^123456789012345678901234567890123456789")
  assert_true(!(long[1:] =~ reb"^0123456789012345678901234567890123456789"))
  if b"a.mbt" =~ (reb"\.mbt$", before=stem) {
    assert_eq(stem, b"a")
  } else {
    fail("suffix literal failed")
  }
  if b"xxGETyy"[1:] =~ (reb"GET", before~, after~) {
    assert_eq(before, b"x")
    assert_eq(after, b"yy")
  } else {
    fail("searched literal failed")
  }
  // A set of literals: earliest alternative under first match, longest under
  // longest match and for a suffix.
  if b"abc" =~ (reb"^(a|abc)", after=rest) {
    assert_eq(rest, b"bc")
  } else {
    fail("first-match prefix set failed")
  }
  let longest = fn(input : BytesView) -> BytesView? {
    lexmatch input with longest {
      (reb"^(a|abc)", after=rest) => Some(rest)
      _ => None
    }
  }
  assert_eq(longest(b"abcd"), Some(b"d"))
  if b"x.mbti" =~ (reb"(i|\.mbti)$", before=stem) {
    assert_eq(stem, b"x")
  } else {
    fail("suffix set failed")
  }
  assert_true(b"\xff\x01" =~ reb"^(\xff\x01|\xff\x02)$")
  assert_true(!(b"\xff\x03" =~ reb"^(\xff\x01|\xff\x02)$"))
  // Ignoring ASCII case.
  assert_true(b"HoSt: x" =~ reb"^(?i:host|accept): ")
  assert_true(!(b"hos: x" =~ reb"^(?i:host|accept): "))
  // Several literal cases: an earlier case wins over a longer later one.
  let dispatch = fn(input : BytesView) -> (Int32, BytesView) {
    lexmatch input {
      (reb"^GET ", after=rest) => (1, rest)
      (reb"^(POST|PUT) ", after=rest) => (2, rest)
      (reb"^G", after=rest) => (3, rest)
      (reb"^\r\n", after=_) => (4, input)
      rest => (0, rest)
    }
  }
  assert_eq(dispatch(b"GET /"), (1, b"/"))
  assert_eq(dispatch(b"PUT /a"), (2, b"/a"))
  assert_eq(dispatch(b"GEX"), (3, b"EX"))
  assert_eq(dispatch(b"\r\nbody"), (4, b"\r\nbody"))
  assert_eq(dispatch(b"-GET"), (0, b"-GET"))
  assert_eq(dispatch(b"zGET /"[1:]), (1, b"/"))
  let shadow = fn(input : Bytes) -> Int32 {
    lexmatch input {
      (reb"^a", after=_) => 1
      (reb"^(ab|b)", after=_) => 2
      _ => 0
    }
  }
  assert_eq(shadow(b"ab"), 1)
  assert_eq(shadow(b"b"), 2)
  // Every lowering evaluates its target once, on success and on failure.
  let once = fn(matched : Bool, expected : Bool) raise {
    assert_eq(matched, expected)
    assert_eq(evaluated.val, 1)
    evaluated.val = 0
  }
  evaluated.val = 0
  once(target(b"GETx") =~ reb"^GET", true)
  once(target(b"xGET") =~ reb"^GET", false)
  once(target(b"a.mbt") =~ reb"\.mbt$", true)
  once(target(b"xxGETyy") =~ reb"GET", true)
  once(target(b"xxGEyy") =~ reb"GET", false)
  once(target(long) =~ reb"^0123456789012345678901234567890123456789$", true)
  once(target(b"else") =~ reb"^(if|else|while)$", true)
  once(target(b"elsex") =~ reb"^(if|else|while)$", false)
  once(target(b"abc") =~ (reb"^(a|abc)", after=_), true)
  once(target(b"x.mbti") =~ (reb"(i|\.mbti)$", before=_), true)
  once(target(b"ACCEPT: x") =~ reb"^(?i:host|accept): ", true)
  once(target(b"ACCEPT x") =~ reb"^(?i:host|accept): ", false)
  let dispatched = lexmatch target(b"PUT /") {
    (reb"^GET ", after=_) => 1
    (reb"^(POST|PUT) ", after=_) => 2
    _ => 0
  }
  once(dispatched == 2, true)
  let missed = lexmatch target(b"PATCH /") {
    (reb"^GET ", after=_) => 1
    (reb"^(POST|PUT) ", after=_) => 2
    _ => 0
  }
  once(missed == 0, true)
}
