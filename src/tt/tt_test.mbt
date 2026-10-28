///|
fn run_check(src : String) -> String {
  try {
    @tt.check_program("test.mbtpp", src)
    "ok"
  } catch {
    @tt.CheckError(msg) => msg
  }
}

///|
test "prelude" {
  inspect(run_check("fn main { println(1) }"), content="ok")
}
