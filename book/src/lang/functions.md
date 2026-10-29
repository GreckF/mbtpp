# 函数

```moonbit
fn add(x : Int, y : Int) -> Int {
  x + y
}

fn[T] twice(f : (T) -> T, x : T) -> T {   // [T]：隐式参数
  f(f(x))
}

fn answer() -> Int { 42 }                 // 无参数函数

fn main {
  println(add(1, 2))
  println(twice(x => x + 1, 0))
  println(twice[Int](x => x * 2, 1))      // 显式给出隐式参数
  println(answer())
}
```

## 不柯里化

函数接受一组参数：`(Int, Int) -> Int` 接受两个参数，和返回函数的
`(Int) -> (Int) -> Int` 是不同的类型。不允许部分应用。

无参数的函数（`fn answer()`）内部表示为接受一个 `Unit` 参数。

## 隐式参数

隐式参数写在 `fn` 后面的 `[...]` 中：

```moonbit
fn[T] count(xs : Array[T], extra : Nat) -> Nat {
  plus(xs.size(), extra)
}

fn main {
  println(count([1, 2], 3).to_int())
}
```

- `[T]` 即 `[T : Type]`。不写类型的隐式参数，类型由使用推断，推断不出时默认为 `Type`。
- 调用时一般由合一推断。也可以用 `f[a, b](x)` 按位置显式给出：可以只给前缀，可以写 `_`。
- 隐式参数只能写在 `fn` 后面，不支持 `fn f[T](...)`。

## 其他形式

- **方法**：`fn Type::m(self : Type, …)`，见[方法与运算符](methods.md)。
- **带标签参数**：`x~ : T`、`x? : T`，见[带标签参数](labelled.md)。
- **lemma**：结果是命题的函数，见 [lemma](lemma.md)。
- **外部原语**：`fn f(x : Int) -> Int = "%prim_name"`，只用于 Prelude。
- **`main`**：`fn main { … }`，程序入口。
