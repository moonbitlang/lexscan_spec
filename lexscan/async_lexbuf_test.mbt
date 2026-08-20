///|
test "LS-002 LS-028 AsyncLexbuf accepts a token across asynchronous refills" {
  let scheduler = TestScheduler::new()
  scheduler.run_async(async fn() {
    let mut index = 0
    let chunks : ReadOnlyArray[String] = ["ab", "cd", "!"]
    let input = @lexbuf.AsyncLexbuf::from_fn(async fn() noraise {
      scheduler.pause()
      if index < chunks.length() {
        let chunk = chunks[index]
        index += 1
        Some(chunk)
      } else {
        None
      }
    })
    let word : StringView = lexscan input {
      re"^[a-z]+" as captured => captured
      _ => ""
    }
    assert_eq(word, "abcd")
    assert_eq(input.__get_cursor(), 4)
    inspect(
      lexscan input {
        re"^!" => "bang"
        _ => "other"
      },
      content="bang",
    )
    assert_eq(input.__get_cursor(), 5)
  })
}

///|
test "LS-008C AsyncLexbuf target expression is evaluated exactly once" {
  let scheduler = TestScheduler::new()
  scheduler.run_async(async fn() {
    let mut target_evaluations = 0
    let mut supplied = false
    let input = @lexbuf.AsyncLexbuf::from_fn(async fn() noraise {
      scheduler.pause()
      if supplied {
        None
      } else {
        supplied = true
        Some("a")
      }
    })
    fn target() -> @lexbuf.AsyncLexbuf {
      target_evaluations += 1
      input
    }
    inspect(
      lexscan target() {
        re"^a" => 1
        _ => 0
      },
      content="1",
    )
    assert_eq(target_evaluations, 1)
    assert_eq(input.__get_cursor(), 1)
  })
}

///|
test "LS-025 AsyncLexbuf ignores empty chunks" {
  let scheduler = TestScheduler::new()
  scheduler.run_async(async fn() {
    let mut index = 0
    let chunks : ReadOnlyArray[String] = ["", "a", ""]
    let input = @lexbuf.AsyncLexbuf::from_fn(async fn() noraise {
      scheduler.pause()
      if index < chunks.length() {
        let chunk = chunks[index]
        index += 1
        Some(chunk)
      } else {
        None
      }
    })
    inspect(
      lexscan input {
        re"^a$" => "a"
        _ => "other"
      },
      content="a",
    )
    assert_eq(input.__get_cursor(), 1)
  })
}

///|
test "LS-025A LS-027B AsyncLexbuf skips empty runs through EOF" {
  let scheduler = TestScheduler::new()
  scheduler.run_async(async fn() {
    let mut index = 0
    let chunks : ReadOnlyArray[String] = ["", "", "a", "", "b", "", ""]
    let input = @lexbuf.AsyncLexbuf::from_fn(async fn() noraise {
      scheduler.pause()
      if index < chunks.length() {
        let chunk = chunks[index]
        index += 1
        Some(chunk)
      } else {
        None
      }
    })
    inspect(
      lexscan input {
        re"^ab$" => "whole"
        _ => "other"
      },
      content="whole",
    )
    assert_eq(input.__get_cursor(), 2)
  })
}

///|
test "LS-020 LS-021 AsyncLexbuf catch-all handles EOF without consuming" {
  let scheduler = TestScheduler::new()
  scheduler.run_async(async fn() {
    let input = @lexbuf.AsyncLexbuf::from_fn(async fn() noraise {
      scheduler.pause()
      None
    })
    inspect(
      lexscan input {
        re"^a" => 1
        _ => 0
      },
      content="0",
    )
    assert_eq(input.__get_cursor(), 0)
  })
}

