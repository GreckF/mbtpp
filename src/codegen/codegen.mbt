///|
/// MoonBit++ → MoonBit: elaborated core terms are translated to MoonBit
/// code over the uniform representation `Value` of the runtime
/// (`runtime.mbt`). Only the globals reachable from `main` are emitted.
/// Calls of imported MoonBit functions go through generated glue that
/// converts between `Value` and MoonBit types (see `ffi`).
pub suberror CodegenError {
  CodegenError(String)
}

///|
priv struct Gen {
  ids : Map[String, String]
  todo : Array[String]
  defs : StringBuilder
  ffi : StringBuilder
  /// MoonBit type of a foreign value -> its `Foreign` constructor.
  foreign : Map[String, String]
  foreign_order : Array[String]
  /// Package path -> alias, for imported packages.
  aliases : Map[String, String]
  mut fresh : Int
}

///|
fn Gen::name(self : Gen, base : String) -> String {
  self.fresh = self.fresh + 1
  base + self.fresh.to_string()
}

///|
/// The MoonBit identifier of a global (scheduling it for emission).
fn Gen::gid(self : Gen, name : String) -> String {
  match self.ids.get(name) {
    Some(id) => id
    None => {
      let buf = StringBuilder::new()
      for c in name {
        if (c >= 'a' && c <= 'z') ||
          (c >= 'A' && c <= 'Z') ||
          (c >= '0' && c <= '9') {
          buf.write_char(
            if c >= 'A' && c <= 'Z' {
              Int::unsafe_to_char(c.to_int() + 32)
            } else {
              c
            },
          )
        } else {
          buf.write_char('_')
        }
      }
      let id = "g" + self.ids.length().to_string() + "_" + buf.to_string()
      self.ids.set(name, id)
      self.todo.push(name)
      id
    }
  }
}

///|
fn double_lit(d : Double) -> String {
  let s = d.to_string()
  if s == "Infinity" {
    "(1.0 / 0.0)"
  } else if s == "-Infinity" {
    "(-1.0 / 0.0)"
  } else if s == "NaN" {
    "(0.0 / 0.0)"
  } else if s.contains(".") || s.contains("e") {
    s
  } else {
    s + ".0"
  }
}

///|
fn lit_code(l : @tt.Lit) -> String {
  match l {
    LInt(n) => "VInt(" + n.to_string() + ")"
    LStr(s) => "VStr(" + s.escape() + ")"
    LChar(c) => "VChar(Int::unsafe_to_char(" + c.to_int().to_string() + "))"
    LBool(b) => "VBool(" + b.to_string() + ")"
    LUnit => "VUnit"
    LDouble(d) => "VDouble(" + double_lit(d) + ")"
  }
}

///|
fn pat_code(p : @tt.CPat) -> String {
  match p {
    CPVar(_) | CPWild => "PAny"
    CPCon(c, ps) =>
      "PCon(" + c.escape() + ", [" + ps.map(pat_code).join(", ") + "])"
    CPLit(l) => "PLit(" + lit_code(l) + ")"
  }
}

///|
priv struct Local {
  name : String
  mutable : Bool
}

///|
fn push_local(env : Array[Local], l : Local) -> Array[Local] {
  let e = env.copy()
  e.push(l)
  e
}

///|
/// The clauses of a match (or of a handler) as an `if` chain over
/// `match_pats`; `fallback` is the code for when no clause matches.
fn Gen::clauses(
  self : Gen,
  env : Array[Local],
  scruts : String,
  cls : Array[@tt.Clause],
  fallback : String,
) -> String {
  let out = self.name("o")
  let buf = StringBuilder::new()
  buf.write_string("{\nlet " + out + " : Array[Value] = []\n")
  for cl in cls {
    let mut env2 = env
    let binds = StringBuilder::new()
    for k = 0; k < @tt.pats_slots(cl.pats); k = k + 1 {
      let x = self.name("v")
      binds.write_string("let " + x + " = " + out + "[" + k.to_string() + "]\n")
      env2 = push_local(env2, { name: x, mutable: false })
    }
    buf.write_string(
      "if match_pats([" +
      cl.pats.map(pat_code).join(", ") +
      "], " +
      scruts +
      ", " +
      out +
      ") {\n",
    )
    buf.write_string(binds.to_string())
    // parenthesised: a lone variable in braces would be a record literal
    buf.write_string("(" + self.tm(env2, cl.body) + ")")
    buf.write_string("\n} else ")
  }
  buf.write_string("{\n" + fallback + "\n}\n}")
  buf.to_string()
}

