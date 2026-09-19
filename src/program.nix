# the program surface an aspect declares against. this composition root wires
# the pieces together and emits the home-manager and nixos modules. the
# vocabularies live in program/spec.nix, the filesystem walk in
# program/directories.nix, the ownership units in program/units.nix, and the
# diagnostics policy in program/report.nix.
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
    files: directories: directoryFileRules: themeEntries: prewalked:
    let
      themeErrors = themeEntryErrors themeEntries;
      normalizedThemeEntries =
        if themeErrors == [ ] then map themeCompiler.normalizeEntry themeEntries else [ ];
      expanded = expandDirectories directories directoryFileRules normalizedThemeEntries prewalked;
      errors = fileErrors files ++ themeErrors ++ expanded.errors;
    in
    checked errors {
      inherit files;
      directoryFiles = expanded.files;
      themeEntries = normalizedThemeEntries;
    };

  hmConfig =
    lib: resolved: pkgs:
    let
      pkg = resolved.pkg or null;
    in
    lib.mkIf (pkg != null) {
      home.packages = [ (pkg pkgs) ];
    };

  # a nixos block that needs nothing from the build is a plain list, and a
  # single slice is just that slice. only the function form is applied.
  sliceList = value: if builtins.isList value then value else [ value ];
in
rawSpec:
let
  boundSpec = if binding == null then rawSpec else binding.validateSpec rawSpec;
  spec = validateSpec boundSpec;
  ownsFiles =
    (spec.files or [ ]) != [ ]
    || (spec.directories or [ ]) != [ ]
    || builtins.any (backend: (spec.theme.${backend} or null) != null) themeBackends;
  needsHomeManager = (spec.pkg or null) != null || (spec.imports or [ ]) != [ ];
  # the prepared resolves translate and compose the unit set once per aspect,
  # then only re-run ctx demand/select/survivors/merge per (host, user) slice.
  homeResolve = resolvePreparedFor [ (specUnit spec) ];
  furnishResolve = resolvePreparedFor [ (furnishUnit spec) ];
  # one read-only directory walk per declared directory, shared by every user
  # slice; shape/source errors stay once-per-aspect too.
  prewalkByIndex = builtins.listToAttrs (
    lib.imap0 (index: entry: {
      name = builtins.toString index;
      value = prewalkDirectory { inherit index entry; };
    }) (spec.directories or [ ])
  );
  # the declaration's own claim, narrowed to what a system-scope resolve can
  # bind. the author's slices hang under it, so `hosts` on the declaration owns
  # the whole aspect. the slices used to resolve unclaimed, which made them
  # globally owned and forced every aspect to restate its host list inside
  # every slice.
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
          imports = resolved.imports or [ ];
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
          # the build is handed to the author's nixos block, so a slice reads
          # `host.system` instead of re-deriving it from pkgs.
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
          # the resolved host already carries its canonical id. rebuilding one from
          # the module's hostname and platform put the same string in two places and
          # drifted the furnish namespace when a host was renamed.
          namespace =
            if context.host != null && context.host ? id then context.host.id else "${system}/${hostName}";
        in
        if !ownsFiles then
          rawSlice
        else
          let
            resolved = furnishResolve context;
            selected = validateSelected (resolved.files or [ ]) (resolved.directoryEntries or [ ]
            ) (resolved.directoryFileRules or [ ]) (resolved.themeEntries or [ ]) prewalkByIndex;
            hostFiles = selected.files ++ selected.directoryFiles ++ themeFiles selected.themeEntries pkgs;
            principals = filePrincipalsFor {
              inherit system;
              inherit (context) user;
              host = hostName;
            };
            # matugen renderers only read one config.toml each, so every aspect's
            # entries are tagged with this user context and merged once by the
            # shared runtime before furnish publishes the renderer config.
            matugenThemeEntries = builtins.filter (entry: entry.runtime == "matugen") selected.themeEntries;
            taggedMatugenEntries = builtins.concatMap (
              principal:
              map (
                entry:
                entry
                // {
                  inherit principal;
                  filesystemNamespace = namespace;
                }
              ) matugenThemeEntries
            ) principals;
          in
          {
            imports = [
              (import ./furnish/runtime.nix { inherit mkCoordinator krisis axiom; })
              (import ./program/theme/matugen-runtime.nix { inherit krisis axiom; })
              {
                assertions = lib.optional (hostFiles != [ ]) {
                  assertion = config.lexicon.furnish.declarations != [ ];
                  message = "furnish: file entries on ${hostName} reached no user principal (have: ${
                    lib.concatStringsSep ", " (hostUserNamesFor {
                      inherit system;
                      host = hostName;
                    })
                  })";
                };
                # den reaches this slice once per selected user.
                lexicon.furnish.declarations = furnishFiles.mkDeclarations {
                  filesystemNamespace = namespace;
                  inherit principals;
                  files = hostFiles;
                };
                lexicon.theme.matugen.entries = taggedMatugenEntries;
              }
            ]
            ++ lib.optional (rawSlice != { }) rawSlice;
          };
    };
in
builtins.seq (if ownsFiles then fileTargetReady else true) result
