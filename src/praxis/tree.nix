{ lib, fields }:
{
  lookup =
    results: path:
    let
      parts = lib.splitString "." path;
    in
    lib.foldl' (
      node: part:
      if node == null then
        null
      else if node.diagnostics != [ ] then
        node
      else
        node.value.children.${part} or null
    ) (results.${builtins.head parts} or null) (builtins.tail parts);

  group =
    name: declarations: lower:
    fields.effects.fromDiagnostics
      (lib.concatMap (
        child:
        lib.optional (!fields.name child) (
          fields.diagnostic "commands.${name}.${child}" "command-name"
            "subcommand names must be command-style names"
        )
      ) (builtins.attrNames declarations))
      {
        description = "Run ${name} subcommands";
        children = lib.mapAttrs (child: declaration: lower "${name}.${child}" declaration) declarations;
      };
}
