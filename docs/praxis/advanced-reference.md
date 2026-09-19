# Praxis advanced public reference

The values below are public for integrations that publish configured packages, apps, shells, checks, or wrapper commands from a declaration.

## Configured output values

`lexicon.lib.praxis` returns `package`, `packages`, `apps`, `checks`, `devShell`, and `flake` for consumers that want to project a particular declaration through another Nix integration.

`cli` is the configured dispatcher package. `commandPackages` and `commandApps` provide command-specific launchers, and `perCommand = true` includes them in `packages` and `apps`. `wrappers = true` includes prefix-free command wrappers in the main configured package. Custom `name` values change the configured dispatcher's identity without changing the generic installed `praxis` command.

`runner` is the reusable runtime package for integrations that embed the runtime directly.

## Inspection values

`diagnostics` and `diagnosticSummaries` expose declaration results by command for tools that present configuration errors. `availability` exposes selected command names and optional Ownerships inspection values.

`manifest` and `manifests` are read-only results for integrations that need evaluated project data.

## Local flake arguments

`localFlake = true` prefixes literal values in an action's declared `args` with `.#`. Use it only when every declared value names a local flake output. Empty values, options beginning with `-`, and values already containing `#` are rejected.

## Optional roster-derived choices

<!-- praxis-adapter-fields: fromRoster fromDen -->

`lexicon.lib.praxisAdapters { inherit (nixpkgs) lib; }` returns `fromRoster` and `fromDen`. Each produces sorted `host` and `user` parameter records. The records remain inert until placed in a command's `parameters` list.

Return to the [public reference](reference.md) or [Praxis contents](README.md).
