///|
/// Why a signature or a type has no native translation, for
/// `moonpp build --verbose` (see `native_report`): the first parameter whose
/// type is not native, then the datatypes and fields that make it so.
fn Gen::sig_reason(self : Gen, name : String) -> String {
  let n = match func_arity(name) {
    Some(n) => n
    None => return "it is not a function"
  }
  let mut t = @tt.globals.get(name).unwrap().ty
  let ctx : Array[TyCtx] = []
  let names : Array[String] = []
  let mut ntvars = 0
  for i = 0; i < n; i = i + 1 {
    match t {
      Pi(x, icit, _, a, b) => {
        if icit == Inst && !self.er.fun_erased(name, i) {
          if bound_of(ctx, a) is None {
            return "the bound " +
              @tt.show_tm(names, a) +
              " is not on a type parameter, or its trait is not #mbt"
          }
          ctx.push(TyOther)
        } else if self.er.fun_erased(name, i) {
          if a is U && !@tt.only_in_rows(b) {
            ctx.push(TyIs(NVar(ntvars)))
            ntvars = ntvars + 1
          } else {
            ctx.push(TyOther)
          }
        } else if icit == Inst {
          return "it has an instance argument that is not erased"
        } else {
          if self.native_ty_in(ctx, a) is None {
            return "the parameter " +
              x +
              " has the type " +
              @tt.show_tm(names, a) +
              self.type_reason(ctx, names, a, 0)
          }
          ctx.push(TyOther)
        }
        names.push(x)
        t = b
      }
      _ => return "its type is not a function type"
    }
  }
  let result = match t {
    Raises(r, _) => r
    _ => t
  }
  if self.native_ty_in(ctx, result) is None {
    return "the result type " +
      @tt.show_tm(names, result) +
      self.type_reason(ctx, names, result, 0)
  }
  "a type parameter occurs only in effects or bounds, not in the parameters or the result"
}

///|
/// Why the type `a` (in the context `ctx`) is not native: ", which ...".
fn Gen::type_reason(
  self : Gen,
  ctx : Array[TyCtx],
  names : Array[String],
  a : @tt.Tm,
  depth : Int32,
) -> String {
  if depth > 3 {
    return ""
  }
  match a {
    U | PropU => ", a type (types are erased only as implicit parameters)"
    Var(_) => ", a parameter that is not a type parameter"
    Pi(_, _, _, _, _) =>
      ", a function type with a type that is not native (or an effect other than async and errors)"
    _ => {
      let (h, args) = flatten_app(a)
      match h {
        // a `mut` field is a box (an array) of its type
        Global("Array" | "Ref") if args.length() == 1 =>
          self.type_reason(ctx, names, args[0], depth)
        Global(d) =>
          match self.data_reason(d, depth) {
            Some(r) => ", and " + r
            None =>
              // the datatype is native: one of its type arguments is not
              match
                args
                .iter()
                .find_first(x => {
                  !(x is (U | PropU)) && self.native_ty_in(ctx, x) is None
                }) {
                Some(x) =>
                  ", whose argument " +
                  @tt.show_tm(names, x) +
                  " is not native" +
                  self.type_reason(ctx, names, x, depth + 1)
                None => ""
              }
          }
        _ => ""
      }
    }
  }
}

///|
/// Why the datatype `d` is not a native enum, if it is not.
fn Gen::data_reason(self : Gen, d : String, depth : Int32) -> String? {
  if self.enum_ok(d) || self.nat_like(d) is Some(_) || @tt.is_foreign_type(d) {
    return None
  }
  let di = match @tt.data_info(d) {
    Some(di) => di
    None => return Some(d + " is not a datatype")
  }
  if di.is_prop {
    return Some(d + " is a proposition")
  }
  if di.is_trait {
    return Some(d + " is a trait")
  }
  if @tt.is_effect(d) {
    return Some(d + " is an effect")
  }
  if d.has_prefix("@") {
    return Some(d + " is an imported type that is not a MoonBit type here")
  }
  if di.cons.length() == 0 {
    return Some(d + " has no constructors")
  }
  let tps = match data_type_params(d) {
    Some(tps) => tps
    None => return Some(d + " has parameters that are not understood")
  }
  // the first field whose type is not native
  for c in di.cons {
    let ci = @tt.con_info(c).unwrap()
    let mut t = @tt.globals.get(c).unwrap().ty
    let ctx : Array[TyCtx] = []
    let names : Array[String] = []
    let mut ntv = 0
    for k = 0; k < ci.nparams; k = k + 1 {
      match t {
        Pi(x, _, _, _, b) => {
          if tps[k] {
            ctx.push(TyIs(NVar(ntv)))
            ntv = ntv + 1
          } else {
            ctx.push(TyOther)
          }
          names.push(x)
          t = b
        }
        _ => return Some(d + " has a constructor of an unexpected type")
      }
    }
    for j = 0; j < ci.nargs; j = j + 1 {
      match t {
        Pi(x, _, _, a, b) => {
          if !self.er.con_erased(c, j) && self.native_ty_in(ctx, a) is None {
            let field = match di.fields {
              Some(fs) if j < fs.length() => "the field " + fs[j]
              _ => "field " + (j + 1).to_string() + " of " + short_con(c)
            }
            return Some(
              field +
              " of " +
              d +
              " has the type " +
              @tt.show_tm(names, a) +
              self.type_reason(ctx, names, a, depth + 1),
            )
          }
          ctx.push(TyOther)
          names.push(x)
          t = b
        }
        _ => break
      }
    }
  }
  Some(d + " is not native")
}
