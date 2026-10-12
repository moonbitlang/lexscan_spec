///|
#warnings("-deprecated")
test "LS-001 direct-imported Lexbuf target" {
  let input = @lexbuf.Lexbuf::from_string("abc")
  inspect(
    lexscan input {
      re"^abc" => "word"
      _ => "other"
    },
    content="word",
  )
  inspect(input.__get_cursor(), content="3")
}

///|
#warnings("-deprecated")
test "LS-008 LS-008A target expression is evaluated exactly once" {
  let mut evaluations = 0
  fn target() -> @lexbuf.Lexbuf {
    evaluations += 1
    @lexbuf.Lexbuf::from_string("a")
  }
  inspect(
    lexscan target() {
      re"^a" => 1
      _ => 0
    },
    content="1",
  )
  inspect(evaluations, content="1")

  fn missing_target() -> @lexbuf.Lexbuf {
    evaluations += 1
    @lexbuf.Lexbuf::from_string("?")
  }
  inspect(
    lexscan missing_target() {
      re"^a" => 1
      _ => 0
    },
    content="0",
  )
  inspect(evaluations, content="2")
}

///|
#warnings("-deprecated")
test "LS-008B selected target is stable across outer reassignment" {
  let first = @lexbuf.Lexbuf::from_string("a")
  let second = @lexbuf.Lexbuf::from_string("b")
  let mut current = first
  inspect(
    lexscan current {
      re"^a" => {
        current = second
        1
      }
      _ => 0
    },
    content="1",
  )
  assert_eq(first.__get_cursor(), 1)
  assert_eq(second.__get_cursor(), 0)
  inspect(
    lexscan current {
      re"^b" => 2
      _ => 0
    },
    content="2",
  )
}

///|
#warnings("-deprecated")
test "LS-010A omitted and explicit first strategies are equivalent" {
  let omitted = @lexbuf.Lexbuf::from_string("ab")
  let explicit = @lexbuf.Lexbuf::from_string("ab")
  let omitted_result = lexscan omitted {
    re"^a" => "short"
    _ => "other"
  }
  let explicit_result = lexscan explicit with first {
    re"^a" => "short"
    _ => "other"
  }
  assert_eq(omitted_result, explicit_result)
  assert_eq(omitted.__get_cursor(), explicit.__get_cursor())
}

///|
#warnings("-unused_lexcase")
test "LS-012 LS-013 LS-014 first and longest case selection" {
  let first = @lexscan.chunked(["ab"])
  inspect(
    lexscan first {
      re"^a" => "short"
      re"^ab" => "long"
      _ => "other"
    },
    content="short",
  )
  inspect(first.__get_cursor(), content="1")

  let longest = @lexscan.chunked(["ab"])
  inspect(
    lexscan longest with longest {
      re"^a" => "short"
      re"^ab" => "long"
      _ => "other"
    },
    content="long",
  )
  inspect(longest.__get_cursor(), content="2")

  let tied = @lexscan.chunked(["ab"])
  inspect(
    lexscan tied with longest {
      re"^a." => "first"
      re"^ab" => "second"
      _ => "other"
    },
    content="first",
  )
}

///|
test "LS-013C ambiguous maximal captures form one coherent path" {
  let input = @lexscan.chunked(["a", "a"])
  lexscan input with longest {
    (((re"^(a|aa)" as left) + (re"a?" as right)) as whole) + re"$" => {
      assert_eq(whole, "aa")
      assert_true(
        (left == "a" && right == "a") || (left == "aa" && right == ""),
      )
    }
    _ => fail("ambiguous maximal capture pattern did not match")
  }
  assert_eq(input.__get_cursor(), 2)
}

///|
#warnings("-unused_lexcase")
test "LS-012A first-mode lazy quantifier spellings and backtracking" {
  let star = @lexscan.chunked(["aaaa"])
  let star_capture : StringView = lexscan star {
    re"^a*?" as captured => captured
    _ => "missing"
  }
  assert_eq(star_capture, "")
  assert_eq(star.__get_cursor(), 0)

  let plus = @lexscan.chunked(["aaaa"])
  let plus_capture : StringView = lexscan plus {
    re"^a+?" as captured => captured
    _ => "missing"
  }
  assert_eq(plus_capture, "a")
  assert_eq(plus.__get_cursor(), 1)

  let optional = @lexscan.chunked(["a"])
  let optional_capture : StringView = lexscan optional {
    re"^a??" as captured => captured
    _ => "missing"
  }
  assert_eq(optional_capture, "")
  assert_eq(optional.__get_cursor(), 0)

  let exact = @lexscan.chunked(["aaaa"])
  let exact_capture : StringView = lexscan exact {
    re"^a{2}?" as captured => captured
    _ => "missing"
  }
  assert_eq(exact_capture, "aa")

  let open = @lexscan.chunked(["aaaa"])
  let open_capture : StringView = lexscan open {
    re"^a{2,}?" as captured => captured
    _ => "missing"
  }
  assert_eq(open_capture, "aa")

  let closed = @lexscan.chunked(["aaaa"])
  let closed_capture : StringView = lexscan closed {
    re"^a{2,4}?" as captured => captured
    _ => "missing"
  }
  assert_eq(closed_capture, "aa")

  let backtracking = @lexscan.chunked(["aa", "ab"])
  let prefix : StringView = lexscan backtracking {
    (re"^a*?" as captured) + re"b" => captured
    _ => "missing"
  }
  assert_eq(prefix, "aaa")
  assert_eq(backtracking.__get_cursor(), 4)
}

