{
  description = "Optional Ownerships selection for Praxis";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.lexicon.url = "github:feltfomo/lexicon";

  outputs =
    { nixpkgs, lexicon, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      ownerships = lexicon.lib.ownerships { inherit (nixpkgs) lib; };
      roster = ownerships.toRoster [
        (ownerships.define.host "desk" { system = "x86_64-linux"; })
        (ownerships.define.host "away" { system = "aarch64-linux"; })
        (ownerships.define.user "river" { hosts = [ "desk" ]; })
      ];
      # explicit selection exposes only commands available in this context
      published = lexicon.lib.praxis {
        inherit pkgs;
        ownership = {
          inherit roster;
          scope = "user";
          context = {
            host.id = "x86_64-linux/desk";
            user.name = "river";
          };
        };
        commands = {
          common = [ "${pkgs.coreutils}/bin/true" ];
          local = {
            hosts = [ "desk" ];
            users = [ "river" ];
            command = [ "${pkgs.coreutils}/bin/true" ];
          };
          away = {
            hosts = [ "away" ];
            command = [ "${pkgs.coreutils}/bin/false" ];
          };
        };
        units = [
          {
            hosts = [ "desk" ];
            children = [
              {
                users = [ "river" ];
                commands.review = [ "${pkgs.coreutils}/bin/true" ];
              }
            ];
          }
        ];
      };
      adapters = lexicon.lib.praxisAdapters { inherit (nixpkgs) lib; };
    in
    published.flake
    // {
      lib = {
        inherit (published) availability;
        choices = adapters.fromRoster roster;
        denChoices = adapters.fromDen { inherit roster; };
      };
    };
}
