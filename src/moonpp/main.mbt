///|
/// `moonpp`: the MoonBit++ build tool, modelled on `moon`.
let help_msg : String =
  #|moonpp: the MoonBit++ build tool
  #|
  #|usage:
  #|  moonpp new <name>          create a new project
  #|  moonpp check [path]        type check the project (or a package directory or file)
  #|  moonpp run [path]          run the main package (or a package directory or file)
  #|  moonpp build [path]        compile to a MoonBit project and `moon build` it: by default
  #|                             mbtpp_out/<pkg> in the project (or _mbtpp_build/<file> for a
  #|                             single file), with the dependencies of the project
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
  #|  -o, --output <dir>  (build, run --compiled) where to generate the MoonBit project
  #|
  #|A package is a directory of .mbtpp files. The MoonBit packages it uses are
  #|listed in the `import` block of its moon.pkg (or the "import" field of a
  #|moon.pkg.json) and referred to as @pkg.name; imported functions are type
  #|checked by the interpreter, and called by the compiled program.

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
  /// The directory of the generated MoonBit project.
  output : String?
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
      @fs.IOError(msg) => die("cannot read " + f + ": " + msg)
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
            "not in a MoonBit++ project (no moon.mod found); try `moonpp new`",
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
          "no main package; mark one with options(\"is-main\": true) in its moon.pkg",
        )
    }
  }
}

