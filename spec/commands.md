# Toplevel Commands (Proposal)

This document proposes a toplevel command system for the language. Commands are the only accepted toplevel items. Existing `def`/`data`/`mutual` are treated as commands so they can be used under `#fail`.

## Goals

- Add explicit commands for interactive checks.
- Allow negative tests with `#fail`.
- Keep existing programs valid by desugaring bare `def`/`data`/`mutual` into command form.
- Default `#infer` output is `term : type`.

## Syntax

### Command prefix

- A command starts with `#` followed by a command keyword.
- Whitespace after `#` is optional.

### Core commands

- `#check <term> : <type>`
- `#infer <term>`
- `#fail <command>`

### Definition commands

Two equivalent surface forms are accepted:

- `#def ...` / `#data ...` / `#mutual ...`
- `def ...` / `data ...` / `mutual ...` (desugared to the `#` forms)

This keeps current source files valid while allowing `#fail` to wrap definitions.

Default choice: keep desugaring enabled (no breaking change for existing sources).

## Examples

```
#check zero : Nat
#infer (suc zero)

#fail #check zero : Nat -- This will fail 
#fail #check zero : Bool -- This will succeed

#fail def f : Nat = True -- This will fail
#fail data Bad (A : U) : U where | mk : Bad Nat -- This will fail
```

## Semantics

### General

- The toplevel of a file is a sequence of commands.
- Commands are executed in order, in the same environment.
- A command may extend the environment (e.g., `#def`, `#data`, `#mutual`).
- A command may produce output (e.g., `#infer`).
- A command may fail with an elaboration error.

### `#check`

- Elaboration: check the term against the provided type.
- On success: no output is required.
- On failure: report the error and abort unless wrapped by `#fail`.

### `#infer`

- Elaboration: infer the type of the term.
- On success: print `term : type`.
- On failure: report the error and abort unless wrapped by `#fail`.

### `#fail`

- Form: `#fail <command>` where `<command>` is a single command.
- Behavior:
  - Run the inner command in a sandboxed error context.
  - If the inner command fails, `#fail` succeeds and suppresses the error output.
  - If the inner command succeeds, `#fail` fails with an error like
    "Expected command to fail, but it succeeded".
- Environment effects:
  - If the inner command fails (expected), it has no effect on the environment.
  - If the inner command succeeds (unexpected), its environment changes are also
    discarded because `#fail` itself fails.

### Definition commands

- `#def` elaborates a definition, inserts it into the environment on success.
- `#data` elaborates a data declaration, inserts the data and constructors.
- `#mutual` elaborates a mutual block, inserts all definitions.
- These commands are semantically identical to the existing toplevel `def`/`data`/`mutual`.

## Parser changes (outline)

- Add a `Command` node:
  - `CmdCheck(term, type)`
  - `CmdInfer(term)`
  - `CmdFail(command)`
  - `CmdDef(def)` / `CmdData(data)` / `CmdMutual(mutual)`
- Parse toplevel as a list of `Command`.
- Desugar bare `def`/`data`/`mutual` into their corresponding `Cmd*` nodes.
- Allow `#fail` only on a single command (no implicit grouping).

## Resolver and elaboration changes (outline)

- Resolver operates per command, producing resolved forms for terms inside.
- Elaboration executes commands in order, threading the environment.
- `#fail` runs its inner command with error capture and environment rollback.

## Error reporting

- If `#fail` succeeds, suppress inner error output.
- If `#fail` fails (inner command succeeded), report an error at the `#fail` site.

## Open questions

- Should `#check` accept `#check term` and infer its type, or only the annotated form?
