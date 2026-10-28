# a skadi-shaped fleet through den v0.19.0. size hosts each carry the same two
# users, and the aspects use includes, batteries, a quirk and lexicon
# declarations with files, links, directories, a theme and ownership units. the
# projection is each host's furnish manifest and each user's home manager file
# names, never a toplevel derivation
{
  api,
  lib,
  names,
  project,
  fixtures,
  ...
}:
let
  # pinned by hash in the workload rather than as a flake input, so consumers of
  # lexicon never inherit den or home manager
  den = import (
    builtins.fetchTree {
      type = "github";
      owner = "denful";
      repo = "den";
      rev = "37eb88ce28a9e42d5b367b967a9097030ff4f665";
      narHash = "sha256-QTPzBJpxfetqU3u29+tQev8SlAC6EaRvHks0+FHAclY=";
    }
    + "/nix"
  );
  homeManager = builtins.fetchTree {
    type = "github";
    owner = "nix-community";
    repo = "home-manager";
    rev = "ec80131710bffcdf3b8498cf41f3a0579833b023";
    narHash = "sha256-TyoYH983Nsc++1scw0SoOEKshPSJWJDxK7tTmuZ974M=";
  };

  inputs = {
    inherit den;
    inherit (project.inputs) nixpkgs;
    home-manager.nixosModules.home-manager = import (homeManager + "/nixos");
  };

  users = [
    "river"
    "ash"
  ];

  furnishRuntime = api.furnishRuntime { };

  schema = {
    den.schema.user.classes = lib.mkDefault [ "homeManager" ];
    den.quirks.persistence.description = "paths feature aspects ask the host to keep";
    den.default = {
      nixos = {
        fileSystems."/".device = "/dev/fake";
        fileSystems."/".fsType = "auto";
        boot.loader.grub.enable = false;
        documentation.enable = false;
        system.stateVersion = "25.11";
      };
      homeManager.home.stateVersion = "25.11";
    };
    den.hosts.x86_64-linux = lib.genAttrs names (_: {
      users = lib.genAttrs users (_: { });
    });
  };

  features =
    { den, ... }:
    let
      lexicon = api.lexicon.forDen { inherit den; };
    in
    {
      den.aspects = {
        # the quirk consumer, shaped like skadi's impermanence aspect
        keep.nixos =
          { persistence, ... }:
          {
            imports = [ furnishRuntime ];
            lexicon.furnish.enable = true;
            environment.etc."kept".text = lib.concatStringsSep "\n" (
              lib.concatMap (entry: entry.directories or [ ]) persistence
            );
          };

        greeter = {
          persistence.directories = [ "/var/lib/greeter" ];
          nixos.services.getty.helpLine = "fleet";
        };

        workstation.includes = [
          den.aspects.greeter
          den.aspects.keep
        ];

        editor = lexicon {
          package = pkgs: pkgs.hello;
          furnish = {
            directories = [
              {
                source = fixtures + "/directory";
                destination = ".config/editor";
              }
            ];
            files = [
              {
                source = fixtures + "/directory/default.nix";
                destination = ".config/editor/init.nix";
                hosts = [ (builtins.head names) ];
              }
            ];
            links = [
              {
                source = "/srv/shared";
                names = [
                  "notes"
                  "books"
                ];
                destinations = [
                  ".local/share/editor"
                  ".cache/editor"
                ];
              }
            ];
          };
          theme = {
            id = "editor";
            output = ".config/editor/palette.nix";
            renderers.dms.source = fixtures + "/directory/safe-render.nix";
          };
          nixos = [
            { value.environment.variables.EDITOR = "hello"; }
            {
              hosts = [ (builtins.head names) ];
              value.environment.variables.FIRST = "1";
            }
          ];
        };
      };
    };

  members =
    { den, ... }:
    {
      den.aspects =
        lib.genAttrs users (user: {
          includes = [
            den.batteries.define-user
            den.aspects.editor
          ];
          homeManager.home.sessionVariables.FLEET_USER = user;
        })
        // lib.genAttrs names (_: {
          includes = [ den.aspects.workstation ];
        });
    };

  evaluation = lib.evalModules {
    specialArgs = { inherit inputs; };
    modules = [
      den.flakeModule
      features
      members
      schema
    ];
  };

  hosts = evaluation.config.flake.nixosConfigurations;
in
map (
  name:
  let
    inherit (hosts.${name}) config;
  in
  {
    inherit name;
    manifest = map (entry: {
      inherit (entry.filesystemIdentity) destination;
      inherit (entry) representation;
    }) config.lexicon.furnish.manifestData;
    homes = lib.genAttrs users (user: builtins.attrNames config.home-manager.users.${user}.home.file);
  }
) names
