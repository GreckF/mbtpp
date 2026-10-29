# 可变状态与循环

```moonbit
fn sum_to(n : Int) -> Int {
  let mut acc = 0
  for i = 1; i <= n; i = i + 1 {
    acc = acc + i
  }
  acc
}

fn find_first(xs : Array[Int], p : (Int) -> Bool) -> Int {
  for x in xs {
    if p(x) {
      return x
    }
  }
  -1
}

fn main {
  println(sum_to(100))
  println(find_first([1, 5, 8, 11], x => x % 2 == 0))
  let mut i = 0
  while true {
    i += 1
    if i > 5 {
      break
    }
  }
  println("i = \{i}")
  let arr = Array::make(3, 0)
  arr[1] = 42
  for k in 0..<3 {
    print(arr[k])
    print(" ")
  }
  println("")
}
```

- **可变变量**：`let mut x = e`，赋值 `x = e`，以及 `+=`、`-=`、`*=`、`/=`。
- **循环**：`while c { … }`；C 风格 `for i = 0; i < n; i = i + 1 { … }`；`for x in xs { … }`
  遍历数组；`for k in a..<b`、`for k in a..=b` 遍历区间。
- **`break`**、**`continue`** 作用于最内层循环；**`return`** 从当前函数返回，在 lambda 中只从
  lambda 返回。
- **数组**是可变的：`xs[i] = v`、`xs.push(x)`。

## 与类型检查的关系

使用了 `let mut`、赋值、循环、`raise`、`try` 的函数在类型检查时**不展开**：它们可以正常调用、
运行，但不参与类型层的计算，关于它们的等式不能用 `Refl` 证明。
