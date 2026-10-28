# Data With Parameters (Plan)

This doc describes what we need to change to add datatype parameters to the current system.

## 1) Adding changes in syntax

We only have indices today (all arguments in `data` headers are treated as indices). We will add parameters by splitting the telescope at `:`.

Syntax:
- `data D (A : U) (B : U) : I1 -> I2 -> U where ...`
- Everything before `:` is parameters, everything after `:` is indices.

Parser and AST changes:
- Extend `RDataDef` to carry separate `params` and `indices`.
- Update `data` parsing and `data` pretty printing.
- Update generated `DataDef` to record parameters distinctly (not only indices).

## 2) What more check do we need

After syntax, we need extra checks that treat parameters as uniform:

- Constructor result type must apply the datatype to the same parameters.
  - If `data D (A : U) : I -> U`, then every constructor result must be `D A <index>`.
- Parameters are not pattern-matched by constructors.
  - Only indices can be refined by constructor result types.
- Unification in coverage checking must treat parameters as rigid and identical across clauses.
- Error reporting should highlight when a constructor returns `D` with different parameters.

Implementation checkpoints:
- When elaborating `data`, split the telescope into params/indices.
- In `check_cons`, compare constructor result parameters against the data definition parameters.
- In `check_data`, store parameters separately so they are available to the constructor checks.

Constructor elaboration (understanding of new plan):
- Constructors should be elaborated in check mode, not infer mode.
- Use the message of type parameters from the data type so constructor parameters are driven by the data type, not introduced from the constructor syntax.

## 3) How will it affect dependent pattern matching

Parameters are uniform, so pattern matching only refines indices.

Effects:
- The scrutinee type `D params indices` keeps `params` fixed during matching.
- The matching algorithm should only use constructor indices to refine the goal type.
- Pattern coverage should ignore parameter differences (they are not allowed to vary).

Example behavior:
- For `Vec (A : U) (n : Nat)`, matching on `Vec A n` refines `n` but never changes `A`.
- Any constructor that tries to change `A` is rejected by the constructor check.

Pattern matching (understanding of new plan):
- When matching, the pattern type is already known, so constructor parameters are already determined.
- We should not introduce parameters from constructors during pattern checking; only indices are refined.

Notes:
- This design avoids spurious ambiguity in pattern matching and keeps parameter inference stable.
- It also aligns with the common distinction in dependent type theory.