///|
fn Gen::tm(self : Gen, env : Array[Local], t : @tt.Tm) -> String {
  match t {
    Var(ix) => {
      let l = env[env.length() - 1 - ix]
      if l.mutable {
        l.name + ".val"
      } else {
        l.name
      }
    }
    Global(n) => self.gid(n) + "()"
    Lam(_, _, _, b) => {
      let x = self.name("x")
      let body = self.tm(push_local(env, { name: x, mutable: false }), b)
      if b is Lam(_, _, _, _) {
        "VFun(" + x + " => " + body + ")"
      } else {
        // the body of a function: `return` stops here
        "VFun(" +
        x +
        " => try { (" +
        body +
        ") } catch { CReturn(r) => r; e => raise e })"
      }
    }
    App(f, a, _) => "apply(" + self.tm(env, f) + ", " + self.tm(env, a) + ")"
    Let(_, _, v, b) => {
      let x = self.name("v")
      "{\nlet " +
      x +
      " = " +
      self.tm(env, v) +
      "\n" +
      self.tm(push_local(env, { name: x, mutable: false }), b) +
      "\n}"
    }
    LetMut(_, _, v, b) => {
      let x = self.name("m")
      "{\nlet " +
      x +
      " = Ref::new(" +
      self.tm(env, v) +
      ")\n" +
      self.tm(push_local(env, { name: x, mutable: true }), b) +
      "\n}"
    }
    U
    | PropU
    | Pi(_, _, _, _, _)
    | Raises(_, _)
    | Meta(_)
    | InsertedMeta(_, _) => "VType"
    Lit(l) => lit_code(l)
    Match(ss, cls) => {
      let s = self.name("s")
      "{\nlet " +
      s +
      " = [" +
      ss.map(x => self.tm(env, x)).join(", ") +
      "]\n" +
      self.clauses(env, s, cls, "rt_fail(\"no match\")") +
      "\n}"
    }
    Assign(ix, v) => {
      let l = env[env.length() - 1 - ix]
      "{\n" + l.name + ".val = " + self.tm(env, v) + "\nVUnit\n}"
    }
    While(c, b, step) =>
      "{\nwhile truthy(" +
      self.tm(env, c) +
      ") {\n" +
      "let brk = try { ignore(" +
      self.tm(env, b) +
      "); false } catch { CBreak => true; CContinue => false; e => raise e }\n" +
      "if brk { break }\nignore(" +
      self.tm(env, step) +
      ")\n}\nVUnit\n}"
    Break => "rt_break()"
    Continue => "rt_continue()"
    Return(v) => "rt_return(" + self.tm(env, v) + ")"
    Raise(v) => "rt_raise(" + self.tm(env, v) + ")"
    Try(b, cls) => {
      let err = self.name("err")
      "(try { (" +
      self.tm(env, b) +
      ") } catch {\nCRaise(" +
      err +
      ") => " +
      self.clauses(env, "[" + err + "]", cls, "rt_raise(" + err + ")") +
      "\ne => raise e\n})"
    }
    ArrayLit(es) => "VArr([" + es.map(x => self.tm(env, x)).join(", ") + "])"
    Seq(a, b) =>
      "{\nignore(" + self.tm(env, a) + ")\n" + self.tm(env, b) + "\n}"
  }
}

///|
/// Nested functions collecting `n` arguments `a0 .. a(n-1)`, then `final`.
fn curried(n : Int, final_ : String) -> String {
  let mut code = final_
  for k = n - 1; k >= 0; k = k - 1 {
    code = "VFun(a" + k.to_string() + " => " + code + ")"
  }
  code
}

