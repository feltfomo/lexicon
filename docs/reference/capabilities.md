# Lexicon after the restructure

Lexicon turns small Nix declarations into native NixOS and Home Manager modules and into plans that
runtime services carry out. After the restructure it does that through one subsystem record shape,
static settings, Krisis diagnostics and a host contract that Den and a plain flake both implement.
A consumer's declarations don't change.

```nix
{ lexicon, ... }:
{
  den.aspects.helix = lexicon {
    package = pkgs: pkgs.helix;
    furnish.files = [ { source = ./config.toml; destination = ".config/helix/config.toml"; } ];
    hosts = [ "khion" ];
  };
}
```

This page states what Lexicon provides and guarantees. [The architecture](../explanation/architecture.md) says
how it's built, and [the audit](../records/restructure-audit.md) holds the evidence behind each decision. Status uses the
capability-page vocabulary: **Current**, **Accepted target**, **Deferred**, **Out of scope**.
The owner approved every decision and proposal on 2026-10-27. Items that rest on a decision say
which one (D-numbers refer to architecture.md's decisions).

## Properties every part keeps

| Property | Status |
| --- | --- |
| Evaluation is pure Nix. Compilation, validation, rendering, settings, composition, docs generation and retained tests are Nix, with no import-from-derivation and no helper in another language | Accepted target. Known violations today: TOML output validation runs Python at build time; some test drivers are Python. architecture.md lists each with its replacement |
| A non-Nix component exists only where execution happens outside evaluation and Nix can't do the job: the Furnish coordinator, the Praxis runtime, runtime publishers, and tests that drive a terminal, a VM or a running process | Accepted target |
| Laziness is part of every contract. Inactive payloads, native module bodies, unselected outputs and unrequested projections stay unforced | Current, kept |
| One diagnostic engine: every user-input failure is a Krisis diagnostic with a code from the owning subsystem's catalog and an authored location | Accepted target |
| Consumer declarations keep their syntax. skadi evaluates unchanged on the day the restructure lands | Accepted target |

## Public entry points

All entry points are attributes of `inputs.lexicon.lib`.

| Entry point | What it gives | Status |
| --- | --- | --- |
| `configure { subsystems ? [ ]; settings ? { }; lib ? nixpkgs.lib; }` | An environment: the assembled subsystems, resolved settings, the configured Ownerships API, `hosts.den`, `flake` and every subsystem surface, all bound to it. It's the only place settings and extra subsystems enter | Accepted target |
| `hosts.den { den; selectionRoster ? { }; selectionContext ? _: { }; }`, which is `(configure { }).hosts.den` | `lexicon` (the declaration function), `mkTarget`, `drop`, `hostAspects`, `roster`, `filePrincipals`, `hostUserNames` | Accepted target |
| `flake { inputs; modules; }`, which is `(configure { }).flake` | A standalone flake's `nixosConfigurations` built from aspect module files through Lexicon's own composition. Shape in [the plain host section](#the-plain-host) | Accepted target (D2) |
| `lexicon.forRoster`, `.forTarget`, `.withResolvers` | Bindings for a hand-built roster, one explicit target, or custom resolvers | Current, kept as bindings any host may use |
| `ownerships`, `toml`, `praxis`, `mkCoordinator` | Ownerships API, TOML generation, Praxis command projects, coordinator package | Current, kept as subsystem surfaces |
| `lexicon.configure { extensions }`, `lexicon.forDen`, `den`, `furnishRuntime` | Today's names | Compatibility aliases (below) |
| `program`, `programDirect`, `programOwnerships`, `programDen`, `report`, `furnish`, `praxisAdapters`, `registry` | Today's names | Compatibility aliases (below) |

### Aliases and their end condition

Every current entry point keeps working when the restructure lands. Each alias is one adapter at one
boundary:

- `lexicon.forDen { den; ... }` is `(hosts.den { den; ... }).lexicon`.
- `den { den; }` is `hosts.den { den; }` with the same `mkTarget`, `drop` and `hostAspects`.
- `furnishRuntime { }` returns the coordinator service module. It keeps its module `key`, so an
  explicit import next to the host-attached copy deduplicates.
- `lexicon.configure { extensions }` converts each old extension record into a subsystem record
  once, at that boundary, including Axiom-shaped field specifications (D4).
- `program*` translate old flat fields into canonical declarations, as today.
- Today's per-factory dependency overrides (`lib`, `krisis`, `axiom`, `mkCoordinator`; `reference.md:27-34`) route
  through `configure`, which builds one dependency set per environment. An alias that receives an
  override it can no longer apply, `axiom` or a per-call `lib`, `krisis` or `mkCoordinator`, ignores
  it and emits a Krisis warning naming the argument and why: `lexicon/ignored-override` from the
  `lexicon.*`, `den` and `furnishRuntime` aliases, `program/ignored-override` from `program*`. The
  warning shows on every evaluation that forces the alias's result, through Nix's warning output.

An alias is removed in a reviewed change once skadi no longer references it and one release has
carried it. The owner sets the dates (D11). No alias grows new behavior.

## The subsystem record

A subsystem is a function from a toolkit to a record. Built-ins and third parties write the same
shape, and a record with only `name` is valid.

```nix
{ T, setting, node, requires, catalog, ... }:
{
  name = "bookmarks";
  requires = [ "furnish" ];
  settings.root = setting {
    type = T.String;
    default = ".local/share/bookmarks";
    doc = "Home-relative directory that receives bookmark links";
  };
  blocks = [ (import ./block.nix { inherit T node requires; }) ];
  catalog = catalog { link-name = { severity = "error"; summary = "bookmark name isn't a relative path"; }; };
}
```

| Guarantee | Status |
| --- | --- |
| Names are unique across every registry: subsystems, blocks, annotation author keys, metadata keys, classes, plan kinds, services, surfaces and catalog namespaces. A collision fails before any declaration compiles, naming every origin | Accepted target; block and annotation uniqueness is Current |
| `requires` is acyclic and satisfied by enabled subsystems. A disabled required subsystem is an error naming both ends; nothing is auto-enabled | Accepted target |
| A subsystem sees only the exports of subsystems in its `requires` closure, and may emit only plan kinds and classes owned inside that closure | Accepted target |
| Order is deterministic: topological by `requires`, ties by authored order, built-ins first | Accepted target; built-ins-first is Current |
| Assembly forces names, requires, catalog code keys and the settings schema's structure, never `lower`, node bodies, services, surfaces or batteries | Accepted target |
| A subsystem adds vocabulary to fixed extension points. It never adds a pipeline stage | Accepted target |
| Block definitions keep today's contract in `definitions.md`, except that field shapes are Krisis types instead of Axiom field specifications | Accepted target, D4 |

## Settings

Settings are static schemas folded over ordered layers. The nixpkgs module system isn't involved.

```nix
inputs.lexicon.lib.configure {
  settings.theme.renderers = [ "noctalia" "caelestia" ];
}
```

| Guarantee | Status |
| --- | --- |
| Each subsystem declares its settings schema; `enable` is added for every subsystem | Accepted target |
| A schema's leaves, types and merge strategies don't depend on any setting's value | Accepted target |
| Layers fold least specific first: schema defaults, then the `configure` layer. Position decides; there's no priority override | Accepted target |
| Each leaf merges by its declared strategy: `replace`, `append`, `union`, `attrs` or a named custom fold applied left to right | Accepted target |
| Every resolved leaf keeps lazy provenance: which layer set it, which value won, which were shadowed | Accepted target |
| Setting an undeclared leaf is an error with a suggestion | Accepted target |
| A block from a disabled subsystem fails as an unknown field whose help names the disabled subsystem | Accepted target, D7 |
| The settings reference page is generated from the schemas | Accepted target |
| Host-bound leaves set per host through a module-system edge adapter | Deferred (D8). No leaf needs it on day one |
| `lexicon.furnish.state` stays a NixOS option of the coordinator service, not a Lexicon setting | Current, kept |

## Composition and hosts

A host tells Lexicon which entities exist, who the principals are and where native classes land.
Den is one host and a plain flake is another.

| Guarantee | Status |
| --- | --- |
| `lexicon { ... }` returns an aspect fragment: the declaration compiles into the native class keys `nixos` and `homeManager`. Lexicon's own `nixos` units list never reaches a walker | Current under Den; Accepted target for the plain host (D2). Passing `name` and `includes` through is accepted target P1 |
| Under Den, Den walks the aspects. Batteries, quirks, `den.default` and every Den feature keep working | Current, kept |
| Under the plain host, Lexicon's composition subsystem walks a portable aspect subset: `name`, `includes`, registered class keys, and functions of entity kinds | Accepted target |
| The portable subset behaves the same under both hosts, checked by a shared fixture suite | Accepted target |
| A plain-host body whose formal argument isn't a known entity kind, and has no `...`, is an error at walk; an unreachable kind stays inert and is recorded in an inspection trace | Accepted target, D5 |
| Compilation is identical under both hosts, because it runs inside the class module functions both hosts receive | Accepted target |
| Cross-declaration destination collisions are checked once per host over every declaration that reached it | Current, kept |
| Den's policies, quirks, `provides`, `meta.guard`, `hasAspect` and `__findFile` in the plain host | Out of scope. Topology comes from the host's kinds; a real need for these is a host feature with its own design |
| A standalone equivalent of `den.quirks` | Out of scope for this effort |

## The plain host

Accepted target (D2). A standalone flake lists module files; each file contributes aspects, hosts and
root includes. architecture.md has the full contract.

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    lexicon.url = "github:feltfomo/lexicon";
  };
  outputs = inputs: inputs.lexicon.lib.flake {
    inherit inputs;
    modules = [ ./modules/khion.nix ./modules/feltfomo.nix ./modules/helix.nix ];
  };
}
```

```nix
# modules/khion.nix
{ aspects, ... }:
{
  hosts.khion = { system = "x86_64-linux"; users.feltfomo = { }; };
  aspects.khion.includes = [ aspects.helix ];
  default = [ { nixos.system.stateVersion = "25.11"; homeManager.home.stateVersion = "25.11"; } ];
}
```

```nix
# modules/feltfomo.nix
{ batteries, ... }:
{
  aspects.feltfomo.includes = [ batteries.define-user batteries.primary-user (batteries.user-shell "fish") ];
}
```

| Guarantee | Status |
| --- | --- |
| A module file is a path or function returning only `aspects`, `hosts` and `default`; any other key is an error naming the file | Accepted target |
| `aspects` and `hosts` from all files merge by name; a name defined twice is an error naming both files | Accepted target |
| Every file sees the merged `aspects`, so `includes` can name aspects from other files | Accepted target |
| A host's aspect is `aspects.<host name>` and a user's is `aspects.<user name>`, as in Den | Accepted target |
| `default` aspects apply at every host and every user, like `den.default` | Accepted target |
| `inputs.nixpkgs` builds each host; `inputs.home-manager` is required only when a user has Home Manager content | Accepted target |
| Batteries on day one: `define-user`, `primary-user`, `user-shell` | Accepted target |

## Consumer API proposals

Approved on 2026-10-27 (D14). P4 lands only after spike S3 shows Nix-side TOML validation is sound. Each removes a wart in real
skadi code.

**P1. `includes` inside `lexicon { }`.** Four skadi aspects merge a plain attrset into a declaration
with `//`, so the aspect has two spellings and `//` would silently drop a key both sides set.

