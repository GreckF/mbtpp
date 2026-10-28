///|
/// Running external commands (`moon add`, `moon info`, ...) on Node.js.
extern "js" fn js_run(cmd : String, cwd : String) -> Int =
  #|(cmd, cwd) => {
  #|  const r = require("child_process").spawnSync(cmd, { cwd, stdio: "inherit", shell: true });
  #|  return r.status === null ? 1 : r.status;
  #|}

///|
extern "js" fn js_run_quiet(cmd : String, cwd : String) -> Int =
  #|(cmd, cwd) => {
  #|  const r = require("child_process").spawnSync(cmd, { cwd, stdio: "ignore", shell: true });
  #|  return r.status === null ? 1 : r.status;
  #|}

///|
/// Run a shell command without showing its output.
fn run_quiet(cmd : String, cwd : String) -> Int {
  js_run_quiet(cmd, cwd)
}

///|
extern "js" fn js_cwd() -> String = "() => process.cwd()"

///|
/// Run a shell command in `cwd`; returns its exit status.
fn run_command(cmd : String, cwd : String) -> Int {
  js_run(cmd, cwd)
}

///|
fn current_dir() -> String {
  js_cwd()
}

///|
let can_run_commands : Bool = true

///|
/// Report the exit status to the launcher: moonpp runs in a worker thread,
/// where `process.exit` could drop output that is not flushed yet.
extern "js" fn set_exit_code(code : Int) -> Unit =
  #|(code) => {
  #|  const { parentPort } = require("worker_threads");
  #|  if (parentPort) { parentPort.postMessage({ exitCode: code }); }
  #|  else { process.exitCode = code; }
  #|}
