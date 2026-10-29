///|
/// Importing MoonBit interfaces, with an inline `.mbti` (no files needed).
let geo_mbti : String =
  #|// Generated using `moon info`, DON'T EDIT IT
  #|package "demo/geo"
  #|
  #|import(
  #|  "demo/units"
  #|)
  #|
  #|// Values
  #|pub fn area(Shape) -> Double
  #|
  #|pub fn[T : Show + Hash] describe(T, prefix? : String, width~ : Int) -> String
  #|
  #|pub fn parse(StringView) -> Shape raise GeoError
  #|
  #|pub let origin : Point
  #|
  #|#deprecated
  #|pub fn old() -> Unit
  #|
  #|pub fn draw(&Show) -> Unit
  #|
  #|pub fn length(@units.Meter) -> Double
  #|
  #|// Errors
  #|pub(all) suberror GeoError {
  #|  GeoError(String)
  #|}
  #|
  #|// Types and methods
  #|pub(all) enum Shape {
  #|  Circle(Point, Double)
  #|  Rect(Point, Point)
  #|}
  #|pub fn Shape::scale(Self, Double) -> Self
  #|#as_free_fn
  #|pub fn Shape::unit_circle() -> Self
  #|pub impl Show for Shape
  #|
  #|pub(all) struct Point {
  #|  x : Double
  #|  y : Double
  #|}
  #|pub impl Eq for Point
  #|
  #|pub type Canvas
  #|pub fn Canvas::new(width~ : Int, height~ : Int) -> Self
  #|pub fn Canvas::add(Self, Shape) -> Unit
  #|
  #|pub fn[T] Array::total_area(Self[T], (T) -> Shape) -> Double
  #|

///|
fn check_geo(src : String) -> String {
  let imports : Array[@tt.Import] = [
    { alias: "geo", path: "demo/geo", mbti: geo_mbti, },
  ]
  @tt.check_program("t.mbtpp", src, imports~) catch {
    @tt.CheckError(msg) => return msg
  }
  "ok"
}

///|
test "import: using an interface" {
  inspect(
    check_geo(
      (
        #|fn radius(s : @geo.Shape) -> Double {
        #|  match s {
        #|    Circle(_, r) => r
        #|    Rect(_, _) => 0.0
        #|  }
        #|}
        #|
        #|fn main {
        #|  let p : @geo.Point = { x: 1.0, y: 2.0 }
        #|  let s : @geo.Shape = Circle(p, 2.0)
        #|  println(@geo.area(s.scale(2.0)))
        #|  println(radius(@geo.unit_circle()))
        #|  println(s)
        #|  println(p == @geo.origin)
        #|  let c = @geo.Canvas::new(height=2, width=1)
        #|  c.add(s)
        #|  println(@geo.describe(42, width=3))
        #|  println(@geo.describe("x", prefix="> ", width=3))
        #|  println(try? @geo.parse("circle"))
        #|  println([1, 2].total_area(r => Circle(p, r.to_double())))
        #|}
      ),
    ),
    content="ok",
  )
}

///|
test "import: items that are not imported" {
  ignore(check_geo("fn main { () }"))
  // deprecated items are dropped silently; trait objects are not supported
  inspect(
    @tt.import_skipped,
    content=(
      #|[pub fn draw(&Show) -> Unit]

    ),
  )
}

///|
test "import: wrong argument type" {
  inspect(
    check_geo("fn main { println(@geo.area(1.0)) }"),
    content=(
      #|t.mbtpp:1:29: error: type mismatch
      #|  expected: @geo.Shape
      #|  actual:   Double
    ),
  )
}

///|
test "import: missing labelled argument" {
  inspect(
    check_geo("fn main { let c = @geo.Canvas::new(width=1) }"),
    content="t.mbtpp:1:35: error: missing labelled argument height~",
  )
}

///|
test "import: unhandled error" {
  inspect(
    check_geo("fn main { let s = @geo.parse(\"x\") }"),
    content="t.mbtpp:1:29: error: this call may raise an error; use it inside `try` or in a function declared with `raise`",
  )
}

///|
test "import: non-exhaustive match on an imported enum" {
  inspect(
    check_geo(
      (
        #|fn f(s : @geo.Shape) -> Int {
        #|  match s {
        #|    Circle(_, _) => 1
        #|  }
        #|}
      ),
    ),
    content=(
      #|t.mbtpp:2:3: error: match is not exhaustive; missing case(s):
      #|  Rect(_, _)
    ),
  )
}

