# Examples

Every directory below contains complete public example files. Follow the linked lesson for field-by-field explanations and exact results.

## Registry

| Example | Teaches |
| --- | --- |
| [registry-minimal](registry-minimal/) | Roots, hosts, users, dimensions, aliases, and the shared roster |
| [workstation](workstation/) | One Registry consumed by Ownerships, Program, Furnish, and Praxis |

Start with [registering the fleet](../docs/registry/getting-started.md).

## Ownerships

| Example | Teaches |
| --- | --- |
| [ownerships-minimal](ownerships-minimal/) | One selected preference |
| [ownerships](ownerships/) | Users, hosts, and system selection |
| [ownerships-claims](ownerships-claims/) | Nested claims and predicates |
| [ownerships-merge](ownerships-merge/) | Merge behavior and policies |
| [ownerships-files](ownerships-files/) | Reusable unit files |
| [ownerships-team](ownerships-team/) | A larger editing-preferences project |

Start with [the first Ownerships result](../docs/ownerships/getting-started.md).

## Furnish

| Example | Teaches |
| --- | --- |
| [furnish](furnish/) | One managed file and its projected desired state |
| [furnish-policies](furnish-policies/) | Representations and conflict policies |
| [furnish-studio](furnish-studio/) | A larger Paperkite file configuration |

Start with [the first Furnish manifest](../docs/furnish/getting-started.md). Evaluation and store builds do not activate a host or write a declared destination.

## Program

| Example | Teaches |
| --- | --- |
| [program-minimal](program-minimal/) | A direct target and NixOS setting |
| [program-capabilities](program-capabilities/) | Sparse package and module outputs |
| [program-files](program-files/) | Application files and directories |
| [program-themes](program-themes/) | A generated theme file |
| [program-ownerships](program-ownerships/) | Optional Ownerships selection |
| [program-den](program-den/) | Optional Den roster binding |
| [program-studio](program-studio/) | A larger Helix setup |

Start with [the direct Program path](../docs/program/getting-started.md).

## Praxis

Place the generic command in a declarative package list once. [praxis-install](praxis-install/) holds a complete configuration flake that adds Lexicon as an input and puts `packages.<system>.praxis` into `environment.systemPackages`, plus `home.nix`, the same placement as a Home Manager module. Switch that configuration normally and `praxis` is on `PATH`. [praxis-shell](praxis-shell/) shows the optional alternative: the same package in one project's development shell.

Every ordinary example is one flake whose `flake.nix` exposes a `praxis` output. Enter the directory and run the direct command; no project-specific Praxis package or app output is required.

The smallest example declares its commands inline in `flake.nix`. The longer ones keep the same declaration in a separate `praxis.nix` that `flake.nix` imports. That choice is ordinary Nix file organization; the installed dispatcher reads the flake output either way and never looks for a filename.

| Example | Declaration | Direct command | Result |
| --- | --- | --- | --- |
| [praxis-install](praxis-install/) | no project declaration | `praxis --version` | the installed command on `PATH` |
| [praxis-shell](praxis-shell/) | inline in `flake.nix` | `praxis inspect` inside the shell | `ready` while the shell is entered |
| [praxis-minimal](praxis-minimal/) | inline in `flake.nix` | `praxis inspect` | `ready` |
| [praxis-everyday](praxis-everyday/) | imported `praxis.nix` | `praxis hosts` | `["workstation","server"]`, beside a `rebuild <host>` command |
| [praxis-commands](praxis-commands/) | imported `praxis.nix` | `praxis list` | commands and the `verify` task |
| [praxis-parameters](praxis-parameters/) | imported `praxis.nix` | `praxis greet River -gwelcome` | `welcome, River!` |
| [praxis-scripts](praxis-scripts/) | imported `praxis.nix` with `scripts/` | `praxis source-script` | `source script directory: work` |
| [praxis-workflow](praxis-workflow/) | imported `praxis.nix` | `DEMO_TOKEN=test-only praxis --quiet authenticate` | successful credential check |
| [praxis-outputs](praxis-outputs/) | inline configured projections | optional Nix output inspection | configured packages, apps, checks, and shell |
| [praxis-ownerships](praxis-ownerships/) | inline configured projections | optional Nix output inspection | selected command names and parameter choices |
| [praxis-project](praxis-project/) | imported `praxis.nix` | `praxis --quiet verify` | `ready` followed by successful checks |

The minimal lesson changes the declaration in `flake.nix` from `.#status` to `.#detailedStatus` and reruns `praxis inspect`; the observed result changes to `ready for checks` without reinstalling Praxis. The [Praxis manual](../docs/praxis/README.md) continues through commands, parameters, scripts, interactions, inspection, and optional integrations.

[Back to the manual](../docs/README.md)
