///|
/// Resolution of the MoonBit packages a program imports: they are listed in
/// a `moon.pkg.json` next to the source file, as in MoonBit:
///
///   { "import": [ "moonbitlang/core/math", { "path": "...", "alias": "m" } ] }
///
/// The interface of `moonbitlang/core/<pkg>` is read from the MoonBit
/// installation (`$MOON_HOME/lib/core`, by default `~/.moon/lib/core`); other
/// packages from a `.mooncakes` directory next to the file or above it.
fn dir_of(path : String) -> String {
  let a = path.rev_find("/")
  let b = path.rev_find("\\")
  let k = match (a, b) {
    (Some(x), Some(y)) => if x > y { x } else { y }
    (Some(x), None) | (None, Some(x)) => x
    (None, None) => return "."
  }
  path.unsafe_substring(start=0, end=k)
}

///|
fn parent_dir(dir : String) -> String? {
  let d = dir_of(dir)
  if d == dir || d == "." || d == "" {
    None
  } else {
    Some(d)
  }
}

///|
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
fn first_existing(paths : Array[String]) -> String? {
  for p in paths {
    if @fs.path_exists(p) {
      return Some(p)
    }
  }
  None
}

///|
/// Where the interface of package `pkg` is.
fn find_mbti(pkg : String, dir : String) -> String? {
  let core = "moonbitlang/core/"
  if pkg.has_prefix(core) {
    let rel = pkg.unsafe_substring(start=core.length(), end=pkg.length())
    let base = moon_home() + "/lib/core/" + rel
    return first_existing([base + "/pkg.generated.mbti", base + "/pkg.mbti"])
  }
  let mut d : String? = Some(dir)
  while d is Some(cur) {
    let base = cur + "/.mooncakes/" + pkg
    match first_existing([base + "/pkg.generated.mbti", base + "/pkg.mbti"]) {
      Some(p) => return Some(p)
      None => d = parent_dir(cur)
    }
  }
  None
}

///|
fn last_segment(path : String) -> String {
  match path.rev_find("/") {
    Some(k) => path.unsafe_substring(start=k + 1, end=path.length())
    None => path
  }
}

///|
/// The packages imported by the program in `file`, read from the
/// `moon.pkg.json` in its directory (if there is one).
fn load_imports(file : String) -> Array[@tt.Import] raise Failure {
  let dir = dir_of(file)
  let cfg = dir + "/moon.pkg.json"
  if !@fs.path_exists(cfg) {
    return []
  }
  let text = @fs.read_file_to_string(cfg) catch {
    e => fail("cannot read " + cfg + ": " + e.to_string())
  }
  let json = @json.parse(text) catch {
    e => fail(cfg + ": invalid JSON: " + e.to_string())
  }
  let entries = match json.value("import") {
    Some(Array(xs)) => xs
    Some(_) => fail(cfg + ": \"import\" must be an array")
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
          _ => fail(cfg + ": an import needs a \"path\"")
        }
      _ => fail(cfg + ": invalid import entry")
    }
    let mbti = match find_mbti(path, dir) {
      Some(p) => p
      None => fail("cannot find the interface (.mbti) of package " + path)
    }
    let src = @fs.read_file_to_string(mbti) catch {
      err => fail("cannot read " + mbti + ": " + err.to_string())
    }
    out.push({ alias, path, mbti: src })
  }
  out
}
