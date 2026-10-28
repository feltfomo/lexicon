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
  reporter = krisis.effects.reporter {
    formatHeader = count: "praxis: ${toString count} declaration error(s)";
    formatDiagnostic = diagnostic: "  - " + krisis.renderPlain diagnostic;
  };
  schema = import ./schema.nix {
    inherit
      lib
      axiom
      krisis
      problem
      ;
  };
  finish = krisis.effects.finishWithReporter reporter;
  finishResult = result: finish (krisis.effects.fromAxiom result);
  project = finish (
    schema.project (
      removeAttrs args [
        "lib"
        "axiom"
        "krisis"
        "lower"
        "installWrappers"
      ]
    )
  );
  results = lib.mapAttrs (
    name: value: krisis.effects.resultOf ((args.lower or schema.command) name value)
  ) project.commands;
  fields = import ./fields.nix {
    inherit
      lib
      axiom
      krisis
      problem
      ;
  };
  inspect = import ./graph.nix { inherit lib fields results; };
  tree = import ./tree.nix { inherit lib fields; };
  selections = lib.mapAttrs (name: _: krisis.effects.resultOf (inspect [ name ])) results;
  inherit (project) pkgs;
  runner = import ./package.nix { inherit pkgs; };
  # selected manifests must not normalize sibling commands
  normalized =
    name:
    let
      command = finishResult (tree.lookup results name);
    in
    removeAttrs command [ "runtimeInputs" ] // { path = lib.makeBinPath command.runtimeInputs; };
  makeManifest = names: {
    version = 2;
    inherit (project) name;
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
    commands = lib.genAttrs names normalized;
  };
  manifests = lib.mapAttrs (_: selection: makeManifest (finishResult selection)) selections;
  manifest = makeManifest (finish (inspect (builtins.attrNames results)));
  manifestText = builtins.toJSON manifest;
  prepared = pkgs.writeTextFile {
    name = "praxis-project-prepared";
    destination = "/manifest.json";
    text = manifestText;
    derivationArgs.commandReferences = builtins.appendContext "praxis-command-references" (
      builtins.getContext manifestText
    );
  };
  emit = import ./wrapper.nix { inherit lib pkgs runner; };
  packages = lib.mapAttrs (
    name: _:
    builtins.seq (finishResult selections.${name}) (emit {
      inherit name;
      manifest = manifests.${name};
      command = name;
      inherit ((finishResult results.${name})) description;
    })
  ) results;
  cli = emit {
    inherit (project) name;
    inherit manifest;
    command = null;
    description = "Run declared commands";
    wrappers = args.installWrappers or false;
  };
in
{
  inherit
    packages
    manifests
    manifest
    prepared
    runner
    cli
    ;
  package = pkgs.symlinkJoin {
    name = "${project.name}-commands";
    paths = [ cli ] ++ builtins.attrValues packages;
    meta.mainProgram = project.name;
  };
  diagnostics = lib.mapAttrs (_: selection: selection.diagnostics) selections;
  diagnosticSummaries = lib.mapAttrs (
    _: selection: krisis.summarizeDiagnostics selection.diagnostics
  ) selections;
  apps = lib.mapAttrs (name: package: {
    type = "app";
    program = "${package}/bin/${name}";
    meta.description = (finishResult results.${name}).description;
  }) packages;
}
