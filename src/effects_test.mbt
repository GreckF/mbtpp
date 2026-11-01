///|
/// Algebraic effects (see doc/mbtpp/effects.md).

///|
test "a handler that resumes in tail position" {
  inspect(
    run_source(
      "t.mbtpp",
      (
        #|effect Yield[T] {
        #|  Yield(T) -> Unit
        #|}
        #|
        #|fn[T] iter_array(xs : Array[T]) -> Unit!Yield[T] {
        #|  for x in xs {
        #|    perform Yield(x)
        #|  }
        #|}
        #|
        #|fn main {
        #|  try {
        #|    iter_array([1, 2, 3])
        #|  } catch {
        #|    Yield(x) => {
        #|      println(x)
        #|      resume()
        #|    }
        #|  }
        #|}
      ),
    ),
    content=(
      #|1
      #|2
      #|3
      #|
    ),
  )
}

///|
test "state, logs, nested handlers and lambdas that capture a handler" {
  inspect(
    run_source(
      "t.mbtpp",
      (
        #|effect State[S] {
        #|  Get() -> S
        #|  Put(S) -> Unit
        #|}
        #|
        #|effect Log {
        #|  Log(String) -> Unit
        #|}
        #|
        #|fn counter(n : Int) -> Int!State[Int] + Log {
        #|  let mut i = 0
        #|  while i < n {
        #|    let v = perform Get()
        #|    perform Put(v + i)
        #|    perform Log("step \{i}")
        #|    i = i + 1
        #|  }
        #|  perform Get()
        #|}
        #|
        #|fn[T] each_list(xs : List[T], f : (T) -> Unit!Log) -> Unit!Log {
        #|  match xs {
        #|    Nil => ()
        #|    Cons(x, rest) => { f(x); each_list(rest, f) }
        #|  }
        #|}
        #|
        #|fn main {
        #|  let mut st = 100
        #|  let r = try {
        #|    try {
        #|      counter(4)
        #|    } catch {
        #|      Log(msg) => { println("log: " + msg); resume() }
        #|    }
        #|  } catch {
        #|    Get() => resume(st)
        #|    Put(v) => { st = v; resume() }
        #|  }
        #|  println(r)
        #|  // a lambda captures the handler in scope
        #|  try {
        #|    each_list(Cons(1, Cons(2, Nil)), x => perform Log("item \{x}"))
        #|  } catch {
        #|    Log(m) => { println(m); resume() }
        #|  }
        #|  // nested handlers of the same effect: the inner one is used
        #|  try {
        #|    try { perform Log("inner") } catch { Log(m) => { println("A " + m); resume() } }
        #|    perform Log("outer")
        #|  } catch {
        #|    Log(m) => { println("B " + m); resume() }
        #|  }
        #|}
      ),
    ),
    content=(
      #|log: step 0
      #|log: step 1
      #|log: step 2
      #|log: step 3
      #|106
      #|item 1
      #|item 2
      #|A inner
      #|B outer
      #|
    ),
  )
}

///|
test "explicit effect polymorphism" {
  inspect(
    run_source(
      "t.mbtpp",
      (
        #|effect Log {
        #|  Log(String) -> Unit
        #|}
        #|
        #|fn[T, e] each(xs : List[T], f : (T) -> Unit!e) -> Unit!e {
        #|  match xs {
        #|    Nil => ()
        #|    Cons(x, rest) => { f(x); each(rest, f) }
        #|  }
        #|}
        #|
        #|fn total(xs : List[Int]) -> Int {
        #|  let mut s = 0
        #|  each(xs, x => { s = s + x })
        #|  s
        #|}
        #|
        #|fn logged(xs : List[Int]) -> Unit!Log {
        #|  each(xs, x => perform Log("x = \{x}"))
        #|}
        #|
        #|fn main {
        #|  println(total(Cons(1, Cons(2, Nil))))
        #|  try { logged(Cons(5, Cons(6, Nil))) } catch { Log(m) => { println(m); resume() } }
        #|  try {
        #|    let f = (x : Int) => perform Log("lambda \{x}")
        #|    f(7)
        #|  } catch { Log(m) => { println(m); resume() } }
        #|}
      ),
    ),
    content=(
      #|3
      #|x = 5
      #|x = 6
      #|lambda 7
      #|
    ),
  )
}

