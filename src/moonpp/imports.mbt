///|
/// Resolution of the MoonBit packages a package imports: they are listed in
/// the `moon.pkg.json` of its directory, as in MoonBit:
///
///   { "import": [ "moonbitlang/core/math", { "path": "...", "alias": "m" } ] }
///
/// The interface of `moonbitlang/core/<pkg>` is read from the MoonBit
/// installation (`$MOON_HOME/lib/core`, by default `~/.moon/lib/core`); other
/// packages from the `.mooncakes` directory of the project (or of a parent
/// directory), where `moon add` / `moon install` put them.
fn moon_home() -> String {
  match @sys.get_env_var("MOON_HOME") {
    Some(h) => h
    None => {
      let home = match @sys.get_env_var("HOME") {
        Some(h) => h
        None => @sys.get_env_var("USERPROFILE").unwrap_or(".")
      }
      home + "/.moon"
    }
  }
}

///|
/// An interface file in `dir`: `pkg.generated.mbti`, `pkg.mbti` or any
/// other `*.mbti`.
fn mbti_in(dir : String) -> String? {
  for name in ["pkg.generated.mbti", "pkg.mbti"] {
    if @fs.path_exists(dir + "/" + name) {
      return Some(dir + "/" + name)
    }
  }
  match list_dir(dir).iter().find_first(f => f.has_suffix(".mbti")) {
    Some(f) => Some(dir + "/" + f)
    None => None
  }
}

///|
/// Is `dir` a MoonBit module? Newer modules describe themselves in
/// `moon.mod` (`key = value` lines) instead of `moon.mod.json`.
fn is_module_dir(dir : String) -> Bool {
  @fs.path_exists(dir + "/moon.mod.json") || @fs.path_exists(dir + "/moon.mod")
}

///|
/// The `source` directory of a MoonBit module (`""` for the module root).
fn module_source(mod_dir : String) -> String {
  match read_json(mod_dir + "/moon.mod.json") {
    Some(j) =>
      match j.value("source") {
        Some(String(s)) => s
        _ => ""
      }
    None => {
      // `source = "src"` in `moon.mod`
      let text = @fs.read_file_to_string(mod_dir + "/moon.mod") catch {
        _ => return ""
      }
      for line in text.split("\n") {
        let l = line.trim(chars=" \t\r").to_string()
        if l.has_prefix("source") {
          let rest = l.unsafe_substring(start=6, end=l.length())
            .trim(chars=" \t")
            .to_string()
          if rest.has_prefix("=") {
            return rest
              .unsafe_substring(start=1, end=rest.length())
              .trim(chars=" \t\"")
              .to_string()
          }
        }
      }
      ""
    }
  }
}

///|
/// The directory of package `pkg` (`user/module/sub/pkg`) of a module
/// downloaded into a `.mooncakes` directory above `dir`.
fn mooncakes_package_dir(pkg : String, dir : String) -> String? {
  let parts = pkg.split("/").map(s => s.to_string()).to_array()
  if parts.length() < 2 {
    return None
  }
  let module_ = parts[0] + "/" + parts[1]
  let rest = parts[2:].to_array()
  let mut d : String? = Some(dir)
  while d is Some(cur) {
    let mod_dir = cur + "/.mooncakes/" + module_
    if is_module_dir(mod_dir) {
      let src = module_source(mod_dir)
      let base = if src == "" { mod_dir } else { mod_dir + "/" + src }
      return Some(
        if rest.length() == 0 {
          base
        } else {
          base + "/" + rest.join("/")
        },
      )
    }
    d = parent_dir(cur)
  }
  None
}

///|
/// Where the interface of package `pkg` is.
fn find_mbti(pkg : String, dir : String) -> String? {
  let core = "moonbitlang/core/"
  if pkg.has_prefix(core) {
    let rel = pkg.unsafe_substring(start=core.length(), end=pkg.length())
    return mbti_in(moon_home() + "/lib/core/" + rel)
  }
  match mooncakes_package_dir(pkg, dir) {
    Some(pd) => mbti_in(pd)
    None => None
  }
}

///|
/// The packages imported by the package in `dir`, read from its
/// `moon.pkg.json` (if there is one).
fn load_imports(dir : String) -> Array[@tt.Import] raise Failure {
  let cfg = dir + "/moon.pkg.json"
  if !@fs.path_exists(cfg) {
    return []
  }
  let json = match read_json(cfg) {
    Some(j) => j
    None => die(cfg + ": invalid JSON")
  }
  let entries = match json.value("import") {
    Some(Array(xs)) => xs
    Some(_) => die(cfg + ": \"import\" must be an array")
    None => []
  }
  let out : Array[@tt.Import] = []
  for e in entries {
    let (path, alias) = match e {
      String(p) => (p, last_segment(p))
      Object(o) =>
        match (o.get("path"), o.get("alias")) {
          (Some(String(p)), Some(String(a))) => (p, a)
          (Some(String(p)), None) => (p, last_segment(p))
          _ => die(cfg + ": an import needs a \"path\"")
        }
      _ => die(cfg + ": invalid import entry")
    }
    let mbti = match find_mbti(path, dir) {
      Some(p) => p
      None =>
        die(
          "cannot find the interface (.mbti) of package " +
          path +
          " (run `moonpp add` / `moonpp install` for packages from mooncakes.io)",
        )
    }
    let src = @fs.read_file_to_string(mbti) catch {
      err => die("cannot read " + mbti + ": " + err.to_string())
    }
    out.push({ alias, path, mbti: src })
  }
  out
}
