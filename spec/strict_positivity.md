# Strict Positivity (Proposal)

To preserve consistency, datatypes must be strictly positive in their constructors.
Intuitively, the datatype being defined may only appear to the right of arrows.

## Rule (informal)

For a datatype `D` with parameters `params` and indices `indices`, each constructor
type must satisfy:

- Occurrences of `D` in constructor argument types are forbidden.
- The return type must be `D params indices` (as already required by parameter
  and index checks).

This forbids negative positions like:

```
data Bad : Type where
| mk : (Bad -> Nat) -> Bad
```

The occurrence of `Bad` in `(Bad -> Nat)` is in a function domain, so the type is
not strictly positive.

## Allowed examples

```
data Good : Type where
| mk : Nat -> Good

data Tree (A : Type) : Type where
| leaf : A -> Tree A
| node : Tree A -> Tree A -> Tree A
```

## Formal-ish check sketch

Define a predicate `positive(D, T)` over types `T`:

- `positive(D, D params indices)` is true.
- `positive(D, (x : A) -> B)` is true iff `D` does not occur in `A` and
  `positive(D, B)` is true.
- `positive(D, Sort u)`, `positive(D, Type u)`, `positive(D, Prop)` are true.
- `positive(D, C args...)` is true for `C != D` iff all argument types are
  `positive(D, arg)`.

The constructor type is strictly positive if all constructor argument types satisfy
`positive(D, arg)`.

## Interaction with parameters and indices

- Parameters are uniform; constructor argument types may mention them freely.
- Indices may appear in constructor arguments, but that does not affect positivity.

## Interaction with Prop

Strict positivity is enforced uniformly for `Type` and `Prop`. Even though `Prop`
has restricted elimination, negative occurrences can still be unsound, so the same
positivity rule applies.

## Diagnostics

When the check fails, report the first negative occurrence with a message like:

"Datatype D is not strictly positive: occurs in function domain at ..."
