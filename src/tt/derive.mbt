///|
/// `derive(Show, Eq, Compare)` on enums and structs: the instances are
/// generated as MoonBit++ source and checked like hand-written ones. They
/// are written on the line of the `derive`, so that errors (e.g. a field
/// whose type has no `Show`) are reported there.
///
/// - `Show`: `C(x, y)` for constructors, `{x: 1, y: 2}` for structs;
/// - `Eq`: the same constructor with equal fields;
/// - `Compare`: by constructor (in declaration order), then by fields from
///   left to right. `Compare` needs `Eq` (derive both).
///
/// Type parameters get the derived trait as a bound: `enum Tree[T] derive(Eq)`
/// gives `impl[T : Eq] Eq for Tree[T]`. Indexed types, GADT constructors and
/// explicit parameters are not supported.
let derivable : Array[String] = ["Show", "Eq", "Compare"]

///|
/// Lines with generated code: no editor information is recorded there.
pub let derived_lines : Array[Int32] = []

///|
/// The declarations with their `derive`s replaced by the generated impls.
fn expand_derives(
  decls : Array[@parser.Decl],
) -> Array[@parser.Decl] raise ElabError {
  let out : Array[@parser.Decl] = []
  for d in decls {
    let ds : Array[(Pos, String)] = []
    out.push(strip_derives(d, ds))
    for x in ds {
      let (p, tr) = x
      for g in derived_impls(d.inner(), p, tr) {
        out.push(g)
      }
    }
  }
  out
}

///|
fn strip_derives(d : @parser.Decl, ds : Array[(Pos, String)]) -> @parser.Decl {
  match d {
    DMbt(p, n, ro, x) => DMbt(p, n, ro, strip_derives(x, ds))
    DPub(x) => DPub(strip_derives(x, ds))
    DDerive(xs, x) => {
      for y in xs {
        ds.push(y)
      }
      strip_derives(x, ds)
    }
    _ => d
  }
}

///|
/// The impl of `tr` for the type declared by `d`, parsed.
fn derived_impls(
  d : @parser.Decl,
  p : Pos,
  tr : String,
) -> Array[@parser.Decl] raise ElabError {
  let cx = empty_cxt(p)
  if !derivable.contains(tr) {
    cx.fail(
      "derive(" + tr + ") is not supported (only " + derivable.join(", ") + ")",
    )
  }
  let (name, tparams) = match d {
    DEnum({ name, impl_params, params, sig, cons, is_error, .. }) => {
      if is_error {
        cx.fail("derive is not supported for error types")
      }
      if params is Some(_) || sig is Some(_) {
        cx.fail("derive is not supported for indexed types (" + name + ")")
      }
      for c in cons {
        if c.ret is Some(_) {
          cx.fail(
            "derive is not supported for constructors with a return type (" +
            name +
            "::" +
            c.name +
            ")",
          )
        }
      }
      (name, impl_params)
    }
    DStruct({ name, impl_params, params, .. }) => {
      if params is Some(_) {
        cx.fail(
          "derive is not supported for structs with parameters (" + name + ")",
        )
      }
      (name, impl_params)
    }
    _ => cx.fail("derive applies to enums and structs")
  }
  for b in tparams {
    match b.ty {
      None | Some(EType(_)) => ()
      _ =>
        cx.fail(
          "derive needs type parameters only, but " +
          name +
          " has the parameter " +
          b.name,
        )
    }
  }
  let ts = tparams.map(b => b.name)
  let head = if ts.length() == 0 {
    name
  } else {
    name + "[" + ts.join(", ") + "]"
  }
  let bounds = if ts.length() == 0 {
    ""
  } else {
    "[" + ts.map(t => t + " : " + tr).join(", ") + "]"
  }
  let impl_head = "impl" + bounds + " " + tr + " for " + head + " with "
  let body = match d {
    DEnum(ed) => {
      let cons = ed.cons.map(c => {
        (name + "::" + c.name, c.name, c.params.length())
      })
      enum_body(tr, cons)
    }
    DStruct(sd) => struct_body(tr, sd.fields.map(f => f.1))
    _ => ""
  }
  let src = impl_head + body
  derived_lines.push(p.line)
  let ds = @parser.parse_program(src, line0=p.line) catch {
    @parser.ParseError(_, msg) =>
      cx.fail("internal error in derive(" + tr + "): " + msg + "\n" + src)
  }
  // the impls belong to the file of the type
  match global_files.get(name) {
    Some(f) => record_file(ds, f)
    None => ()
  }
  ds
}

