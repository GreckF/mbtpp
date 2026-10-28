# Universe Levels (Type/Level)

This proposal adds universe polymorphism using a dedicated universe of levels.

## Core entities

- `Level` is a type living in the special universe `Typew`.
- `Sort` is a function from `Level` to universes.
- `Type a` is defined as `Sort (lsuc a)`.
- `Prop` is defined as `Sort lzero`.

Judgments:

- `a : Level |- Sort a type`
- `a : Level |- Sort a : Sort (lsuc a)`

Notes:

- `Type` is syntactic sugar for `Type lzero` (that is, `Sort (lsuc lzero)`).
- There is no cumulativity. In particular, from `a < b` we do NOT derive `Type a : Type b`.
- `Typew` is the highest universe; it is not itself a `Type`.

## Level constructors

```
Level : Typew
lzero : Level
lsuc  : Level -> Level
lmax  : Level -> Level -> Level
```

## Level computation rules

The following equations are definitional equalities for `lmax`:

- `lmax a b = lmax b a`
- `lmax a lzero = a`
- `lmax (lsuc a) (lsuc b) = lsuc (lmax a b)`
- `lmax (lmax a b) c = lmax a (lmax b c)`

## Pi formation rules

```
A : Sort a,    x : A |- B : Type b
---------------------------------
 (x : A) -> B : Type (lmax a b)

A : Sort a,    x : A |- B : Prop
---------------------------------
 (x : A) -> B : Prop
```

Every polymorphic function is explicitly a function over `Type` via `Level`.
For example, a polymorphic identity has the shape:

```
{id : {a : Level} {A : Type a} -> A -> A}
```

## Interaction with data types

To prevent injections from higher universes into lower ones (Girard's paradox),
constructor argument universes must not exceed the return universe of the data type.

### Safety rule

If a data type is declared as:

```
data D (params...) : Type u where
| c : (args...) -> D params...
```

then each constructor argument type must live in `Type v` where `v <= u`.

### Example: forbidden

```
data S (a : Level) : Type a where
| mkS : Type a -> S a
```

Here `Type a : Type (lsuc a)`, so the constructor argument is in a strictly higher
universe than the return universe `Type a`. This must be rejected.

### Example: allowed

```
data S (a : Level) : Type (lsuc a) where
| mkS : Type a -> S a
```

### Example: identity type

```
data Id {a : Level} {A : Type a} (x : A) : A -> Type a where
| refl : Id x x
```

This is allowed because `refl` introduces no constructor argument whose type lives
above `Type a`.

## Irrelevance and elimination from Prop

`Prop` is an irrelevant universe. For any `A : Prop`, all terms of `A` are
judgmentally equal.

To preserve consistency, elimination from `Prop` into relevant universes is
forbidden. If you pattern match on a term of type `A : Prop`, the result type
must also live in `Prop`.

### Example: forbidden

```
data P : Prop where
| mkP1 : P
| mkP2 : P

def f : P -> Bool where
| mkP1 = True
| mkP2 = False
```

This is rejected because the match returns a value in `Bool`, which lives in
`Type`, not in `Prop`.

## Implementation plan

1. Syntax and parser
	- Add tokens/keywords for `Sort`, `Prop`, and `Level` if they are not already reserved.
	- Treat bare `Type` as desugared to `Type lzero` (that is, `Sort (lsuc lzero)`).
	- Ensure numeric literal `0` in `Prop := Sort lzero` is consistently represented.

2. Core terms and values
	- Introduce core term for `Sort` and a value representation for universe levels.
	- Represent `Prop` as `Sort lzero` and `Type a` as `Sort (lsuc a)` in the core.
	- Keep `Typew` as a distinct internal top universe used only for special types
	  like `Level` (users cannot write `Typew`).

3. Elaboration rules
	- Replace `U` with `Sort` in type formation and inference.
	- Implement the two Pi formation rules:
	  - `A : Sort a, x : A |- B : Type b` yields `(x : A) -> B : Type (lmax a b)`.
	  - `A : Sort a, x : A |- B : Prop` yields `(x : A) -> B : Prop`.
	- Enforce non-cumulativity in universe comparisons.

4. Level computation and definitional equality
	- Implement a canonical normalization for `lmax` (flatten, remove `lzero`,
	  sort/associate arguments) so definitional equality terminates.
	- Ensure kernel equality compares normalized `lmax` forms when comparing sorts.

5. Datatype universe checks
	- For each constructor argument type, compute its universe level.
	- If the data type returns a `Type u`, reject any constructor where an argument
	  universe is strictly above `u`.
	- If the data type returns `Prop`, allow arguments from any universe (since
	  eliminations from `Prop` are restricted).
	- Keep the existing index/parameter rules intact.

6. Prop irrelevance
	- Add judgmental equality rule in conversion: for any `A : Prop`, all terms of
	  `A` are judgmentally equal when their types are checked.
	- Refactor unification/conversion to consult the type's universe and
	  short-circuit equality when the type is in `Prop`.
	- Enforce elimination restriction for all eliminators (`match`, recursors,
	  lambda-case, and dependent elimination): if the scrutinee has type `A : Prop`,
	  the result type must also live in `Prop`.

7. Tests and examples
	- Add parser/elaborator tests for `Sort`, `Type`, `Prop`, `Level` constructs.
	- Add positive/negative tests for the Pi formation and datatype universe checks.
	- Add tests for Prop irrelevance and the elimination restriction.