///|
test "inferred effect polymorphism, also of the Prelude" {
  inspect(
    run_source(
      "t.mbtpp",
      (
        #|effect Yield[T] {
        #|  Yield(T) -> Unit
        #|}
        #|
        #|// no annotation: f does not escape, so iter is effect polymorphic
        #|fn[T] iter(xs : List[T], f : (T) -> Unit) -> Unit {
        #|  match xs {
        #|    Nil => ()
        #|    Cons(x, rest) => { f(x); iter(rest, f) }
        #|  }
        #|}
        #|
        #|fn[T] iter_list(xs : List[T]) -> Unit!Yield[T] {
        #|  iter(xs, x => perform Yield(x))
        #|}
        #|
        #|fn main {
        #|  try {
        #|    iter_list(Cons(1, Cons(2, Cons(3, Nil))))
        #|  } catch {
        #|    Yield(x) => { println(x); resume() }
        #|  }
        #|  // the Prelude's List::map is effect polymorphic too
        #|  let ys = try {
        #|    Cons(1, Cons(2, Nil)).map(x => { perform Yield(x * 10); x + 1 })
        #|  } catch {
        #|    Yield(v) => { println("saw \{v}"); resume() }
        #|  }
        #|  println(ys)
        #|}
      ),
    ),
    content=(
      #|1
      #|2
      #|3
      #|saw 10
      #|saw 20
      #|Cons(2, Cons(3, Nil))
      #|
    ),
  )
}

///|
test "ctl operations: all paths, abort, one path" {
  inspect(
    run_source(
      "t.mbtpp",
      (
        #|effect Choose {
        #|  ctl Choose() -> Bool
        #|}
        #|
        #|fn choose2() -> Int!Choose {
        #|  let a = perform Choose()
        #|  let b = perform Choose()
        #|  (if a { 2 } else { 0 }) + (if b { 1 } else { 0 })
        #|}
        #|
        #|fn main {
        #|  // all paths: resume twice (multi-shot)
        #|  let all = try {
        #|    let v = choose2()
        #|    Cons(v, Nil)
        #|  } catch {
        #|    Choose() => resume(true).append(resume(false))
        #|  }
        #|  println(all)
        #|  // abort: do not resume
        #|  let r = try { choose2() } catch { Choose() => -1 }
        #|  println(r)
        #|  // one-shot
        #|  let one = try { choose2() } catch { Choose() => resume(true) }
        #|  println(one)
        #|}
      ),
    ),
    content=(
      #|Cons(3, Cons(2, Cons(1, Cons(0, Nil))))
      #|-1
      #|3
      #|
    ),
  )
}

///|
test "ctl operations: let mut per resumption, loops, return, polymorphism, nesting" {
  inspect(
    run_source(
      "t.mbtpp",
      (
        #|effect Choose {
        #|  ctl Choose() -> Bool
        #|}
        #|
        #|effect Gen[T] {
        #|  ctl Emit(T) -> Unit
        #|}
        #|
        #|effect Fail {
        #|  ctl Fail() -> Unit
        #|}
        #|
        #|// `let mut` keeps its value per resumption
        #|fn count_trues() -> Int!Choose {
        #|  let mut n = 0
        #|  if perform Choose() { n = n + 1 }
        #|  if perform Choose() { n = n + 1 }
        #|  n
        #|}
        #|
        #|// a loop with `break`, performing in its body
        #|fn emit_until(limit : Int) -> Unit!Gen[Int] {
        #|  let mut i = 0
        #|  while true {
        #|    if i >= limit { break }
        #|    perform Emit(i)
        #|    i = i + 1
        #|  }
        #|}
        #|
        #|fn first_true() -> Int!Choose {
        #|  let mut i = 0
        #|  while i < 5 {
        #|    if perform Choose() { return i }
        #|    i = i + 1
        #|  }
        #|  -1
        #|}
        #|
        #|fn[T] each(xs : List[T], f : (T) -> Unit) -> Unit {
        #|  match xs {
        #|    Nil => ()
        #|    Cons(x, rest) => { f(x); each(rest, f) }
        #|  }
        #|}
        #|
        #|fn main {
        #|  println(try { Cons(count_trues(), Nil) } catch { Choose() => resume(true).append(resume(false)) })
        #|  // collect what a generator emits
        #|  let mut got : List[Int] = Nil
        #|  try { emit_until(4) } catch { Emit(x) => { got = Cons(x, got); resume(()) } }
        #|  println(got)
        #|  // return from inside the loop
        #|  println(try { first_true() } catch { Choose() => resume(false) })
        #|  println(try { Cons(first_true(), Nil) } catch { Choose() => resume(true).append(resume(false)) })
        #|  // an effect-polymorphic function with a ctl lambda (its translated version)
        #|  let mut seen : List[Int] = Nil
        #|  try {
        #|    each(Cons(1, Cons(2, Cons(3, Nil))), x => perform Emit(x * 100))
        #|  } catch {
        #|    Emit(v) => { seen = Cons(v, seen); resume(()) }
        #|  }
        #|  println(seen)
        #|  // nested handlers: Fail passes through the Choose handler
        #|  let r = try {
        #|    try {
        #|      let a = perform Choose()
        #|      if !a { perform Fail() }
        #|      Cons(1, Nil)
        #|    } catch {
        #|      Choose() => resume(true).append(resume(false))
        #|    }
        #|  } catch {
        #|    Fail() => Nil
        #|  }
        #|  println(r)
        #|}
      ),
    ),
    content=(
      #|Cons(2, Cons(1, Cons(1, Cons(0, Nil))))
      #|Cons(3, Cons(2, Cons(1, Cons(0, Nil))))
      #|-1
      #|Cons(0, Cons(1, Cons(2, Cons(3, Cons(4, Cons(-1, Nil))))))
      #|Cons(300, Cons(200, Cons(100, Nil)))
      #|Nil
      #|
    ),
  )
}