///|
test "LS-012B failed partial prefix does not consume" {
  let input = @lexscan.chunked(["a", "c"])
  inspect(
    lexscan input {
      re"^ab" => "ab"
      re"^a" => "a"
      _ => "other"
    },
    content="a",
  )
  assert_eq(input.__get_cursor(), 1)
}

///|
test "LS-012C cross-refill partial failure retries from the scan origin" {
  let first = @lexscan.chunked(["a", "c"])
  let first_token : StringView = lexscan first {
    re"^ab" as token => token
    re"^ac" as token => token
    _ => ""
  }
  assert_eq(first_token, "ac")
  assert_eq(first.__get_cursor(), 2)

  let longest = @lexscan.chunked(["a", "c"])
  let longest_token : StringView = lexscan longest with longest {
    re"^ab" as token => token
    re"^ac" as token => token
    _ => ""
  }
  assert_eq(longest_token, "ac")
  assert_eq(longest.__get_cursor(), 2)
}

///|
#warnings("-unused_lexcase")
test "LS-013A longest waits across refills for the maximal token" {
  let input = @lexscan.chunked(["a", "b", "c", "d", "!"])
  inspect(
    lexscan input with longest {
      re"^a" => "short"
      re"^abcd" => "long"
      _ => "other"
    },
    content="long",
  )
  assert_eq(input.__get_cursor(), 4)
}

///|
fn scan_after_commit(input : @lexbuf.Lexbuf) -> String {
  lexscan input {
    re"^a" =>
      lexscan input {
        re"^b" => "ab"
        _ => "missing-b"
      }
    _ => "missing-a"
  }
}

///|
#warnings("-deprecated")
test "LS-015 successful case commits before its body" {
  let input = @lexbuf.Lexbuf::from_string("ab")
  assert_eq(scan_after_commit(input), "ab")
  assert_eq(input.__get_cursor(), 2)
}

///|
#warnings("-deprecated")
test "LS-017 LS-020 LS-021 catch-all never consumes" {
  let unmatched = @lexbuf.Lexbuf::from_string("?")
  inspect(
    lexscan unmatched {
      re"^[a-z]" => 1
      _ => 0
    },
    content="0",
  )
  inspect(unmatched.__get_cursor(), content="0")
  inspect(
    lexscan unmatched {
      re"^[a-z]" => 1
      _ => 0
    },
    content="0",
  )
  inspect(unmatched.__get_cursor(), content="0")

  let eof = @lexbuf.Lexbuf::from_string("")
  inspect(
    lexscan eof {
      re"^a" => 1
      _ => 0
    },
    content="0",
  )
  inspect(eof.__get_cursor(), content="0")
}

///|
test "LS-019A wildcard-only expression does not refill" {
  let mut source_calls = 0
  let input = @lexbuf.Lexbuf::from_fn(() => {
    source_calls += 1
    Some("a")
  })
  inspect(
    lexscan input {
      _ => 7
    },
    content="7",
  )
  inspect(source_calls, content="0")
  inspect(input.__get_cursor(), content="0")
}

///|
#warnings("-deprecated")
test "LS-019C wildcard-only StringScanner behavior" {
  let scanner = @lexbuf.StringScanner::{ data: "a"[:], cursor: 0, }
  inspect(
    lexscan scanner {
      _ => 7
    },
    content="7",
  )
  inspect(scanner.cursor, content="0")
}

///|
#warnings("-unused_lexcase")
test "LS-021B read-ahead cannot change logical cursor or next token" {
  let input = @lexscan.chunked(["a", "b"])
  inspect(
    lexscan input {
      re"^a" => "a"
      re"^ab" => "ab"
      _ => "other"
    },
    content="a",
  )
  inspect(input.__get_cursor(), content="1")
  inspect(
    lexscan input {
      re"^b" => "b"
      _ => "other"
    },
    content="b",
  )
  inspect(input.__get_cursor(), content="2")
}

