# Implementation notes

## Packages

- `src/parser`: lexer (newline-sensitive like MoonBit, string interpolation)
  and a recursive-descent parser producing the surface AST.
- `src/tt`: the type checker.
  - `core.mbt`: core terms (de Bruijn indices) and values (levels).
  - `eval.mbt`: normalisation by evaluation. Global functions are kept folded
    (`VGlobal`) and unfolded on demand by `force`; a function stays folded when
    its unfolding is stuck on a `match`.
  - `unify.mbt`: pattern unification with a first-order fallback (used to infer
    higher-kinded arguments such as `M[T] = Option[Int]`) and definitional
    proof irrelevance.
  - `cxt.mbt`: elaboration contexts. Variables are bound or *defined*; pattern
    matching refines a context by defining bound variables (`Cxt::refine`).
  - `elab*.mbt`: bidirectional elaboration of expressions, statements,
    `match` (with coverage checking), declarations and `monad` blocks.
  - `instance.mbt`: trait instance search (local instances, superclasses,
    global instances).
  - `tactic.mbt`: `intros`, `exact`, `rfl`, `destruct`, `rewrite`, `apply`,
    `assume`.
  - `prelude.mbt`: the prelude, written in MoonBit++.
- `src/interp`: a tree-walking interpreter over elaborated core terms.
- `src/codegen`: the compiler to MoonBit (see below).
- `src/moonpp`: the `moonpp` build tool (projects, packages, `moon` calls
  through a Node.js FFI in `host_js.mbt`; `bin/moonpp.js` runs it in a worker
  thread with a large stack); `src/mbtpp.mbt`: check-and-run helpers used by
  the tests in `src/*_test.mbt`.

## Compiler (`src/codegen`)

- `runtime.mbt`: the support code emitted with every program: the uniform
  representation `Value` (`VInt`, `VCon(name, args)`, `VFun`, ...), `apply`,
  primitives, a pattern matcher for patterns MoonBit cannot express.
- `codegen.mbt`: the uniform translation. Only globals reachable from
  `main` are emitted. A function of n parameters becomes a MoonBit function
  (saturated calls are direct, `<id>_v()` is its curried value); constants
  are cached; `match` becomes a MoonBit `match` on `VCon`; `if`, constructors
  and primitive operations are inlined.
- `erase.mbt`: erasure analysis (greatest fixed point over the program):
  type parameters are always erased; other implicit parameters and implicit
  constructor fields are erased unless used at run time.
- `typed.mbt`: the native translation. Functions whose (not erased)
  parameters and result have native types (scalars, type parameters,
  datatypes with type parameters, function types) and whose bodies stay in
  the first-order fragment get a native MoonBit version `f_t`; which ones is
  decided by a fixed point. Native datatypes become generic MoonBit enums
  without indices or erased fields, with conversions to and from `Value`.
  Typed code calls imported MoonBit functions directly.
- `traits.mbt`: `#mbt` types and traits (checked in `src/tt/mbt.mbt`):
  `#mbt` datatypes are the MoonBit types of their names, `#mbt` traits
  MoonBit traits; bounds become MoonBit bounds, method calls `Tr::m(..)`,
  and instances whose methods are typed become `impl`s.
- `export.mbt`: `#mbt` functions become public MoonBit functions calling
  their native translation; a body outside the fragment is a compile error
  naming the first term that is not native.
- `ffi.mbt`: calls of imported MoonBit functions from uniform code, with
  conversions derived from their signatures (scalars, type variables,
  `Array`, `Option`, `#mbt` datatypes, callbacks, opaque foreign types
  boxed in a generated `Foreign` enum, labelled and optional arguments,
  errors). Calling a function whose signature is not supported is a compile
  error.

## Core language

- Uncurried functions are curried Pi types whose explicit binders carry a
  "starts a new argument group" flag; unification compares the flags, and
  application requires a whole group. Implicit binders attach to the following
  explicit group. A function with no parameters takes one `Unit` argument.
- `Type : Type`; `Prop : Type` is impredicative and proof irrelevant.
  Matching on a proof is only allowed into a proposition unless the datatype is
  a subsingleton (such as `===`).
- `match` compiles to a core `Match` over a list of scrutinees and clauses with
  nested patterns. Every pattern node occupies one variable slot (the value it
  matches), followed by the slots of a constructor's arguments, both in the
  type checker and in the interpreter.
- Functions whose body uses mutation, loops, `return`, `raise`, `try`,
  sequencing or array literals are opaque: they never unfold during type
  checking.
- Tagged arguments are metadata of top-level declarations: the core Pi
  type only has positional parameters (in declaration order). A call is
  rearranged by `place_tagged`; an omitted `x~ : T = e` calls a helper
  `f$default$x[impl](earlier params, ())`, an omitted `x? : T` becomes `None`.
- MoonBit imports (`src/parser/mbti.mbt`, `load_imports` in
  `src/tt/driver.mbt`, `src/moonpp/imports.mbt`): each item of a `.mbti` is parsed
  with the MoonBit++ parser and turned into a declaration whose functions are
  external (`"@mbt:<package>.<name>"`), so they never unfold. Imported
  declarations are elaborated leniently: one that fails is skipped (with the
  instance constraints it left behind) instead of failing the program.
  Unknown types and traits become opaque; an opaque trait is solved by its
  (empty) record constructor.
- There is no termination or positivity checking, so type checking can loop.

## Differences from the original description

- Propositional equality is `enum Id[T](x : T) : (y : T) -> Prop { Refl : Id[T](x)(x) }`;
  `a === b` is `Id[_](a)(b)`. The name `Eq` is the boolean equality trait,
  as in MoonBit.
- The kind of `Self` in `Monad` is `[T] -> Type`, like `Array` and `Option`.
- Resumable algebraic effects, `simp`, `omega` and `auto` are not implemented.