///|
test "handled code computes during type checking" {
  inspect(
    check(
      (
        #|effect Yield[T] {
        #|  Yield(T) -> Unit
        #|}
        #|
        #|fn[T] iter(xs : List[T], f : (T) -> Unit) -> Unit {
        #|  match xs {
        #|    Nil => ()
        #|    Cons(x, rest) => { f(x); iter(rest, f) }
        #|  }
        #|}
        #|
        #|fn[T] iter_list(xs : List[T]) -> Unit!Yield[T] {
        #|  iter(xs, x => perform Yield(x))
        #|}
        #|
        #|// a handler without state
        #|fn count(xs : List[Int]) -> Int {
        #|  try { iter_list(xs); 0 } catch { Yield(_) => resume() }
        #|}
        #|
        #|// a handler that updates a `let mut`
        #|fn sum(xs : List[Int]) -> Int {
        #|  let mut s = 0
        #|  try { iter_list(xs) } catch { Yield(x) => { s = s + x; resume() } }
        #|  s
        #|}
        #|
        #|lemma count_ok() -> count(Cons(1, Nil)) === 0 { Refl }
        #|lemma sum_ok() -> sum(Cons(1, Cons(2, Cons(3, Nil)))) === 6 { Refl }
        #|
        #|effect Ask {
        #|  Ask() -> Int
        #|}
        #|
        #|fn with_default(xs : List[Int]) -> List[Int] {
        #|  try { xs.map(x => x + perform Ask()) } catch { Ask() => resume(10) }
        #|}
        #|
        #|lemma with_default_cons(x : Int, xs : List[Int]) ->
        #|  with_default(Cons(x, xs)) === Cons(x + 10, with_default(xs)) { Refl }
      ),
    ),
    content=(
      #|ok
    ),
  )
}

///|
test "perform needs a handler or a declared effect" {
  inspect(
    check(
      (
        #|effect Log {
        #|  Log(String) -> Unit
        #|}
        #|fn logs() -> Unit!Log { perform Log("x") }
        #|fn f() -> Unit { perform Log("a") }
      ),
    ),
    content=(
      #|t.mbtpp:5:18: error: perform Log: no enclosing `try` handles the effect Log and the function does not declare it
    ),
  )
}

///|
test "a call needs a handler of its effects" {
  inspect(
    check(
      (
        #|effect Log {
        #|  Log(String) -> Unit
        #|}
        #|fn logs() -> Unit!Log { perform Log("x") }
        #|fn f() -> Unit { logs() }
      ),
    ),
    content=(
      #|t.mbtpp:5:22: error: this call performs the effect Log, which no enclosing `try` handles and the function does not declare
    ),
  )
}

///|
test "resume must be the last step of a tail-resumptive arm" {
  inspect(
    check(
      (
        #|effect Log {
        #|  Log(String) -> Unit
        #|}
        #|fn logs() -> Unit!Log { perform Log("x") }
        #|fn f() -> Unit { try { logs() } catch { Log(m) => { resume(); println(m) } } }
      ),
    ),
    content=(
      #|t.mbtpp:5:70: error: the handler of this operation must end with `resume(...)` (declare the operation with `ctl` to resume elsewhere, or not at all)
    ),
  )
}

///|
test "every path of a tail-resumptive arm resumes" {
  inspect(
    check(
      (
        #|effect Log {
        #|  Log(String) -> Unit
        #|}
        #|fn logs() -> Unit!Log { perform Log("x") }
        #|fn f() -> Unit { try { logs() } catch { Log(m) => if m == "" { resume() } else { () } } }
      ),
    ),
    content=(
      #|t.mbtpp:5:82: error: the handler of this operation must end with `resume(...)` (declare the operation with `ctl` to resume elsewhere, or not at all)
    ),
  )
}

