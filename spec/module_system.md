# Module System Design (Draft)

Goal: add a first-class module system. Every source file begins with a module declaration and may import other modules. This is a design-only document; implementation comes later.

## Syntax

### Module declaration (required)

- Form:
  - `module <Module.Name>`
- Must be the first non-comment token in the file.
- A module name is a dot-separated path of identifiers.

Example:

```
module Data.Nat
```

### Submodules / namespaces (optional)

- Form:
  - `module <Name> where` ... `end`
  - `module <Name> (<params>) where` ... `end`
  - `module _ (<params>) where` ... `end`
- Used inside a module to create a nested namespace.
- `end` closes the most recent `module` block.
- Parameters behave like implicit module arguments, threaded into all items
  inside the submodule.
- A special `_` submodule is anonymous and may omit the name after `end`.

Example:

```
module Data.Nat

module Internal where
  def add : Nat -> Nat -> Nat
  | zero m = m
  | (suc n) m = suc (add n m)
end
```

Parameterized submodule example:

```
module Functor (F: U -> U) where
  def fmap : {a b : U} -> (a -> b) -> F a -> F b
  | ...
end
```

Anonymous submodule example:

```
module M where

module _ (A B : U) where
  def f : A -> B 
  | ...
end

-- here f : {A B : U} -> A -> B
```

### Imports (optional)

- Form:
  - `import <Module.Name>`
  - `import <Module.Name> as <Alias>`
  - `open import <Module.Name>`
  - `open import <Module.Name> as <Alias>`
  - `open <ModuleOrAlias>`
  - `open <ModuleOrAlias> as <Alias>`
  - `open <ModuleOrAlias> <arg1> <arg2> ...`
- Must appear after the module declaration and before any `def`/`data`/`mutual` block.
- Duplicate imports are allowed but should be deduplicated by the loader.

Example:

```
module App.Main
import Data.Nat
import Data.List as List
open import Data.Bool
open Data.Nat
open List as L
```

Open with arguments (parameterized submodule):

```
module App.Main

open Functor List
```

## Semantics

### Module scope

- Each file defines exactly one module.
- All top-level definitions belong to that module.
- No implicit re-export; only direct definitions are exposed.
- Submodules create nested namespaces within a file.
- Names inside a submodule are referenced as `Submodule.name`.
- Parameterized submodules introduce implicit parameters on all exported names.
- Anonymous submodules (`module _`) do not create a namespace; their definitions
  are lifted into the parent with implicit parameters.

### Imports

- Importing a module registers it for use; it does not implicitly open names.
- `open import M` is shorthand for `import M` followed by `open M`.
- `open import` never takes arguments, because only top-level modules can be
  imported and top-level modules do not take parameters.
- If an alias is provided, names are accessed as `Alias.name`.
- Without an alias, names are accessed as `Module.Name`.
- `open` brings names into scope; optional `as` provides a short alias for
  qualified access.
- For parameterized submodules, `open M Arg1 Arg2 ...` applies the implicit
  module parameters before bringing names into scope.
- Ambiguity (two modules exporting the same name with no alias) is an error.
  Ambiguity from `open` is also an error.

### Export surface

- Initially: all top-level `def` and `data` in a module are exported.
- Future: add explicit `export` lists.
- Submodules are exported by default as namespaces (not flattened into the parent).

### Semantics spec (normative)

- Parsing order: the header is parsed first; any `def`/`data`/`mutual` before a
  header is an error.
- Module identity: the module name is the canonical key in the loader; if two
  files declare the same name, it is an error.
- Import resolution: `import M` registers module `M` and makes `M.name` a valid
  qualified reference unless hidden by an alias.
- Open import: `open import M` is equivalent to `import M` then `open M`.
- Open import arguments are not allowed.
- Alias binding: `import M as X` binds `X` to module `M` and disables `M.name`
  in the current file; only `X.name` is valid.
- Open binding: `open M` brings all exported names of `M` into the local scope
  and preserves the qualified name `M.name` unless an alias was used.
