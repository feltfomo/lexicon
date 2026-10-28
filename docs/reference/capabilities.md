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

This page states Lexicon's current behavior and accepted target interfaces.
[The architecture](../explanation/architecture.md) explains their design. **Current** means
implemented; **Accepted target** means specified but not yet implemented. What Lexicon does not
provide is listed at the end. D-numbers refer to the architecture's design choices.

## Properties every part keeps

| Property | Status |
| --- | --- |
| Evaluation is pure Nix. Compilation, validation, rendering, settings, composition, docs generation and retained tests are Nix, with no import-from-derivation and no helper in another language | Accepted target. Known violations today: TOML output validation runs Python at build time; some test drivers are Python. the architecture lists each with its replacement |
| A non-Nix component exists only where execution happens outside evaluation and Nix can't do the job: the Furnish coordinator, the Praxis runtime, runtime publishers, and tests that drive a terminal, a VM or a running process | Accepted target |
| Laziness is part of every contract. Inactive payloads, native module bodies, unselected outputs and unrequested projections stay unforced | Current, kept |
| One diagnostic engine: every user-input failure is a Krisis diagnostic with a code from the owning subsystem's catalog and an authored location | Accepted target |
| Consumer declarations keep their syntax. skadi evaluates unchanged on the day the restructure lands | Current; consumer evaluations remain compatible |

## Public entry points

All entry points are attributes of `inputs.lexicon.lib`.

