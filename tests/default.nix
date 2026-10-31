# the nix-unit tree, one node per file under tests so a suite moves with its file
{
  lib,
  pkgs,
  axiom,
  krisis,
  krisisSource,
  lexicon,
  nixpkgs,
}:
let
  core = { inherit lib axiom krisis; };
  withPackages = core // {
    inherit pkgs lexicon;
  };
  examples = { inherit lexicon nixpkgs; };

  # a declared away host distinguishes inactive payloads from unknown claims
  furnishFixture =
    let
      ownerships = import ../src/ownerships core;
      roster = ownerships.toRoster [
        (ownerships.define.host "khion" { system = "x86_64-linux"; })
        (ownerships.define.host "lumi" { system = "x86_64-linux"; })
        (ownerships.define.user "feltfomo" {
          hosts = [
            "khion"
            "lumi"
          ];
        })
      ];
      hostCtx = {
        id = "x86_64-linux/khion";
        name = "khion";
        system = "x86_64-linux";
      };
    in
    {
      resolve = ownerships.mkResolve roster;
      resolveSystem = ownerships.mkResolveSystem roster;
      principalContexts = [
        {
          authority = {
            scope = "system";
            identity = "x86_64-linux/khion";
          };
          ctx.host = hostCtx;
        }
        {
          authority = {
            scope = "user";
            identity = "feltfomo";
          };
          ctx = {
            host = hostCtx;
            user.name = "feltfomo";
          };
        }
      ];
    };

  publicDeclarations = import ./declarations/public.nix withPackages;
  observations = import ./events/fixtures.nix (withPackages // { inherit krisisSource; });
in
{
  effects-contract = observations.effects.tests;
  bench = {
    default = (import ./bench { inherit lib; }).tests;
    markers = (import ./bench/markers.nix { inherit lib; }).tests;
    workloads = (import ./bench/workloads.nix { inherit lib lexicon; }).tests;
  };
  registry = (import ./registry core).tests;

  declarations = {
    default = (import ./declarations core).tests;
    registration = (import ./declarations/registration.nix core).tests;
    outputs = (import ./declarations/outputs.nix core).tests;
    public = publicDeclarations.tests;
    inherit (publicDeclarations) links;
    contextual-theme = publicDeclarations.contextualTheme;
    resource-effects = (import ./declarations/resource-effects.nix withPackages).tests;
    observations = observations.compiler.tests;
  };

  ownerships = {
    engine = (import ./ownerships/engine.nix core).tests;
    roster = (import ./ownerships/roster.nix core).tests;
    surface = (import ./ownerships/surface.nix core).tests;
    descriptors = (import ./ownerships/descriptors.nix core).tests;
    matrix = (import ./ownerships/matrix.nix core).tests;
    import-units = (import ./ownerships/import-units.nix core).tests;
    observations = observations.ownerships.tests;
  };

  furnish = {
    default = (import ./furnish (core // furnishFixture)).tests;
    effects = (import ./furnish/effects.nix core).tests;
    runtime = (import ./furnish/runtime.nix (core // { inherit pkgs nixpkgs; })).tests;
    observations = observations.resources.tests;
    terminals = observations.terminals.tests;
  };

  program = {
    default = import ./program withPackages;
    bindings = import ./program/bindings.nix withPackages;
    links = import ./program/links.nix withPackages;
    context = import ./program/context.nix withPackages;
    directories = (import ./program/directories.nix core).tests;
    theme-effects = (import ./program/theme-effects.nix withPackages).tests;
    theme-templates = (import ./program/theme-templates.nix withPackages).tests;
    lucid = import ./program/lucid.nix withPackages;
    serpantinum = import ./program/serpantinum.nix withPackages;
  };

  praxis = {
    default = (import ./praxis core).tests;
    graph-effects = (import ./praxis/graph-effects.nix core).tests;
    effects = observations.praxis.tests;
    public-surface = (import ./praxis/public-surface.nix core).tests;
  };

  toml = {
    encoding = import ./toml/encoding.nix { inherit pkgs lexicon; };
    render = import ./toml/render.nix { inherit pkgs lexicon; };
    rendering =
      (import ./toml/rendering.nix {
        inherit lib;
        context = "${pkgs.coreutils}/bin/true";
      }).tests;
  };

  furnish-examples = (import ./furnish-examples.nix examples).tests;
  ownerships-examples = (import ./ownerships-examples.nix examples).tests;
  praxis-examples = (import ./praxis-examples.nix examples).tests;
  program-examples = (import ./program-examples.nix examples).tests;
}
