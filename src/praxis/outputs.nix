{
  lib,
  fields,
  spec,
  compiled,
  selected,
}:
let
  inherit (spec) pkgs name;
  inherit (fields) diagnostic validation finish;
  package = if spec.wrappers then compiled.package else compiled.cli;
  packages = {
    ${name} = package;
  }
  // lib.optionalAttrs spec.perCommand compiled.packages;
  app = {
    type = "app";
    program = "${package}/bin/${name}";
  };
  apps = {
    ${name} = app;
  }
  // lib.optionalAttrs spec.perCommand compiled.apps;
  checkFor =
    command:
    let
      exists = builtins.hasAttr command compiled.manifests;
      manifest = compiled.manifests.${command};
      commands = builtins.attrValues manifest.commands;
      interactive = builtins.any (
        c:
        builtins.any (p: p.sensitive || p.env != null || (p.required && p.default == null)) c.parameters
        || builtins.any (s: s.kind == "prompt" || s.interactive || s.confirm != null) c.steps
      ) commands;
      fixed =
        spec.cwd != null
        || builtins.any (
          c:
          (c.cwd != null && lib.hasPrefix "/" c.cwd)
          || builtins.any (s: s.cwd != null && lib.hasPrefix "/" s.cwd) c.steps
        ) commands;
      requiresSource =
        spec.atRoot
        || spec.discoverRoot != null
        || spec.requireRoot
        || builtins.any (c: builtins.any (s: s.kind == "script") c.steps) commands;
      diagnostics =
        if !exists then
          [ (diagnostic "praxis.checks" "check-name" "unknown selected command '${command}'") ]
        else
          validation.collect [
            (validation.optional interactive (
              diagnostic "checks.${command}" "interactive-check"
                "flake checks cannot contain prompts, terminal requirements or runtime parameter sources"
            ))
            (validation.optional fixed (
              diagnostic "checks.${command}" "check-directory"
                "flake checks cannot depend on a fixed runtime directory"
            ))
            (validation.optional (requiresSource && spec.root == null) (
              diagnostic "checks.${command}" "check-root" "this flake check needs root = ./. for its source files"
            ))
          ];
      file = pkgs.writeText "praxis-check-${command}.json" (builtins.toJSON manifest);
    in
    finish (
      validation.fromDiagnostics diagnostics (
        pkgs.runCommand "praxis-check-${command}" { } ''
          mkdir source
          cd source
          ${lib.optionalString (spec.root != null) ''
            cp -R ${spec.root}/. .
            chmod -R u+w .
          ''}
          ${compiled.runner}/bin/praxis --manifest ${file} --non-interactive run ${lib.escapeShellArg command}
          touch "$out"
        ''
      )
    );
  checks = lib.genAttrs spec.checks checkFor;
  devShell = pkgs.mkShell { packages = [ package ]; };
  system = pkgs.stdenv.hostPlatform.system;
in
{
  inherit
    package
    packages
    apps
    checks
    devShell
    ;
  inherit (compiled)
    cli
    runner
    manifest
    manifests
    diagnostics
    diagnosticSummaries
    ;
  commandPackages = compiled.packages;
  commandApps = compiled.apps;
  inherit (selected) availability;
  flake = {
    packages.${system} = packages;
    apps.${system} = apps;
    checks.${system} = checks;
  }
  // lib.optionalAttrs spec.devShell { devShells.${system}.default = devShell; };
}
