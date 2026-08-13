# Program

`program` is the normal aspect-authoring surface for software that installs packages, imports Home Manager modules, places files, expands configuration directories, registers application themes, or emits a NixOS slice.

A declaration has no effect unless it contains a capability such as `pkg`, `imports`, `files`, `directories`, `theme`, or `nixos`.

## Minimal program

```nix
{ program, rootPath, ... }:
{
  den.aspects.ghostty = program {
    pkg = pkgs: pkgs.ghostty;
    directories = [
      {
        src = "${rootPath}/configs/ghostty";
        dest = ".config/ghostty";
      }
    ];
  };
}
```

## Combining Home Manager and other capabilities

Put all capabilities for one application in the same `program` declaration. Use `imports` for Home Manager configuration, then add `pkg`, `files`, `directories`, `theme`, or `nixos` beside it as needed. Do not merge the result of `program` with a separate `homeManager` attribute.

```nix
{ program, rootPath, ... }:
{
  den.aspects.example = program {
    imports = [
      (
        { config, ... }:
        {
          programs.example = {
            enable = true;
            settings.themeFile = "${config.home.homeDirectory}/.config/example/reactive.conf";
          };
        }
      )
    ];

    files = [
      {
        src = "${rootPath}/configs/example/config.toml";
        dest = ".config/example/config.toml";
      }
    ];

    theme = {
      id = "example";
      output = ".config/example/reactive.conf";
      renderers = {
        noctalia = {
          source = "${rootPath}/configs/example/reactive.conf";
          sharedWith = [
            "dms"
            "illogical-impulse"
            "end4-pc"
          ];
        };
        caelestia.source = "${rootPath}/configs/example/caelestia.conf";
      };
    };
  };
}
```

`imports` is the normal bridge to Home Manager. Keeping it inside `program` gives one readable declaration for the application and lets Program combine every selected capability under the same ownership rules.

## Theme registration

A theme declaration describes one application theme. Common renderer settings live beside `renderers`; a renderer may override any of them locally. `renderers` explicitly selects the shells that may render the theme.

```nix
theme = {
  id = "kitty";
  output = ".config/kitty/themes/reactive.conf";
  reload = "pkill -SIGUSR1 kitty";

  renderers = {
    noctalia = {
      source = "${rootPath}/configs/kitty/themes/reactive.conf";
      sharedWith = [
        "dms"
        "illogical-impulse"
        "end4-pc"
      ];
    };

    caelestia.source = "${rootPath}/configs/kitty/themes/caelestia.conf";
  };
};
```

The declaration visibly says that Kitty has one renderer shared by Noctalia, DMS, Illogical Impulse, and end4-pC, plus a distinct Caelestia template. `output` and `reload` are written once because they describe the application result rather than a shell-specific input.

- An omitted shell is not registered; its configuration remains static unless another declaration manages it.
- Shared fields are applied first, then renderer-local fields override them.
- `sharedWith` directly copies the complete effective renderer settings to the named shells. It is not transitive and does not chase another renderer declaration.
- The primary renderer key carries no priority. Noctalia shared with DMS has the same meaning as DMS shared with Noctalia.
- A shell may be assigned by exactly one renderer declaration within a template.
- An empty renderer is valid only when inherited fields make its effective settings complete.

### Renderer fields

The following fields may be written beside `renderers` as shared settings or inside a renderer as an override:

- `source`: template source path.
- `output`: stable path below the user's home directory.
- `reload`: optional command run after publishing the rendered output.
- `subdir`: optional renderer template subdirectory.
- `placedAs`: optional basename for the shell's managed template copy. It defaults to the basename of `source`. Current adapters use explicit input paths, so changing this name does not change rendering behavior or `output`.
- `subId`: optional suffix for the registration identity.
- `native`: optional backend-specific registration fields.

`placedAs` controls the basename of the shell-managed template copy. It is useful both for readable shell-side names and for avoiding staging collisions. The Firefox templates below stage `caelestia-userChrome.css` and `caelestia-userContent.css` as `userChrome.css` and `userContent.css`.

Registration identity and filesystem identity are separate. `id` plus `subId` distinguishes registrations, but it does not make identical staged paths distinct. If two templates for the same application use sources with the same basename and land in the same renderer subdirectory, give them different `placedAs` values. Otherwise Furnish correctly reports `collision-detection/duplicate-filesystem-identity`. Cross-application reuse does not normally collide because the application ID namespaces the renderer directory.

Renderer entries additionally accept `sharedWith`, a list of registered shell names that use the same effective settings. Program validates these names against the adapter registry, reports every known shell, and suggests a nearby name for likely typos.

Every effective renderer must define `source` and `output` after shared fields and local overrides are combined.

### Renderer-specific fields

