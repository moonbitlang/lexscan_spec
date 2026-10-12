///|
fn runtime_pattern_rejected(pattern : String) -> Bool {
  try {
    ignore(@string.Regex(pattern))
    false
  } catch {
    _ => true
  }
}
