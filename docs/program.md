# program

`program` is the function an aspect declares against. you hand it one attribute
set and it hands back the home manager and nixos modules den installs.
everything in between is validation, ownership resolution and file expansion.

```nix
den.aspects.hyprland = program {
  hosts = [ "khion" "lumi" ];
  pkg = pkgs: pkgs.pyprland;
  nixos = { pkgs, host, ... }: [ ... ];
  files = [ ... ];
  directories = [ ... ];
  theme = { ... };
};
```

## the declaration

a declaration is a closed vocabulary. an unknown key is a typo and is reported
as one, naming the nearest legal key when there is one close enough.

| key | shape | meaning |
| --- | --- | --- |
| `hosts` | list of names | claim, restricts the whole aspect |
| `users` | list of names | claim |
| `exceptHosts` | list of names | claim |
| `exceptUsers` | list of names | claim |
| `when` | predicate | claim |
| `pkg` | function of pkgs | one package into the user's profile |
| `nixos` | function, list, or one slice | system configuration |
| `imports` | list | home manager imports |
| `files` | list of file entries | files furnish installs |
| `directories` | list of directory entries | directory trees furnish installs |
| `theme` | attribute set | theme templates |

the five claim keys are the ownership engine's claim keys and mean the same
thing here that they mean anywhere else.

## nixos

three spellings.

```nix
nixos = { services.foo.enable = true; };
nixos = [ { services.foo.enable = true; } { services.bar.enable = true; } ];
nixos = { pkgs, config, host, user, ... }: [ ... ];
```

only the function form is applied, and it receives the build, so a slice can
read the resolved host instead of rebuilding it from `pkgs.stdenv.hostPlatform`
and `config.networking.hostName`.

the slices hang under the declaration's own claim, narrowed to what a system
scope resolve can bind. the outer `hosts` owns them all.

```nix
den.aspects.hyprland = program {
  hosts = [ "khion" "lumi" ];
  nixos = { pkgs, ... }: [
    { programs.hyprland.enable = true; }
    { hosts = [ "khion" ]; hardware.nvidia.modesetting.enable = true; }
  ];
};
```

the first slice lands on both hosts because it inherits the declaration's
claim. the second narrows within it. a slice cannot widen past the
declaration, so a host the declaration does not claim resolves to nothing.

## files

a file entry names one source and one destination, and may carry a claim so it
reaches only some of the aspect's hosts or users.

| key | meaning |
| --- | --- |
| the five claim keys | narrow this entry within the declaration |
| `src` | source path |
| `dest` | destination, relative and normalized |
| `label` | name shown in diagnostics |
| `representation` | how furnish materializes it |
| `onConflict` | one of the declared conflict policies |
| `provenance` | free text recorded on the installed file |

## directories

a directory entry installs a whole tree. the tree is read once per aspect, not
once per user.

| key | meaning |
| --- | --- |
| the five claim keys | narrow this entry within the declaration |
| `src` | source directory |
| `dest` | destination root |
| `exclude` | normalized relative names to leave out |
| `files` | per file overrides inside the tree |
| `representation`, `onConflict`, `provenance` | defaults for every file in the tree |

an entry in `files` names one or more members of the tree and overrides their
lifecycle keys.

| key | meaning |
| --- | --- |
| the five claim keys | narrow this rule |
| `names` | non empty list of normalized relative names |
| `representation`, `onConflict`, `provenance` | overrides for those names |

the checks are strict on purpose. excluding a name that is not in the tree,
overriding a name that is not in the tree, overriding a name you also excluded,
repeating an override name, and excluding or overriding a file the theme owns
are all errors that name the declaring index.

### why the walk is split

reading the source tree does not depend on which user is being resolved, but it
used to happen inside the per user resolve, so a two user host walked every
directory twice. `prewalkDirectory` does everything that is context free, the
readDir recursion, the membership inventory and the shape and source checks
that gate them. the aspect runs it once per declared directory and every user
slice threads the result through `expandDirectory`.

the prewalk is looked up by the declaring index. a missing index means the
declared list and the resolved entries disagree, which throws and names the
index. it used to fall back to an empty walk, which turned that disagreement
into a directory that silently installed nothing.

## theme

the theme block carries an `id` and either one inline template or a `templates`
list. the two spellings cannot be mixed and mixing them is reported with the
offending keys. a single template is normalized into a one element list before
the compiler sees it, so the compiler only handles one shape.

matugen backed templates are tagged with the user context and merged once by the
shared runtime, because a matugen renderer reads one config file per user.

## what program emits

`homeManager` is emitted when the declaration has a `pkg` or any `imports`. it
resolves the declaration for the given host and user and installs the package
and the imports.

`nixos` is emitted when the declaration has a `nixos` block or owns any files.
it resolves the system slices, and when the declaration owns files it also
resolves the file, directory and theme entries, expands them, and hands the
result to furnish along with the host's principals.

the furnish namespace is the resolved host's canonical id. when there is no
resolved host, standalone evaluation for instance, it falls back to the
platform and hostname pair.

an assertion fires when an aspect produces files but no principal receives
them, and it lists the users the host actually has, because that failure is
almost always a claim that reaches no one.

## the file layout

`program.nix` is the composition root. it wires the pieces together and holds
the two emitters.

| file | holds |
| --- | --- |
| `program/fields.nix` | the small predicates and key sets everything shares |
| `program/spec.nix` | the closed vocabularies, the schemas, `validateSpec` |
| `program/directories.nix` | the readDir walk, the prewalk split, expansion |
| `program/units.nix` | the ownership units a declaration becomes |
| `program/report.nix` | the diagnostics policy and the suggester |
| `program/theme/` | the theme compiler and its backends |

the suggester is duplicated between `program/report.nix` and
`ownerships/axes.nix` rather than imported. the `program-boundary` check exists
to keep the program layer from reaching into ownership internals, and one small
duplicated helper is cheaper than a hole in that boundary.
