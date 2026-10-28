///|
/// Command line interface: `mbtpp [check|run] <file.mbtpp>`.
let help_msg : String =
  #|usage:
  #|  mbtpp run <file>     type check the file and run its `main`
  #|  mbtpp check <file>   only type check
  #|  mbtpp <file>         same as `run`
  #|options:
  #|  --no-prelude         do not load the prelude
  #|  --verbose            list the interface items that could not be imported
  #|
  #|MoonBit packages listed in a moon.pkg.json next to the file are imported
  #|(type checking only): refer to them as @pkg.name.

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
fn main {
  let args = @sys.get_cli_args()
  let rest : Array[String] = []
  let mut prelude = true
  let mut verbose = false
  for i = 1; i < args.length(); i = i + 1 {
    match args[i] {
      "--help" | "-h" => {
        println(help_msg)
        return
      }
      "--no-prelude" => prelude = false
      "--verbose" => verbose = true
      a => rest.push(a)
    }
  }
  let (mode, file) = match rest {
    ["check", f] => ("check", f)
    ["run", f] => ("run", f)
    [f] => ("run", f)
    _ => {
      println(help_msg)
      @sys.exit(1)
      return
    }
  }
  let src = @fs.read_file_to_string(file) catch {
    e => {
      println("cannot read " + file + ": " + e.to_string())
      @sys.exit(1)
      return
    }
  }
  let imports = load_imports(file) catch {
    Failure(msg) => {
      println(msg)
      @sys.exit(1)
      return
    }
  }
  @tt.check_program(file, src, prelude~, imports~) catch {
    @tt.CheckError(msg) => {
      println(msg)
      @sys.exit(1)
      return
    }
  }
  if verbose && @tt.import_skipped.length() > 0 {
    println("not imported:")
    for s in @tt.import_skipped {
      println("  " + s)
    }
  }
  if mode == "check" {
    println("ok")
    return
  }
  let out = { buf: StringBuilder::new() }
  @interp.run_main(s => out.write(s)) catch {
    @interp.RunError(msg) => {
      out.flush()
      println(msg)
      @sys.exit(1)
      return
    }
  }
  out.flush()
}
