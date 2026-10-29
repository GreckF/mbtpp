# Labelled Arguments

Same as in MoonBit:

```moonbit
fn greet(name~ : String, greeting~ : String = "Hello", title? : String) -> String {
  match title {
    Some(t) => greeting + ", " + t + " " + name
    None => greeting + ", " + name
  }
}

fn main {
  println(greet(name="Alice"))
  println(greet(greeting="Hi", name="Bob", title="Dr."))
  let name = "Carol"
  println(greet(name~))            // name~ means name=name
  let t : String? = None
  println(greet(name~, title?=t))  // title?= passes an Option directly
}
```

| Declaration | Call | Notes |
| --- | --- | --- |
| `x~ : T` | `f(x=e)`, `f(x~)` | Required |
| `x~ : T = d` | May be omitted | The default `d` may refer to earlier parameters and is evaluated on each call |
| `x? : T` | `f(x=e)`, `f(x?=opt)`, omitted | Has type `T?` in the body; `None` when omitted |

- Labelled arguments can be passed in any order and interleaved with positional arguments.
- Only top-level functions (including methods) can have labelled arguments; lambdas and local functions cannot.
- When a function is used as a value, its function type lists only the parameters in declaration order, without labels.
