{ krisis, axiom }:
{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
let
  cfg = config.lexicon.theme.composition;
  composition = import ./composition.nix { inherit lib axiom krisis; };
  toml = import ../../toml {
    inherit
      pkgs
      lib
      axiom
      krisis
      ;
  };
  contract = import ../../furnish/contract.nix { inherit lib axiom; };
  furnishFiles = import ../../furnish/files.nix { inherit lib contract; };
  inherit (composition) homeOf;
  groupKey = entry: "${homeOf entry.principal}/${entry.finalOutput}";
  groups = builtins.attrValues (builtins.groupBy groupKey cfg.entries);
  overlaps =
    left: right: left == right || lib.hasPrefix "${left}/" right || lib.hasPrefix "${right}/" left;
  stateRoots = lib.unique (
    map (entry: "${homeOf entry.principal}/.local/state/lexicon/toml") cfg.entries
  );
  publishedPaths = lib.unique (
    map groupKey cfg.entries
    ++ map (entry: "${homeOf entry.principal}/${entry.output}") cfg.ordinary
    ++ map (entry: entry.filesystemIdentity.destination) config.lexicon.furnish.manifestData
  );
  stateAssertions = map (
    root:
    let
      collisions = builtins.filter (overlaps root) publishedPaths;
    in
    {
      assertion = collisions == [ ];
      message = "theme.merge: reserved state directory ${root} overlaps declared outputs: ${lib.concatStringsSep ", " collisions}";
    }
  ) stateRoots;
  ownerOf =
    entries:
    let
      first = builtins.head entries;
      inherit (first) merge;
      base = toml.source "theme-base.toml" merge.base;
      signature =
        entry:
        builtins.toJSON {
          base = toString (toml.source "theme-base.toml" entry.merge.base);
          conflict = entry.merge.conflict or "error";
          arrays = entry.merge.arrays or "replace";
          reload = entry.originalReload;
          inherit (entry.principal) authority;
        };
      output = groupKey first;
      home = homeOf first.principal;
      descriptor = "${home}/${composition.descriptorOf first.finalOutput}";
      state = "${home}/.local/state/lexicon/toml/${composition.idOf first.finalOutput}";
      spec = pkgs.writeText "theme-composition.json" (
        builtins.toJSON {
          inherit output state base;
          conflict = merge.conflict or "error";
          reload = first.originalReload;
          shell = "${pkgs.bash}/bin/bash";
        }
      );
      providers = builtins.groupBy (entry: entry.renderer) entries;
      competingProviders = builtins.filter (renderer: builtins.length providers.${renderer} > 1) (
        builtins.attrNames providers
      );
      firstSignature = signature first;
      conflicts = builtins.filter (entry: signature entry != firstSignature) entries;
      # the publisher owns its destination outside furnish's ledger
      overlapsOutput =
        other: other == output || lib.hasPrefix "${other}/" output || lib.hasPrefix "${output}/" other;
      themeOverlaps = builtins.filter (
        entry: overlapsOutput "${homeOf entry.principal}/${entry.output}"
      ) cfg.ordinary;
      ownerOverlaps = builtins.filter (
        entry: groupKey entry != output && overlapsOutput (groupKey entry)
      ) cfg.entries;
      overlaps = builtins.filter (
        entry:
        let
          dest = entry.filesystemIdentity.destination;
        in
        dest == output || lib.hasPrefix "${dest}/" output || lib.hasPrefix "${output}/" dest
      ) config.lexicon.furnish.manifestData;
    in
    {
      assertions = [
        {
          assertion = competingProviders == [ ];
          message = "theme.merge: ${output} has multiple providers for one renderer: ${lib.concatStringsSep ", " competingProviders}";
        }
        {
          assertion = ownerOverlaps == [ ];
          message = "theme.merge: ${output} overlaps another composed output";
        }
        {
          assertion = first.principal.authority.scope == "user";
          message = "theme.merge requires a user principal";
        }
        {
          assertion = conflicts == [ ];
          message = "theme.merge: conflicting owners of ${output}";
        }
        {
          assertion = themeOverlaps == [ ];
          message = "theme.merge: ${output} overlaps an ordinary theme output";
        }
        {
          assertion = overlaps == [ ];
          message = "theme.merge: ${output} overlaps a Furnish-owned destination";
        }
      ];
      inherit
        first
        spec
        descriptor
        output
        ;
      name = "lexicon-toml-${builtins.substring 0 24 (builtins.hashString "sha256" output)}";
      declarations = furnishFiles.mkDeclarations {
        inherit (first) filesystemNamespace;
        principals = [ first.principal ];
        files = [
          {
            dest = composition.descriptorOf first.finalOutput;
            src = spec;
            provenance = "lexicon/program/theme/composition-runtime.nix";
          }
        ];
      };
    };
  owners = map ownerOf groups;
in
{
  key = "lexicon/program/theme/composition-runtime.nix";
  options.lexicon.theme.composition.ordinary = lib.mkOption {
    type = lib.types.listOf lib.types.attrs;
    default = [ ];
    description = "Ordinary theme outputs checked against composed publishers.";
  };
  options.lexicon.theme.composition.entries = lib.mkOption {
    type = lib.types.listOf lib.types.attrs;
    default = [ ];
    description = "Selected composed TOML outputs and their rendering variants.";
  };
  config = lib.mkIf (cfg.entries != [ ]) {
    assertions = stateAssertions ++ builtins.concatMap (owner: owner.assertions) owners;
    lexicon.furnish.declarations = builtins.concatMap (owner: owner.declarations) owners;
    systemd.services = lib.mkIf config.lexicon.furnish.enable (
      builtins.listToAttrs (
        map (owner: {
          inherit (owner) name;
          value = {
            description = "Publish composed TOML ${owner.output}";
            wantedBy = [ "multi-user.target" ];
            requires = [ "furnish.service" ];
            after = [
              "furnish.service"
              "local-fs.target"
            ];
            unitConfig.RequiresMountsFor = [
              owner.output
              owner.descriptor
            ];
            restartTriggers = [
              owner.spec
              toml.package
            ];
            path = [ pkgs.coreutils ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              User = owner.first.principal.authority.identity;
              ExecStart = utils.escapeSystemdExecArgs [
                "${toml.package}/bin/lexicon-toml"
                "publish"
                owner.descriptor
              ];
            };
          };
        }) owners
      )
    );
  };
}
