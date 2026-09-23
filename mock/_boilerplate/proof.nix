# the whole tree compared against what it is supposed to produce, off the two
# libraries and a nixpkgs tree with no flake in the evaluation
{
  lib,
  fx,
  nixpkgs,
  systems,
}:
let
  mock = import ../lexicon.nix { inherit lib fx nixpkgs; };

  door = mock.configure ../.;

  prepared = door.prepare door.value;

  emitted = door.emit prepared.value;

  targets = emitted.value;

  named = outcome: map (given: { inherit (given) code at; }) outcome.diagnostics;

  # a tree that is meant to be refused is a configuration of its own and goes
  # through the same door as the fleet
  refused =
    root:
    let
      opened = mock.configure root;
    in
    named (opened.prepare opened.value);

  answer = mock.library.introspect {
    walked = door.value;
    prepared = prepared.value;
  };

  # the outputs this fleet declares, projected onto the surface a reader of
  # this flake already knows. the declarations come off the same walk the
  # entries did, and the hosts come off the prepared registry, so a
  # declaration naming a host the fleet does not hold is refused here rather
  # than landing under a name nothing answers to
  surface = mock.library.telos.outputs {
    entries = door.owned.telos;
    hosts = prepared.value.registry.hosts;
    packageSets = lib.genAttrs systems mock.packageSetFor;
    inherit systems;
  };

  hosts = builtins.attrNames targets.native;

  configOf = placement: name: targets.${placement}.${name}.built.config;

  agrees =
    name:
    (configOf "native" name).system.build.toplevel.drvPath == (configOf "den" name)
    .system.build.toplevel.drvPath;

  accountOn = name: person: (configOf "native" name).users.users.${person};

  reaching =
    name:
    builtins.attrNames
      (lib.findFirst (held: held.kind == "host" && held.name == name) null answer.fleet).claimed.entries;

  expectations = [
    {
      at = "the walk";
      expected = [ ];
      actual = named door;
    }
    {
      at = "the declaration";
      expected = [ ];
      actual = named prepared;
    }
    {
      at = "emission";
      expected = [ ];
      actual = named emitted;
    }
    {
      at = "placements";
      expected = [
        "den"
        "native"
      ];
      actual = builtins.attrNames targets;
    }
    {
      at = "hosts";
      expected = [
        "folio"
        "pattern"
        "tower"
        "vessel"
      ];
      actual = hosts;
    }
    {
      at = "one derivation per host";
      expected = lib.genAttrs hosts (_: true);
      actual = lib.genAttrs hosts agrees;
    }
    {
      at = "networking.hostName";
      expected = lib.genAttrs hosts (name: name);
      actual = lib.genAttrs hosts (name: (configOf "native" name).networking.hostName);
    }
    {
      at = ''fileSystems."/".device'';
      expected = {
        folio = "/dev/nvme0n1p2";
        pattern = "/dev/disk/by-label/root";
        tower = "/dev/sda2";
        vessel = "/dev/vda1";
      };
      actual = lib.genAttrs hosts (name: (configOf "native" name).fileSystems."/".device);
    }
    {
      at = "the accounts on tower";
      expected = {
        scribe = {
          shell = "/run/current-system/sw/bin/bash";
          extraGroups = [ ];
        };
        warden = {
          shell = "/run/current-system/sw/bin/fish";
          extraGroups = [ "wheel" ];
        };
      };
      actual = lib.genAttrs [ "scribe" "warden" ] (
        person:
        let
          account = accountOn "tower" person;
        in
        {
          shell = toString account.shell;
          inherit (account) extraGroups;
        }
      );
    }
    {
      at = "the template holds no accounts";
      expected = {
        scribe = false;
        warden = false;
      };
      actual = lib.genAttrs [ "scribe" "warden" ] (
        person: (configOf "native" "pattern").users.users ? ${person}
      );
    }
    {
      at = "the facet that claims one host";
      expected = {
        folio = false;
        pattern = false;
        tower = true;
        vessel = false;
      };
      actual = lib.genAttrs hosts (name: targets.native.${name}.carried ? monitors);
    }
    {
      at = "the entries reaching each host";
      expected = lib.genAttrs hosts (
        name:
        lib.sort (a: b: a < b) (
          [
            "accounts"
            "desk"
            "hardware"
            "system"
          ]
          ++ lib.optional (name == "tower") "monitors"
        )
      );
      actual = lib.genAttrs hosts reaching;
    }
    {
      at = "the declarations the walk read";
      expected = 12;
      actual = builtins.length answer.files;
    }
    {
      at = "the checks one knot over both trees declares";
      expected = [
        "fleet-declares-hostless"
        "host-declares-its-own"
        "walk-reached-accounts"
        "walk-reached-desk"
        "walk-reached-fleet"
        "walk-reached-folio"
        "walk-reached-git"
        "walk-reached-hardware"
        "walk-reached-monitors"
        "walk-reached-pattern"
        "walk-reached-scribe"
        "walk-reached-system"
        "walk-reached-tower"
        "walk-reached-tower-checks"
        "walk-reached-vessel"
        "walk-reached-warden"
      ];
      actual = lib.sort (a: b: a < b) (builtins.attrNames surface.checks.x86_64-linux);
    }
    {
      at = "refusals/entries";
      expected = [
        {
          code = "kata/disallowed-block";
          at = ''$."modules/git.nix".nixos'';
        }
        {
          code = "kata/unknown-block";
          at = ''$."modules/shell.nix".nixso'';
        }
        {
          code = "kata/nixos-interior";
          at = ''$."modules/system.nix".nixos'';
        }
        {
          code = "kata/malformed-construction";
          at = ''$."modules/tower.nix".system'';
        }
      ];
      actual = refused ../refusals/entries;
    }
    {
      at = "refusals/fleet";
      expected = [
        {
          code = "kata/unknown-claimed-host";
          at = ''$."modules/desk.nix".furnish.hosts'';
        }
      ];
      actual = refused ../refusals/fleet;
    }
    {
      at = "refusals/fields";
      expected = [
        {
          code = "lexicon/unknown-field";
          at = "$.hosts.tower.users.warden.shel";
        }
      ];
      actual = refused ../refusals/fields;
    }
  ];

  failed = builtins.filter (want: want.actual != want.expected) expectations;

  show = builtins.toJSON;

  mismatch = want: "${want.at}\n  expected ${show want.expected}\n  actual   ${show want.actual}";

  line = want: "  ${want.at} = ${show want.actual}";
in
{
  proof =
    if failed == [ ] then
      lib.concatStringsSep "\n" (
        [ "proof ok, ${toString (builtins.length expectations)} values compared" ] ++ map line expectations
      )
    else
      throw (lib.concatStringsSep "\n\n" ([ "proof failed" ] ++ map mismatch failed));

  print = lib.concatStringsSep "\n" answer.lines;

  # what the flake publishes, both as lexicon's own attribute and merged into
  # the standard names beside it. the proof above compares values, and this
  # is the half only a build can answer
  lexicon = surface;

  inherit answer;
}
