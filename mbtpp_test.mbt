///|
fn run_example(name : String) -> String {
  let path = "examples/" + name
  let src = @fs.read_file_to_string(path) catch { e => return e.to_string() }
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
      #|c
      #|42
      #|1
      #|7
      #|
    ),
  )
}
