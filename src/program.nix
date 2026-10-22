{
  lib,
  krisis,
  axiom,
  mkCoordinator,
  resolve,
  resolveSystem,
  resolvePrepared,
  filePrincipals,
  hostUserNames,
  binding ? null,
}:
let
  furnish = import ./furnish {
    inherit
      lib
      krisis
      axiom
      resolve
      resolveSystem
      ;
  };
  ownerships = if binding == null then import ./ownerships { inherit lib krisis axiom; } else null;
  inherit (furnish) contract;
  claimKeys = if binding == null then ownerships.claimKeys else binding.claimKeys;
  projectClaims = if binding == null then ownerships.projectClaims else _scope: claims: claims;
  programReport = import ./program/report.nix { inherit lib krisis axiom; };
  inherit (programReport)
    problem
    reporter
    duplicateValues
    suggestionFor
    ;
  inherit (reporter) checked;
  furnishFiles = furnish.files;
  resolvePreparedFor = if binding == null then resolvePrepared else binding.resolvePrepared;
  filePrincipalsFor = if binding == null then filePrincipals else binding.filePrincipals;
  hostUserNamesFor = if binding == null then hostUserNames else binding.hostUserNames;

  fields = import ./program/fields.nix {
    inherit
      lib
      axiom
      claimKeys
      problem
      ;
  };
  inherit (fields)
    claimsOf
    withoutClaims
    unknownFields
    validRelativePath
    validBaseName
    validSubdir
    ;

  themeCompiler = import ./program/theme {
    inherit
      lib
      axiom
      contract
      claimKeys
      claimsOf
      withoutClaims
      unknownFields
      validRelativePath
      validBaseName
      validSubdir
      duplicateValues
      problem
      reporter
      ;
  };
  inherit (themeCompiler)
    themeBackends
    themeSharedFields
    themeEntryErrors
    themeFields
    themeFiles
    themeTemplateErrors
    themeUnits
    ;

  specLib = import ./program/spec.nix {
    inherit
      lib
      axiom
      contract
      fields
      claimKeys
      problem
      reporter
      suggestionFor
      themeFields
      themeSharedFields
      themeTemplateErrors
      ;
    elaborateTheme = themeCompiler.elaborate;
  };
  inherit (specLib)
    validateSpec
    fileErrors
    linkErrors
    directoryShapeErrors
    directoryRuleErrors
    ;

  directoriesLib = import ./program/directories.nix {
    inherit
      lib
      axiom
      fields
      problem
      directoryShapeErrors
      directoryRuleErrors
      ;
  };
  inherit (directoriesLib) prewalkDirectory expandDirectories;

  unitsLib = import ./program/units.nix { inherit lib fields themeUnits; };
  inherit (unitsLib) furnishUnit specUnit;

  validateSelected =
    files: links: directories: directoryFileRules: themeEntries: prewalked:
    let
      themeErrors = themeEntryErrors themeEntries;
      normalizedThemeEntries =
        if themeErrors == [ ] then map themeCompiler.normalizeEntry themeEntries else [ ];
      expanded = expandDirectories directories directoryFileRules normalizedThemeEntries prewalked;
      errors = fileErrors files ++ linkErrors links ++ themeErrors ++ expanded.errors;
    in
    checked errors {
      inherit files links;
      directoryFiles = expanded.files;
      themeEntries = normalizedThemeEntries;
    };

  hmConfig =
    lib: resolved: pkgs:
    let
      pkg = resolved.pkg or null;
    in
    lib.optionalAttrs (pkg != null) {
      home.packages = [ (pkg pkgs) ];
    };

  sliceList = value: if builtins.isList value then value else [ value ];
