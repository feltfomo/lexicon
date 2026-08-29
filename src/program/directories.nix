# a declared directory becomes a concrete file list here. the walk is the only
# part of the program layer that reads the filesystem, and it is deliberately
# split in two: prewalkDirectory does everything that does not depend on the
# resolve context, expandDirectory does the rest. an aspect walks each source
# once and every user slice reuses the result.
{
  lib,
  axiom,
  fields,
  problem,
  directoryShapeErrors,
  directoryRuleErrors,
}:
let
  inherit (fields) joinSource lifecycleKeysAttrs;

  # every diagnostic here labels itself with the index of the declaration it
  # came from, so the label is built in one place.
  subjectAt = index: "directories[" + toString index + "]";

  excludedBy =
    exclusions: name:
    builtins.any (excluded: name == excluded || lib.hasPrefix "${excluded}/" name) exclusions;

  walkDirectory =
    root: exclusions:
    let
      walk =
        relative:
        let
          current = joinSource root relative;
          scanned = builtins.tryEval (builtins.readDir current);
        in
        if !scanned.success then
          {
            diagnostics = [
              (problem {
                code = "directory-source-kind";
                message = "directory source ${toString current} is not readable as a directory";
              })
            ];
            files = [ ];
            members = [ ];
          }
        else
          let
            resultFor =
              name:
              let
                kind = scanned.value.${name};
                child = if relative == "" then name else "${relative}/${name}";
                excluded = builtins.elem child exclusions;
                base = {
                  diagnostics = [ ];
                  files = [ ];
                  members = [ child ];
                };
              in
              if excluded then
                base
              else if kind == "directory" then
                let
                  nested = walk child;
                in
                {
                  inherit (nested) diagnostics files;
                  members = [ child ] ++ nested.members;
                }
              else if kind == "regular" then
                base // { files = [ child ]; }
              else
                base
                // {
                  diagnostics = [
                    (problem {
                      code = "directory-member-kind";
                      message = "directory source member ${child} must be a regular file or directory, not ${kind}";
                    })
                  ];
                };
            results = map resultFor (builtins.attrNames scanned.value);
          in
          {
            diagnostics = builtins.concatMap (result: result.diagnostics) results;
            files = builtins.concatMap (result: result.files) results;
            members = builtins.concatMap (result: result.members) results;
          };
    in
    walk "";

  sourceRelativeTo =
    root: source:
    let
      rootString = lib.removeSuffix "/" (builtins.unsafeDiscardStringContext (toString root));
      prefix = "${rootString}/";
      sourceString = builtins.unsafeDiscardStringContext (toString source);
    in
    if lib.hasPrefix prefix sourceString then lib.removePrefix prefix sourceString else null;

  # the read-only directory walk (readDir recursion, membership inventory) plus
  # the shape/source checks that gate it. all of it is ctx-independent, so the
  # aspect closure computes it once per directory and the per-user slices thread
  # the result through instead of re-walking the source for every user.
  prewalkDirectory =
    wrapped:
    let
      entry = if builtins.isAttrs wrapped.entry then wrapped.entry else { };
      shapeErrors = directoryShapeErrors wrapped;
      sourceKind =
        if shapeErrors != [ ] then
          null
        else if !builtins.pathExists entry.src then
          "missing"
        else
          builtins.readFileType entry.src;
      sourceErrors =
        lib.optional (shapeErrors == [ ] && sourceKind == "missing") (problem {
          code = "directory-source-missing";
          message = "src does not exist in the flake source: ${toString entry.src}";
          primary.label = subjectAt wrapped.index;
          notes = [ "git-backed flakes omit empty and untracked directories" ];
          help = "add a tracked file beneath the directory or remove the declaration";
        })
        ++
          lib.optional (shapeErrors == [ ] && sourceKind != "missing" && sourceKind != "directory")
            (problem {
              code = "directory-source-kind";
              message = "src must be a directory: ${toString entry.src} is ${sourceKind}";
              primary.label = subjectAt wrapped.index;
            });
      walked =
        if sourceErrors == [ ] && shapeErrors == [ ] then
          walkDirectory entry.src (entry.exclude or [ ])
        else
          {
            diagnostics = [ ];
            files = [ ];
            members = [ ];
          };
    in
    {
      inherit shapeErrors sourceErrors walked;
    };

  expandDirectory =
    wrapped: rules: themeEntries: pw:
    let
      inherit (pw) shapeErrors sourceErrors walked;
      entry = if builtins.isAttrs wrapped.entry then wrapped.entry else { };
      selectedRules = builtins.filter (rule: rule.index == wrapped.index) rules;
      selectedRuleErrors = builtins.concatMap directoryRuleErrors selectedRules;
      exclude = if entry ? exclude && builtins.isList entry.exclude then entry.exclude else [ ];
      inventory = walked.files;
      reserved = wrapped.reservedNames;
      uniqueReserved = lib.unique reserved;
      duplicateReserved =
        (axiom.registry.compile {
          registrations = reserved;
          keyOf = name: name;
          onDuplicate =
            name: _duplicates:
            problem {
              code = "directory-file-duplicate";
              message = "repeats override name ${name}";
              primary.label = subjectAt wrapped.index;
            };
        }).diagnostics;
      unknownExcluded = builtins.filter (name: !(builtins.elem name walked.members)) exclude;
      excludedOverrides = builtins.filter (excludedBy exclude) uniqueReserved;
      unknownReserved = builtins.filter (
        name: !(excludedBy exclude name) && !(builtins.elem name inventory)
      ) uniqueReserved;
      themeNames = builtins.filter (name: name != null) (
        map (theme: sourceRelativeTo entry.src theme.source) themeEntries
      );
      excludedThemes = builtins.filter (excludedBy exclude) themeNames;
      themeOverrides = builtins.filter (name: builtins.elem name themeNames) uniqueReserved;
      semanticErrors =
        duplicateReserved
        ++ lib.optional (unknownExcluded != [ ]) (problem {
          code = "directory-exclude-unknown";
          message = "excludes unknown names: ${lib.concatStringsSep ", " unknownExcluded}";
          primary.label = subjectAt wrapped.index;
        })
        ++ lib.optional (unknownReserved != [ ]) (problem {
          code = "directory-file-unknown";
          message = "overrides unknown names: ${lib.concatStringsSep ", " unknownReserved}";
          primary.label = subjectAt wrapped.index;
        })
        ++ lib.optional (excludedOverrides != [ ]) (problem {
          code = "directory-file-excluded";
          message = "overrides excluded names: ${lib.concatStringsSep ", " excludedOverrides}";
          primary.label = subjectAt wrapped.index;
        })
        ++ lib.optional (excludedThemes != [ ]) (problem {
          code = "directory-theme-excluded";
          message = "excludes theme sources: ${lib.concatStringsSep ", " excludedThemes}";
          primary.label = subjectAt wrapped.index;
        })
        ++ lib.optional (themeOverrides != [ ]) (problem {
          code = "directory-file-themed";
          message = "overrides theme sources: ${lib.concatStringsSep ", " themeOverrides}";
          primary.label = subjectAt wrapped.index;
        });
      defaults = builtins.intersectAttrs lifecycleKeysAttrs entry;
      destinationRoot = lib.removeSuffix "/" (entry.dest or "");
      fileFor =
        extra: name:
        defaults
        // builtins.intersectAttrs lifecycleKeysAttrs extra
        // {
          src = joinSource entry.src name;
          dest = "${destinationRoot}/${name}";
        };
      inheritedNames = builtins.filter (
        name: !(builtins.elem name reserved) && !(builtins.elem name themeNames)
      ) inventory;
      selectedFiles = builtins.concatMap (
        rule:
        if builtins.isAttrs rule.entry && rule.entry ? names && builtins.isList rule.entry.names then
          map (fileFor rule.entry) rule.entry.names
        else
          [ ]
      ) selectedRules;
      errors = shapeErrors ++ selectedRuleErrors ++ sourceErrors ++ walked.diagnostics ++ semanticErrors;
    in
    {
      inherit errors;
      files = if errors == [ ] then map (fileFor { }) inheritedNames ++ selectedFiles else [ ];
    };

  # the prewalk table is built from the same declaration list the resolved
  # entries came from, so a missing index means the two drifted. this used to
  # fall back to an empty walk, which turned that drift into a directory that
  # silently contributed no files.
  prewalkFor =
    prewalked: index:
    prewalked.${builtins.toString index} or (throw (
      "program: "
      + subjectAt index
      + " has no prewalk; the declared directories and the resolved directory entries disagree"
    ));

  expandDirectories =
    directories: rules: themeEntries: prewalked:
    let
      expanded = map (
        directory: expandDirectory directory rules themeEntries (prewalkFor prewalked directory.index)
      ) directories;
    in
    {
      errors = builtins.concatMap (result: result.errors) expanded;
      files = builtins.concatMap (result: result.files) expanded;
    };
in
{
  inherit
    excludedBy
    walkDirectory
    sourceRelativeTo
    prewalkDirectory
    expandDirectory
    expandDirectories
    prewalkFor
    ;
}