Before, `modules/editors/nvim/default.nix` as it is today:

```nix
{
  lexicon,
  den,
  ...
}:
{
  den.aspects.nvim = {
    includes = [ den.aspects.devenv ];
  }
  // lexicon {
    package =
      pkgs:
      pkgs.symlinkJoin {
        name = "neovim-with-deps";
        # ...
      };
    furnish.directories = [
      {
        source = ./config;
        destination = ".config/nvim";
      }
    ];
    theme = {
      id = "nvim";
      # ...
    };
  };
}
```

After:

```nix
{
  lexicon,
  den,
  ...
}:
{
  den.aspects.nvim = lexicon {
    includes = [ den.aspects.devenv ];
    package =
      pkgs:
      pkgs.symlinkJoin {
        name = "neovim-with-deps";
        # ...
      };
    furnish.directories = [
      {
        source = ./config;
        destination = ".config/nvim";
      }
    ];
    theme = {
      id = "nvim";
      # ...
    };
  };
}
```

The same applies to `ai/claude-code/default.nix`, `desktop/compositors/hyprland/default.nix` and
`gaming/prismlauncher.nix`.

Buys one spelling. Costs a new structural field in the declaration vocabulary, passed through
untouched and never forced by Lexicon; the old form keeps working. Recommend.

