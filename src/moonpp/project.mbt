///|
/// Projects: a MoonBit++ project is a MoonBit module (`moon.mod.json`, so
/// that `moon add` / `moon install` manage its dependencies) whose packages
/// are directories of `.mbtpp` files, each with an optional `moon.pkg.json`
/// listing the MoonBit packages it imports.
fn dir_of(path : String) -> String {
  let a = path.rev_find("/")
  let b = path.rev_find("\\")
  let k = match (a, b) {
    (Some(x), Some(y)) => if x > y { x } else { y }
    (Some(x), None) | (None, Some(x)) => x
    (None, None) => return "."
  }
  if k == 0 {
    "/"
  } else {
    path.unsafe_substring(start=0, end=k)
  }
}

///|
/// Fail with a message (unlike `fail`, without the location in moonpp).
fn[T] die(msg : String) -> T raise Failure {
  raise Failure(msg)
}

///|
fn parent_dir(dir : String) -> String? {
  let d = dir_of(dir)
  if d == dir || d == "." || d == "" || d == "/" {
    None
  } else {
    Some(d)
  }
}

///|
fn last_segment(path : String) -> String {
  match path.rev_find("/") {
    Some(k) => path.unsafe_substring(start=k + 1, end=path.length())
    None => path
  }
}

///|
fn list_dir(dir : String) -> Array[String] {
  let names = @fs.read_dir(dir) catch { _ => return [] }
  names.sort()
  names
}

///|
fn is_dir(path : String) -> Bool {
  @fs.is_dir(path) catch {
    _ => false
  }
}

///|
fn read_json(path : String) -> Json? {
  if !@fs.path_exists(path) {
    return None
  }
  let text = @fs.read_file_to_string(path) catch { _ => return None }
  let j = @json.parse(text) catch { _ => return None }
  Some(j)
}

///|
/// The root of the project containing `dir`: the nearest directory with a
/// `moon.mod.json`.
fn find_project(dir : String) -> String? {
  let mut d : String? = Some(dir)
  while d is Some(cur) {
    if @fs.path_exists(cur + "/moon.mod.json") {
      return Some(cur)
    }
    d = parent_dir(cur)
  }
  None
}

///|
/// The `.mbtpp` files of a package directory.
fn package_files(dir : String) -> Array[String] {
  list_dir(dir).filter(f => f.has_suffix(".mbtpp")).map(f => dir + "/" + f)
}

///|
/// The packages of a project: the directories (below its `source`
/// directory) that contain `.mbtpp` files.
fn project_packages(root : String) -> Array[String] {
  let src = module_source(root)
  let base = if src == "" { root } else { root + "/" + src }
  let out : Array[String] = []
  fn walk(dir : String, out : Array[String]) -> Unit {
    if package_files(dir).length() > 0 {
      out.push(dir)
    }
    for name in list_dir(dir) {
      if name.has_prefix(".") ||
        name.has_prefix("_") ||
        name == "target" ||
        name == "node_modules" {
        continue
      }
      let sub = dir + "/" + name
      if is_dir(sub) {
        walk(sub, out)
      }
    }
  }

  walk(base, out)
  out
}

///|
/// Is the package in `dir` a main package (`"is-main": true` in its
/// `moon.pkg.json`)?
fn is_main_package(dir : String) -> Bool {
  match read_json(dir + "/moon.pkg.json") {
    Some(j) => j.value("is-main") is Some(Json::True)
    None => false
  }
}

///|
/// A path relative to `base`, for messages.
fn relative(path : String, base : String) -> String {
  if path.has_prefix(base + "/") {
    path.unsafe_substring(start=base.length() + 1, end=path.length())
  } else {
    path
  }
}

///|
let template_main : String =
  #|// A MoonBit++ program. `moonpp run` runs it, `moonpp check` type checks it.
  #|
  #|enum Vector[T] : Nat -> Type {
  #|  Nil : Vector[T](0)
  #|  Cons[n : Nat](T, Vector[T](n)) : Vector[T](S(n))
  #|}
  #|
  #|// `head` only accepts non-empty vectors: no case for `Nil` is needed.
  #|fn[T, n : Nat] Vector::head(self : Vector[T](S(n))) -> T {
  #|  match self {
  #|    Cons(x, _) => x
  #|  }
  #|}
  #|
  #|fn main {
  #|  let v : Vector[String](2) = Cons("Hello", Cons("MoonBit++", Nil))
  #|  println(v.head() + ", " + v.tail_head())
  #|}
  #|
  #|fn[T, n : Nat] Vector::tail_head(self : Vector[T](S(S(n)))) -> T {
  #|  match self {
  #|    Cons(_, Cons(y, _)) => y
  #|  }
  #|}
  #|

///|
/// `moonpp new <name>`: create a project directory.
fn new_project(name : String) -> Unit raise Failure {
  if @fs.path_exists(name) {
    die(name + " already exists")
  }
  let module_name = "username/" + last_segment(name)
  let files : Array[(String, String)] = [
    (
      "moon.mod.json",
      (
        $|{
        $|  "name": "\{module_name}",
        $|  "version": "0.1.0",
        $|  "deps": {},
        $|  "source": "src"
        $|}
        $|
      ),
    ),
    (
      "src/main/moon.pkg.json",
      (
        #|{
        #|  "is-main": true,
        #|  "import": []
        #|}
        #|
      ),
    ),
    ("src/main/main.mbtpp", template_main),
    (
      ".gitignore",
      (
        #|.mooncakes/
        #|_build/
        #|target/
        #|
      ),
    ),
    (
      "README.md",
      (
        $|# \{last_segment(name)}
        $|
        $|A MoonBit++ project.
        $|
        $|```bash
        $|moonpp run                 # run src/main
        $|moonpp check               # type check all packages
        $|moonpp add <user/module>   # add a dependency from mooncakes.io
        $|```
        $|
        $|Imported MoonBit packages are listed in the `import` field of a
        $|package's `moon.pkg.json` and used as `@pkg.name`.
        $|
      ),
    ),
  ]
  for f in files {
    let path = name + "/" + f.0
    let parts = f.0.split("/").map(s => s.to_string()).to_array()
    let mut d = name
    @fs.create_dir(d) catch {
      _ => ()
    }
    for k = 0; k < parts.length() - 1; k = k + 1 {
      d = d + "/" + parts[k]
      @fs.create_dir(d) catch {
        _ => ()
      }
    }
    @fs.write_string_to_file(path, f.1) catch {
      e => die("cannot write " + path + ": " + e.to_string())
    }
  }
}
