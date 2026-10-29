///|
fn run_example(name : String) -> String {
  let path = "examples/" + name
  let src = @fs.read_file_to_string(path) catch {
    @fs.IOError(msg) => return msg
  }
  run_source(path, src)
}

///|
test "example basic" {
  inspect(run_example("basic.mbtpp"), content="3\n")
}

///|
test "example vector" {
  inspect(
    run_example("vector.mbtpp"),
    content=(
      #|1
      #|2
      #|Cons(1, Cons(2, Cons(3, Cons(10, Cons(20, Cons(30, Nil))))))
      #|true
      #|
    ),
  )
}

///|
test "example struct_proof" {
  inspect(
    run_example("struct_proof.mbtpp"),
    content=(
      #|2
      #|[1, 2, 3]
      #|
    ),
  )
}

///|
test "example monad" {
  inspect(
    run_example("monad.mbtpp"),
    content=(
      #|Some(3)
      #|None
      #|Cons(10, Cons(20, Cons(20, Cons(40, Nil))))
      #|None
      #|
    ),
  )
}

///|
test "example errors" {
  inspect(
    run_example("errors.mbtpp"),
    content=(
      #|caught: division by zero
      #|0
      #|Ok(5)
      #|5050
      #|8
      #|i = 6
      #|0 42 0 
      #|
    ),
  )
}

///|
test "example dependent" {
  inspect(
    run_example("dependent.mbtpp"),
    content=(
      #|6
      #|2
      #|8
      #|
    ),
  )
}

///|
test "example traits" {
  inspect(
    run_example("traits.mbtpp"),
    content=(
      #|square with area 9
      #|rect with area 10
      #|square with area 4, volume 8
      #|<1><2><3>
      #|
    ),
  )
}

///|
test "example proofs" {
  inspect(
    run_example("proofs.mbtpp"),
    content=(
      #|Cons(1, Cons(2, Cons(1, Cons(2, Cons(1, Cons(2, Nil))))))
      #|Cons(1, Cons(2, Cons(3, Nil)))
      #|
    ),
  )
}

///|
test "example stlc" {
  inspect(
    run_example("stlc.mbtpp"),
    content=(
      #|tt after 1 steps
      #|tt after 2 steps
      #|tt after 2 steps
      #|(fn wk(tt)) after 1 steps
      #|((fn (#0 tt)) (fn #0)) ~> ((fn #0) tt) ~> tt
      #|(((fn (fn #1)) tt) tt) ~> ((fn wk(tt)) tt) ~> tt
      #|(fn wk(tt))
      #|
    ),
  )
}

///|
test "example labelled" {
  inspect(
    run_example("labelled.mbtpp"),
    content=(
      #|7
      #|42
      #|0
      #|10
      #|20
      #|Hello, Alice
      #|Hello, Mr. Bob
      #|Hello, Dr. Carol
      #|0
      #|10
      #|Cons(x, Cons(x, Cons(x, Nil)))
      #|
    ),
  )
}

///|
test "example mbt_types" {
  inspect(
    run_example("mbt_types.mbtpp"),
    content=(
      #|25
      #|10
      #|0
      #|2510
      #|Some(5)
      #|None
      #|4
      #|
    ),
  )
}

///|
test "example derive" {
  inspect(
    run_example("derive.mbtpp"),
    content=(
      #|Rect(1, 2)
      #|true
      #|-1
      #|Node(Leaf, 1, Node(Leaf, 2, Leaf))
      #|{x: 1, y: 2} != {x: 1, y: 3}
      #|{x: 1, y: 3}
      #|Some(3)
      #|{x: 0, y: 1}
      #|-7
      #|{x: 0, y: 0}
      #|
    ),
  )
}

///|
test "example trait_objects" {
  inspect(
    run_example("trait_objects.mbtpp"),
    content=(
      #|10
      #|circle
      #|square
      #|circle
      #|<42>
      #|<hi>
      #|1
      #|two
      #|true
      #|Some(3)
      #|#7
      #|7
      #|
    ),
  )
}

///|
test "example patterns" {
  inspect(
    run_example("patterns.mbtpp"),
    content=(
      #|polygon, big circle, circle
      #|true
      #|true false
      #|9 0 0
      #|3
      #|42 5
      #|tiny seven other
      #|6 -3
      #|ok 8, bad, very bad
      #|3
      #|
    ),
  )
}

///|
test "async functions run in the interpreter" {
  inspect(
    run_source(
      "t.mbtpp",
      (
        #|async fn twice(f : async (Int) -> Int, x : Int) -> Int { f(f(x)) }
        #|async fn inc(x : Int) -> Int noraise { x + 1 }
        #|async fn main {
        #|  let g = async fn(x : Int) -> Int { inc(x) * 2 }
        #|  println(twice(g, 1))
        #|  println(twice(x => inc(x), 5))
        #|}
      ),
    ),
    content=(
      #|10
      #|7
      #|
    ),
  )
}

///|
test "example syntax" {
  inspect(
    run_example("syntax.mbtpp"),
    content=(
      #|55
      #|2 -1
      #|2 * 6
      #|55
      #|cleanup 3
      #|6
      #|cleanup 0
      #|-1
      #|same ends around 2
      #|starts with 4
      #|lower upper digit
      #|2
      #|280
      #|two lines,
      #|the second with 6
      #|
    ),
  )
}
