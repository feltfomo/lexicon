# turns resolved file entries into furnish declarations
# ownership is read before an entry reaches this layer
{
  lib,
  contract,
}:
let
  # home-relative destinations belong only to user principals
  homePrincipals =
    principals: builtins.filter (principal: principal.authority.scope == "user") principals;

  declarationFor =
    filesystemNamespace: principal: source: entry:
    {
      label = entry.label or "${if source.kind == "external" then "links" else "files"}[${entry.dest}]";
      inherit filesystemNamespace;
      inherit (principal) authority;
      # an explicit root supports nonstandard homes without changing current principals
      managedRoot = principal.managedRoot or "/home/${principal.authority.identity}";
      destination = entry.dest;
      # an absent representation retains the original symlink behavior
      representation = entry.representation or contract.capabilities.symlink;
      inherit source;
    }
    # core supplies the default conflict policy after selection
    // lib.optionalAttrs (entry ? onConflict) { inherit (entry) onConflict; }
    // lib.optionalAttrs (entry ? provenance) { provenance.source = entry.provenance; };
in
{
  # emit one declaration per entry and selected user principal
  mkDeclarations =
    {
      filesystemNamespace,
      principals,
      files ? [ ],
      links ? [ ],
    }:
    builtins.concatMap (
      principal:
      map (
        entry:
        declarationFor filesystemNamespace principal {
          kind = "path";
          value = entry.src;
        } entry
      ) files
      ++ map (
        entry:
        declarationFor filesystemNamespace principal {
          kind = "external";
          value = entry.target;
        } entry
      ) links
    ) (homePrincipals principals);
}