**P2. One host binding in `outputs.nix`.** skadi builds three Lexicon values from one `den`, with
three dependency sets today.

Before, `/etc/skadi/outputs.nix` as it is today:

```nix
inputs:
inputs.flake-parts.lib.mkFlake { inherit inputs; } (
  { den, ... }:
  let
    denApi = inputs.lexicon.lib.den { inherit den; };
  in
  {
    imports = [ (inputs.import-tree ./modules) ];
    systems = [ "x86_64-linux" ];
    _module.args = {
      lexicon = inputs.lexicon.lib.lexicon.forDen { inherit den; };
      furnishRuntime = inputs.lexicon.lib.furnishRuntime { };
      inherit denApi;
    };
  }
)
```

After:

```nix
inputs:
inputs.flake-parts.lib.mkFlake { inherit inputs; } (
  { den, ... }:
  let
    denApi = inputs.lexicon.lib.hosts.den { inherit den; };
  in
  {
    imports = [ (inputs.import-tree ./modules) ];
    systems = [ "x86_64-linux" ];
    _module.args = {
      inherit (denApi) lexicon;
      inherit denApi;
    };
  }
)
```

Buys one binding, one dependency set and no `lib.lexicon.forDen` stutter. Costs a two-line edit in
skadi whenever it chooses; aliases stay. Recommend.

