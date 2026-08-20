///|
pub fn chunked(chunks : Array[String]) -> @lexbuf.Lexbuf {
  let iterator = chunks.iter()
  @lexbuf.Lexbuf::from_fn(() => iterator.next())
}

///|
pub async fn[T] spec_suspend(register : ((T) -> Unit) -> Unit) -> T noraise = "%async.suspend"

///|
pub fn spec_run_async(work : async () -> Unit noraise) -> Unit = "%async.run"

///|
pub struct TestScheduler {
  continuations : Array[() -> Unit]
}

///|
pub fn TestScheduler::new() -> TestScheduler {
  { continuations: [] }
}

///|
pub fn TestScheduler::run_async(
  self : TestScheduler,
  work : async () -> Unit,
) -> Unit {
  spec_run_async(() => work() catch { _ => panic() })
  let mut index = 0
  while index < self.continuations.length() {
    let continue_ = self.continuations[index]
    index += 1
    continue_()
  }
}

///|
pub async fn TestScheduler::pause(self : TestScheduler) -> Unit noraise {
  spec_suspend(continue_ => self.continuations.push(() => continue_(())))
}
