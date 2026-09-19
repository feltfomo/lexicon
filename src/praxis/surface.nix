{ lib, fields }:
let
  inherit (fields)
    field
    closed
    diagnostic
    validation
    nullable
    ;
  boolean =
    name: default:
    field "praxis" name "${name} must be a boolean" builtins.isBool // { inherit default; };
  attrs =
    name: field "praxis" name "${name} must be an attribute set" builtins.isAttrs // { default = { }; };
  project =
    raw:
    validation.andThen
      (
        spec:
        validation.fromDiagnostics (validation.collect [
          (validation.optional (spec.atRoot && (spec.cwd != null || spec.discoverRoot != null)) (
            diagnostic "praxis" "root-policy" "atRoot cannot be combined with cwd or discoverRoot"
          ))
          (validation.optional (spec.check && (spec.commands ? check || spec.tasks ? check)) (
            diagnostic "praxis" "check-conflict" "choose check = true or your own check declaration"
          ))
          (validation.optional (spec.ownership == null && spec.units != [ ]) (
            diagnostic "praxis.units" "ownership" "units require an ownership configuration"
          ))
        ]) spec
      )
      (
        closed "project" "praxis" {
          pkgs = {
            required = true;
            onMissing = _: diagnostic "praxis" "pkgs" "pkgs is required";
          };
          name = field "praxis" "name" "name must be a command-style name" fields.name // {
            default = "praxis";
          };
          commands = attrs "commands";
          tasks = attrs "tasks";
          check = boolean "check" false;
          atRoot = boolean "atRoot" false;
          wrappers = boolean "wrappers" false;
          perCommand = boolean "perCommand" false;
          devShell = boolean "devShell" false;
          root = {
            default = null;
          };
          cwd = {
            default = null;
          };
          discoverRoot = {
            default = null;
          };
          requireRoot = boolean "requireRoot" false;
          ui = {
            default = { };
          };
          checks =
            field "praxis" "checks" "checks must be a list of distinct command names" (
              v:
              builtins.isList v
              && builtins.all fields.name v
              && builtins.length v == builtins.length (fields.sets.unique v)
            )
            // {
              default = [ ];
            };
          ownership =
            field "praxis" "ownership" "ownership must be an attribute set or null" (nullable builtins.isAttrs)
            // {
              default = null;
            };
          units = field "praxis" "units" "units must be a list" builtins.isList // {
            default = [ ];
          };
        } raw
      );
in
{
  inherit project;
}
