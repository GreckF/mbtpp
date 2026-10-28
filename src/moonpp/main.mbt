///|
/// `moonpp`: the MoonBit++ build tool, modelled on `moon`.
let help_msg : String =
  #|moonpp: the MoonBit++ build tool
  #|
  #|usage:
  #|  moonpp new <name>          create a new project
  #|  moonpp check [path]        type check the project (or a package directory or file)
  #|  moonpp run [path]          run the main package (or a package directory or file)
  #|  moonpp build [path]        compile to MoonBit (`moon build`); the generated code is in
  #|                             src/mbtpp_out/<pkg> (or _mbtpp_build/<file> for a single file)
  #|  moonpp run --compiled [path]  compile to MoonBit and run it with `moon run`
  #|  moonpp add <user/module>   add a dependency (`moon add`) and extract its interfaces
  #|  moonpp remove <module>     remove a dependency (`moon remove`)
  #|  moonpp install             install the dependencies (`moon install`) and extract interfaces
  #|  moonpp tree                show the dependency tree (`moon tree`)
  #|  moonpp interfaces          generate missing interfaces of downloaded dependencies
  #|                             (done automatically by `add` and `install`)
  #|  moonpp version
  #|
  #|options:
  #|  --no-prelude   do not load the prelude
  #|  --verbose      list the interface items that could not be imported
  #|  --compiled     (run) run the program compiled to MoonBit instead of interpreting it
  #|
  #|A package is a directory of .mbtpp files. The MoonBit packages it uses are
  #|listed in the "import" field of its moon.pkg.json and referred to as
  #|@pkg.name; imported functions are type checked but cannot be run.

///|
let version : String = "moonpp 0.1.0"

///|
/// Line-buffered output.
struct Out {
  buf : StringBuilder
}

///|
fn Out::write(self : Out, s : String) -> Unit {
  for c in s {
    if c == '\n' {
      println(self.buf.to_string())
      self.buf.reset()
    } else {
      self.buf.write_char(c)
    }
  }
}

///|
fn Out::flush(self : Out) -> Unit {
  if self.buf.to_string() != "" {
    println(self.buf.to_string())
    self.buf.reset()
  }
}

///|
struct Options {
  prelude : Bool
  verbose : Bool
  compiled : Bool
}

///|
/// Read the files of a package (or a single file) and type check them.
fn check_files(
  opts : Options,
  dir : String,
  files : Array[String],
) -> Unit raise Failure {
  let srcs : Array[(String, String)] = []
  let cwd = current_dir()
  for f in files {
    let src = @fs.read_file_to_string(f) catch {
      e => die("cannot read " + f + ": " + e.to_string())
    }
    srcs.push((relative(f, cwd), src))
  }
  let imports = load_imports(dir)
  @tt.check_package(srcs, prelude=opts.prelude, imports~) catch {
    @tt.CheckError(msg) => die(msg)
  }
  if opts.verbose && @tt.import_skipped.length() > 0 {
    println("not imported:")
    for s in @tt.import_skipped {
      println("  " + s)
    }
  }
}

///|
/// What a path argument designates: a single file, or packages.
fn targets(
  path : String?,
) -> (String, Array[(String, Array[String])]) raise Failure {
  let cwd = current_dir()
  match path {
    Some(p) if p.has_suffix(".mbtpp") => {
      if !@fs.path_exists(p) {
        die("no such file: " + p)
      }
      (cwd, [(dir_of(p), [p])])
    }
    Some(p) if package_files(p).length() > 0 => (cwd, [(p, package_files(p))])
    _ => {
      let start = path.unwrap_or(cwd)
      let root = match find_project(start) {
        Some(r) => r
        None =>
          die(
            "not in a MoonBit++ project (no moon.mod.json found); try `moonpp new`",
          )
      }
      let pkgs = project_packages(root)
      if pkgs.length() == 0 {
        die("the project has no .mbtpp files")
      }
      (root, pkgs.map(d => (d, package_files(d))))
    }
  }
}

///|
fn cmd_check(opts : Options, path : String?) -> Bool raise Failure {
  let (base, pkgs) = targets(path)
  let mut ok = true
  for pkg in pkgs {
    let (dir, files) = pkg
    let name = relative(dir, base)
    check_files(opts, dir, files) catch {
      Failure(msg) => {
        println(msg)
        ok = false
        continue
      }
    }
    println(
      "ok: " +
      (if files.length() == 1 && path is Some(_) { files[0] } else { name }),
    )
  }
  ok
}