///|
test "an operation gets its number of arguments" {
  inspect(
    check(
      (
        #|effect Log {
        #|  Log(String) -> Unit
        #|}
        #|fn logs() -> Unit!Log { perform Log("x") }
        #|fn f() -> Unit { try { logs() } catch { Log(m, n) => resume() } }
      ),
    ),
    content=(
      #|t.mbtpp:5:41: error: Log takes 1 argument(s), got 2
    ),
  )
}

///|
test "a row has effects" {
  inspect(
    check(
      (
        #|effect Log {
        #|  Log(String) -> Unit
        #|}
        #|fn logs() -> Unit!Log { perform Log("x") }
        #|fn f() -> Unit!Int { () }
      ),
    ),
    content=(
      #|t.mbtpp:5:16: error: not an effect: Int
    ),
  )
}

///|
test "a lambda with effects is not a pure function" {
  inspect(
    check(
      (
        #|effect Log {
        #|  Log(String) -> Unit
        #|}
        #|fn logs() -> Unit!Log { perform Log("x") }
        #|fn app(f : () -> Unit!pure) -> Unit { f() }
        #|fn f() -> Unit { try { app(() => perform Log("a")) } catch { Log(m) => resume() } }
      ),
    ),
    content=(
      #|t.mbtpp:6:34: error: this performs Log, which is not handled here and not in the effects of the function (add `!Log` to its type)
    ),
  )
}

///|
test "an effect variable is in the function's effects" {
  inspect(
    check(
      (
        #|fn[e] bad(f : () -> Unit!e) -> Unit { f() }
      ),
    ),
    content=(
      #|t.mbtpp:1:40: error: this performs e, which is not handled here and not in the effects of the function (add `!e` to its type)
    ),
  )
}

///|
test "an escaping parameter is not effect polymorphic" {
  inspect(
    check(
      (
        #|effect Log {
        #|  Log(String) -> Unit
        #|}
        #|fn logs() -> Unit!Log { perform Log("x") }
        #|fn[A, B, C] compose(f : (B) -> C, g : (A) -> B) -> (A) -> C { x => f(g(x)) }
        #|fn h() -> Unit!Log {
        #|  let k = compose((x : Int) => { perform Log("a"); x }, (y : Int) => y)
        #|  let _ = k(1)
        #|}
      ),
    ),
    content=(
      #|t.mbtpp:7:34: error: this performs Log, which is not handled here and not in the effects of the function (add `!Log` to its type)
    ),
  )
}

///|
test "a tail-resumptive arm cannot perform ctl operations" {
  inspect(
    check(
      (
        #|effect Log {
        #|  Log(String) -> Unit
        #|}
        #|fn logs() -> Unit!Log { perform Log("x") }
        #|effect Choose {
        #|  ctl Choose() -> Bool
        #|}
        #|fn f() -> Bool!Choose {
        #|  try { logs(); true } catch { Log(m) => { let _ = perform Choose(); resume() } }
        #|}
      ),
    ),
    content=(
      #|t.mbtpp:9:52: error: the handler of a tail-resumptive operation cannot perform `ctl` operations
    ),
  )
}

///|
test "errors and ctl operations are handled by different trys" {
  inspect(
    check(
      (
        #|effect Choose {
        #|  ctl Choose() -> Bool
        #|}
        #|suberror E
        #|fn f() -> Bool { try { perform Choose() } catch { Choose() => resume(true); E => false } }
      ),
    ),
    content=(
      #|t.mbtpp:5:18: error: a `try` cannot handle errors and `ctl` operations together yet; use two `try`s
    ),
  )
}

///|
test "a try around ctl operations is not supported yet" {
  inspect(
    check(
      (
        #|effect Choose {
        #|  ctl Choose() -> Bool
        #|}
        #|suberror E
        #|fn g() -> Bool raise E { true }
        #|fn f() -> Bool!Choose { try { perform Choose() && g() } catch { E => false } }
      ),
    ),
    content=(
      #|t.mbtpp:6:1: error: `try` and `defer` around code that performs `ctl` operations are not supported yet
    ),
  )
}

///|
test "a function that returns a proof has no effects" {
  inspect(
    check(
      (
        #|effect Log {
        #|  Log(String) -> Unit
        #|}
        #|fn logs() -> Unit!Log { perform Log("x") }
        #|fn p() -> 1 === 1!Log { Refl }
      ),
    ),
    content=(
      #|t.mbtpp:5:18: error: a function that returns a proof cannot have effects (proofs are erased at run time)
    ),
  )
}