///|
/// The icitness of the binders of a (closed) Pi type.
fn binder_icits(ty : @tt.Tm, n : Int) -> Array[@tt.Icit] {
  let out : Array[@tt.Icit] = []
  let mut t = ty
  for _ in 0..<n {
    match t {
      Pi(_, i, _, _, b) => {
        out.push(i)
        t = b
      }
      _ => out.push(Expl)
    }
  }
  out
}

///|
fn Gen::global(self : Gen, name : String) -> Unit raise CodegenError {
  let g = match @tt.globals.get(name) {
    Some(g) => g
    None => raise CodegenError("unknown global " + name)
  }
  let code = match g.kind {
    GFunc(Some(body), _, _) => self.tm([], body)
    GFunc(None, _, _) => "rt_fail(\"" + name + " has no definition\")"
    GData(_) => "VType"
    GCon(ci) =>
      if ci.nparams + ci.nargs == 0 {
        "VCon(" + name.escape() + ", [])"
      } else {
        let args : Array[String] = []
        for k = ci.nparams; k < ci.nparams + ci.nargs; k = k + 1 {
          args.push("a" + k.to_string())
        }
        curried(
          ci.nparams + ci.nargs,
          "VCon(" + name.escape() + ", [" + args.join(", ") + "])",
        )
      }
    GPrim(p, arity) => {
      let all : Array[String] = []
      for k = 0; k < arity; k = k + 1 {
        all.push("a" + k.to_string())
      }
      let call = if p.has_prefix("@mbt:") {
        self.ffi_fn(name, p, g.ty, arity) + "([" + all.join(", ") + "])"
      } else {
        let icits = binder_icits(g.ty, arity)
        let expl : Array[String] = []
        for k = 0; k < arity; k = k + 1 {
          if icits[k] == Expl {
            expl.push("a" + k.to_string())
          }
        }
        "prim(" + p.escape() + ", [" + expl.join(", ") + "])"
      }
      curried(arity, call)
    }
  }
  let id = self.gid(name)
  self.defs.write_string(
    (
      $|
      $|let \{id}_cache : Ref[Value?] = Ref::new(None)
      $|
      $|fn \{id}() -> Value raise {
      $|  match \{id}_cache.val {
      $|    Some(v) => v
      $|    None => {
      $|      let v = \{code}
      $|      \{id}_cache.val = Some(v)
      $|      v
      $|    }
      $|  }
      $|}
      $|
    ),
  )
}

///|
/// Generate the MoonBit program for the last type checked MoonBit++
/// program. `imports` are the imported packages (path, alias).
pub fn generate(imports : Array[(String, String)]) -> String raise CodegenError {
  if !@tt.globals.contains("main") {
    raise CodegenError("no main function")
  }
  let g : Gen = {
    ids: {},
    todo: [],
    defs: StringBuilder::new(),
    ffi: StringBuilder::new(),
    foreign: {},
    foreign_order: [],
    aliases: {},
    fresh: 0,
  }
  for im in imports {
    g.aliases.set(im.0, im.1)
  }
  let main_id = g.gid("main")
  while g.todo.length() > 0 {
    let n = g.todo.pop().unwrap()
    g.global(n)
  }
  let foreign = StringBuilder::new()
  foreign.write_string("enum Foreign {\n  FNone\n")
  for ty in g.foreign_order {
    foreign.write_string("  " + g.foreign.get(ty).unwrap() + "(" + ty + ")\n")
  }
  foreign.write_string("}\n")
  "// Generated by moonpp from MoonBit++. Do not edit.\n\n" +
  runtime_src +
  "\n// ---- foreign MoonBit values and functions ----------------------------\n\n" +
  foreign.to_string() +
  g.ffi.to_string() +
  "\n// ---- the program ------------------------------------------------------\n" +
  g.defs.to_string() +
  "\nfn main {\n  run_main(() => " +
  main_id +
  "())\n}\n"
}