**P3. No explicit coordinator import.** `impermanence.nix` imports `furnishRuntime` only so the
`lexicon.furnish.state` option exists on a host.

Before, `modules/system/impermanence.nix` as it is today, cut to the parts that change:

```nix
{ inputs, furnishRuntime, ... }:
{
  den.aspects.impermanence.nixos =
    {
      config,
      lib,
      persistence,
      ...
    }:
    {
      imports = [
        inputs.impermanence.nixosModules.impermanence
        furnishRuntime
      ];

      lexicon.furnish.state = {
        path = "/persist/var/lib/furnish";
        # ...
      };
    };
}
```

After:

```nix
{ inputs, ... }:
{
  den.aspects.impermanence.nixos =
    {
      config,
      lib,
      persistence,
      ...
    }:
    {
      imports = [ inputs.impermanence.nixosModules.impermanence ];

      lexicon.furnish.state = {
        path = "/persist/var/lib/furnish";
        # ...
      };
    };
}
```

Buys one fewer module argument. Costs attaching the coordinator module to every host, where it
stays inert until `lexicon.furnish.enable`; its `key` dedups a leftover import. Recommend.

**P4. A TOML document as a file source.** Ten places in six skadi files instantiate
`inputs.lexicon.lib.toml { inherit pkgs; }` inside a callback only to render a file.

Before, `modules/editors/helix/default.nix` as it is today, without its theme:

```nix
{
  config,
  inputs,
  lexicon,
  ...
}:
{
  den.aspects.helix = lexicon {
    package = pkgs: pkgs.evil-helix;
    furnish.files =
      { pkgs, ... }:
      [
        {
          source = (inputs.lexicon.lib.toml { inherit pkgs; }).generate "helix-config.toml" (
            import ./_settings.nix
          );
          destination = ".config/helix/config.toml";
        }
      ];
  };
}
```

After:

```nix
{
  config,
  inputs,
  lexicon,
  ...
}:
{
  den.aspects.helix = lexicon {
    package = pkgs: pkgs.evil-helix;
    furnish.files = [
      {
        source.toml = import ./_settings.nix;
        destination = ".config/helix/config.toml";
      }
    ];
  };
}
```

Buys a static collection instead of a callback, and no `pkgs` plumbing. Costs: `source` becomes an
union of path, string, derivation and a `{ toml = attrs; }` record, so Furnish forces a source to
weak head normal form to classify it, which it doesn't today; rendering moves into the settle stage
with the host's `pkgs`. `{ json = ...; }` would follow the same form if a second format earns it. Recommend only after S3 shows Nix-side TOML validation is sound.

Kept as is:

