{
  lib,
  axiom,
  krisis,
  definitions,
}:
let
  problem = krisis.mkDiagnosticFactory {
    severity = "error";
    codePrefix = "bookmarks";
  };
  string = {
    required = true;
    validate = builtins.isString;
    onMissing =
      _:
      problem {
        code = "missing";
        message = "required bookmark field is missing";
      };
    onInvalid =
      _: _:
      problem {
        code = "string";
        message = "bookmark field must be a string";
      };
  };
  entry = definitions.record {
    fields = {
      source = string;
      destination = string;
    };
  };
in
{
  name = "bookmarks";
  ownership = [
    (definitions.mkSetDescriptor {
      name = "role";
      includeKey = "roles";
      excludeKey = "exceptRoles";
      includeOrder = 60;
      excludeOrder = 70;
      allowedScopes = [ "user" ];
      roster = {
        membersField = "roles";
        define = name: {
          kind = "role";
          inherit name;
        };
        project = { declarations, ... }: {
          roles = map (declaration: declaration.name) (
            builtins.filter (declaration: declaration.kind == "role") declarations
          );
        };
      };
    })
  ];
  metadata = [
    {
      name = "tags";
      field = {
        validate = value: builtins.isList value && builtins.all builtins.isString value;
        onInvalid =
          _: _:
          problem {
            code = "tags";
            message = "tags must be strings";
          };
      };
    }
  ];
  blocks = [
    {
      name = "bookmarks";
      scope = "user";
      outputs = [ "resources" ];
      node = definitions.record {
        children.entries = definitions.collection {
          item = entry;
          contextual = true;
        };
      };
      lower = { value, origins, ... }: {
        resources = lib.imap0 (index: entry: {
          kind = "external-link";
          value = entry;
          origin = (builtins.elemAt origins.children.entries index).self;
        }) (value.entries or [ ]);
      };
    }
  ];
}
