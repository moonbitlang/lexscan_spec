///|
test "LS-003 LS-016 StringScanner updates its relative cursor" {
  let scanner = @lexbuf.StringScanner::{ data: "abc123"[:], cursor: 0 }
  inspect(
    lexscan scanner {
      re"^[a-z]+" => "word"
      _ => "other"
    },
    content="word",
  )
  inspect(scanner.cursor, content="3")
}

///|
test "LS-016A StringScanner body mutation follows automatic commit" {
  let scanner = @lexbuf.StringScanner::{ data: "ab"[:], cursor: 0 }
  lexscan scanner {
    re"^a" => scanner.cursor = 0
    _ => fail("initial token did not match")
  }
  assert_eq(scanner.cursor, 0)
  lexscan scanner {
    re"^a" => ()
    _ => fail("body cursor mutation was overwritten")
  }
  assert_eq(scanner.cursor, 1)
}

///|
test "LS-008C StringScanner target expression is evaluated exactly once" {
  let mut evaluations = 0
  let scanner = @lexbuf.StringScanner::{ data: "a"[:], cursor: 0 }
  fn target() -> @lexbuf.StringScanner {
    evaluations += 1
    scanner
  }
  inspect(
    lexscan target() {
      re"^a" => 1
      _ => 0
    },
    content="1",
  )
  assert_eq(evaluations, 1)
  assert_eq(scanner.cursor, 1)
}

///|
test "LS-008B StringScanner target remains stable across reassignment" {
  let first = @lexbuf.StringScanner::{ data: "a"[:], cursor: 0 }
  let second = @lexbuf.StringScanner::{ data: "b"[:], cursor: 0 }
  let mut current = first
  lexscan current {
    re"^a" => current = second
    _ => fail("first scanner did not match")
  }
  assert_eq(first.cursor, 1)
  assert_eq(second.cursor, 0)
  lexscan current {
    re"^b" => ()
    _ => fail("reassigned scanner did not match")
  }
  assert_eq(second.cursor, 1)
}

///|
test "LS-018 LS-021A StringScanner catch-all leaves cursor unchanged" {
  let scanner = @lexbuf.StringScanner::{ data: "?"[:], cursor: 0 }
  inspect(
    lexscan scanner {
      re"^[a-z]" => 1
      _ => 0
    },
    content="0",
  )
  inspect(scanner.cursor, content="0")

  let eof = @lexbuf.StringScanner::{ data: ""[:], cursor: 0 }
  for _ in 0..<2 {
    inspect(
      lexscan eof {
        re"^a" => 1
        _ => 0
      },
      content="0",
    )
    inspect(eof.cursor, content="0")
  }
}

///|
test "LS-029 LS-029B sliced StringView bounds and Unicode cursor offsets" {
  let backing = "--abc++"
  let scanner = @lexbuf.StringScanner::{ data: backing[2:5], cursor: 0 }
  inspect(
    lexscan scanner {
      re"^abc$" => "slice"
      _ => "other"
    },
    content="slice",
  )
  inspect(scanner.cursor, content="3")

  let resumed = @lexbuf.StringScanner::{ data: backing[2:5], cursor: 1 }
  inspect(
    lexscan resumed {
      re"^bc$" => "relative"
      _ => "other"
    },
    content="relative",
  )
  inspect(resumed.cursor, content="3")

  let unicode_backing = "--😀x++"
  let unicode = @lexbuf.StringScanner::{ data: unicode_backing[2:5], cursor: 2 }
  let tail : Char = lexscan unicode {
    re"^.$" as ch => ch
    _ => '?'
  }
  assert_eq(tail, 'x')
  assert_eq(unicode.cursor, 3)
}

///|
test "LS-029A cursor zero and data length are valid boundaries" {
  let at_start = @lexbuf.StringScanner::{ data: "a"[:], cursor: 0 }
  inspect(
    lexscan at_start {
      re"^a" => 1
      _ => 0
    },
    content="1",
  )
  inspect(at_start.cursor, content="1")

  let at_end = @lexbuf.StringScanner::{ data: "a"[:], cursor: 1 }
  inspect(
    lexscan at_end {
      re"^$" => "eof"
      _ => "other"
    },
    content="eof",
  )
  inspect(at_end.cursor, content="1")
}

