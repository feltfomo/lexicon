{
  lib,
  axiom,
  krisis,
  fields,
  spec,
}:
let
  inherit (fields) diagnostic finish;
  commands =
    spec.commands
    // lib.optionalAttrs spec.check {
      check = [
        "${spec.pkgs.nix}/bin/nix"
        "flake"
        "check"
      ];
    };
  entries =
    kind: declarations:
    lib.mapAttrsToList (name: declaration: {
      inherit name kind declaration;
    }) declarations;
  direct = entries "command" commands ++ entries "task" spec.tasks;
  configured = spec.ownership != null;
  config = finish (
    fields.closed "ownership" "praxis.ownership" {
      roster = {
        required = true;
        onMissing = _: diagnostic "praxis.ownership" "ownership" "roster is required";
      };
      context = {
        required = true;
        onMissing = _: diagnostic "praxis.ownership" "ownership" "context is required";
      };
      scope =
        fields.field "praxis.ownership" "ownership" "scope must be system or user" (
          v:
          builtins.isString v
          && builtins.elem v [
            "system"
            "user"
          ]
        )
        // {
          default = "system";
        };
      engine = {
        default = import ../ownerships { inherit lib axiom krisis; };
      };
    } spec.ownership
  );
  inherit (config) engine;
  claims = lib.genAttrs engine.claimKeys (_: null);
  unitFor =
    entry:
    let
      raw = entry.declaration;
      record = builtins.isAttrs raw;
    in
    lib.optionalAttrs record (builtins.intersectAttrs claims raw)
    // {
      label = "${entry.kind}s.${entry.name}";
      value.entries = [
        (
          entry
          // {
            declaration = if record then removeAttrs raw engine.claimKeys else raw;
          }
        )
      ];
    };
  group =
    raw:
    let
      shape = finish (
        fields.closed "unit" "praxis.units" (
          lib.genAttrs (
            engine.claimKeys
            ++ [
              "label"
              "source"
            ]
          ) (_: { })
          // {
            commands =
              fields.field "praxis.units" "commands" "commands must be an attribute set" builtins.isAttrs
              // {
                default = { };
              };
            tasks = fields.field "praxis.units" "tasks" "tasks must be an attribute set" builtins.isAttrs // {
              default = { };
            };
            children = fields.field "praxis.units" "children" "children must be a list" builtins.isList // {
              default = [ ];
            };
          }
        ) raw
      );
    in
    removeAttrs shape [
      "commands"
      "tasks"
      "children"
    ]
    // {
      children =
        map unitFor (entries "command" shape.commands ++ entries "task" shape.tasks)
        ++ map group shape.children;
    };
  units = map unitFor direct ++ map group spec.units;
  resolver =
    projection:
    engine.resolverFor {
      inherit (config) roster scope;
      inherit projection;
      strict = true;
    };
  resolved = if configured then ((resolver "value") units config.context).entries or [ ] else direct;
  # only names enter the registry; selected declaration bodies stay lazy
  registry = finish (
    axiom.registry.compile {
      registrations = resolved;
      diagnosticsFor =
        entry:
        fields.validation.optional (!fields.name entry.name || entry.name == spec.name) (
          diagnostic "${entry.kind}s.${entry.name}" "command-name"
            "names must be command-style and cannot shadow the dispatcher '${spec.name}'"
        );
      keyOf = entry: entry.name;
      onDuplicate =
        name: _:
        diagnostic "praxis" "duplicate-name" "command or task '${name}' is declared more than once";
    }
  );
  declarations = registry.byKey;
in
{
  inherit declarations;
  availability = {
    names = builtins.attrNames declarations;
    trace = if configured then (resolver "trace") units config.context else null;
    matrix = if configured then (resolver "matrix") { inherit units; } else null;
  };
}