Noctalia and DMS adapters may also set `native` fields supported by their registration format.

```nix
theme = {
  id = "example";
  renderers.dms = {
    source = ./colors.conf;
    output = ".config/example/colors.conf";
    native.compare_to = "dark";
  };
};
```

Caelestia does not expose native per-template registration fields. Program rejects `renderers.caelestia.native` rather than pretending the backend supports it.

### Caelestia publication

Caelestia renders registered templates into its state directory. Program emits one executable publisher per application under `.config/caelestia/theme-hooks/`.

A publisher installs every output for that application before running any reload command. Entries are ordered by registration identity, and both the publisher and aggregate `postHook` stop on the first failure. This prevents a partial multi-output publication from being followed by a reload that observes only some new files.

## Multiple outputs

Use `templates` when one application publishes multiple files. `id` remains application-wide; shared fields belong inside each template because each one describes a different output.

When multiple entries reuse one source basename, assign distinct staged basenames even if their `subId` and `output` differ:

```nix
theme = {
  id = "qt";
  templates = [
    {
      subId = "qt5ct";
      source = "${rootPath}/configs/qt/reactive.conf";
      output = ".config/qt5ct/colors/reactive.conf";
      placedAs = "qt5ct.conf";
      renderers.noctalia.sharedWith = [ "dms" ];
    }
    {
      subId = "qt6ct";
      source = "${rootPath}/configs/qt/reactive.conf";
      output = ".config/qt6ct/colors/reactive.conf";
      placedAs = "qt6ct.conf";
      renderers.noctalia.sharedWith = [ "dms" ];
    }
  ];
};
```

Without the distinct `placedAs` values, both registrations would try to stage `reactive.conf` at the same shell-managed path.

```nix
theme = {
  id = "firefox";
  templates = [
    {
      subId = "chrome";
      output = ".config/mozilla/firefox/feltfomo/chrome/userChrome.css";
      renderers = {
        noctalia = {
          source = "${rootPath}/configs/firefox/chrome/userChrome.css";
          sharedWith = [
            "dms"
            "illogical-impulse"
            "end4-pc"
          ];
        };
        caelestia = {
          source = "${rootPath}/configs/firefox/chrome/caelestia-userChrome.css";
          placedAs = "userChrome.css";
        };
      };
    }
    {
      subId = "content";
      output = ".config/mozilla/firefox/feltfomo/chrome/userContent.css";
      renderers = {
        noctalia = {
          source = "${rootPath}/configs/firefox/chrome/userContent.css";
          sharedWith = [
            "dms"
            "illogical-impulse"
            "end4-pc"
          ];
        };
        caelestia = {
          source = "${rootPath}/configs/firefox/chrome/caelestia-userContent.css";
          placedAs = "userContent.css";
        };
      };
    }
  ];
};
```

The multi-template form does not mix single-template fields beside `templates`. Put shared fields inside each list entry.

## Compositor themes

Compositors register only with the shell engine used in that session.

```nix
theme = {
  id = "hyprland";
  renderers.caelestia = {
    source = "${rootPath}/configs/hypr/caelestia-colors.lua";
    output = ".config/hypr/colors.lua";
    placedAs = "colors.lua";
    reload = "hyprctl reload";
  };
};
```

Niri uses `renderers.dms`; Mango uses `renderers.noctalia`.

## Files

```nix
files = [
  {
    src = "${rootPath}/configs/example/config.toml";
    dest = ".config/example/config.toml";
  }
];
```

Optional file lifecycle fields are `representation`, `onConflict`, and `provenance`.

## Directories

```nix
directories = [
  {
    src = "${rootPath}/configs/example";
    dest = ".config/example";
    exclude = [ "generated.conf" ];
    files = [
      {
        names = [ "state.json" ];
        representation = "writable";
        onConflict = "source-wins";
      }
    ];
  }
];
```

Directory expansion manages regular files recursively. Theme sources under that directory are reserved automatically and are not also emitted as ordinary files.

## Ownership

Program declarations and nested file, directory, or theme entries accept Ownerships claims such as `hosts`, `users`, `exceptHosts`, `exceptUsers`, and `when`.

Prefer the highest declaration level that accurately expresses ownership. Use nested claims only when one capability has narrower ownership than the rest of the program.

## Validation

Program uses a closed declaration schema. It rejects unknown fields, malformed destinations, incomplete effective renderer settings, malformed or unknown `sharedWith` names, repeated or self-shared shells, overlapping renderer groups, unsupported native fields, duplicate registration identities, invalid conflict policies, and theme sources hidden under excluded directory subtrees. Independent declaration problems are accumulated before Program stops; dependent elaboration does not run after an invalid renderer shape.

Payloads selected by Ownerships are validated before Program emits Furnish declarations.
