# 策略

`proof { … }` 用策略一步步构造证明，每行一条：

```moonbit
lemma plus_zero(n : Nat) -> n + 0 === n {
  match n {
    Z => Refl
    S(k) => Id::cong(S, plus_zero(k))
  }
}

lemma plus_succ(n : Nat, m : Nat) -> n + S(m) === S(n + m) {
  match n {
    Z => Refl
    S(k) => Id::cong(S, plus_succ(k, m))
  }
}

lemma plus_comm : forall n m : Nat, n + m === m + n = proof {
  intros n m
  destruct n
  rewrite plus_zero(m)
  rfl
  rewrite plus_succ(m, n_0)
  rewrite plus_comm(n_0, m)
  rfl
}
```

| 策略 | 作用 |
| --- | --- |
| `intros x y` | 引入假设（也写 `intro`；`_` 忽略） |
| `exact e` | 用表达式 `e` 完成当前目标 |
| `rfl` | 用 `Refl` 完成目标（两边规范化后相同） |
| `destruct x` | 对 `x` 分情况，每个构造子一个新目标；字段命名为 `x_0`、`x_1`…（也写 `cases`） |
| `rewrite e`、`rewrite <- e` | 用等式 `e` 从左到右、从右到左改写目标（也写 `rw`） |
| `apply f` | 用函数 `f` 把目标归约为它的参数 |
| `assume h : P` | 先把 `P` 作为假设 `h` 使用，之后再证明 `P`（也写 `have`） |

更多例子：

```moonbit
enum And[A : Prop, B : Prop] : Prop {
  Conj(A, B)
}

lemma and_comm[A : Prop, B : Prop] : (And[A, B]) -> And[B, A] = proof {
  intros p
  destruct p
  exact Conj(p_1, p_0)
}

lemma modus_ponens[A : Prop, B : Prop] : (A, (A) -> B) -> B = proof {
  intros a f
  apply f
  exact a
}

lemma zero_ne_one : (0 : Nat) === 1 -> Int = proof {
  intros h
  destruct h
}
```

- 策略只是构造证明项的另一种方式，结果与手写的项相同。
- 对不可能的等式（如 `0 === 1`）做 `destruct` 没有剩余目标。
- 没有 `simp`、`omega`、`auto` 这类自动化策略。
