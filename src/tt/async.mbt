///|
/// `async` is an effect of function types, kept with `raise` in the
/// codomain: `async fn f() -> T raise E` has the codomain `T raise
/// %Async[E]`, and `%Async[%NoRaise]` for `noraise` (async functions raise
/// `Error` by default). An async function can only be called in an async
/// function, and is compiled to native MoonBit code.

///|
/// The effect of a codomain `T raise e`: whether it is async, and the type
/// of the errors it may raise (`None`: it does not raise).
pub fn effect_of(e : Val) -> (Bool, Val?) {
  match force(e) {
    VData("%Async", [(err, _)]) =>
      match force(err) {
        VData("%NoRaise", _) => (true, None)
        _ => (true, Some(err))
      }
    _ => (false, Some(e))
  }
}

///|
/// `effect_of` on a core term.
pub fn tm_effect(e : Tm) -> (Bool, Tm?) {
  match e {
    App(Global("%Async"), Global("%NoRaise"), _) => (true, None)
    App(Global("%Async"), err, _) => (true, Some(err))
    _ => (false, Some(e))
  }
}

///|
/// The body of a function with result type `ty`: its type, whether it may
/// raise and whether it is async.
fn body_effects(ty : Val) -> (Val, Bool, Bool) {
  match force(ty) {
    VRaises(a, e) => {
      let (is_async, err) = effect_of(e)
      (a, err is Some(_), is_async)
    }
    other => (other, false, false)
  }
}

///|
/// Is the global `name` an async function (or an async `main`)?
pub fn is_async_global(name : String) -> Bool {
  match globals.get(name) {
    Some(g) => {
      // the codomain after its own parameters (it may return an async
      // function without being one)
      let n = match g.kind {
        GFunc(_, _, n) | GPrim(_, n) => n
        _ => return false
      }
      let mut t = g.ty
      for _ in 0..<n {
        match t {
          Pi(_, _, _, _, b) => t = b
          _ => return false
        }
      }
      t is Raises(_, e) && tm_effect(e).0
    }
    None => false
  }
}