///|
fn write_file(path : String, content : String) -> Unit raise Failure {
  @fs.write_string_to_file(path, content) catch {
    @fs.IOError(msg) => die("cannot write " + path + ": " + msg)
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
/// The configuration files of the generated project (`moon.mod`,
/// `moon.work`): the name, version and dependencies of the MoonBit++ project
/// (`root`, if any). Local modules (workspace members, or local dependencies
/// of an old `moon.mod.json`) are members of the generated workspace, by
/// absolute path.
fn output_module(
  root : String?,
  default_name : String,
) -> (String, String) raise Failure {
  let info = match root {
    Some(r) => module_info(r)
    None => { name: None, version: None, source: "", deps: [], local_deps: [], }
  }
  let deps = info.deps.copy()
  let members : Array[String] = []
  match root {
    Some(r) => {
      for m in workspace_members(r) {
        if normalize_path(m) != normalize_path(r) && is_module_dir(m) {
          members.push(m)
        }
      }
      for ld in info.local_deps {
        members.push(normalize_path(ld.1))
        let v = (module_info(ld.1) catch { _ => info }).version
        deps.push(
          match v {
            Some(v) if is_module_dir(ld.1) => ld.0 + "@" + v
            _ => ld.0
          },
        )
      }
    }
    None => ()
  }
  let m = StringBuilder::new()
  m.write_string("name = " + mstr(info.name.unwrap_or(default_name)) + "\n\n")
  m.write_string("version = " + mstr(info.version.unwrap_or("0.1.0")) + "\n")
  if deps.length() > 0 {
    m.write_string("\nimport {\n")
    for d in deps {
      m.write_string("  " + mstr(d) + ",\n")
    }
    m.write_string("}\n")
  }
  // the generated project is a workspace of its own (also so that a
  // `moon.work` of the MoonBit++ project does not apply to it)
  let w = StringBuilder::new()
  w.write_string("members = [\n  \".\",\n")
  for mem in members {
    w.write_string("  " + mstr(mem) + ",\n")
  }
  w.write_string("]\n")
  (m.to_string(), w.to_string())
}

///|
/// Compile a package (or file) to a MoonBit project. Returns the project
/// directory and the name of the generated package in it.
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
  let (out, pkg, default_name) = match project {
    Some(root) => {
      let pkg = last_segment(dir)
      // generated by older versions of moonpp, inside the project's module
      let old = (if module_source(root) == "" {
          root
        } else {
          root + "/" + module_source(root)
        }) +
        "/mbtpp_out"
      if @fs.path_exists(old) {
        println(
          "note: " +
          relative(old, current_dir()) +
          " was generated by an older moonpp and can be deleted",
        )
      }
      (root + "/mbtpp_out/" + pkg, pkg, "mbtpp/" + pkg)
    }
    None => {
      let stem = last_segment(files[0]).replace(old=".mbtpp", new="")
      (dir_of(files[0]) + "/_mbtpp_build/" + stem, "main", "mbtpp/" + stem)
    }
  }
  let out = opts.output.unwrap_or(out)
  make_dirs(out + "/" + pkg)
  let (mod_file, work_file) = output_module(project, default_name)
  // files of older versions of moonpp
  for old in ["/moon.mod.json", "/" + pkg + "/moon.pkg.json"] {
    if @fs.path_exists(out + old) {
      @fs.remove_file(out + old) catch {
        _ => ()
      }
    }
  }
  write_file(out + "/moon.mod", mod_file)
  write_file(out + "/moon.work", work_file)
  write_file(
    out + "/.gitignore",
    (
      #|_build/
      #|target/
      #|.mooncakes/
      #|moon.work.lock
      #|
    ),
  )
  let source = match project {
    Some(root) => relative(dir, root)
    None => files[0]
  }
  write_file(
    out + "/README.md",
    (
      $|# MoonBit code generated from MoonBit++
      $|
      $|Generated by `moonpp build` from `\{source}`; it is overwritten by the
      $|next build. A standalone MoonBit project:
      $|
      $|```bash
      $|moon run \{pkg}
      $|moon build
      $|```
      $|
      $|`\{pkg}/main.mbt` is the program, `\{pkg}/runtime.mbt` its runtime support.
      $|
    ),
  )
  let pkg_file = StringBuilder::new()
  pkg_file.write_string("warnings = \"-a\"\n")
  if imports.length() > 0 {
    pkg_file.write_string("\nimport {\n")
    for i in imports {
      pkg_file.write_string("  " + mstr(i.path) + " @" + i.alias + ",\n")
    }
    pkg_file.write_string("}\n")
  }
  pkg_file.write_string("\noptions(\n  \"is-main\": true,\n)\n")
  write_file(out + "/" + pkg + "/moon.pkg", pkg_file.to_string())
  write_file(out + "/" + pkg + "/main.mbt", code)
  write_file(out + "/" + pkg + "/runtime.mbt", @codegen.runtime_code())
  // format the generated code (best effort)
  if can_run_commands {
    ignore(run_quiet("moon fmt", out))
  }
  (out, pkg)
}

///|
fn cmd_build(opts : Options, path : String?) -> Bool raise Failure {
  let (out, pkg) = compile(opts, path)
  moon("build", out)
  println(
    "compiled to the MoonBit project " +
    relative(out, current_dir()) +
    " (run it there with `moon run " +
    pkg +
    "`)",
  )
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
          "no main package; mark one with options(\"is-main\": true) in its moon.pkg",
        )
    }
  }
  ignore(base)
  check_files(opts, dir, files)
  let out = { buf: StringBuilder::new(), }
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
    let hint = match find_project(dir) {
      Some(root) if !@fs.path_exists(root + "/moon.mod") =>
        "\nhint: the project uses moon.mod.json, which newer versions of moon no longer accept; run `moon fmt` in " +
        root +
        " to migrate it to moon.mod (moonpp reads both)"
      _ => ""
    }
    die(
      "`moon " +
      args +
      "` failed (exit status " +
      status.to_string() +
      ")" +
      hint,
    )
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
      if !is_module_dir(mod_dir) {
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
    None => die("not in a MoonBit++ project (no moon.mod found)")
  }
}

///|
fn run_cli(args : Array[String]) -> Bool raise Failure {
  let rest : Array[String] = []
  let mut prelude = true
  let mut verbose = false
  let mut compiled = false
  let mut output : String? = None
  let mut i = 0
  while i < args.length() {
    match args[i] {
      "--no-prelude" => prelude = false
      "--verbose" => verbose = true
      "--compiled" => compiled = true
      "-o" | "--output" =>
        if i + 1 < args.length() {
          i = i + 1
          output = Some(args[i])
        } else {
          die("missing directory after " + args[i])
        }
      a => rest.push(a)
    }
    i = i + 1
  }
  let opts = { prelude, verbose, compiled, output, }
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
      // `user/module@version`
      let name = match m.find("@") {
        Some(k) => m.unsafe_substring(start=0, end=k)
        None => m
      }
      println(
        "added " +
        m +
        "; list its packages (e.g. \"" +
        name +
        "/<pkg>\") in the import block of a moon.pkg",
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