///|
test "import: unknown name" {
  inspect(
    check_geo("fn main { @geo.nope() }"),
    content="t.mbtpp:1:11: error: unknown name @geo.nope",
  )
}

///|
test "import: an opaque type of another package" {
  inspect(
    check_geo("fn f(m : @units.Meter) -> Double { @geo.length(m) }"),
    content="ok",
  )
}

///|
test "import: running calls an imported function" {
  inspect(
    check_geo("fn main { println(1); println(@geo.area(@geo.unit_circle())) }"),
    content="ok",
  )
  let buf = StringBuilder::new()
  @interp.run_main(s => buf.write_string(s)) catch {
    @interp.RunError(msg) => buf.write_string(msg)
  }
  inspect(
    buf.to_string(),
    content=(
      #|1
      #|runtime error: cannot run the imported MoonBit function demo/geo.Shape::unit_circle in the interpreter (imports are only type checked)
    ),
  )
}

///|
let handles_mbti : String =
  #|package "demo/handles"
  #|
  #|pub fn make(Int) -> Handle
  #|pub fn id(Handle) -> Int
  #|
  #|pub enum Handle {
  #|  H(Int)
  #|}
  #|
  #|pub(all) enum Color {
  #|  Red
  #|  Rgb(Int, Int, Int)
  #|}
  #|
  #|pub(all) struct Big {
  #|  xs : Array[Int]
  #|}
  #|
  #|pub(open) trait Named {
  #|  name(Self) -> String
  #|}
  #|
  #|pub trait Sealed {
  #|  seal(Self) -> Int
  #|}
  #|

///|
fn check_handles(src : String) -> String {
  let imports : Array[@tt.Import] = [
    { alias: "h", path: "demo/handles", mbti: handles_mbti, },
  ]
  @tt.check_program("t.mbtpp", src, imports~) catch {
    @tt.CheckError(msg) => return msg
  }
  "ok"
}

///|
test "import: pub(all) types and pub(open) traits are #mbt" {
  inspect(check_handles("fn main { println(@h.id(@h.make(1))) }"), content="ok")
  let marks = ["@h.Handle", "@h.Color", "@h.Big", "@h.Named", "@h.Sealed"].map(n => {
    (n, @tt.mbt_info(n).map(i => (i.name, i.read_only)))
  })
  // `Big` has an `Array` field, which is not a MoonBit++ #mbt type
  inspect(
    marks,
    content=(
      #|[(@h.Handle, Some((@h.Handle, true))), (@h.Color, Some((@h.Color, false))), (@h.Big, None), (@h.Named, Some((@h.Named, false))), (@h.Sealed, Some((@h.Sealed, true)))]

    ),
  )
}

///|
test "import: read-only types cannot be constructed" {
  inspect(
    check_handles("fn f() -> @h.Handle { H(1) }"),
    content="t.mbtpp:1:23: error: cannot construct a value of the MoonBit type @h.Handle outside its package (it is not pub(all))",
  )
  inspect(
    check_handles(
      "fn f(h : @h.Handle) -> Int { match h { H(n) => n } }\nfn g() -> @h.Color { @h.Rgb(1, 2, 3) }",
    ),
    content="ok",
  )
  inspect(
    check_handles(
      "struct S { n : Int }\nimpl @h.Sealed for S with seal(self) { self.n }",
    ),
    content="t.mbtpp:2:1: error: impl of #mbt trait @h.Sealed: the MoonBit trait @h.Sealed cannot be implemented outside its package (it is not pub(open))",
  )
  inspect(
    check_handles("impl @h.Named for Int with name(self) { self.to_string() }"),
    content="t.mbtpp:1:1: error: impl of #mbt trait @h.Named: MoonBit does not allow implementing the existing trait @h.Named for a type that is not generated by this program",
  )
}

///|
test "import: Int32 is Int" {
  let mbti =
    #|package "demo/ints"
    #|
    #|pub fn twice(Int32) -> Int32
    #|
  let imports : Array[@tt.Import] = [
    { alias: "ints", path: "demo/ints", mbti },
  ]
  let r = try {
    @tt.check_program(
      "t.mbtpp",
      "fn main { println(@ints.twice(21) + 1) }",
      imports~,
    )
    "ok"
  } catch {
    @tt.CheckError(msg) => msg
  }
  inspect(r, content="ok")
}
