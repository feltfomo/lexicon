# Lexicon manual

Lexicon begins with **Registry**, the one place a configuration says which hosts and users exist, along with its source and live roots. **Ownerships** selects and merges Nix values for particular users and hosts. **Furnish** declares managed files, lets you inspect the compiled desired state, and can reconcile it on NixOS. **Program** groups one application's packages, modules, files, and themes. **Praxis** turns declared commands and tasks into an inspectable project CLI.

The [feature list](features.md) is the overview: every feature grouped by subsystem, each linked to the page that teaches it. Use it when you want to know whether something exists; use the paths below when you want to learn one subsystem from the beginning.

## Where to start

If you have not used Nix, begin with [preparation](preparation.md). It covers the language and command-line concepts needed by every path.

Most configurations should start with Registry. A standalone subsystem remains valid when there are no shared fleet or root facts.

- [Registry getting started](registry/getting-started.md) writes `lexicon.nix`, evaluates one normalized fleet summary, adds a second host, and uses the files as a separate flake.
- [Ownerships getting started](ownerships/getting-started.md) evaluates one selected preference, changes it, and moves the example into a separate flake.
- [Furnish getting started](furnish/getting-started.md) evaluates one managed-file manifest, makes a predictable destination edit, and builds the manifest without host activation.
- [Program getting started](program/getting-started.md) binds one claim-free target, evaluates a NixOS application setting, makes a predictable edit, and adds a Program-managed file.
- [Praxis getting started](praxis/getting-started.md) adds the generic command to a declarative package list, exposes a declaration from `flake.nix`, and observes a declaration edit immediately.

The [Registry contents](registry/README.md), [Ownerships contents](ownerships/README.md), [Furnish contents](furnish/README.md), [Program contents](program/README.md), and [Praxis contents](praxis/README.md) keep each reading order in one place.

## Learn by task

Use the [Registry reference](registry/reference.md) to add roots, dimensions, host or user metadata, or a selected context after the first example. Use [Den integration](registry/den.md) when Den already owns the fleet.

Use [Ownerships usage](ownerships/usage.md) for claims, nested selections, merge policies, and reusable unit files. Follow its [worked team configuration](ownerships/worked-example.md) to see those pieces together.

Use [Furnish usage](furnish/usage.md) for direct file-lifecycle declarations, representations, conflict policies, authority, path boundaries, state, and diagnostics. Its [Paperkite worked example](furnish/worked-example.md) combines user and system declarations without another Lexicon system.

Use [Program common usage](program/usage.md) for packages and module outputs, [files and directories](program/files.md) for automatic Furnish-backed publication, and [themes](program/themes.md) for renderer output. The [Helix worked example](program/worked-example.md) combines those application capabilities. Ownerships and Den integrations remain optional later paths.

Use [Praxis commands and tasks](praxis/commands-and-tasks.md) to choose literal argv, shell, scripts, or references; [runtime inspection](praxis/runtime.md) to list, plan, and diagnose commands; and [parameters](praxis/parameters.md) or [scripts and roots](praxis/scripts-and-roots.md) when a workflow grows. Its [reporting example](praxis/worked-example.md) keeps every effect in a copied project.

## Look something up

The [Registry reference](registry/reference.md) documents the constructor, every declaration field, normalized outputs, lookup and context helpers, and subsystem boundaries.

The [Ownerships reference](ownerships/reference.md) documents its public functions and authoring fields; [inspection](ownerships/inspection.md) and [advanced reference](ownerships/advanced-reference.md) cover traces and custom merge support.

The [Furnish reference](furnish/reference.md) documents declarations, compiler results, helpers, and NixOS options. [Runtime and safety](furnish/runtime.md) covers activation, boot, ledger state, and retirement; [advanced reference](furnish/advanced-reference.md) records integration and version-sensitive exports.

The [Program reference](program/reference.md) documents all four constructors, direct targets, declaration fields, conditional outputs, nested file and theme shapes, and failures. Its [advanced binding reference](program/advanced-reference.md) covers custom resolver and principal callbacks.

The [Praxis reference](praxis/reference.md) documents project, command, task, action, parameter, interaction, root, check, and output fields. Its [advanced reference](praxis/advanced-reference.md) covers manifests, diagnostics, adapters, wrappers, and confinement without teaching compiler schema as public syntax.

Complete files live in [examples](../examples/README.md).