///|
test "LS-030 successive scans resume at the stored cursor" {
  let scanner = @lexbuf.StringScanner::{ data: "abc123"[:], cursor: 0 }
  inspect(
    lexscan scanner {
      re"^[a-z]+" => "word"
      _ => "other"
    },
    content="word",
  )
  inspect(
    lexscan scanner {
      re"^[0-9]+" => "number"
      _ => "other"
    },
    content="number",
  )
  inspect(scanner.cursor, content="6")
}

///|
test "LS-031 LS-032A empty match neither warns nor advances" {
  let scanner = @lexbuf.StringScanner::{ data: "abc"[:], cursor: 0 }
  inspect(
    lexscan scanner {
      re"^" => "empty"
    },
    content="empty",
  )
  inspect(scanner.cursor, content="0")
  inspect(
    lexscan scanner {
      re"^" => "empty"
    },
    content="empty",
  )
  inspect(scanner.cursor, content="0")
}

///|
fn count_until_eof(scanner : @lexbuf.StringScanner) -> Int {
  let mut count = 0
  for ;; {
    let done = lexscan scanner {
      re"^$" => true
      re"^." => {
        count += 1
        false
      }
    }
    if done {
      break
    }
  }
  count
}

///|
fn recursive_count(scanner : @lexbuf.StringScanner, count : Int) -> Int {
  lexscan scanner {
    re"^$" => count
    re"^." => recursive_count(scanner, count + 1)
  }
}

///|
test "LS-032B LS-038 exhaustive EOF case and recursive scanning" {
  let scanner = @lexbuf.StringScanner::{ data: "a😀b"[:], cursor: 0 }
  assert_eq(count_until_eof(scanner), 3)
  assert_eq(scanner.cursor, 4)

  let long_input = "x".repeat(2048)
  let recursive = @lexbuf.StringScanner::{ data: long_input[:], cursor: 0 }
  assert_eq(recursive_count(recursive, 0), 2048)
  assert_eq(recursive.cursor, 2048)
}

///|
test "LS-033 LS-034 StringScanner non-BMP cursor and Char capture" {
  let scanner = @lexbuf.StringScanner::{ data: "😀!"[:], cursor: 0 }
  let face : Char = lexscan scanner {
    re"^." as ch => ch
    _ => 'x'
  }
  assert_eq(face, '😀')
  assert_eq(scanner.cursor, 2)
}

///|
fn scan_string_scanner_after_commit(scanner : @lexbuf.StringScanner) -> String {
  lexscan scanner {
    re"^a" =>
      lexscan scanner {
        re"^b" => "ab"
        _ => "missing-b"
      }
    _ => "missing-a"
  }
}

///|
test "LS-015A StringScanner commits before body evaluation" {
  let scanner = @lexbuf.StringScanner::{ data: "ab"[:], cursor: 0 }
  assert_eq(scan_string_scanner_after_commit(scanner), "ab")
  assert_eq(scanner.cursor, 2)
}

///|
#warnings("-unused_lexcase")
test "LS-013B StringScanner longest selection" {
  let scanner = @lexbuf.StringScanner::{ data: "abcd!"[:], cursor: 0 }
  inspect(
    lexscan scanner with longest {
      re"^a" => "short"
      re"^abcd" => "long"
      _ => "other"
    },
    content="long",
  )
  assert_eq(scanner.cursor, 4)
}

///|
test "LS-013C StringScanner ambiguous maximal captures are coherent" {
  let scanner = @lexbuf.StringScanner::{ data: "aa"[:], cursor: 0 }
  lexscan scanner with longest {
    (((re"^(a|aa)" as left) + (re"a?" as right)) as whole) + re"$" => {
      assert_eq(whole, "aa")
      assert_true(
        (left == "a" && right == "a") || (left == "aa" && right == ""),
      )
    }
    _ => fail("ambiguous maximal capture pattern did not match")
  }
  assert_eq(scanner.cursor, 2)
}

///|
test "LS-035D temporary StringScanner target preserves returned captures" {
  fn make_target() -> String {
    "abc!"
  }
  let captured : StringView = lexscan
    @lexbuf.StringScanner::{ data: make_target()[:], cursor: 0 } {
    re"^[a-z]+" as word => word
    _ => ""
  }
  assert_eq(captured, "abc")
}
