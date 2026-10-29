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

使用了 `let mut`、赋值、循环、`raise`、`try` 的函数，在类型检查时会像解释器一样**被执行**：
执行跑完，调用就换成它的结果；跑不完，整个调用保持不展开，和普通常量一样。

```moonbit
fn sum_to(n : Int) -> Int {
  let mut i = 0
  let mut acc = 0
  while i < n {
    i = i + 1
    acc = acc + i
  }
  acc
}

fn inc(x : Int) -> Int {
  let mut y = x
  y = y + 1
  y
}

lemma s10 : sum_to(10) === 55 = Refl
lemma inc_x[x : Int] : inc(x) === x + 1 = Refl

fn main {
  let v : Array[Int] = Array::make(sum_to(3), 0)
  println(v.length())
}
```

- **能跑完**：所有判断都能确定，例如参数是具体的值，或者像 `inc(x)` 那样根本不需要判断。错误
  会正常传到 `try`，`println` 等输出被跳过（输出不影响结果）。
- **保持不展开**：需要根据未知的值做判断（`abs(x)` 中的 `if x < 0`，`x` 是变量）；错误一直抛到
  函数外；用到数组（数组是可变的）、导入的 MoonBit 函数或 async 函数；lambda 捕获了 `let mut`
  变量。这些情况下结果可能不只由参数决定，所以不展开。
- 所以关于变量参数的一般性质，例如“对所有 `n`，`sum_to(n) * 2 == n * (n + 1)`”，仍然不能这样
  证明。
- 不终止的循环会让检查一直执行下去，直到这个定义的[检查时限](type-level.md#检查时限)。