- `nixos` units with `value`: the wrapper keeps ownership `users` apart from native `users.users`.
- `package = pkgs: drv`: one obvious form already.
- Declaration-level `hosts`, `users`, `exceptHosts`, `exceptUsers`, `when`: the ownership vocabulary.
- `theme` renderer records, including `sharedWith`: skadi's shared renderer list is skadi's own option.
- `configure` and `hosts.den` signatures: settings enter only through `configure` (fixed above).
- The plain host's module file: it's already the proposal under D2.

## Extension

A third party extends Lexicon by passing subsystem records to `configure`. One record can add
blocks, ownership annotations, metadata keys, plan kinds, classes, services, settings, surfaces and
a catalog. A new annotation applies to every declared record node of every block, built-ins
included. A block gets ownership processing, metadata, contextual callbacks, origin tracking and the
shared Furnish collision check without writing any of them. Definitions are trusted Nix, not
sandboxed plugins (Current, kept).

## Diagnostics

| Guarantee | Status |
| --- | --- |
| Every user-input failure is a Krisis diagnostic whose code belongs to the emitting subsystem's catalog; an uncatalogued code fails at construction | Accepted target |
| A code reads `<namespace>/<code>`. A subsystem's namespace is its `name`. The engine keeps `lexicon`, other systems use their directory name (`ownerships`, `settings`, `toml`, `coordinator`), hosts use `den` and `plain`, and the legacy translator keeps `program`. Those are reserved; a subsystem can't take one | Accepted target; `lexicon`, `ownerships`, `toml` and `program` are Current |
| Locations are structured Krisis paths into the authored declaration, such as `furnish.links[0].source`, and survive filtering and expansion | Accepted target; rendered labels are Current |
| Independent checks accumulate, so one evaluation reports every independent error. Dependent work stops after an invalid parent | Current, kept |
| Callback exceptions keep their original error, with context added at the forced expression | Current, kept |
| A malformed definition fails before its `lower` can run | Current, kept |
| Diagnostics are rendered only by Krisis | Accepted target |

## What a consumer sees on failure

| Situation | Behavior | Status |
| --- | --- | --- |
| Invalid declaration or extension input | Evaluation throws at the forced bridge expression with every visible diagnostic of that report rendered by Krisis | Accepted target; today throws through the compatibility reporter |
| Duplicate registration, cyclic or unsatisfied `requires`, bad settings | `configure` throws before any declaration compiles | Accepted target |
| Two declarations claim one destination on a host | The host's evaluation throws naming every claimant | Current, kept |
| A required context key a custom axis needs is missing | Ownerships fails with a missing-context diagnostic | Current, kept |
| Warnings | Surface as module-system warnings where the host has them; otherwise in the finished report | Accepted target |
| Runtime reconciliation or publication fails | The coordinator or publisher reports at activation or user time; evaluation is unaffected | Current, kept |

Lexicon never converts a callback exception into a diagnostic, never deep-forces a payload to
improve a message, and never returns a partial module for a failed slice.

## Evaluation benchmarks

Lexicon carries an evaluation benchmark suite that says whether a change makes evaluation better or
worse, and where.

| Guarantee | Status |
| --- | --- |
| Compares a candidate revision with a baseline revision on fixed workloads: a skadi-shaped fleet through the Den host, a standalone flake through the plain host, and per-subsystem fixtures at fixed sizes | Accepted target |
| Reports the change per workload and per marked region, from deterministic evaluator counters | Accepted target |
| Wall time and CPU time are reported with their sampling schedule and machine, never used as a verdict on their own | Accepted target |
| Pins one evaluator as the flake package `bench-evaluator` (`nixVersions.nix_2_34` from the flake's nixpkgs, 2.34.8 at this lock) and records its version and out path in every record; a comparison across evaluators is refused | Accepted target |
| Markers are pure, change no semantics or laziness, and cost one function application each | Accepted target |
| Counter budgets fail a separate benchmark gate, not the default gate | Accepted target (D12) |

## What Lexicon doesn't do

- Read mutable state or use import-from-derivation during evaluation.
- Run a nixpkgs module system for its own configuration.
- Wrap or replace Krisis reporting.
- Sandbox extension code.
- Provide a dynamic plugin loader or filesystem discovery of definitions. Discovery as an
  import-tree equivalent and flake management are candidate subsystems after this effort.
- Generalize the `nixos` ownership-unit merge into a native module merger.
