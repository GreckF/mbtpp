///|
/// Other backends cannot start processes: only the JS build of moonpp can
/// call `moon`.
fn run_command(cmd : String, cwd : String) -> Int {
  ignore(cmd)
  ignore(cwd)
  -1
}

///|
fn current_dir() -> String {
  "."
}

///|
let can_run_commands : Bool = false

///|
fn set_exit_code(code : Int) -> Unit {
  @sys.exit(code)
}
