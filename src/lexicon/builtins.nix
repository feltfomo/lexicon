{
  lib,
  axiom,
  krisis,
  definitions,
  resources,
  systemOwner,
}:
let
  report = import ../declarations/report.nix { inherit lib axiom krisis; };
  inherit (definitions)
    record
    collection
    recordMap
    native
    value
    ;
  payload =
    owner:
    native {
      inherit owner;
      validate = v: builtins.isAttrs v || builtins.isFunction v;
    };
  resource = kind: entry: origin: prepared: {
    inherit kind origin prepared;
    value = entry;
  };
  furnished = record {
    children = {
      files = collection {
        contextual = true;
        item = record { fields = resources.schemas.file; };
      };
      links = collection {
        contextual = true;
        item = record { fields = resources.schemas."external-link"; };
      };
      directories = collection {
        contextual = true;
        item = record {
          fields = resources.schemas.directory;
          prepare = resources.prepareDirectory;
          children.files = collection { item = record { fields = resources.schemas.rule; }; };
        };
      };
    };
  };
  themeFields = lib.genAttrs [
    "source"
    "output"
    "subdir"
    "placedAs"
    "subId"
    "reload"
    "native"
    "merge"
  ] (_: { });
  renderer = record {
    fields = themeFields // {
      sharedWith = { };
    };
  };
  prepareTheme = { structure, ... }: {
    rendererCount = builtins.length (builtins.attrNames (structure.renderers or { }));
  };
  template = record {
    prepare = prepareTheme;
    fields = themeFields;
    children.renderers = recordMap {
      item = renderer;
      key = _: true;
    };
  };
  themeNode = record {
    prepare = prepareTheme;
    fields = themeFields // {
      id = {
        required = true;
        validate = resources.fields.validBaseName;
        onMissing = _: {
          severity = "error";
          code = "lexicon/theme-id";
          message = "theme.id is required";
        };
        onInvalid = _: _: {
          severity = "error";
          code = "lexicon/theme-id";
          message = "theme.id must be a normalized name";
        };
      };
    };
    children = {
      renderers = recordMap {
        item = renderer;
        key = _: true;
      };
      templates = collection { item = template; };
    };
  };

in
[
  {
    name = "package";
    scope = "user";
    outputs = [ "homeManager" ];
    node = value (report.field [ ] "package" builtins.isFunction);
    lower =
      {
        value,
        origins,
        context,
        ...
      }:
      {
        homeManager = [
          {
            origin = origins;
            module = {
              home.packages = [ (value context.pkgs) ];
            };
          }
        ];
      };
  }
  {
    name = "homeManager";
    scope = "user";
    outputs = [ "homeManager" ];
    node = payload "Home Manager";
    lower =
      {
        value,
        context,
        origins,
        ...
      }:
      {
        homeManager = [
          {
            origin = origins;
            module =
              if lib.isFunction value then
                lib.setFunctionArgs (args: value (args // { inherit (context) host user; })) (
                  removeAttrs (lib.functionArgs value) [
                    "host"
                    "user"
                  ]
                )
              else
                value;
          }
        ];
      };
  }
  systemOwner.block
  {
    name = "furnish";
    scope = "user";
    outputs = [ "resources" ];
    node = furnished;
    resourceIntent =
      structure:
      builtins.any
        (name: builtins.isFunction (structure.${name} or null) || (structure.${name} or [ ]) != [ ])
        [
          "files"
          "links"
          "directories"
        ];
    lower =
      {
        value,
        origins,
        prepared,
        ...
      }:
      {
        resources =
          builtins.concatMap
            (
              name:
              lib.imap0 (
                index: entry:
                let
                  p = builtins.elemAt prepared.children.${name} index;
                in
                resource
                  {
                    files = "file";
                    links = "external-link";
                    directories = "directory";
                  }
                  .${name}
                  entry
                  (builtins.elemAt origins.children.${name} index).self
                  (
                    p.self
                    // lib.optionalAttrs (name == "directories") {
                      ruleOrigins = (builtins.elemAt origins.children.${name} index).children.files or [ ];
                    }
                  )
              ) (value.${name} or [ ])
            )
            [
              "files"
              "links"
              "directories"
            ];
      };
  }
  {
    name = "theme";
    scope = "user";
    outputs = [ "resources" ];
    node = themeNode;
    resourceIntent =
      structure:
      if structure ? templates && builtins.isList structure.templates && structure.templates == [ ] then
        report.checked (
          lib.optional (!resources.fields.validBaseName (structure.id or null)) (
            report.at [ "theme" "id" ] "theme-id" "theme.id must be a normalized nonempty name"
          )
          ++ lib.optional (builtins.any (name: structure ? ${name}) (
            builtins.attrNames themeFields ++ [ "renderers" ]
          )) (report.at [ "theme" ] "theme-mixed-syntax" "theme cannot mix templates with inline fields")
        ) false
      else
        true;
    lower =
      {
        value,
        origins,
        prepared,
        ...
      }:
      let
        templates = value.templates or [ (removeAttrs value [ "id" ]) ];
        templateOrigins = if value ? templates then origins.children.templates else [ origins ];
        templatePrepared = if value ? templates then prepared.children.templates else [ prepared ];
        mixed =
          value ? templates
          && builtins.any (name: value ? ${name}) (builtins.attrNames themeFields ++ [ "renderers" ]);
        errors =
          lib.optional mixed (
            report.at origins.self "theme-mixed-syntax" "theme cannot mix templates with inline template fields"
          )
          ++ builtins.concatLists (
            lib.imap0 (
              index: template:
              if
                template ? renderers
                && template.renderers == { }
                && (builtins.elemAt templatePrepared index).self.rendererCount > 0
              then
                [ ]
              else
                resources.theme.themeTemplateErrors (krisis.renderPath (builtins.elemAt templateOrigins index).self) template
            ) templates
          );
        checked = report.checked errors templates;
        entries = builtins.concatMap (
          renderer:
          builtins.concatLists (
            lib.imap0 (
              index: template:
              builtins.concatMap (
                declared:
                let
                  override = template.renderers.${declared};
                  matches = builtins.elem renderer ([ declared ] ++ (override.sharedWith or [ ]));
                  origin = (builtins.elemAt templateOrigins index).children.renderers.${declared}.self;
                in
                lib.optional matches (
                  let
                    effective = removeAttrs template [ "renderers" ] // removeAttrs override [ "sharedWith" ];
                  in
                  resource "theme"
                    {
                      inherit renderer;
                      blockId = value.id;
                      entry = effective;
                    }
                    origin
                    {
                      fieldOrigins = lib.genAttrs (builtins.attrNames effective) (
                        name:
                        (if override ? ${name} then origin else (builtins.elemAt templateOrigins index).self) ++ [ name ]
                      );
                    }
                )
              ) (builtins.attrNames (template.renderers or { }))
            ) checked
          )
        ) resources.theme.themeBackends;
      in
      {
        resources = entries;
      };
  }
]
