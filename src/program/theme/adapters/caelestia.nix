{ lib }:
let
  capability = import ../capabilities.nix;
in
{
  capabilities = [ capability.blockFiles ];
  dialect = "caelestia";
  templateRoot = ".config/caelestia/templates";
  templateNameOf = entry: "${entry.registrationId}-${entry.placedAs}";
  filesFor =
    {
      pkgs,
      blockId,
      entries,
      templateNameOf,
    }:
    let
      orderedEntries = builtins.sort (
        left: right: builtins.lessThan left.registrationId right.registrationId
      ) entries;
      reloadEntries = builtins.filter (entry: entry.reload != null) orderedEntries;
      homePath =
        entry: path:
        if entry ? compositionHome then
          lib.escapeShellArg "${entry.compositionHome}/${path}"
        else
          ''"$HOME"/${lib.escapeShellArg path}'';
      installCommands = lib.concatMapStringsSep "\n" (entry: ''
        ${pkgs.coreutils}/bin/install -Dm644 \
          ${homePath entry ".local/state/caelestia/theme/${templateNameOf entry}"} \
          ${homePath entry entry.output}
      '') orderedEntries;
      reloadCommands = lib.concatMapStringsSep "\n" (entry: entry.reload) reloadEntries;
    in
    [
      {
        dest = ".config/caelestia/theme-hooks/${blockId}";
        src = pkgs.writeShellScript "caelestia-${blockId}-theme-hook" ''
          set -eu

          ${installCommands}
          ${reloadCommands}
        '';
        provenance = "lexicon/program/theme/adapters/caelestia.nix";
      }
    ];
}
