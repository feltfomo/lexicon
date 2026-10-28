# the workload catalog. a workload is a dotted name mapped to a function from one
# sized context to a finite projection both revisions must produce identically.
# enumeration reads names and limits only, so listing what can run forces no
# case body and needs no lexicon source
let
  sizes = [
    4
    16
    64
  ];

  # a declared workload that can't run yet stays in the catalog, so the report
  # names the gap instead of the workload disappearing
  limits = {
    "fleet.plain" = "fleet.plain waits on the plain host, band 6";
  };

  # a family file returns its cases as one attribute set. its names are read by
  # applying it to a context whose every formal throws, which keeps a family's
  # case set independent of its inputs
  family =
    prefix: path:
    let
      cases = builtins.attrNames (
        import path (
          builtins.mapAttrs (name: _: throw "workload enumeration forced ${name}") (
            builtins.functionArgs (import path)
          )
        )
      );
    in
    builtins.listToAttrs (
      map (case: {
        name = "${prefix}.${case}";
        value = context: (import path context).${case};
      }) cases
    );

  workloads = {
    "fleet.den" = import ./fleet/den.nix;
    "fleet.plain" = _: throw limits."fleet.plain";
  }
  // family "subsystem.declarations" ./subsystem/declarations.nix
  // family "subsystem.ownerships" ./subsystem/ownerships.nix
  // family "subsystem.registry" ./subsystem/registry.nix
  // family "subsystem.furnish" ./subsystem/furnish.nix
  // family "subsystem.praxis" ./subsystem/praxis.nix
  // family "subsystem.theme" ./subsystem/theme.nix
  // family "subsystem.toml" ./subsystem/toml.nix;

  # the vocabulary the ported fixtures share, built once per evaluation
  context =
    {
      project,
      system,
      size,
    }:
    let
      names = builtins.genList (index: "item${toString index}") size;
    in
    {
      inherit
        project
        system
        size
        names
        ;
      inherit (project.inputs.nixpkgs) lib;
      pkgs = project.inputs.nixpkgs.legacyPackages.${system};
      api = project.lib;
      fixtures = ./fixtures;
      records =
        f:
        builtins.listToAttrs (
          map (name: {
            inherit name;
            value = f name;
          }) names
        );
    };

  project =
    {
      project,
      system,
      size,
      name,
    }:
    if !(workloads ? ${name}) then
      throw "unknown benchmark workload ${name}"
    else if !(builtins.elem size sizes) then
      throw "benchmark workload ${name} has no size ${toString size}"
    else
      workloads.${name} (context {
        inherit project system size;
      });

  names = builtins.attrNames workloads;
in
{
  inherit
    project
    limits
    sizes
    names
    ;
  runnable = builtins.filter (name: !(limits ? ${name})) names;
}
