args@{
  lib,
  axiom,
  krisis,
  ...
}:
let
  problem = krisis.mkDiagnosticFactory {
    severity = "error";
    codePrefix = "praxis";
  };
  reporter = krisis.mkReporter {
    formatHeader = count: "praxis: ${toString count} declaration error(s)";
    formatDiagnostic = diagnostic: "  - " + krisis.renderPlain diagnostic;
  };
  schema = import ./praxis/schema.nix {
    inherit
      lib
      axiom
      krisis
      problem
      ;
  };
  inherit (reporter) finish;
  project = finish (
    schema.project (
      removeAttrs args [
        "lib"
        "axiom"
        "krisis"
      ]
    )
  );
  results = lib.mapAttrs schema.command project.commands;
  fields = import ./praxis/fields.nix {
    inherit
      lib
      axiom
      krisis
      problem
      ;
  };
  inspect = import ./praxis/graph.nix { inherit lib fields results; };
  selections = lib.mapAttrs (name: _: inspect [ name ]) results;
  inherit (project) pkgs;
  runner = import ./praxis/package.nix { inherit pkgs; };
  # selected manifests must not normalize sibling commands
  normalized = builtins.mapAttrs (
    _: result:
    let
      command = finish result;
    in
    removeAttrs command [ "runtimeInputs" ] // { path = lib.makeBinPath command.runtimeInputs; }
  ) results;
  makeManifest = names: {
    version = 1;
    bash = "${pkgs.bash}/bin/bash";
    project = {
      inherit (project)
        cwd
        discoverRoot
        requireRoot
        ui
        ;
      expectedFlake =
        if project.requireRoot then builtins.readFile (project.root + "/flake.nix") else null;
    };
    commands = lib.genAttrs names (name: normalized.${name});
  };
  manifests = lib.mapAttrs (_: selection: makeManifest (finish selection)) selections;
  manifest = makeManifest (finish (inspect (builtins.attrNames results)));
  emit = import ./praxis/wrapper.nix { inherit lib pkgs runner; };
  packages = lib.mapAttrs (
    name: _:
    builtins.seq (finish selections.${name}) (emit {
      inherit name;
      manifest = manifests.${name};
      command = name;
      inherit ((finish results.${name})) description;
    })
  ) results;
  cli = emit {
    name = "praxis";
    inherit manifest;
    command = null;
    description = "Run declared commands";
  };
in
{
  inherit
    packages
    manifests
    manifest
    runner
    cli
    ;
  package = pkgs.symlinkJoin {
    name = "praxis-commands";
    paths = [ cli ] ++ builtins.attrValues packages;
    meta.mainProgram = "praxis";
  };
  diagnostics = lib.mapAttrs (_: selection: selection.diagnostics) selections;
  diagnosticSummaries = lib.mapAttrs (
    _: selection: krisis.summarizeDiagnostics selection.diagnostics
  ) selections;
  apps = lib.mapAttrs (name: package: {
    type = "app";
    program = "${package}/bin/${name}";
    meta.description = (finish results.${name}).description;
  }) packages;
}