///|
fn vars(x : String, n : Int32) -> Array[String] {
  Array::makei(n, k => x + k.to_string())
}

///|
fn con_pat(c : String, xs : Array[String]) -> String {
  if xs.length() == 0 {
    c
  } else {
    c + "(" + xs.join(", ") + ")"
  }
}

///|
/// `x0.compare(y0)`, then the next fields while they are equal.
fn lex_compare(xs : Array[String], ys : Array[String]) -> String {
  if xs.length() == 0 {
    return "0"
  }
  let mut code = xs[xs.length() - 1] + ".compare(" + ys[ys.length() - 1] + ")"
  for k = xs.length() - 2; k >= 0; k = k - 1 {
    code = "{ let c = " +
      xs[k] +
      ".compare(" +
      ys[k] +
      "); if c == 0 { " +
      code +
      " } else { c } }"
  }
  code
}

///|
/// The method of `tr` for an enum with constructors (qualified name, name,
/// number of explicit fields).
fn enum_body(tr : String, cons : Array[(String, String, Int32)]) -> String {
  match tr {
    "Show" => {
      let arms = cons.map(c => {
        let (q, short, n) = c
        let xs = vars("x", n)
        let shown = if n == 0 {
          short.escape()
        } else {
          (short + "(").escape() +
          " + " +
          xs.map(x => x + ".to_string()").join(" + \", \" + ") +
          " + \")\""
        }
        con_pat(q, xs) + " => " + shown
      })
      "to_string(self) { match self { " + arms.join("; ") + " } }"
    }
    "Eq" => {
      let arms = cons.map(c => {
        let (q, _, n) = c
        let xs = vars("x", n)
        let ys = vars("y", n)
        let eq = if n == 0 {
          "true"
        } else {
          xs.mapi((k, x) => x + " == " + ys[k]).join(" && ")
        }
        "(" + con_pat(q, xs) + ", " + con_pat(q, ys) + ") => " + eq
      })
      "op_equal(a, b) { match (a, b) { " +
      [..arms, "_ => false"].join("; ") +
      " } }"
    }
    _ => {
      let arms = cons.map(c => {
        let (q, _, n) = c
        let xs = vars("x", n)
        let ys = vars("y", n)
        "(" +
        con_pat(q, xs) +
        ", " +
        con_pat(q, ys) +
        ") => " +
        lex_compare(xs, ys)
      })
      // different constructors: by position
      let tag = (v : String) => {
        "match " +
        v +
        " { " +
        cons
        .mapi((k, c) => {
          con_pat(c.0, Array::make(c.2, "_")) + " => " + k.to_string()
        })
        .join("; ") +
        " }"
      }
      "compare(a, b) { match (a, b) { " +
      [
        ..arms,
        "_ => { let ta = " +
        tag("a") +
        "; let tb = " +
        tag("b") +
        "; ta.compare(tb) }",
      ].join("; ") +
      " } }"
    }
  }
}

///|
/// The method of `tr` for a struct with the given fields.
fn struct_body(tr : String, fields : Array[String]) -> String {
  match tr {
    "Show" => {
      let parts = fields.mapi((k, f) => {
        let sep = if k == 0 { "" } else { ", " }
        (sep + f + ": ").escape() + " + self." + f + ".to_string()"
      })
      "to_string(self) { " + ["\"{\"", ..parts, "\"}\""].join(" + ") + " }"
    }
    "Eq" => {
      let eq = if fields.length() == 0 {
        "true"
      } else {
        fields.map(f => "a." + f + " == b." + f).join(" && ")
      }
      "op_equal(a, b) { " + eq + " }"
    }
    _ =>
      "compare(a, b) { " +
      lex_compare(fields.map(f => "a." + f), fields.map(f => "b." + f)) +
      " }"
  }
}
