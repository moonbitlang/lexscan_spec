///|
test "LM-022 wildcard catch-all" {
  inspect(
    lexmatch "no" {
      re"^yes$" => "yes"
      _ => "fallback"
    },
    content="fallback",
  )
}

///|
test "LM-023 LM-023A LM-023B binder catch-all receives complete target view" {
  let backing = "--target++"
  let slice = backing[2:8]
  let result : StringView = lexmatch slice {
    re"^never$" => ""
    rest => rest
  }
  assert_eq(result, "target")
  let only : StringView = lexmatch "whole" {
    rest => rest
  }
  assert_eq(only, "whole")
  fn make_target() -> String {
    "temporary"
  }
  let temporary : StringView = lexmatch make_target() {
    re"^never$" => ""
    rest => rest
  }
  assert_eq(temporary, "temporary")
  inspect(
    lexmatch "anything" {
      _ => 7
    },
    content="7",
  )
}

///|
test "LM-026 exhaustive expression may omit catch-all" {
  inspect(
    lexmatch "anything" {
      re"^.*$" => 1
    },
    content="1",
  )
  inspect(
    lexmatch "" {
      re"^.*$" => 1
    },
    content="1",
  )
}
