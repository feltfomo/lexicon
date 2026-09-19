# Program

Program groups one application's packages, Home Manager imports, NixOS module content, managed files, directory trees, and generated theme files behind one small declaration. The declaration emits only the module outputs its capabilities need.

For ordinary application configuration, start with [`programDirect`](getting-started.md). It binds one host and optional user once, then application files use `program { ... }` without resolver or principal callbacks.

Choose a different path only when the task requires it:

- Use [Ownerships integration](ownerships.md) when Program declarations must select hosts or users with `hosts`, `users`, exclusions, or predicates.
- Use [Den integration](den.md) when an existing Den configuration should supply the roster and principal wiring.
- Use the [advanced binding reference](advanced-reference.md) when another framework must provide custom resolver and principal callbacks.
- Use raw [Furnish](../furnish/README.md) for general file lifecycle work that is not naturally part of an application declaration.

Ownerships and Den are optional. Neither is a prerequisite for the direct path.

## Reading path

1. [Getting started](getting-started.md) binds one target, evaluates a NixOS setting, predicts an edit, adds a managed file, and moves the example into an ordinary consumer flake.
2. [Common usage](usage.md) adds package, Home Manager import, and NixOS-only capabilities while explaining sparse outputs.
3. [Files and directories](files.md) covers automatic Furnish lowering, representations, policies, expansion, exclusions, and per-file rules.
4. [Themes](themes.md) covers file-producing theme templates and the five renderer backends.
5. [Worked example](worked-example.md) combines a Helix package, Home Manager import, NixOS setting, file, and directory tree.
6. [Reference](reference.md) records every public declaration field, target default, nested shape, output, and relevant failure.

Optional integration paths follow the direct material:

- [Ownerships-backed Program](ownerships.md)
- [Den-backed Program](den.md)
- [Advanced/custom callbacks](advanced-reference.md)

Complete runnable files are indexed under [Program examples](../../examples/README.md#program).

[Back to the Lexicon manual](../README.md)
