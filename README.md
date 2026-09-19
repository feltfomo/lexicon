# Lexicon

Lexicon is a collection of Nix libraries for declaring shared configuration facts, choosing configuration, managing files, describing application setup, and running project commands.

- **Registry** records roots, hosts, users, and membership once for other subsystems to consume.
- **Ownerships** selects and merges settings for particular users and hosts.
- **Furnish** declares managed files and reconciles them on NixOS, including symlinked and writable files.
- **Program** groups an application's packages, files, and settings into Home Manager and NixOS modules.
- **Praxis** turns Nix command declarations into a project CLI, with arguments and multi-step tasks.

The [feature list](docs/features.md) is the overview of everything Lexicon offers, grouped by subsystem, with a link to the page that teaches each feature.

Start with the [manual](docs/README.md). Register the fleet first when several subsystems need the same hosts, users, or roots; every subsystem also keeps a standalone learning path, runnable examples, and a public reference.

Already know Nix? Start with [your first Registry](docs/registry/getting-started.md). For isolated use, evaluate [your first Ownerships result](docs/ownerships/getting-started.md), [your first Furnish manifest](docs/furnish/getting-started.md), [your first Program result](docs/program/getting-started.md), or [run your first Praxis command](docs/praxis/getting-started.md). New to it? Read the short [preparation page](docs/preparation.md) first.

[Examples](examples/README.md)