///|
test "LS-023 exhaustive character-or-EOF cases omit catch-all" {
  let nonempty = @lexscan.chunked(["x"])
  inspect(
    lexscan nonempty {
      re"^(?:.|$)" => "covered"
    },
    content="covered",
  )
  let empty = @lexscan.chunked([])
  inspect(
    lexscan empty {
      re"^(?:.|$)" => "covered"
    },
    content="covered",
  )
}

///|
test "LS-039 Lexbuf zero-length success and EOF are distinct" {
  let nonempty = @lexscan.chunked(["a"])
  inspect(
    lexscan nonempty {
      re"^" => "empty"
    },
    content="empty",
  )
  assert_eq(nonempty.__get_cursor(), 0)
  inspect(
    lexscan nonempty {
      re"^$" => "eof"
      re"^." => "scalar"
    },
    content="scalar",
  )
  assert_eq(nonempty.__get_cursor(), 1)
  inspect(
    lexscan nonempty {
      re"^$" => "eof"
      re"^." => "scalar"
    },
    content="eof",
  )
  assert_eq(nonempty.__get_cursor(), 1)
}

///|
#warnings("-unused_lexcase")
test "LS-040 result typing and selected body evaluation" {
  let input = @lexscan.chunked(["a"])
  let mut selected_runs = 0
  let mut unselected_runs = 0
  let result : Int = lexscan input {
    re"^a" => {
      selected_runs += 1
      1
    }
    re"^b" => {
      unselected_runs += 1
      2
    }
    _ => 3
  }
  assert_eq(result, 1)
  assert_eq(selected_runs, 1)
  assert_eq(unselected_runs, 0)
}

///|
test "LS-024 LS-025 LS-026 token and capture span chunks" {
  let input = @lexscan.chunked(["", "ab", "", "cd", "!"])
  let captured : StringView = lexscan input {
    re"^[a-z]+" as word => word
    _ => ""
  }
  assert_eq(captured, "abcd")
  assert_eq(input.__get_cursor(), 4)
  inspect(
    lexscan input {
      re"^!" => "bang"
      _ => "other"
    },
    content="bang",
  )
}

///|
test "LS-024A token ending at a chunk boundary commits only its end" {
  let input = @lexscan.chunked(["ab", "!"])
  let token : StringView = lexscan input {
    re"^ab" as captured => captured
    _ => ""
  }
  assert_eq(token, "ab")
  assert_eq(input.__get_cursor(), 2)
  inspect(
    lexscan input {
      re"^!" => 1
      _ => 0
    },
    content="1",
  )
}

///|
test "LS-025A finite empty-chunk runs preserve the token stream" {
  let input = @lexscan.chunked(["", "", "a", "", "", "b", "", ""])
  inspect(
    lexscan input {
      re"^ab$" => "whole"
      _ => "other"
    },
    content="whole",
  )
  assert_eq(input.__get_cursor(), 2)
}

///|
test "LS-026A nested captures cross independent chunk boundaries" {
  let input = @lexscan.chunked(["a", "b", "c", "d", "!"])
  lexscan input {
    (re"^a" + (re"bc" as middle) + re"d") as whole => {
      assert_eq(middle, "bc")
      assert_eq(whole, "abcd")
    }
    _ => fail("nested cross-chunk captures did not match")
  }
  assert_eq(input.__get_cursor(), 4)
}

///|
test "LS-027 dollar waits for true EOF rather than a chunk boundary" {
  let not_eof = @lexscan.chunked(["ab", "!"])
  inspect(
    lexscan not_eof {
      re"^ab$" => "wrong-end"
      _ => "not-at-end"
    },
    content="not-at-end",
  )
  inspect(not_eof.__get_cursor(), content="0")

  let true_eof = @lexscan.chunked(["a", "b"])
  inspect(
    lexscan true_eof {
      re"^ab$" => "at-end"
      _ => "other"
    },
    content="at-end",
  )
  inspect(true_eof.__get_cursor(), content="2")
}

///|
test "LS-027C failed dollar match restores cursor after refill to EOF" {
  let input = @lexscan.chunked(["a", "b", "!", "", ""])
  inspect(
    lexscan input {
      re"^ab$" => "wrong-end"
      _ => "not-at-end"
    },
    content="not-at-end",
  )
  assert_eq(input.__get_cursor(), 0)
  inspect(
    lexscan input {
      re"^ab!$" => "whole"
      _ => "other"
    },
    content="whole",
  )
  assert_eq(input.__get_cursor(), 3)
}