///|
test "LS-021A AsyncLexbuf catch-all repeats on an unmatched scalar" {
  let scheduler = TestScheduler::new()
  scheduler.run_async(async fn() {
    let mut supplied = false
    let input = @lexbuf.AsyncLexbuf::from_fn(async fn() noraise {
      scheduler.pause()
      if supplied {
        None
      } else {
        supplied = true
        Some("?")
      }
    })
    for _ in 0..<2 {
      inspect(
        lexscan input {
          re"^[a-z]" => "letter"
          _ => "other"
        },
        content="other",
      )
      assert_eq(input.__get_cursor(), 0)
    }
  })
}

///|
test "LS-019C AsyncLexbuf wildcard-only does not refill" {
  let scheduler = TestScheduler::new()
  scheduler.run_async(() => {
    let mut source_calls = 0
    let input = @lexbuf.AsyncLexbuf::from_fn(async fn() noraise {
      source_calls += 1
      scheduler.pause()
      Some("a")
    })
    inspect(
      lexscan input {
        _ => 7
      },
      content="7",
    )
    assert_eq(source_calls, 0)
    assert_eq(input.__get_cursor(), 0)
  })
}

///|
test "LS-015A AsyncLexbuf commits before body evaluation" {
  let scheduler = TestScheduler::new()
  scheduler.run_async(async fn() {
    let mut index = 0
    let chunks : ReadOnlyArray[String] = ["a", "b"]
    let input = @lexbuf.AsyncLexbuf::from_fn(async fn() noraise {
      scheduler.pause()
      if index < chunks.length() {
        let chunk = chunks[index]
        index += 1
        Some(chunk)
      } else {
        None
      }
    })
    let result = lexscan input {
      re"^a" =>
        lexscan input {
          re"^b" => "ab"
          _ => "missing-b"
        }
      _ => "missing-a"
    }
    assert_eq(result, "ab")
    assert_eq(input.__get_cursor(), 2)
  })
}

///|
test "LS-027A AsyncLexbuf dollar waits for true EOF" {
  let scheduler = TestScheduler::new()
  scheduler.run_async(async fn() {
    let mut index = 0
    let chunks : ReadOnlyArray[String] = ["ab", "!"]
    let not_eof = @lexbuf.AsyncLexbuf::from_fn(async fn() noraise {
      scheduler.pause()
      if index < chunks.length() {
        let chunk = chunks[index]
        index += 1
        Some(chunk)
      } else {
        None
      }
    })
    inspect(
      lexscan not_eof {
        re"^ab$" => "wrong-end"
        _ => "not-at-end"
      },
      content="not-at-end",
    )
    assert_eq(not_eof.__get_cursor(), 0)

    let mut eof_index = 0
    let eof_chunks : ReadOnlyArray[String] = ["a", "b"]
    let true_eof = @lexbuf.AsyncLexbuf::from_fn(async fn() noraise {
      scheduler.pause()
      if eof_index < eof_chunks.length() {
        let chunk = eof_chunks[eof_index]
        eof_index += 1
        Some(chunk)
      } else {
        None
      }
    })
    inspect(
      lexscan true_eof {
        re"^ab$" => "at-end"
        _ => "other"
      },
      content="at-end",
    )
    assert_eq(true_eof.__get_cursor(), 2)
  })
}

///|
test "LS-027C AsyncLexbuf failed dollar match restores cursor after refill" {
  let scheduler = TestScheduler::new()
  scheduler.run_async(async fn() {
    let mut index = 0
    let chunks : ReadOnlyArray[String] = ["a", "b", "!", "", ""]
    let input = @lexbuf.AsyncLexbuf::from_fn(async fn() noraise {
      scheduler.pause()
      if index < chunks.length() {
        let chunk = chunks[index]
        index += 1
        Some(chunk)
      } else {
        None
      }
    })
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
  })
}

