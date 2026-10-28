{
  lib,
  pkgs,
  nixpkgs,
  axiom,
  krisis,
}:
let
  runtime = import ../../src/furnish/runtime.nix {
    inherit axiom krisis;
    mkCoordinator = _: pkgs.hello;
  };
  declaration = {
    label = "runtime";
    filesystemNamespace = "host";
    authority = {
      scope = "user";
      identity = "alice";
    };
    managedRoot = "/srv/alice";
    destination = ".config/runtime";
    representation = "symlink";
    source = {
      kind = "external";
      value = "/absent/runtime-source";
    };
  };
  evaluate =
    enable: declarations:
    (nixpkgs.lib.nixosSystem {
      system = pkgs.stdenv.hostPlatform.system;
      modules = [
        runtime
        {
          boot.isContainer = true;
          system.stateVersion = "26.05";
          networking.hostName = "resource-effects";
          lexicon.furnish = {
            inherit enable declarations;
            state.requiresMountsFor = [ "/persist/furnish" ];
          };
        }
      ];
    }).config;
  disabled = evaluate false [ ];
  disabledPoison = evaluate false [
    (
      declaration
      // {
        source = {
          kind = "path";
          value = throw "disabled runtime forced a source";
        };
      }
    )
  ];
  generated = pkgs.writeText "resource-runtime-generated" "generated source";
  generatedConfig = evaluate true [
    (
      declaration
      // {
        source = {
          kind = "path";
          value = generated;
        };
      }
    )
  ];
  empty = evaluate true [ ];
  populated = evaluate true [ declaration ];
  service = populated.systemd.services.furnish;
  tests = {
    "test native disabled runtime is inert" = {
      expr =
        disabledPoison.lexicon.furnish.manifestPath == null
        && disabled.lexicon.furnish.manifestPath == null
        && !(disabled.systemd.services ? furnish)
        && !(disabled.system.activationScripts ? furnish);
      expected = true;
    };
    "test native generated sources stay in the system closure" = {
      expr = builtins.any (
        value: lib.isDerivation value && value.drvPath == generated.drvPath
      ) generatedConfig.system.extraDependencies;
      expected = true;
    };
    "test native enabled empty reconciles retirements" = {
      expr =
        empty.lexicon.furnish.manifestData == [ ]
        && empty.lexicon.furnish.manifestPath != null
        && empty.systemd.services.furnish.wantedBy == [ "multi-user.target" ]
        && lib.hasInfix "reconcile" empty.system.activationScripts.furnish.text;
      expected = true;
    };
    "test native nonempty runtime preserves order and mounts" = {
      expr =
        builtins.length populated.lexicon.furnish.manifestData == 1
        && populated.system.activationScripts.furnish.deps == [ "users" ]
        && builtins.elem "local-fs.target" service.after
        &&
          service.unitConfig.RequiresMountsFor == [
            "/srv/alice/.config/runtime"
            "/persist/furnish"
          ]
        && service.serviceConfig.RemainAfterExit
        && service.serviceConfig.Type == "oneshot";
      expected = true;
    };
    "test native activation defers initrd and preserves protocol" = {
      expr =
        lib.hasInfix "IN_NIXOS_SYSTEMD_STAGE1" populated.system.activationScripts.furnish.text
        && lib.hasInfix "/run/lock" populated.system.activationScripts.furnish.text
        && lib.hasInfix "--diagnostic-format plain" service.script
        && lib.hasInfix "--state-dir /var/lib/furnish" service.script
        && populated.lexicon.furnish.ledgerPath == "/var/lib/furnish/applied-state.json";
      expected = true;
    };
  };
in
{
  inherit tests;
}
