# enum 与索引类型

## 普通 enum

```moonbit
enum Shape {
  Circle(Double)
  Rect(Double, Double)
}

fn Shape::area(self : Shape) -> Double {
  match self {
    Circle(r) => 3.14 * r * r
    Rect(w, h) => w * h
  }
}

fn main {
  println(Rect(2.0, 3.0).area())
}
```

## 参数与索引

```text
enum 名字[隐式参数](显式参数) : 索引 -> 宇宙 { 构造子 }
```

- **参数**写在名字后，在所有构造子中固定。
- **索引**写在冒号后，可以随构造子变化。宇宙是 `Type` 或 `Prop`。
- **构造子**：`C[自己的隐式参数](字段) : 返回类型`。没有索引时可以省略返回类型。

```moonbit
enum Vector[T] : Nat -> Type {
  Nil : Vector[T](0)
  Cons[n : Nat](T, Vector[T](n)) : Vector[T](S(n))
}

// 索引写在 [] 中：GADT
enum Exp : [T] -> Type {
  IntLit(Int) : Exp[Int]
  BoolLit(Bool) : Exp[Bool]
  Add(Exp[Int], Exp[Int]) : Exp[Int]
  If[T](Exp[Bool], Exp[T], Exp[T]) : Exp[T]
}

fn[T] Exp::eval(self : Exp[T]) -> T {
  match self {
    IntLit(n) => n
    BoolLit(b) => b
    Add(l, r) => l.eval() + r.eval()
    If(c, t, f) => if c.eval() { t.eval() } else { f.eval() }
  }
}

fn main {
  let e = If(BoolLit(true), Add(IntLit(1), IntLit(2)), IntLit(0))
  println(e.eval())
}
```

`Exp::eval` 的结果类型随构造子变化：匹配到 `IntLit(n)` 时 `T` 被细化为 `Int`。

## 命名字段

构造子的字段可以命名，后面的字段的类型可以引用它：

```moonbit
enum Sigma[A](P : (A) -> Type) {
  MkSigma(fst : A, snd : P(fst))
}
```

## 使用构造子

- 数据类型的参数总是推断的；`[...]` 只给构造子自己的隐式参数，例如 `Cons[n](x, xs)`。
- 重名构造子按期望类型区分，也可以写全名 `Vector::Cons`。
- 宇宙为 `Prop` 的 enum 是命题，例如 Prelude 中的 `Id`（见[命题相等](equality.md)）。

## 带标签的字段

```moonbit
enum Shape {
  Rect(width~ : Int, height~ : Int)
  Circle(Int, label~ : String)
}

fn area(s : Shape) -> Int {
  match s {
    Rect(width~, height~) => width * height
    Circle(r, ..) => 3 * r * r
  }
}

fn main {
  println(area(Rect(height=2, width=5)))
}
```

构造子的字段可以带标签：构造时写 `C(x=e)`，模式中写 `C(x~)` 或 `C(x=p)`；`..` 表示其余字段
匹配任何值。
