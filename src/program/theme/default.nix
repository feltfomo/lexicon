{
  lib,
  axiom,
  krisis,
  contract,
  unknownFields,
  validRelativePath,
  validBaseName,
  validSubdir,
  duplicateValues,
  problem,
  reporter,
}:
let
  capability = import ./capabilities.nix;
  markers = import ./markers.nix;
  inherit (krisis) effects;
  inherit (effects.native) validation;

  declares = name: adapter: (axiom.requirements.evaluate [ name ] adapter.capabilities).satisfied;

  entryProblem =
    subject: code: message:
    problem {
      inherit code message;
      primary.label = subject;
    };

  adapters = import ./adapters { inherit lib; };
  dialects = import ./dialects.nix { inherit lib; };
  template = import ./template.nix { inherit lib; };
  themeBackends = builtins.attrNames adapters;
  themeValueFields = [
    "source"
    "template"
    "transform"
    "output"
    "subdir"
    "placedAs"
    "subId"
    "reload"
    "native"
    "merge"
  ];
  themeSharedFields = themeValueFields;
  themeRendererFields = themeSharedFields ++ [ "sharedWith" ];
  themeFields = [
    "id"
    "renderers"
    "templates"
  ]
  ++ themeValueFields;
  themeEntryFields = (lib.remove "template" themeSharedFields) ++ [ "syntax" ];

  # an entry carries one source. a portable template becomes that source tagged with its
  # syntax, and the innermost layer that names a source decides which kind it is.
  effectiveEntry =
    base: override:
    let
      chosen =
        if override ? source then
          removeAttrs base [ "template" ]
        else if override ? template then
          removeAttrs base [ "source" ]
        else
          base;
      merged = chosen // removeAttrs override [ "sharedWith" ];
    in
    if merged ? template then
      removeAttrs merged [ "template" ]
      // {
        source = merged.template;
        syntax = "portable";
      }
    else
      merged;

  knownShellsNote = "known shells: ${lib.concatStringsSep ", " themeBackends}";

  editDistance =
    left: right:
    let
      leftChars = lib.stringToCharacters left;
      rightChars = lib.stringToCharacters right;
      rightLength = builtins.length rightChars;
      initialRow = lib.range 0 rightLength;
      nextRow =
        previous: indexed:
        if rightLength == 0 then
          [ (indexed.index + 1) ]
        else
          lib.foldl' (
            row: rightIndex:
            let
              insertion = lib.last row + 1;
              deletion = builtins.elemAt previous (rightIndex + 1) + 1;
              substitution =
                builtins.elemAt previous rightIndex
                + (if indexed.char == builtins.elemAt rightChars rightIndex then 0 else 1);
            in
            row ++ [ (lib.min insertion (lib.min deletion substitution)) ]
          ) [ (indexed.index + 1) ] (lib.range 0 (rightLength - 1));
      finalRow = lib.foldl' nextRow initialRow (
        lib.imap0 (index: char: { inherit index char; }) leftChars
      );
    in
    lib.last finalRow;

  nearestShell =
    value:
    let
      scored = map (name: {
        inherit name;
        distance = editDistance value name;
      }) themeBackends;
      nearest = lib.foldl' (
        best: candidate: if candidate.distance < best.distance then candidate else best
      ) (builtins.head scored) (builtins.tail scored);
    in
    if nearest.distance <= 2 then nearest.name else null;

  unknownShellProblem =
    subject: shell:
    let
      suggestion = nearestShell shell;
    in
    problem (
      {
        code = "theme-renderer-unknown";
        message = "unknown shell \"${shell}\"";
        primary.label = subject;
        notes = [ knownShellsNote ];
      }
      // lib.optionalAttrs (suggestion != null) { help = "did you mean \"${suggestion}\"?"; }
    );

  sharedShellsOf =
    override:
    if builtins.isAttrs override && override ? sharedWith && builtins.isList override.sharedWith then
      builtins.filter builtins.isString override.sharedWith
    else
      [ ];

  targetsForRenderer = renderer: override: lib.unique ([ renderer ] ++ sharedShellsOf override);

  sourceConflictProblem =
    subject:
    problem {
      code = "theme-template-source-conflict";
      message = "cannot set both source and template";
      primary.label = subject;
    };

  effectiveEntryErrors =
    subject: effective:
    lib.optional (!(effective ? source) || !(effective ? output)) (problem {
      code = "theme-renderer-incomplete";
      message = "effective renderer settings must define source and output, or template and output";
      primary.label = subject;
    })
    ++
      lib.optional
        (
          (effective.syntax or null) == "portable"
          && effective ? source
          && builtins.isString effective.source
          && !(effective ? placedAs)
        )
        (problem {
          code = "theme-template-name";
          message = "a template given as a string needs placedAs";
          primary.label = subject;
        })
    ++ lib.optional (effective ? transform && (effective.syntax or null) != "portable") (problem {
      code = "theme-transform-source";
      message = "transform only applies to a template";
      primary.label = subject;
    });

  themeTemplateErrors =
    subject: template:
    if !builtins.isAttrs template then
      [
        (problem {
          code = "theme-template-shape";
          message = "must be an attribute set";
          primary.label = subject;
        })
      ]
    else
      let
        unknownTemplate = unknownFields (themeSharedFields ++ [ "renderers" ]) template;
        portable = template ? template;
        renderers =
          if template ? renderers && builtins.isAttrs template.renderers then template.renderers else { };
        rendererNames = builtins.attrNames renderers;
        shared = removeAttrs template [ "renderers" ];
        unknownRendererErrors = map (
          renderer: unknownShellProblem "${subject}.renderers.${renderer}" renderer
        ) (builtins.filter (name: !(builtins.elem name themeBackends)) rendererNames);
        rendererErrors = builtins.concatMap (
          renderer:
          let
            override = renderers.${renderer};
            rendererSubject = "${subject}.renderers.${renderer}";
            unknownOverride =
              if builtins.isAttrs override then unknownFields themeRendererFields override else [ ];
            sharedWith = if builtins.isAttrs override then override.sharedWith or [ ] else [ ];
            sharedIsList = builtins.isList sharedWith;
            sharedStrings = if sharedIsList then builtins.filter builtins.isString sharedWith else [ ];
            duplicateShared = duplicateValues sharedStrings;
            unknownShared = builtins.filter (name: !(builtins.elem name themeBackends)) sharedStrings;
          in
          lib.optional (!builtins.isAttrs override) (problem {
            code = "theme-renderer-shape";
            message = "must be an attribute set";
            primary.label = rendererSubject;
          })
          ++ lib.optionals (builtins.isAttrs override) (
            lib.optional (unknownOverride != [ ]) (problem {
              code = "theme-renderer-fields";
              message = "has unknown fields: ${lib.concatStringsSep ", " unknownOverride}";
              primary.label = rendererSubject;
            })
            ++ lib.optional (!sharedIsList) (problem {
              code = "theme-renderer-shared-shape";
              message = "sharedWith must be a list of shell names";
              primary.label = "${rendererSubject}.sharedWith";
            })
            ++
              lib.optional (sharedIsList && builtins.length sharedStrings != builtins.length sharedWith)
                (problem {
                  code = "theme-renderer-shared-name";
                  message = "sharedWith must contain only shell-name strings";
                  primary.label = "${rendererSubject}.sharedWith";
                })
            ++ lib.optional (duplicateShared != [ ]) (problem {
              code = "theme-renderer-shared-duplicate";
              message = "sharedWith repeats shells: ${lib.concatStringsSep ", " duplicateShared}";
              primary.label = "${rendererSubject}.sharedWith";
            })
            ++ lib.optional (builtins.elem renderer sharedStrings) (problem {
              code = "theme-renderer-shared-self";
              message = "a renderer cannot share with itself";
              primary.label = "${rendererSubject}.sharedWith";
            })
            ++ map (shell: unknownShellProblem "${rendererSubject}.sharedWith" shell) unknownShared
            ++ lib.optional (override ? source && override ? template) (sourceConflictProblem rendererSubject)
            ++ effectiveEntryErrors rendererSubject (effectiveEntry shared override)
          )
        ) rendererNames;
        assignments = builtins.concatMap (
          renderer:
          map (shell: { inherit renderer shell; }) (targetsForRenderer renderer renderers.${renderer})
        ) rendererNames;
        overlapErrors =
          (axiom.registry.compile {
            registrations = builtins.filter (
              assignment: builtins.elem assignment.shell themeBackends
            ) assignments;
            keyOf = assignment: assignment.shell;
            onDuplicate =
              shell: owners:
              let
                ownerNames = map (owner: owner.renderer) owners;
                firstOwner = builtins.head ownerNames;
              in
              problem {
                code = "theme-renderer-overlap";
                message = "shell ${shell} is assigned by multiple renderer declarations";
                primary.label = "${subject}.renderers.${firstOwner}";
                secondaryLabels = map (owner: {
                  label = "${subject}.renderers.${owner}";
                  message = "also assigns ${shell}";
                }) (builtins.tail ownerNames);
                help = "keep ${shell} in exactly one renderer declaration";
              };
          }).diagnostics;
      in
      lib.optional (unknownTemplate != [ ]) (problem {
        code = "theme-template-fields";
        message = "has unknown fields: ${lib.concatStringsSep ", " unknownTemplate}";
        primary.label = subject;
      })
      ++ lib.optional (template ? source && portable) (sourceConflictProblem subject)
      ++
        lib.optional (if template ? renderers then !builtins.isAttrs template.renderers else !portable)
          (problem {
            code = "theme-renderers-shape";
            message = "renderers must be an attribute set";
            primary.label = subject;
          })
      ++
        lib.optional
          (!portable && template ? renderers && builtins.isAttrs template.renderers && rendererNames == [ ])
          (problem {
            code = "theme-renderers-empty";
            message = "renderers must select at least one renderer";
            primary.label = subject;
          })
      ++ lib.optionals portable (effectiveEntryErrors subject (effectiveEntry shared { }))
      ++ unknownRendererErrors
      ++ rendererErrors
      ++ overlapErrors;

  themeEntrySchema =
    subject: fieldOrigins:
    let
      fieldAt = name: fieldOrigins.${name} or "${subject}.${name}";
    in
    axiom.schema.compile {
      onRecord = _value: entryProblem subject "theme-entry-shape" "must be an attribute set";
      onUnknown = name: _value: entryProblem subject "theme-entry-fields" "has unknown field ${name}";
      order = themeEntryFields;
      fields = {
        source = {
          required = true;
          validate = value: builtins.isPath value || builtins.isString value;
          onMissing =
            _entry: entryProblem (fieldAt "source") "theme-source" "source must be a path or string";
          onInvalid =
            _entry: _value: entryProblem (fieldAt "source") "theme-source" "source must be a path or string";
        };
        output = {
          required = true;
          validate = validRelativePath;
          onMissing =
            _entry: entryProblem (fieldAt "output") "theme-output" "output must be a normalized relative path";
          onInvalid =
            _entry: _value:
            entryProblem (fieldAt "output") "theme-output" "output must be a normalized relative path";
        };
        subdir = {
          validate = value: value == null || validSubdir value;
          onInvalid =
            _entry: _value:
            entryProblem (fieldAt "subdir") "theme-subdir"
              "subdir must be null, empty, or a normalized relative directory";
        };
        placedAs = {
          validate = validBaseName;
          onInvalid =
            _entry: _value:
            entryProblem (fieldAt "placedAs") "theme-placed-name" "placedAs must be a normalized basename";
        };
        subId = {
          validate = value: value == null || validBaseName value;
          onInvalid =
            _entry: _value:
            entryProblem (fieldAt "subId") "theme-sub-id" "subId must be null or a normalized non-empty name";
        };
        reload = {
          validate = value: value == null || builtins.isString value;
          onInvalid =
            _entry: _value: entryProblem (fieldAt "reload") "theme-reload" "reload must be null or a string";
        };
        merge = {
          validate =
            value:
            builtins.isAttrs value
            && (value.format or null) == "toml"
            && value ? base
            && builtins.all (
              key:
              builtins.elem key [
                "format"
                "base"
                "conflict"
                "arrays"
              ]
            ) (builtins.attrNames value)
            && builtins.elem (value.conflict or "error") [
              "error"
              "first"
              "last"
            ]
            && (value.arrays or "replace") == "replace";
          onInvalid =
            _entry: _value:
            entryProblem (fieldAt "merge") "theme-merge"
              "merge requires format=toml, base, conflict=error|first|last and arrays=replace";
        };
        native = {
          validate = builtins.isAttrs;
          onInvalid =
            _entry: _value: entryProblem (fieldAt "native") "theme-native" "native must be an attribute set";
        };
        transform = {
          validate = builtins.isFunction;
          onInvalid =
            _entry: _value: entryProblem (fieldAt "transform") "theme-transform" "transform must be a function";
        };
        syntax = {
          validate =
            value:
            builtins.elem value [
              "native"
              "portable"
            ];
          onInvalid = _entry: _value: entryProblem subject "theme-syntax" "syntax must be native or portable";
        };
      };
    };

  normalizeThemeEntry =
    wrapped:
    let
      inherit (wrapped) blockId renderer;
      inherit (wrapped.entry) source output;
      inherit (wrapped) entry;
      syntax = entry.syntax or "native";
      rawSubdir =
        if !(entry ? subdir) then
          blockId
        else if entry.subdir == null then
          ""
        else
          lib.removeSuffix "/" entry.subdir;
      subdir = if rawSubdir == "" then "" else "${rawSubdir}/";
      placedAs = entry.placedAs or (builtins.unsafeDiscardStringContext (baseNameOf source));
      subId = entry.subId or null;
    in
    {
      inherit
        source
        output
        subdir
        placedAs
        subId
        blockId
        renderer
        syntax
        ;
      merge = entry.merge or null;
      transform = entry.transform or lib.id;
      reload = entry.reload or null;
      native = entry.native or { };
      registrationId =
        if subId == null then
          blockId
        else
          axiom.canonical.join "-" [
            blockId
            subId
          ];
      runtime = adapters.${renderer}.runtime or null;
    };

  # a path is read at evaluation. generated text stays a string, because reading a derivation
  # output here would be import from derivation.
  fragmentsOf =
    entry:
    template.parse (
      if builtins.isPath entry.source then builtins.readFile entry.source else entry.source
    );

  portableSourceOf =
    pkgs: dialect: entry:
    toString (
      entry.transform (
        pkgs.writeText "${entry.blockId}-${entry.placedAs}" (template.render dialect (fragmentsOf entry))
      )
    );

  tokenProblems =
    subject:
    let
      byTag = {
        unknown-token =
          issue:
          let
            suggestion = krisis.suggest issue.name template.tokens;
          in
          {
            code = "theme-token-unknown";
            message = "unknown token \"${issue.name}\" in ${issue.text}";
            help =
              if suggestion == null then
                "tokens are material color names, term0 to term15, success and warning"
              else
                "did you mean \"${suggestion}\"?";
          };
        unknown-modifier = issue: {
          code = "theme-token-modifier";
          message = "unknown modifier \"${issue.modifier}\" in ${issue.text}";
          help = "modifiers are ${lib.concatStringsSep ", " template.modifiers}";
        };
        conflicting-modes = issue: {
          code = "theme-token-mode";
          message = "more than one mode in ${issue.text}";
        };
      };
    in
    issues:
    map (fields: problem (fields // { primary.label = subject; })) (
      lib.unique (map (issue: byTag.${issue.tag} issue) issues)
    );

  themeGroupComputation =
    pkgs: entries:
    let
      inherit ((builtins.head entries)) blockId renderer;
      adapter = adapters.${renderer};
      registrations = axiom.registry.compile {
        registrations = entries;
        keyOf = entry: entry.registrationId;
        onDuplicate =
          id: _duplicates:
          problem {
            code = "theme-registration-duplicate";
            message = "has duplicate registration id ${id}";
            primary.label = "theme.${renderer}.${blockId}";
          };
      };
      unsupportedNativeIds = map (entry: entry.registrationId) (
        builtins.filter (entry: !(declares capability.nativeBlocks adapter) && entry.native != { }) entries
      );
      portableEntries = builtins.filter (entry: entry.syntax == "portable") entries;
      portableProblems = tokenProblems "theme.${renderer}.${blockId}" (
        builtins.concatMap (entry: template.issues (fragmentsOf entry)) portableEntries
      );
      inherit (adapter) templateNameOf;
      seedFileOf = entry: {
        dest = "${adapter.templateRoot}/${templateNameOf entry}";
        src =
          if entry.syntax == "portable" then
            portableSourceOf pkgs dialects.${adapter.dialect} entry
          else
            entry.source;
        representation = contract.capabilities.writable;
        onConflict = contract.conflictPolicies.runtimeWins;
        provenance = "lexicon/program/theme/default.nix";
      };
    in
    validation.andThen (
      _:
      validation.andThen
        (
          _:
          effects.accept (
            map seedFileOf entries
            ++ adapter.filesFor {
              inherit
                pkgs
                blockId
                entries
                templateNameOf
                ;
            }
          )
        )
        (
          effects.fromDiagnostics (
            lib.optional (unsupportedNativeIds != [ ]) (problem {
              code = "theme-native-unsupported";
              message = "cannot use native registration fields: ${lib.concatStringsSep ", " unsupportedNativeIds}";
              primary.label = "theme.${renderer}.${blockId}";
            })
            ++ portableProblems
          ) null
        )
    ) (effects.fromAxiom registrations);

  themeGroupFiles =
    pkgs: entries:
    effects.finishComputation (diagnostics: reporter.checked diagnostics [ ]) (
      themeGroupComputation pkgs entries
    );

  aggregatedThemeFiles =
    entries: pkgs:
    builtins.concatMap (
      renderer:
      let
        adapter = adapters.${renderer};
        rendererEntries = builtins.filter (entry: entry.renderer == renderer) entries;
        computation =
          validation.andThen
            (
              _:
              effects.accept (
                adapter.aggregateFilesFor {
                  inherit pkgs;
                  entries = rendererEntries;
                  registrationOf = adapter.registrationOf or (entry: entry.native);
                }
              )
            )
            (
              effects.fromAxiom (
                axiom.registry.compile {
                  registrations = rendererEntries;
                  keyOf = entry: entry.registrationId;
                  onDuplicate =
                    id: _duplicates:
                    problem {
                      code = "theme-registration-duplicate";
                      message = "has duplicate registration id ${id} across blocks";
                      primary.label = "theme.${renderer}";
                    };
                }
              )
            );
      in
      if !(declares capability.aggregateFiles adapter) || rendererEntries == [ ] then
        [ ]
      else
        effects.finishComputation (diagnostics: reporter.checked diagnostics [ ]) computation
    ) themeBackends;

  themeFiles =
    entries: pkgs:
    markers.composeThemes (
      builtins.concatMap (themeGroupFiles pkgs) (
        builtins.attrValues (
          builtins.groupBy (
            entry:
            axiom.canonical.join ":" [
              entry.renderer
              entry.blockId
            ]
          ) entries
        )
      )
      ++ aggregatedThemeFiles entries pkgs
    );
in
{
  inherit
    effectiveEntry
    themeBackends
    themeSharedFields
    themeEntrySchema
    themeFields
    themeFiles
    themeTemplateErrors
    ;
  normalizeEntry = normalizeThemeEntry;
}
