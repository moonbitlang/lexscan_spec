///|
test "RX-012D StringScanner commits the ordered nullable match end" {
  let scanner = @lexbuf.StringScanner::{ data: "baaa"[:], cursor: 0, }
  let word : StringView = lexscan scanner {
    re"^(?:a*?b*?)*a" as word => word
    _ => "missing"
  }
  assert_eq(word, "baa")
  assert_eq(scanner.cursor, 3)
  let tail : Char = lexscan scanner {
    re"^a$" as tail => tail
    _ => '?'
  }
  assert_eq(tail, 'a')
  assert_eq(scanner.cursor, 4)
}

///|
test "RX-012D nullable repetition preserves priority across Lexbuf refills" {
  let input = @lexscan.chunked(["b", "a", "", "a", "a"])
  let word : StringView = lexscan input {
    re"^(?:a*?b*?)*a" as word => word
    _ => "missing"
  }
  assert_eq(word, "baa")
  assert_eq(input.__get_cursor(), 3)
  let tail : Char = lexscan input {
    re"^a$" as tail => tail
    _ => '?'
  }
  assert_eq(tail, 'a')
  assert_eq(input.__get_cursor(), 4)
  assert_eq(word, "baa")
}

///|
test "RX-012D nullable repetition preserves priority across AsyncLexbuf refills" {
  let scheduler = @lexscan.TestScheduler::new()
  scheduler.run_async(async fn() {
    let chunks : ReadOnlyArray[String] = ["b", "a", "", "a", "a"]
    let mut index = 0
    let input = @lexbuf.AsyncLexbuf::from_fn(async fn() noraise {
      scheduler.pause()
      if index == chunks.length() {
        None
      } else {
        let chunk = chunks[index]
        index += 1
        Some(chunk)
      }
    })
    let word : StringView = lexscan input {
      re"^(?:a*?b*?)*a" as word => word
      _ => "missing"
    }
    assert_eq(word, "baa")
    assert_eq(input.__get_cursor(), 3)
    let tail : Char = lexscan input {
      re"^a$" as tail => tail
      _ => '?'
    }
    assert_eq(tail, 'a')
    assert_eq(input.__get_cursor(), 4)
    assert_eq(word, "baa")
  })
}
