# Declaration API

`inputs.lexicon.lib.lexicon` provides `forTarget`, `forRoster`, `forDen`,
`withResolvers`, `configure` and the default `ownerships` API. Each factory returns
a plain declaration function. Factories accept the usual `lib`, `axiom`, `krisis`
and `mkCoordinator` dependency overrides.

```nix
lexicon = inputs.lexicon.lib.lexicon.forDen { inherit den; };
```

Inject that function into aspect files.

```nix
{ lexicon, ... }:
{
  den.aspects.editor = lexicon {
    package = pkgs: pkgs.helix;
    homeManager.home.sessionVariables.EDITOR = "hx";
    furnish.links = [{
      source = "/home/alice/Projects/editor/config.toml";
      destination = ".config/helix/config.toml";
    }];
  };
}
```

Distribute selected entries from one checkout with one destination per line.

```nix
furnish.links = [{
  source = "/home/alice/Projects/skills";
  names = [ "subphase-architect" "subphase-implementer" "subphase-orchestrator" ];
  destinations = [ ".claude/skills" ".codex/skills" ".agents/skills" ];
}];
```

This produces nine external links without reading the checkout. Names may be nested
relative paths. Either empty list emits no links while still validating the group.
Individual `source`/`destination` records remain supported. Group and individual
fields cannot be mixed. Furnish still owns containment, collisions and retirement.

[Syntax](syntax.md) defines records and annotations. The [definition contract](definitions.md)
explains extension registration, selection, preparation and typed outputs. Built-ins
are registered in builtins.nix. `tests/declarations/fixtures/bookmarks.nix` is a
complete imported extension and public.nix tests it through these factories.

`forTarget { target }` binds an explicit host and optional user. Targets use
`host = { name; system; id ? "system/name"; }` and optional
`user = { name; home ? "/home/name"; }`. Direct mode rejects all registered ownership
annotations. Package and native Home Manager declarations may omit a user.
Resource-producing declarations require one, including contextual empty collections.
Static empty resource collections remain inert.

`forRoster { roster; selectionContext ? args: {}; }` binds a configured Ownerships
roster. `forDen { den; selectionRoster ? {}; selectionContext ? args: {}; }` uses
Den's base roster with extra selection data. Extra data cannot replace base fields.
Selection context adds registered non-base axis keys, demanded lazily. It cannot
replace host, user or native bridge arguments.

`configure { extensions = [ importedExtension ]; }` returns the same factories and
configured Ownerships. `withResolvers { resolvers; filePrincipals; hostUserNames;
selectionContext ? args: {}; }` calls its resolver builder with that configured
Ownerships API. The builder returns `resolve`, `resolveSystem` and `resolvePrepared`.

A declaration returns optional `homeManager` and `nixos` module functions. An empty
declaration returns `{}`. Native contributions use normal module composition;
callers must evaluate modules rather than depend on a package contribution occupying
`result.config.home.packages`. Native Home Manager functions retain requested
module arguments and receive bound host/user only at their declared boundary.

The legacy `program`, `programDirect`, `programOwnerships` and `programDen` exports
translate old syntax into this compiler. Their input forms remain supported. Their
native module result representation may use imports where the former compiler used
config. The resulting module behavior and filesystem declarations are unchanged.
