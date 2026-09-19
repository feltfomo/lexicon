{
  description = "Praxis commands published as flake outputs";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.lexicon.url = "github:feltfomo/lexicon";

  outputs =
    { nixpkgs, lexicon, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      # one declaration, written once and used by both surfaces below
      declaration = {
        commands.greet = [
          "${pkgs.coreutils}/bin/printf"
          "hi from praxis\n"
        ];
        # publish-time fields: read while lexicon.lib.praxis compiles this
        # declaration, ignored by the installed command
        perCommand = true;
        checks = [ "greet" ];
      };
      published = lexicon.lib.praxis ({ inherit pkgs; } // declaration);
    in
    published.flake
    // {
      # the installed dispatcher reads this output; the published packages,
      # apps, and checks serve everyone who does not have Praxis installed
      praxis = _: declaration;
    };
}
