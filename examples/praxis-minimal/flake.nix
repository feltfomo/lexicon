{
  description = "A first installed Praxis project";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }: {
    status = "ready";
    detailedStatus = "ready for checks";

    # the installed dispatcher runs the commands this output declares
    praxis =
      { pkgs, root, ... }:
      {
        atRoot = true;
        # the first command evaluates project data without changing the system
        commands.inspect = [
          "nix"
          "eval"
          "--json"
          ".#status"
        ];
      };
  };
}
