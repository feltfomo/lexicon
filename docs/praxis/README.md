# Praxis

Praxis is an installed command runner for Nix projects. Add the package to your configuration once, expose a `praxis` output from a project's `flake.nix`, and run memorable project commands such as `praxis check` from the project root or any directory below it.

Commands are the foundation. Parameters, scripts, tasks, output integrations, and Ownerships are optional additions.

## Read in order

1. [Install Praxis and run your first project command](getting-started.md).
2. [Give your everyday Nix work names](everyday-commands.md).
3. [Commands and tasks](commands-and-tasks.md).
4. [Parameters and forwarding](parameters.md).
5. [Scripts and roots](scripts-and-roots.md).
6. [Interactions and policy](interactions.md).
7. [Runtime inspection](runtime.md).
8. [Publish your commands as flake outputs](outputs.md).
9. [Optional Ownerships selection](ownerships.md).
10. [Worked Nix project](worked-example.md).
11. [Public reference](reference.md).
12. [Advanced public reference](advanced-reference.md).

Use the [public reference](reference.md) when an exact field, default, restriction, or failure matters. The advanced page describes supported values for integrations without making them prerequisites.

[Back to the Lexicon manual](../README.md) · [Complete examples](../../examples/README.md)