///|
test "LS-033 LS-034 non-BMP token is one Char and two code units" {
  let source = "😀"
  let input = @lexscan.chunked([
    source.unsafe_substring(start=0, end=1),
    source.unsafe_substring(start=1, end=2),
  ])
  let captured : Char = lexscan input {
    re"^." as ch => ch
    _ => 'x'
  }
  assert_eq(captured, '😀')
  assert_eq(input.__get_cursor(), 2)
}

///|
test "LS-034B Lexbuf joins a split non-BMP scalar across empty chunks" {
  let source = "😀"
  let input = @lexscan.chunked([
    source.unsafe_substring(start=0, end=1),
    "",
    "",
    source.unsafe_substring(start=1, end=2),
  ])
  let captured : Char = lexscan input {
    re"^.$" as ch => ch
    _ => 'x'
  }
  assert_eq(captured, '😀')
  assert_eq(input.__get_cursor(), 2)
}

///|
test "LS-035 LS-035B retained captures remain valid after later refills" {
  let input = @lexscan.chunked(["ab", "cd", " ", "ef", "gh", "!"])
  let first : StringView = lexscan input {
    re"^[a-z]+" as word => word
    _ => ""
  }
  assert_eq(first, "abcd")
  inspect(
    lexscan input {
      re"^ " => "space"
      _ => "other"
    },
    content="space",
  )
  let second : StringView = lexscan input {
    re"^[a-z]+" as word => word
    _ => ""
  }
  assert_eq(second, "efgh")
  inspect(
    lexscan input {
      re"^!" => "bang"
      _ => "other"
    },
    content="bang",
  )
  assert_eq(first, "abcd")
  assert_eq(second, "efgh")
}

///|
test "LS-024 LS-026 LS-035 retention across one thousand chunks" {
  let chunks = Array::make(512, "x")
  chunks.push(" ")
  for _ in 0..<512 {
    chunks.push("y")
  }
  chunks.push("!")
  let input = @lexscan.chunked(chunks)
  let first : StringView = lexscan input {
    re"^x+" as word => word
    _ => ""
  }
  assert_eq(first.length(), 512)
  inspect(
    lexscan input {
      re"^ " => "space"
      _ => "other"
    },
    content="space",
  )
  let second : StringView = lexscan input {
    re"^y+" as word => word
    _ => ""
  }
  assert_eq(second.length(), 512)
  inspect(
    lexscan input {
      re"^!" => "bang"
      _ => "other"
    },
    content="bang",
  )
  assert_eq(first.length(), 512)
  assert_eq(second.length(), 512)
}

///|
test "LS-035C repeated compaction preserves absolute cursors" {
  let chunks = Array::make(300, "a ")
  chunks.push("!")
  let input = @lexscan.chunked(chunks)
  let mut tokens = 0
  for _ in 0..<300 {
    let word : Char = lexscan input {
      re"^a" as captured => captured
      _ => '?'
    }
    assert_eq(word, 'a')
    inspect(
      lexscan input {
        re"^ " => 1
        _ => 0
      },
      content="1",
    )
    tokens += 1
  }
  assert_eq(tokens, 300)
  assert_eq(input.__get_cursor(), 600)
  inspect(
    lexscan input {
      re"^!" => 1
      _ => 0
    },
    content="1",
  )
  assert_eq(input.__get_cursor(), 601)
}

///|
test "RX-037 RX-037A referenced and composed constants work in lexscan" {
  let input = @lexscan.chunked(["hello", "!"])
  let whole : StringView = lexscan input {
    @patterns.HIDDEN_ANCHORED_NAMED_CAPTURE as whole => whole
    _ => ""
  }
  assert_eq(whole, "hello")
  assert_eq(input.__get_cursor(), 5)

  let composed = @lexscan.chunked(["ab", "!"])
  let pair : StringView = lexscan composed {
    (re"^" + @patterns.QUALIFIED_A + @patterns.QUALIFIED_B) as pair => pair
    _ => ""
  }
  assert_eq(pair, "ab")
  assert_eq(composed.__get_cursor(), 2)
}

///|
test "LS-037 backend-neutral scanning semantics" {
  let input = @lexscan.chunked(["ab", "12", "😀"])
  let word : StringView = lexscan input {
    re"^[a-z]+" as captured => captured
    _ => ""
  }
  let number : StringView = lexscan input {
    re"^[0-9]+" as captured => captured
    _ => ""
  }
  let face : Char = lexscan input {
    re"^." as captured => captured
    _ => 'x'
  }
  assert_eq(word, "ab")
  assert_eq(number, "12")
  assert_eq(face, '😀')
  assert_eq(input.__get_cursor(), 6)
}
