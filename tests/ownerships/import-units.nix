{
  lib,
  krisis,
  axiom,
}:
let
  ownerships = import ../../src/ownerships { inherit lib krisis axiom; };

  throws = value: !(builtins.tryEval (builtins.deepSeq value value)).success;

  flat = ownerships.importUnits {
    dir = ./fixtures/import-units/flat;
    args = {
      marker = "passed-through";
      poison = throw "forced imported unit payload";
    };
  };

  unitSets = ownerships.importUnitSets {
    dir = ./fixtures/import-units/sets;
    args.marker = "set-marker";
  };

  roster = ownerships.toRoster [
    (ownerships.define.host "khion" { system = "x86_64-linux"; })
    (ownerships.define.user "feltfomo" { hosts = [ "khion" ]; })
  ];

  host = {
    name = "khion";
    system = "x86_64-linux";
  };
  user.name = "feltfomo";

  resolvedSystem = ownerships.mkResolveSystem roster unitSets.system { inherit host; };
  resolvedHome = ownerships.mkResolve roster unitSets.home { inherit host user; };

  tests = {
    "test importUnits recursively discovers files in deterministic relative-path order" = {
      expr = map (unit: unit.label) flat;
      expected = [
        "alpha"
        "beta"
        "gamma"
      ];
    };
    "test importUnits normalizes one unit and a list into one flat collection" = {
      expr = builtins.length flat;
      expected = 3;
    };
    "test importUnits passes caller arguments to function files" = {
      expr = (builtins.head flat).imported.marker;
      expected = "passed-through";
    };
    "test importUnits validates only the unit shell and keeps payload fields lazy" = {
      expr =
        (builtins.tryEval (builtins.deepSeq (map (unit: unit.label) flat) true)).success
        && throws (builtins.head flat).imported.lazy;
      expected = true;
    };
    "test importUnitSets discovers system and home collections in one call" = {
      expr =
        map (unit: unit.label) unitSets.system == [ "system fixture" ]
        && map (unit: unit.label) unitSets.home == [ "home fixture" ];
      expected = true;
    };
    "test imported system units resolve through the public system door" = {
      expr = resolvedSystem;
      expected = {
        services.ownershipsImporter = {
          enable = true;
          marker = "set-marker";
        };
      };
    };
    "test imported home units resolve through the public user door" = {
      expr = resolvedHome;
      expected = {
        programs.ownershipsImporter.enable = true;
        home.sessionVariables.OWNERSHIPS_IMPORTER = "set-marker";
      };
    };
    "test mixed trees reject loose root nix files instead of guessing their scope" = {
      expr = ownerships.importUnitSets {
        dir = ./fixtures/import-units/ambiguous;
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[ownerships/import/loose-unit\\] cannot classify unit file 'loose\\.nix' in a mixed unit tree; move it under the '";
    };
    "test mixed trees reject unknown top-level collections" = {
      expr = ownerships.importUnitSets {
        dir = ./fixtures/import-units;
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[ownerships/import/unknown-collection\\] unknown unit collection 'ambiguous'; mixed unit trees support only 'sys";
    };
    "test invalid imported values fail closed" = {
      expr = ownerships.importUnits {
        dir = ./fixtures/import-units/invalid;
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[ownerships/import/unit-shape\\] imported unit file 'bad\\.nix' must return an attribute set or a list of attribut";
    };
    "test importUnits rejects a non-attribute argument bundle" = {
      expr = ownerships.importUnits {
        dir = ./fixtures/import-units/flat;
        args = [ ];
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[ownerships/import/args-shape\\] importUnits args must be an attribute set; got list";
    };
    "test importUnitSets rejects a non-attribute argument bundle" = {
      expr = ownerships.importUnitSets {
        dir = ./fixtures/import-units/sets;
        args = [ ];
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[ownerships/import/args-shape\\] importUnitSets args must be an attribute set; got list";
    };
  };

in
{
  inherit tests;
}
