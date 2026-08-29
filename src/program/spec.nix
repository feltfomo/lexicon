# every closed key vocabulary a declaration is checked against, and the single
# entry point that turns a raw declaration into a validated, theme-elaborated
# one. the vocabularies are closed, so an unknown key is a typo: each is named
# on its own with the nearest legal key rather than collapsed into one joined
# message.
{
  lib,
  axiom,
  contract,
  fields,
  claimKeys,
  problem,
  reporter,
  suggestionFor,
  themeFields,
  themeSharedFields,
  themeTemplateErrors,
  elaborateTheme,
}:
let
  inherit (reporter) checked;
  inherit (fields)
    lifecycleKeys
    unknownFields
    validBaseName
    validRelativePath
    labeled
    requiredLabeled
    optionalLabeled
    nonEmptyString
    ;

  conflictPolicies = builtins.attrValues contract.conflictPolicies;
  declaredPolicy = value: builtins.isString value && builtins.elem value conflictPolicies;

  specFields = claimKeys ++ [
    "pkg"
    "nixos"
    "imports"
    "files"
    "directories"
    "theme"
  ];
  fileFields =
    claimKeys
    ++ [
      "dest"
      "src"
      "label"
    ]
    ++ lifecycleKeys;
  directoryFields =
    claimKeys
    ++ [
      "src"
      "dest"
      "exclude"
      "files"
    ]
    ++ lifecycleKeys;
  directoryRuleFields = claimKeys ++ [ "names" ] ++ lifecycleKeys;

  specSchema = axiom.schema.compile {
    onRecord =
      _value:
      problem {
        code = "spec-shape";
        message = "declaration must be an attribute set";
      };
    onUnknown =
      name: _value:
      problem {
        code = "spec-fields";
        message = "declaration has unknown field ${name}${suggestionFor specFields name}";
      };
    order = specFields;
    fields = lib.genAttrs claimKeys (_: { }) // {
      pkg = {
        validate = builtins.isFunction;
        onInvalid =
          _spec: _value:
          problem {
            code = "pkg-shape";
            message = "pkg must be a function";
          };
      };
      # a slice list that needs nothing from the build is just a list, and a
      # single slice is just that slice. forcing every declaration through a
      # function meant writing `_: [ ... ]` to say nothing.
      nixos = {
        validate = value: builtins.isFunction value || builtins.isList value || builtins.isAttrs value;
        onInvalid =
          _spec: value:
          problem {
            code = "nixos-shape";
            message = "nixos must be a function, a list of units, or a single unit; got ${builtins.typeOf value}";
          };
      };
      imports = {
        validate = builtins.isList;
        onInvalid =
          _spec: _value:
          problem {
            code = "imports-shape";
            message = "imports must be a list";
          };
      };
      files = {
        validate = builtins.isList;
        onInvalid =
          _spec: _value:
          problem {
            code = "files-shape";
            message = "files must be a list";
          };
      };
      directories = {
        validate = builtins.isList;
        onInvalid =
          _spec: _value:
          problem {
            code = "directories-shape";
            message = "directories must be a list";
          };
      };
      theme = {
        validate = builtins.isAttrs;
        onInvalid =
          _spec: _value:
          problem {
            code = "theme-shape";
            message = "theme must be an attribute set";
          };
      };
    };
  };

  fileSchema =
    subject:
    axiom.schema.compile {
      onRecord = _value: labeled subject "file-entry-shape" "must be an attribute set";
      onUnknown =
        name: _value:
        labeled subject "file-fields" "has unknown field ${name}${suggestionFor fileFields name}";
      order = fileFields;
      fields = lib.genAttrs claimKeys (_: { }) // {
        dest = requiredLabeled subject "file-destination" "dest must be a non-empty string" nonEmptyString;
        src = {
          required = true;
          onMissing = _entry: labeled subject "file-source" "src is required";
        };
        label = optionalLabeled subject "file-label" "label must be a string" builtins.isString;
        representation =
          optionalLabeled subject "file-representation" "representation must be a non-empty string"
            nonEmptyString;
        onConflict =
          optionalLabeled subject "file-conflict-policy" "onConflict must be a declared conflict policy"
            declaredPolicy;
        provenance =
          optionalLabeled subject "file-provenance" "provenance must be a string"
            builtins.isString;
      };
    };

  directorySchema =
    subject:
    axiom.schema.compile {
      onRecord = _value: labeled subject "directory-entry-shape" "must be an attribute set";
      onUnknown =
        name: _value:
        labeled subject "directory-fields" "has unknown field ${name}${suggestionFor directoryFields name}";
      order = directoryFields;
      fields = lib.genAttrs claimKeys (_: { }) // {
        src = {
          required = true;
          validate = value: builtins.isPath value || builtins.isString value;
          onMissing = _entry: labeled subject "directory-source" "src is required";
          onInvalid = _entry: _value: labeled subject "directory-source-shape" "src must be a path or string";
        };
        dest =
          requiredLabeled subject "directory-destination" "dest must be a non-empty string"
            nonEmptyString;
        exclude = {
          validate = value: builtins.isList value && builtins.all validRelativePath value;
          onInvalid =
            _entry: value:
            if !builtins.isList value then
              labeled subject "directory-exclude-shape" "exclude must be a list"
            else
              labeled subject "directory-exclude-name" "exclude must contain normalized relative paths";
        };
        files = optionalLabeled subject "directory-files-shape" "files must be a list" builtins.isList;
        representation =
          optionalLabeled subject "directory-representation" "representation must be a non-empty string"
            nonEmptyString;
        onConflict =
          optionalLabeled subject "directory-conflict-policy" "onConflict must be a declared conflict policy"
            declaredPolicy;
        provenance =
          optionalLabeled subject "directory-provenance" "provenance must be a string"
            builtins.isString;
      };
    };

  directoryRuleSchema =
    subject:
    axiom.schema.compile {
      onRecord = _value: labeled subject "directory-file-shape" "entries must be attribute sets";
      onUnknown =
        name: _value:
        labeled subject "directory-file-fields"
          "has unknown field ${name}${suggestionFor directoryRuleFields name}";
      order = directoryRuleFields;
      fields = lib.genAttrs claimKeys (_: { }) // {
        names = {
          required = true;
          validate = value: builtins.isList value && value != [ ] && builtins.all validRelativePath value;
          onMissing = _entry: labeled subject "directory-file-names" "names must be a non-empty list";
          onInvalid =
            _entry: value:
            if !builtins.isList value || value == [ ] then
              labeled subject "directory-file-names" "names must be a non-empty list"
            else
              labeled subject "directory-file-name" "names must contain normalized relative paths";
        };
        representation =
          optionalLabeled subject "directory-file-representation" "representation must be a non-empty string"
            nonEmptyString;
        onConflict =
          optionalLabeled subject "directory-file-conflict-policy"
            "onConflict must be a declared conflict policy"
            declaredPolicy;
        provenance =
          optionalLabeled subject "directory-file-provenance" "provenance must be a string"
            builtins.isString;
      };
    };

  # the theme block accepts either one inline template or a templates list, and
  # the two spellings cannot be mixed. the single-template form is normalized
  # into a one-element list here so the compiler only sees one shape.
  themeErrorsFor =
    spec:
    let
      themeIsAttrs = !(spec ? theme) || builtins.isAttrs spec.theme;
      theme = if themeIsAttrs && spec ? theme then spec.theme else { };
      unknownTheme = if themeIsAttrs && spec ? theme then unknownFields themeFields theme else [ ];
      hasTemplates = theme ? templates;
      rawTemplates =
        if !themeIsAttrs || !(spec ? theme) then
          [ ]
        else if hasTemplates && builtins.isList theme.templates then
          theme.templates
        else if hasTemplates then
          [ ]
        else
          [ (removeAttrs theme [ "id" ]) ];
      mixedThemeFields = builtins.filter (
        name: builtins.elem name (themeSharedFields ++ [ "renderers" ])
      ) (builtins.attrNames theme);
    in
    {
      inherit themeIsAttrs theme;
      errors =
        lib.optional (unknownTheme != [ ]) (problem {
          code = "theme-fields";
          message = "theme has unknown fields: ${lib.concatStringsSep ", " unknownTheme}";
        })
        ++ lib.optionals (themeIsAttrs && spec ? theme) (
          lib.optional (!(theme ? id) || !validBaseName theme.id) (problem {
            code = "theme-id";
            message = "theme.id must be a normalized non-empty name";
          })
          ++ lib.optional (hasTemplates && !builtins.isList theme.templates) (problem {
            code = "theme-templates-shape";
            message = "theme.templates must be a list";
          })
          ++ lib.optional (hasTemplates && mixedThemeFields != [ ]) (problem {
            code = "theme-mixed-syntax";
            message = "theme cannot mix templates with single-template fields: ${lib.concatStringsSep ", " mixedThemeFields}";
          })
          ++ builtins.concatMap (
            indexed: themeTemplateErrors ("theme.templates[" + toString indexed.index + "]") indexed.template
          ) (lib.imap0 (index: template: { inherit index template; }) rawTemplates)
        );
    };

  validateSpec =
    spec:
    if !builtins.isAttrs spec then
      checked [
        (problem {
          code = "spec-shape";
          message = "declaration must be an attribute set";
        })
      ] spec
    else
      let
        themed = themeErrorsFor spec;
        elaborated =
          if spec ? theme && themed.themeIsAttrs then
            spec // { theme = elaborateTheme themed.theme; }
          else
            spec;
      in
      checked ((specSchema spec).diagnostics ++ themed.errors) elaborated;

  fileErrors =
    files:
    builtins.concatMap (
      indexed: (fileSchema ("files[" + toString indexed.index + "]") indexed.entry).diagnostics
    ) (lib.imap0 (index: entry: { inherit index entry; }) files);

  # the subject string is concatenated rather than interpolated so the closing
  # bracket stays out of the interpolation.
  subjectAt = index: "directories[" + toString index + "]";

  directoryShapeErrors =
    wrapped: (directorySchema (subjectAt wrapped.index) wrapped.entry).diagnostics;

  directoryRuleErrors =
    wrapped: (directoryRuleSchema (subjectAt wrapped.index + ".files") wrapped.entry).diagnostics;
in
{
  inherit
    specFields
    fileFields
    directoryFields
    directoryRuleFields
    validateSpec
    fileErrors
    directoryShapeErrors
    directoryRuleErrors
    ;
}