///|
/// The package to run or build.
fn main_package(path : String?) -> (String, Array[String]) raise Failure {
  let (_, pkgs) = targets(path)
  if pkgs.length() == 1 {
    pkgs[0]
  } else {
    match pkgs.iter().find_first(p => is_main_package(p.0)) {
      Some(p) => p
      None =>
        die(
          "no main package; mark one with \"is-main\": true in its moon.pkg.json",
        )
    }
  }
}

///|
fn write_file(path : String, content : String) -> Unit raise Failure {
  @fs.write_string_to_file(path, content) catch {
    e => die("cannot write " + path + ": " + e.to_string())
  }
}

///|
fn make_dirs(path : String) -> Unit {
  let parts = path.split("/").map(s => s.to_string()).to_array()
  let mut d = ""
  for p in parts {
    d = if d == "" { p } else { d + "/" + p }
    if d != "" && d != "." && !@fs.path_exists(d) {
      @fs.create_dir(d) catch {
        _ => ()
      }
    }
  }
}

///|
/// Compile a package (or file) to MoonBit. Returns the module directory and
/// the path of the generated package in it.
fn compile(opts : Options, path : String?) -> (String, String) raise Failure {
  let (dir, files) = main_package(path)
  check_files(opts, dir, files)
  let imports = load_imports(dir)
  let code = @codegen.generate(imports.map(i => (i.path, i.alias))) catch {
    @codegen.CodegenError(msg) => die("cannot compile: " + msg)
  }
  let single = match path {
    Some(p) => p.has_suffix(".mbtpp")
    None => false
  }
  let project = if single { None } else { find_project(dir) }
  let (mod_dir, pkg_rel) = match project {
    Some(root) => {
      let src = module_source(root)
      let rel = (if src == "" { "" } else { src + "/" }) +
        "mbtpp_out/" +
        last_segment(dir)
      (root, rel)
    }
    None => {
      let stem = last_segment(files[0]).replace(old=".mbtpp", new="")
      let m = dir_of(files[0]) + "/_mbtpp_build/" + stem
      make_dirs(m)
      write_file(
        m + "/moon.mod.json",
        (
          $|{
          $|  "name": "mbtpp/\{stem}",
          $|  "version": "0.1.0"
          $|}
          $|
        ),
      )
      (m, "main")
    }
  }
  let out = mod_dir + "/" + pkg_rel
  make_dirs(out)
  let imports_json = imports
    .map(i => "    { \"path\": " +
      i.path.escape() +
      ", \"alias\": " +
      i.alias.escape() +
      " }")
    .join(",\n")
  write_file(
    out + "/moon.pkg.json",
    (
      $|{
      $|  "is-main": true,
      $|  "warn-list": "-a",
      $|  "import": [
      $|\{imports_json}
      $|  ]
      $|}
      $|
    ),
  )
  write_file(out + "/main.mbt", code)
  write_file(out + "/runtime.mbt", @codegen.runtime_code())
  // format the generated code (best effort)
  if can_run_commands {
    ignore(run_quiet("moon fmt", mod_dir))
  }
  (mod_dir, pkg_rel)
}

///|
fn cmd_build(opts : Options, path : String?) -> Bool raise Failure {
  let (mod_dir, pkg) = compile(opts, path)
  moon("build", mod_dir)
  println("compiled to " + relative(mod_dir + "/" + pkg, current_dir()))
  true
}

///|
fn cmd_run(opts : Options, path : String?) -> Bool raise Failure {
  if opts.compiled {
    let (mod_dir, pkg) = compile(opts, path)
    moon("run -q " + pkg, mod_dir)
    return true
  }
  let (base, pkgs) = targets(path)
  let (dir, files) = if pkgs.length() == 1 {
    pkgs[0]
  } else {
    match pkgs.iter().find_first(p => is_main_package(p.0)) {
      Some(p) => p
      None =>
        die(
          "no main package; mark one with \"is-main\": true in its moon.pkg.json",
        )
    }
  }
  ignore(base)
  check_files(opts, dir, files)
  let out = { buf: StringBuilder::new() }
  @interp.run_main(s => out.write(s)) catch {
    @interp.RunError(msg) => {
      out.flush()
      println(msg)
      return false
    }
  }
  out.flush()
  true
}