- Open with alias: `open M as X` brings all exported names of `M` into scope and
  adds `X.name` as a qualified reference.
- Open with arguments: `open M A1 A2` elaborates as applying module parameters
  before bringing names into scope. The arity must match the submodule
  parameter list.
- Parameterized submodule elaboration: a definition `def f : T` inside
  `module N (P1 : K1) ... (Pn : Kn) where` is exported as
  `N.f : {P1 : K1} ... {Pn : Kn} -> T`.
- Anonymous submodule elaboration: a definition `def f : T` inside
  `module _ (P1 : K1) ... (Pn : Kn) where` is lifted to the parent as
  `f : {P1 : K1} ... {Pn : Kn} -> T`.
- Qualified names: definitions are referenced by `QName`, which contains the
  defining module path and the local identifier.
- Variable names: local binders keep simple `Name` (string) and are not
  qualified.
- Resolution phase: before elaboration, a resolver maps raw names to either
  local `Name` (for binders) or `QName` (for definitions). Resolution is a
  separate pass that does not change term structure.
- Shadowing: local binders always shadow imported or opened definitions.
- Ambiguity: if multiple opened modules define the same name, resolution fails
  with an error listing all candidates.

## File and module mapping

- Source files use `.shitt` extension.
- Module `A.B.C` is resolved to `A/B/C.shitt` relative to a search root.
- Search root defaults to the current working directory, with a `--root` CLI override.

## Parser changes

- Add new keywords: `module`, `import`, `as`, `where`, `end`, `open`.
- Parse a new header:
  - `ModuleHeader = module <ModuleName> (imports...)*`
- `Program` becomes:
  - `Module = { name, imports, defs }`
- Add `ModuleBlock` for submodules:
  - `module <Name> (<params>)? where` ... `end`
  - `module _ (<params>) where` ... `end`
- Add `OpenDecl`:
  - `open <ModuleOrAlias> (<args>...)` with optional `as` alias
- Add `OpenImportDecl`:
  - `open import <Module.Name>` with optional `as` alias
- Preserve source positions in headers for error reporting.

## Loader and dependency graph

- New loader reads the entry file, parses the header, and recursively loads imports.
- Build a DAG of modules; detect and report cycles.
- On cycle detection, report the cycle path in order.

## Name resolution

### Representation

- `Name` is a plain string used for local binders.
- `QName` is a qualified definition reference:
  - `QName = { module: Array[String], name: String }`

### Resolution rules

- Each module has its own local scope for definitions.
- Imported modules add entries into a module table (by name and alias).
- `open` adds the exported names of a module into the unqualified lookup table.
- Unqualified lookup order: local binders, then opened modules (error on
  ambiguity), then local definitions.
- Qualified lookup checks only the named module alias or module name.
- Resolution produces a new syntax tree where raw definition references are
  replaced with `QName`.

## Typechecking integration

- Typechecking runs per module, in topological order.
- Each module receives a `Defs` context combining:
  - Prelude (if enabled)
  - Imported modules (as a read-only view)
- Definitions remain monomorphic across module boundaries (for now).

## CLI changes

- `shitt <file.shitt>` treats the file as the entry module.
- Watch mode still watches a single file for now.
- Future: watch should include imported files.

## Error handling

- Missing module: `import` resolution error with module name and expected path.
- Duplicate module name found at different paths: error with both paths.
- Ambiguous import (name conflict without alias): error pointing to import list.

## Migration plan

1. Add parser support for module/import headers.
2. Add loader and module DAG.
3. Add resolver pass producing `QName` (before elaboration).
4. Update typechecker to accept `Module` instead of `Program` and consume
  resolved names.
5. Update CLI and tests.
6. Add basic module tests (single import, alias, cycle error).

## Questions

- Should unqualified imports be allowed by default, or require explicit `open`?

Answer: explicit `open`.

- Should we allow multiple modules per file (likely no)?

Answer: no, keep one module per file for simplicity.

- Should `module` accept a file path literal instead of dotted names?

Answer: no, keep dotted names for clarity and consistency.