| Entry point | What it gives | Status |
| --- | --- | --- |
| `configure { subsystems ? [ ]; settings ? { }; lib ? nixpkgs.lib; }` | An environment: the assembled subsystems, resolved settings, the configured Ownerships API, `hosts.den`, `flake` and every subsystem surface, all bound to it. It's the only place settings and extra subsystems enter | Accepted target |
| `hosts.den { den; selectionRoster ? { }; selectionContext ? _: { }; }`, which is `(configure { }).hosts.den` | `lexicon` (the declaration function), `mkTarget`, `drop`, `hostAspects`, `roster`, `filePrincipals`, `hostUserNames` | Accepted target |
| `flake { inputs; modules; }`, which is `(configure { }).flake` | A standalone flake's `nixosConfigurations` built from aspect module files through Lexicon's own composition. Shape in [the plain host section](#the-plain-host) | Accepted target (D2) |
| `lexicon.forRoster`, `.forTarget`, `.withResolvers` | Bindings for a hand-built roster, one explicit target, or custom resolvers | Current, kept as bindings any host may use |
| `ownerships`, `toml`, `praxis`, `mkCoordinator` | Ownerships API, TOML generation, Praxis command projects, coordinator package | Current, kept as subsystem surfaces |
| `json { pkgs; }` | `render value -> string` and `generate name value -> derivation`, the JSON counterpart of `toml` | Accepted target |
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

Every alias remains available until a separate API change removes it (D11); this page promises
no removal date. No alias grows new behavior.

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
| A schema leaf declared `bind = "host"` can also be set per host from NixOS modules; every other leaf, including `enable`, is environment-bound | Accepted target (D8) |
| Every leaf appears as a NixOS option `lexicon.settings.<subsystem>.<leaf>` on each host, whose value is the leaf fully resolved for that host; defining an environment-bound leaf there is an error naming the file and the binding time | Accepted target |
| The host layer folds after the `configure` layer. `mkIf`, `mkMerge`, `mkDefault` and `mkForce` behave as in any NixOS option; `mkBefore` and `mkAfter` order `append` and `union` contributions within the host layer | Accepted target |
| Two different host definitions of a `replace` leaf at the winning priority are an error naming both files; equal definitions are fine | Accepted target |
| Host-bound values are readable in the NixOS bridge, and in the Home Manager bridge through `osConfig`; outside a host, such as `forTarget`, a host-bound leaf has its environment value | Accepted target |
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
| A quirk is a registered name under which aspects emit structured data. Each entity scope collects the values its aspects emit, flattening list values one level, and a class module receives its scope's list by naming the quirk as an argument, `[ ]` when nothing was emitted | Accepted target |
| Quirk names are registered by plain-host module files or subsystem records, and can't collide with each other, class names, structural aspect keys or module arguments | Accepted target |
| Consumers see every producer regardless of include order; values keep walk order; a quirk value is forced only when a consumer demands it | Accepted target |
| Under Den, Den's own quirks keep working, and `lexicon { }` passes the host's registered quirk keys through like `includes` | Accepted target |
| Same-scope quirk collection behaves the same under both hosts, checked by the conformance suite | Accepted target |

## The plain host

Accepted target (D2). A standalone flake lists module files; each file contributes aspects,
hosts, quirks and root includes. The architecture has the full contract.

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
# modules/impermanence.nix, the skadi persistence quirk without Den
{ inputs, ... }:
{
  quirks.persistence.doc = "Impermanence paths declared by feature aspects";
  aspects.networking.persistence.directories = [ "/etc/NetworkManager/system-connections" ];
  aspects.impermanence.nixos =
    { lib, persistence, ... }:
    {
      imports = [ inputs.impermanence.nixosModules.impermanence ];
      environment.persistence."/persist".directories = lib.concatMap (p: p.directories or [ ]) persistence;
    };
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
| A module file is a path or function returning only `aspects`, `hosts`, `quirks` and `default`; any other key is an error naming the file | Accepted target |
| `aspects` and `hosts` from all files merge by name; a name defined twice is an error naming both files | Accepted target |
| Every file sees the merged `aspects`, so `includes` can name aspects from other files | Accepted target |
| A host's aspect is `aspects.<host name>` and a user's is `aspects.<user name>`, as in Den | Accepted target |
| `default` aspects apply at every host and every user, like `den.default` | Accepted target |
| `inputs.nixpkgs` builds each host; `inputs.home-manager` is required only when a user has Home Manager content | Accepted target |
| Batteries on day one: `define-user`, `primary-user`, `user-shell` | Accepted target |

## Consumer API changes

These accepted target interfaces simplify consumer declarations (D14).

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
untouched and never forced by Lexicon; the old form keeps working.

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
skadi whenever it chooses; aliases stay.

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
stays inert until `lexicon.furnish.enable`; its `key` dedups a leftover import. Under Den the
module arrives through the NixOS bridge of any `lexicon { }` aspect on the host, so a host with no
Lexicon declaration still needs the explicit import. Every skadi host includes `base`, which
includes the Lexicon aspect `audio` (`system/base.nix`, `system/audio.nix`), so all four get it.

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
with the host's `pkgs`. `source.json` has the same form (below). Nix-side TOML validation must
reach parity with today's validator on every fixture.

Kept as is:

- `nixos` units with `value`: the wrapper keeps ownership `users` apart from native `users.users`.
- `package = pkgs: drv`: one obvious form already.
- Declaration-level `hosts`, `users`, `exceptHosts`, `exceptUsers`, `when`: the ownership vocabulary.
- `theme` renderer records, including `sharedWith`: skadi's shared renderer list is skadi's own option.
- `configure` and `hosts.den` signatures: settings enter only through `configure` (fixed above).
- The plain host's module file: it's already the proposal under D2.

## File sources and formats

| Guarantee | Status |
| --- | --- |
| A Furnish file `source` is a path, a string, a derivation, or a one-key record `{ <format> = value; }` naming a registered format | Accepted target (P4) |
| `toml` and `json` are registered formats in one format registry; a subsystem record can register another through the same extension point | Accepted target |
| A format source renders in Nix during evaluation to a `writeText` derivation named after the destination's file name; no other language runs | Accepted target |
| An unregistered format key, or a record with more than one key, is an error at the authored `source` path | Accepted target |
| A value the format can't represent (a function, a path, a float outside the format, a non-string key) is an error at its path inside the value | Accepted target |
| JSON renders with two-space indentation, sorted keys and a trailing newline, the same bytes for the same value on every evaluator | Accepted target |
| TOML output is validated in Nix by parsing it back with `builtins.fromTOML` and comparing with the input, on both Lix and CppNix | Accepted target |
| Theme composition merges published TOML at runtime as today; a theme composition that asks to merge a JSON output is an error, since no JSON runtime merge exists | Accepted target |

```nix
# before, modules/desktop/shells/serpantinum/default.nix
source = builtins.toFile "serpantinum-settings.json" (builtins.toJSON (settings // { inherit (overrides) display; }));
# after
source.json = settings // { inherit (overrides) display; };
```

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
| A host-bound setting is defined twice with different values, or an environment-bound setting is defined from a module | That host's evaluation throws naming each defining file | Accepted target |
| A plain-host aspect uses a key that's neither structural, a class nor a registered quirk, or two quirks collide | The plain host throws naming the aspect or both origins | Accepted target |
| A file source names an unknown format or holds a value the format can't represent | Evaluation throws at the authored `source` path | Accepted target |
| Warnings | Shown through Nix's warning output when the result that carries them is forced, rendered by Krisis | Accepted target |
| Runtime reconciliation or publication fails | The coordinator or publisher reports at activation or user time; evaluation is unaffected | Current, kept |

Lexicon never converts a callback exception into a diagnostic, never deep-forces a payload to
improve a message, and never returns a partial module for a failed slice.

## Evaluation benchmarks

Lexicon carries an evaluation benchmark suite that says whether a change makes evaluation better or
worse, and where.

| Guarantee | Status |
| --- | --- |
| Compares candidate and baseline revisions on a Den fleet and per-subsystem fixtures at fixed sizes | Current; the standalone fleet remains unavailable until the plain host is implemented |
| Reports the change per workload and per marked region, from deterministic evaluator counters | Current |
| Wall time and CPU time are reported with their sampling schedule and machine, never used as a verdict on their own | Current |
| Pins one evaluator as the flake package `bench-evaluator` (`nixVersions.nix_2_34` from the flake's nixpkgs, 2.34.8 at this lock) and records its version and out path in every record; a comparison across evaluators is refused | Current |
| Markers are pure, change no semantics or laziness, and cost one function application each | Current |
| Counter budgets fail a separate benchmark gate, not the default gate | Current (D12) |

## What Lexicon doesn't do

- Read mutable state or use import-from-derivation during evaluation.
- Run a nixpkgs module system for its own configuration.
- Wrap or replace Krisis reporting.
- Sandbox extension code.
- Provide a dynamic plugin loader or filesystem discovery of definitions. Discovery as an
  import-tree equivalent and flake management are candidate subsystems after this effort.
- Generalize the `nixos` ownership-unit merge into a native module merger.
- Offer Den's policies, pipes, `provides`, `_` sub-aspects, `meta.guard`, `hasAspect`, `excludes`
  or `__findFile` in the plain host. Topology comes from the host's entity kinds. Under Den, all of
  them keep working because Den walks.
- Move quirk data across scopes in the plain host, or resolve a quirk value against the producer's
  `config`. A plain-host quirk value is plain data delivered within its own scope.
- Merge JSON documents at runtime. JSON files are rendered at evaluation and placed like any file.
- Promise a date for removing a compatibility alias.