///|
/// Run a `moon` command in the project, failing if it fails.
fn moon(args : String, dir : String) -> Unit raise Failure {
  if !can_run_commands {
    die("this build of moonpp cannot run `moon`; use the JS build (bin/moonpp)")
  }
  let status = run_command("moon " + args, dir)
  if status != 0 {
    die("`moon " + args + "` failed (exit status " + status.to_string() + ")")
  }
}

///|
/// Make sure every package of the downloaded dependencies has an interface
/// file, generating the missing ones with `moon info`.
fn extract_interfaces(root : String) -> Unit raise Failure {
  let cakes = root + "/.mooncakes"
  for user in list_dir(cakes) {
    for m in list_dir(cakes + "/" + user) {
      let mod_dir = cakes + "/" + user + "/" + m
      if !@fs.path_exists(mod_dir + "/moon.mod.json") {
        continue
      }
      let src = module_source(mod_dir)
      let base = if src == "" { mod_dir } else { mod_dir + "/" + src }
      let missing : Array[String] = []
      fn walk(dir : String, missing : Array[String]) -> Unit {
        let is_pkg = @fs.path_exists(dir + "/moon.pkg.json") ||
          @fs.path_exists(dir + "/moon.pkg")
        if is_pkg && mbti_in(dir) is None {
          missing.push(dir)
        }
        for name in list_dir(dir) {
          if !name.has_prefix(".") && !name.has_prefix("_") && name != "target" {
            let sub = dir + "/" + name
            if is_dir(sub) {
              walk(sub, missing)
            }
          }
        }
      }

      walk(base, missing)
      if missing.length() > 0 {
        println(
          "generating interfaces of " +
          user +
          "/" +
          m +
          " (" +
          missing.length().to_string() +
          " package(s))",
        )
        moon("info", mod_dir) catch {
          Failure(msg) => println("warning: " + msg)
        }
      }
    }
  }
}

///|
fn project_root() -> String raise Failure {
  match find_project(current_dir()) {
    Some(r) => r
    None => die("not in a MoonBit++ project (no moon.mod.json found)")
  }
}

///|
fn run_cli(args : Array[String]) -> Bool raise Failure {
  let rest : Array[String] = []
  let mut prelude = true
  let mut verbose = false
  let mut compiled = false
  for a in args {
    match a {
      "--no-prelude" => prelude = false
      "--verbose" => verbose = true
      "--compiled" => compiled = true
      _ => rest.push(a)
    }
  }
  let opts = { prelude, verbose, compiled }
  match rest {
    [] | ["help"] | ["--help"] | ["-h"] => {
      println(help_msg)
      true
    }
    ["version"] | ["--version"] => {
      println(version)
      true
    }
    ["new", name] => {
      new_project(name)
      println("created " + name + "; try: cd " + name + " && moonpp run")
      true
    }
    ["check"] => cmd_check(opts, None)
    ["check", p] => cmd_check(opts, Some(p))
    ["build"] => cmd_build(opts, None)
    ["build", p] => cmd_build(opts, Some(p))
    ["run"] => cmd_run(opts, None)
    ["run", p] => cmd_run(opts, Some(p))
    [p] if p.has_suffix(".mbtpp") => cmd_run(opts, Some(p))
    ["add", m] => {
      let root = project_root()
      moon("add " + m, root)
      extract_interfaces(root)
      println(
        "added " +
        m +
        "; list its packages (e.g. \"" +
        m +
        "/<pkg>\") in the \"import\" field of a moon.pkg.json",
      )
      true
    }
    ["remove", m] => {
      moon("remove " + m, project_root())
      true
    }
    ["install"] => {
      let root = project_root()
      moon("install", root)
      extract_interfaces(root)
      true
    }
    ["interfaces"] => {
      extract_interfaces(project_root())
      true
    }
    ["tree"] => {
      moon("tree", project_root())
      true
    }
    _ => {
      println(help_msg)
      false
    }
  }
}

///|
fn main {
  // the first argument is the program itself
  let args = @sys.get_cli_args()
  let ok = run_cli(args[1:].to_array()) catch {
    Failure(msg) => {
      println("error: " + msg)
      false
    }
  }
  if !ok {
    set_exit_code(1)
  }
}
