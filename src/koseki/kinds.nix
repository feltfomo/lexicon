# data. the fold never names anything in this file, so deleting it leaves a
# working engine with an empty registry
{
  lib,
  t,
  field,
}:
let
  inherit (field) describe;

  classOf =
    entity:
    let
      system = entity.system or null;
    in
    if builtins.isString system && lib.hasSuffix "-darwin" system then "darwin" else "linux";

  rootOf =
    parent: name:
    let
      class = if parent == null then "linux" else (parent.class or "linux");
    in
    (if class == "darwin" then "/Users/" else "/home/") + name;

  absolute = value: value == null || lib.hasPrefix "/" value;
in
[
  {
    name = "host";
    collection = "hosts";
    parent = null;
    container = null;
    requirements = [ ];
    fields = map describe [
      {
        name = "system";
        type = t.String;
      }
      {
        name = "class";
        type = t.String;
        dependsOn = [ "system" ];
        derive = { self, ... }: classOf self;
      }
      {
        name = "users";
        type = t.Attrs;
      }
      {
        name = "extra";
        type = t.Attrs;
        default = { };
      }
    ];
  }
  {
    name = "user";
    collection = "users";
    parent = "host";
    container = "users";
    fields = map describe [
      {
        name = "homeRoot";
        type = t.String;
        derive = { self, parent }: rootOf parent self.name;
      }
      {
        name = "runtimeRoot";
        type = t.nullOr t.String;
        default = null;
      }
      {
        name = "shell";
        type = t.nullOr t.String;
        default = null;
      }
      {
        name = "extra";
        type = t.Attrs;
        default = { };
      }
    ];
    requirements = [
      {
        name = "absolute-runtime-root";
        field = "runtimeRoot";
        needs = [ "runtimeRoot" ];
        check = entity: absolute entity.runtimeRoot;
      }
    ];
  }
]
