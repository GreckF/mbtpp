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
    { alias: "geo", path: "demo/geo", mbti: geo_mbti },
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
      #|["pub fn draw(&Show) -> Unit"]
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
