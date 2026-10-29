# lemma

`lemma` 与 `fn` 相同，只是结果通常是命题。有两种写法：

- `lemma 名字[隐式](参数) -> 命题 { 证明 }`
- `lemma 名字[隐式] : 命题 = 证明表达式`

用模式匹配和递归做归纳：

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

lemma append_nil[T](xs : List[T]) -> xs.append(Nil) === xs {
  match xs {
    Nil => Refl
    Cons(x, rest) => Id::cong(r => List::Cons(x, r), append_nil(rest))
  }
}
```

- `Z` 分支中目标 `0 + 0 === 0` 计算后两边相同，用 `Refl`。
- `S(k)` 分支中目标是 `S(k) + 0 === S(k)`，计算为 `S(k + 0) === S(k)`；用递归得到的
  `k + 0 === k` 加上 `Id::cong(S, …)` 得出。
- 递归调用就是归纳假设。检查器不验证递归是否终止。

更长的证明见仓库中的 `examples/proofs.mbtpp`（向量拼接的结合律、`reverse` 的性质）和
`examples/stlc.mbtpp`（简单类型 λ 演算的代换引理、progress 与 canonicity，以及从 canonicity
证明中提取求值器）。