in
rawSpec:
let
  boundSpec = if binding == null then rawSpec else binding.validateSpec rawSpec;
  spec = validateSpec boundSpec;
  ownsFiles =
    (spec.files or [ ]) != [ ]
    || (spec.links or [ ]) != [ ]
    || (spec.directories or [ ]) != [ ]
    || builtins.any (backend: (spec.theme.${backend} or null) != null) themeBackends;
  hasHomePayload = (spec.pkg or null) != null || (spec.imports or [ ]) != [ ];
  needsHomeManager = hasHomePayload || spec ? homeManager;
  contextFields = [
    "files"
    "links"
    "directories"
  ];
  dynamicFields = builtins.filter (name: builtins.isFunction (spec.${name} or null)) contextFields;
  # select the declaration before evaluating callbacks that may read user or host data
  declarationResolve = resolvePreparedFor [ (claimsOf spec // { programSelected = true; }) ];
  selectedFor = context: (declarationResolve context).programSelected or false;
  materialize =
    args:
    let
      values = lib.genAttrs dynamicFields (
        name:
        let
          value = krisis.withErrorContext "program: while evaluating ${name} context function" (
            spec.${name} args
          );
        in
        checked (lib.optional (!builtins.isList value) (problem {
          code = "${name}-result";
          message = "${name} context function must return a list; got ${builtins.typeOf value}";
          primary.label = name;
        })) value
      );
      concrete = spec // values;
    in
    if binding == null then concrete else binding.validateSpec concrete;
  filesFor =
    args: context:
    if dynamicFields == [ ] then
      furnishResolve context
    else if selectedFor context then
      (resolvePreparedFor [ (furnishUnit (materialize args)) ]) context
    else
      { };
  homeResolve = resolvePreparedFor (lib.optional hasHomePayload (specUnit spec));
  furnishResolve = resolvePreparedFor [ (furnishUnit spec) ];
  # static sources share their directory inventory across user slices
  prewalkByIndex = builtins.listToAttrs (
    lib.imap0 (index: entry: {
      name = builtins.toString index;
      value = prewalkDirectory { inherit index entry; };
    }) (if builtins.isFunction (spec.directories or null) then [ ] else spec.directories or [ ])
  );
  systemClaim = projectClaims "system" (claimsOf spec);
  authorSlices =
    args: sliceList (if builtins.isFunction spec.nixos then spec.nixos args else spec.nixos);
  fileTargetReady =
    if binding != null && binding ? requireFileTarget then binding.requireFileTarget else true;
  result =
    lib.optionalAttrs needsHomeManager {
      homeManager =
        {
          pkgs,
          lib,
          host ? null,
          user ? null,
          ...
        }:
        let
          context = if binding == null then { inherit host user; } else binding.context;
          resolved = homeResolve context;
        in
        {
          imports =
            (resolved.imports or [ ])
            ++ lib.optional (spec ? homeManager && selectedFor context) (
              if builtins.isFunction spec.homeManager then
                lib.setFunctionArgs (args: spec.homeManager (args // context)) (
                  removeAttrs (builtins.functionArgs spec.homeManager) [
                    "host"
                    "user"
                  ]
                )
              else
                spec.homeManager
            );
          config = hmConfig lib resolved pkgs;
        };
    }
    // lib.optionalAttrs (spec ? nixos || ownsFiles) {
      nixos =
        {
          pkgs,
          config,
          host ? null,
          user ? null,
          ...
        }:
        let
          context = if binding == null then { inherit host user; } else binding.context;
          slices =
            if spec ? nixos then
              authorSlices {
                inherit
                  pkgs
                  config
                  ;
                inherit (context) host user;
              }
            else
              [ ];
          rawSlice =
            if slices == [ ] then
              { }
            else if binding == null then
              resolveSystem [ (systemClaim // { children = slices; }) ] { inherit (context) host; }
            else
              binding.nixos slices;
          hostName = config.networking.hostName;
          inherit (pkgs.stdenv.hostPlatform) system;
          # canonical host identity also owns the furnish namespace
          namespace =
            if context.host != null && context.host ? id then context.host.id else "${system}/${hostName}";
        in
        if !ownsFiles then
          rawSlice
        else
          let
            resolved = filesFor ({ inherit pkgs config; } // context) context;
            prewalked =
              if builtins.isFunction (spec.directories or null) then
                builtins.listToAttrs (
                  map (wrapped: {
                    name = toString wrapped.index;
                    value = prewalkDirectory wrapped;
                  }) (resolved.directoryEntries or [ ])
                )
              else
                prewalkByIndex;
            selected =
              validateSelected (resolved.files or [ ]) (resolved.links or [ ]) (resolved.directoryEntries or [ ])
                (resolved.directoryFileRules or [ ])
                (resolved.themeEntries or [ ])
                prewalked;
            composition = import ./program/theme/composition.nix { inherit lib krisis axiom; };
            hostFiles = selected.files ++ selected.directoryFiles;
            principals = builtins.filter (principal: principal.authority.scope == "user") (filePrincipalsFor {
              inherit system;
              inherit (context) user;
              host = hostName;
            });
            entriesFor =
              principal:
              map (
                entry:
                composition.lower pkgs (
                  entry
                  // {
                    inherit principal;
                    filesystemNamespace = namespace;
                  }
                )
              ) selected.themeEntries;
            principalGroups = map (principal: {
              inherit principal;
              entries = entriesFor principal;
            }) principals;
            taggedEntries = builtins.concatMap (group: group.entries) principalGroups;
            taggedMatugenEntries = builtins.filter (entry: entry.runtime == "matugen") taggedEntries;
          in
          {
            imports = [
              (import ./furnish/runtime.nix { inherit mkCoordinator krisis axiom; })
              (import ./program/theme/matugen-runtime.nix { inherit krisis axiom; })
              (import ./program/theme/composition-runtime.nix { inherit krisis axiom; })
              {
                assertions =
                  lib.optional (hostFiles != [ ] || selected.links != [ ] || selected.themeEntries != [ ])
                    {
                      assertion = config.lexicon.furnish.declarations != [ ];
                      message = "furnish: file entries on ${hostName} reached no user principal (have: ${
                        lib.concatStringsSep ", " (hostUserNamesFor {
                          inherit system;
                          host = hostName;
                        })
                      })";
                    };
                # den reaches this slice once per selected user.
                lexicon.furnish.declarations = builtins.concatMap (
                  group:
                  furnishFiles.mkDeclarations {
                    filesystemNamespace = namespace;
                    principals = [ group.principal ];
                    files = hostFiles ++ themeFiles group.entries pkgs;
                    inherit (selected) links;
                  }
                ) principalGroups;
                lexicon.theme.matugen.entries = taggedMatugenEntries;
                lexicon.theme.composition.ordinary = builtins.filter (entry: entry.merge == null) taggedEntries;
                lexicon.theme.composition.entries = builtins.filter (entry: entry.merge != null) taggedEntries;
              }
            ]
            ++ lib.optional (rawSlice != { }) rawSlice;
          };
    };
in
builtins.seq (if ownsFiles then fileTargetReady else true) result