///|
test "LS-013B AsyncLexbuf longest selection across refills" {
  let scheduler = TestScheduler::new()
  scheduler.run_async(async fn() {
    let mut index = 0
    let chunks : ReadOnlyArray[String] = ["a", "b", "c", "d", "!"]
    let input = @lexbuf.AsyncLexbuf::from_fn(async fn() noraise {
      scheduler.pause()
      if index < chunks.length() {
        let chunk = chunks[index]
        index += 1
        Some(chunk)
      } else {
        None
      }
    })
    inspect(
      lexscan input with longest {
        re"^a" => "short"
        re"^abcd" => "long"
        _ => "other"
      },
      content="long",
    )
    assert_eq(input.__get_cursor(), 4)
  })
}

///|
test "LS-013C AsyncLexbuf ambiguous maximal captures are coherent" {
  let scheduler = TestScheduler::new()
  scheduler.run_async(async fn() {
    let mut index = 0
    let chunks : ReadOnlyArray[String] = ["a", "", "a"]
    let input = @lexbuf.AsyncLexbuf::from_fn(async fn() noraise {
      scheduler.pause()
      if index < chunks.length() {
        let chunk = chunks[index]
        index += 1
        Some(chunk)
      } else {
        None
      }
    })
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
  })
}

///|
test "LS-035A LS-035B AsyncLexbuf retains captures after later refills" {
  let scheduler = TestScheduler::new()
  scheduler.run_async(async fn() {
    let mut index = 0
    let chunks : ReadOnlyArray[String] = ["ab", "cd", " ", "ef", "gh", "!"]
    let input = @lexbuf.AsyncLexbuf::from_fn(async fn() noraise {
      scheduler.pause()
      if index < chunks.length() {
        let chunk = chunks[index]
        index += 1
        Some(chunk)
      } else {
        None
      }
    })
    let first : StringView = lexscan input {
      re"^[a-z]+" as word => word
      _ => ""
    }
    inspect(
      lexscan input {
        re"^ " => 1
        _ => 0
      },
      content="1",
    )
    let second : StringView = lexscan input {
      re"^[a-z]+" as word => word
      _ => ""
    }
    inspect(
      lexscan input {
        re"^!" => 1
        _ => 0
      },
      content="1",
    )
    assert_eq(first, "abcd")
    assert_eq(second, "efgh")
  })
}

///|
test "LS-039 AsyncLexbuf zero-length success and EOF" {
  let scheduler = TestScheduler::new()
  scheduler.run_async(async fn() {
    let mut supplied = false
    let input = @lexbuf.AsyncLexbuf::from_fn(async fn() noraise {
      scheduler.pause()
      if supplied {
        None
      } else {
        supplied = true
        Some("a")
      }
    })
    inspect(
      lexscan input {
        re"^" => "empty"
      },
      content="empty",
    )
    assert_eq(input.__get_cursor(), 0)
    inspect(
      lexscan input {
        re"^$" => "eof"
        re"^." => "scalar"
      },
      content="scalar",
    )
    assert_eq(input.__get_cursor(), 1)
    inspect(
      lexscan input {
        re"^$" => "eof"
        re"^." => "scalar"
      },
      content="eof",
    )
    assert_eq(input.__get_cursor(), 1)
  })
}

///|
test "LS-034A AsyncLexbuf joins a split non-BMP scalar" {
  let scheduler = TestScheduler::new()
  scheduler.run_async(async fn() {
    let source = "😀"
    let chunks : ReadOnlyArray[String] = [
      source.unsafe_substring(start=0, end=1),
      source.unsafe_substring(start=1, end=2),
    ]
    let mut index = 0
    let input = @lexbuf.AsyncLexbuf::from_fn(async fn() noraise {
      scheduler.pause()
      if index < chunks.length() {
        let chunk = chunks[index]
        index += 1
        Some(chunk)
      } else {
        None
      }
    })
    let face : Char = lexscan input {
      re"^." as captured => captured
      _ => '?'
    }
    assert_eq(face, '😀')
    assert_eq(input.__get_cursor(), 2)
  })
}
