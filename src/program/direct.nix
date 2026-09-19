{
  lib,
  krisis,
  axiom,
  mkCoordinator,
  target ? null,
}:
let
  programReport = import ./report.nix { inherit lib krisis axiom; };
  inherit (programReport) problem;
  inherit (programReport.reporter) checked;

  claimKeys = [
    "hosts"
    "users"
    "exceptHosts"
    "exceptUsers"
    "when"
  ];
  targetFields = [
    "host"
    "user"
  ];
  hostFields = [
    "name"
    "system"
    "id"
  ];
  userFields = [
    "name"
    "home"
  ];

  nonEmptyString = value: builtins.isString value && value != "";
  absolutePath = value: nonEmptyString value && lib.hasPrefix "/" value;
  diagnostic =
    code: subject: message:
    problem {
      inherit code message;
      primary.label = subject;
    };
  unknownAt =
    subject: allowed: value:
    map
      (name: diagnostic "direct-target-field" "${subject}.${name}" "${subject} has unknown field ${name}")
      (
        if builtins.isAttrs value then
          builtins.filter (name: !(builtins.elem name allowed)) (builtins.attrNames value)
        else
          [ ]
      );

  hostErrors =
    if !builtins.isAttrs target || !(target ? host) then
      [
        (diagnostic "direct-target-host" "target.host" "target.host must provide a host name and system")
      ]
    else if !builtins.isAttrs target.host then
      [
        (diagnostic "direct-target-host-shape" "target.host" "target.host must be an attribute set")
      ]
    else
      unknownAt "target.host" hostFields target.host
      ++ lib.optional (!nonEmptyString (target.host.name or null)) (
        diagnostic "direct-target-host-identity" "target.host.name"
          "target.host.name must be a non-empty string"
      )
      ++ lib.optional (!nonEmptyString (target.host.system or null)) (
        diagnostic "direct-target-host-identity" "target.host.system"
          "target.host.system must be a non-empty string"
      )
      ++ lib.optional (target.host ? id && !nonEmptyString target.host.id) (
        diagnostic "direct-target-host-identity" "target.host.id"
          "target.host.id must be a non-empty string when set"
      );

  userErrors =
    if !builtins.isAttrs target || !(target ? user) || target.user == null then
      [ ]
    else if !builtins.isAttrs target.user then
      [
        (diagnostic "direct-target-user-shape" "target.user"
          "target.user must be an attribute set or omitted"
        )
      ]
    else
      unknownAt "target.user" userFields target.user
      ++ lib.optional (!nonEmptyString (target.user.name or null)) (
        diagnostic "direct-target-user-name" "target.user.name"
          "target.user.name must be a non-empty string"
      )
      ++ lib.optional (target.user ? home && !absolutePath target.user.home) (
        diagnostic "direct-target-user-home" "target.user.home"
          "target.user.home must be an absolute path when set"
      );

  targetErrors =
    if !builtins.isAttrs target then
      [
        (diagnostic "direct-target-shape" "target" "programDirect requires a target attribute set")
      ]
    else
      unknownAt "target" targetFields target ++ hostErrors ++ userErrors;

  checkedTarget = checked targetErrors target;
  normalizedHost = checkedTarget.host // {
    id = checkedTarget.host.id or "${checkedTarget.host.system}/${checkedTarget.host.name}";
  };
  normalizedUser =
    if !(checkedTarget ? user) || checkedTarget.user == null then
      null
    else
      checkedTarget.user
      // {
        home = checkedTarget.user.home or "/home/${checkedTarget.user.name}";
      };
  context = {
    host = normalizedHost;
    user = normalizedUser;
  };

  claimProblems =
    subject: value:
    map
      (
        name:
        problem {
          code = "direct-claim";
          message = "${subject} uses claim field '${name}', but programDirect activates every declaration";
          primary.label = "${subject}.${name}";
          help = "remove the claim or use lexicon.lib.programOwnerships when selection is intended";
        }
      )
      (
        if builtins.isAttrs value then
          builtins.filter (name: builtins.elem name claimKeys) (builtins.attrNames value)
        else
          [ ]
      );

  rendererProblems =
    subject: renderers:
    if !builtins.isAttrs renderers then
      [ ]
    else
      builtins.concatMap (name: claimProblems "${subject}.${name}" renderers.${name}) (
        builtins.attrNames renderers
      );

  templateProblems =
    subject: template:
    claimProblems subject template
    ++ rendererProblems "${subject}.renderers" (
      if builtins.isAttrs template then template.renderers or null else null
    );

  fileProblems =
    spec:
    if builtins.isAttrs spec && builtins.isList (spec.files or null) then
      builtins.concatMap (indexed: claimProblems "files[${toString indexed.index}]" indexed.entry) (
        lib.imap0 (index: entry: { inherit index entry; }) spec.files
      )
    else
      [ ];

  directoryProblems =
    spec:
    if builtins.isAttrs spec && builtins.isList (spec.directories or null) then
      builtins.concatMap (
        indexed:
        let
          subject = "directories[${toString indexed.index}]";
          inherit (indexed) entry;
        in
        claimProblems subject entry
        ++ lib.optionals (builtins.isAttrs entry && builtins.isList (entry.files or null)) (
          builtins.concatMap (rule: claimProblems "${subject}.files[${toString rule.index}]" rule.entry) (
            lib.imap0 (index: ruleEntry: {
              inherit index;
              entry = ruleEntry;
            }) entry.files
          )
        )
      ) (lib.imap0 (index: entry: { inherit index entry; }) spec.directories)
    else
      [ ];

  themeProblems =
    spec:
    if !builtins.isAttrs spec || !builtins.isAttrs (spec.theme or null) then
      [ ]
    else
      let
        inherit (spec) theme;
      in
      claimProblems "theme" theme
      ++ rendererProblems "theme.renderers" (theme.renderers or null)
      ++ lib.optionals (builtins.isList (theme.templates or null)) (
        builtins.concatMap (
          indexed: templateProblems "theme.templates[${toString indexed.index}]" indexed.template
        ) (lib.imap0 (index: template: { inherit index template; }) theme.templates)
      );

  directClaimErrors =
    spec:
    claimProblems "declaration" spec
    ++ fileProblems spec
    ++ directoryProblems spec
    ++ themeProblems spec;

  merge =
    left: right:
    lib.zipAttrsWith
      (
        _: values:
        if builtins.all builtins.isList values then
          builtins.concatLists values
        else if builtins.all builtins.isAttrs values then
          lib.foldl' merge { } values
        else
          lib.last values
      )
      [
        left
        right
      ];

  collect =
    unit:
    let
      own = removeAttrs unit (claimKeys ++ [ "children" ]);
    in
    lib.foldl' merge own (map collect (unit.children or [ ]));

  resolvePrepared = units: _context: lib.foldl' merge { } (map collect units);

  fileTargetCheck =
    if normalizedUser != null then
      true
    else
      checked [
        (problem {
          code = "direct-file-user";
          message = "programDirect needs target.user for files, directories, or file-producing themes";
          primary.label = "target.user";
          help = "add target.user with a name and optional home path";
        })
      ] true;

  binding = {
    inherit
      claimKeys
      context
      resolvePrepared
      ;
    validateSpec = spec: checked (directClaimErrors spec) spec;
    nixos = slices: { imports = slices; };
    requireFileTarget = fileTargetCheck;
    filePrincipals =
      _:
      lib.optional (normalizedUser != null) {
        authority = {
          scope = "user";
          identity = normalizedUser.name;
        };
        managedRoot = normalizedUser.home;
      };
    hostUserNames = _: lib.optional (normalizedUser != null) normalizedUser.name;
  };

  unavailable = name: throw "programDirect forced the internal ${name} callback";
  core = import ../program.nix {
    inherit
      lib
      krisis
      axiom
      mkCoordinator
      binding
      ;
    resolve = unavailable "resolve";
    resolveSystem = unavailable "resolveSystem";
    resolvePrepared = unavailable "resolvePrepared";
    filePrincipals = unavailable "filePrincipals";
    hostUserNames = unavailable "hostUserNames";
  };
in
builtins.seq checkedTarget core
