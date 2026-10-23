{
  lib,
  axiom,
  krisis,
  mkCoordinator,
}:
let
  compiler = import ../declarations { inherit lib axiom krisis; };
  report = import ../declarations/report.nix { inherit lib axiom krisis; };
  systemOwner = import ./system.nix {
    inherit lib axiom krisis;
    inherit (compiler) definitions;
  };
  resources = import ./resources.nix { inherit lib axiom krisis; };
  runtime = import ./runtime.nix {
    inherit
      lib
      axiom
      krisis
      mkCoordinator
      resources
      ;
  };
  configure =
    {
      extensions ? [ ],
    }:
    let
      environment = compiler.configure {
        inherit extensions;
        blocks = import ./builtins.nix {
          inherit
            lib
            axiom
            krisis
            resources
            systemOwner
            ;
          inherit (compiler) definitions;
        };
      };
      inherit (environment) ownerships;
      bind =
        {
          roster ? null,
          resolvers ? null,
          direct ? false,
          target ? null,
          selectionContext ? (_: { }),
          filePrincipals,
          hostUserNames,
        }:
        let
          bound = environment.bind { inherit roster resolvers direct; };
          axisKeys = map (descriptor: (descriptor.axisFor roster).ctxKey) (
            builtins.filter (
              descriptor:
              !builtins.elem descriptor.name [
                "host"
                "user"
                "when"
              ]
            ) environment.descriptors
          );
          forbidden = builtins.filter (
            key:
            builtins.elem key [
              "host"
              "user"
              "pkgs"
              "config"
              "scope"
              "output"
              "mergeSystem"
            ]
          ) axisKeys;
          extraKeys = report.checked (map (
            key: report.at [ key ] "context-collision" "axis context key collides with a bridge argument"
          ) forbidden) (lib.unique (builtins.filter (key: key != null) axisKeys));
          mergeSystem = systemOwner.merger {
            inherit
              direct
              resolvers
              ownerships
              roster
              ;
          };
          contextFor =
            scope: output: args:
            let
              base =
                if direct then
                  target
                else
                  {
                    host = args.host or null;
                    user = args.user or null;
                  };
              common = args // base // { inherit scope output; };
              extra = selectionContext common;
              checkedExtra = report.finish (
                (report.schema [ "selectionContext" ] (lib.genAttrs extraKeys (_: { }))) extra
              );
              context = common // lib.genAttrs extraKeys (key: checkedExtra.${key} or null);
            in
            context
            // {
              mergeSystem = units: mergeSystem units (compiler.contextForScope "system" context);
            };
          declaration =
            raw:
            let
              prepared = bound.prepare raw;
              present = builtins.filter (block: raw ? ${block.name}) environment.blocks.registrations;
              has = output: builtins.any (block: builtins.elem output block.outputs) present;
              intents = map (
                block:
                let
                  intent = krisis.withErrorContext "lexicon resource intent for ${block.name}" (
                    block.resourceIntent raw.${block.name}
                  );
                in
                report.checked (lib.optional (!builtins.isBool intent) (
                  report.at [ block.name ] "resource-intent-shape" "resource intent must be a boolean"
                )) intent
              ) (builtins.filter (block: builtins.elem "resources" block.outputs) present);
              resourceIntent = builtins.any (intent: intent) intents;
              targetCheck = report.checked (lib.optional (direct && resourceIntent && target.user == null) (
                report.at [
                  "target"
                  "user"
                ] "resource-user" "resource-producing declarations require a concrete user target"
              )) true;
              compile =
                scope: output: args:
                prepared.compile {
                  inherit scope;
                  outputs = [ output ];
                  context = contextFor scope output args;
                };
            in
            builtins.seq prepared (
              builtins.seq targetCheck (
                lib.optionalAttrs (has "homeManager") {
                  homeManager =
                    {
                      pkgs,
                      lib,
                      host ? null,
                      user ? null,
                      ...
                    }@args:
                    let
                      selected = compile "user" "homeManager" args;
                      modules = builtins.concatMap (
                        entry:
                        if builtins.isAttrs entry.module && builtins.attrNames entry.module == [ "imports" ] then
                          entry.module.imports
                        else
                          [ entry.module ]
                      ) selected.homeManager;
                    in
                    {
                      imports = modules;
                    };
                }
                // lib.optionalAttrs (has "nixos" || resourceIntent) {
                  nixos =
                    {
                      pkgs,
                      config,
                      host ? null,
                      user ? null,
                      ...
                    }@args:
                    let
                      system = compile "system" "nixos" args;
                      native = map (entry: entry.module) system.nixos;
                      base =
                        if native == [ ] then
                          { }
                        else if builtins.length native == 1 then
                          builtins.head native
                        else
                          { imports = native; };
                      user = compile "user" "resources" args;
                      files = runtime {
                        context = contextFor "user" "resources" args;
                        selected = resources.compose user.resources;
                        inherit filePrincipals hostUserNames;
                      };
                    in
                    if resourceIntent then
                      files // { imports = files.imports ++ lib.optional (base != { }) base; }
                    else
                      base;
                }
              )
            );
        in
        builtins.seq extraKeys declaration;
      principalFor = user: {
        authority = {
          scope = "user";
          identity = user.id or user.name;
        };
        managedRoot = user.home or "/home/${user.id or user.name}";
      };
      defaults = roster: {
        filePrincipals =
          {
            user ? null,
            ...
          }:
          lib.optional (user != null) (principalFor user);
        hostUserNames =
          { system, host }: roster.membership."${system}/${host}" or (roster.membership.${host} or [ ]);
      };
      forRoster =
        {
          roster,
          selectionContext ? (_: { }),
        }:
        let
          valid =
            builtins.isAttrs roster
            && builtins.isList (roster.hosts or null)
            && builtins.isList (roster.users or null)
            && builtins.isAttrs (roster.membership or null)
            && builtins.isList (roster.usersWithUnknownMembership or null);
          checked = report.checked (lib.optional (!valid) (
            report.at [ "roster" ] "roster" "roster must be produced by configured Ownerships"
          )) roster;
        in
        builtins.seq checked (
          bind (
            {
              roster = checked;
              inherit selectionContext;
            }
            // defaults checked
          )
        );
      forDen =
        {
          den,
          selectionRoster ? { },
          selectionContext ? (_: { }),
        }:
        let
          denApi = import ../den.nix {
            inherit
              den
              lib
              axiom
              krisis
              ;
          };
          checkedSelectionRoster = report.checked (lib.optional (!builtins.isAttrs selectionRoster) (
            report.at [ "selectionRoster" ] "roster-shape" "selection roster must be a record"
          )) selectionRoster;
          collisions = builtins.filter (key: denApi.roster ? ${key}) (
            builtins.attrNames checkedSelectionRoster
          );
          roster = report.checked (map (
            key:
            report.at [
              "selectionRoster"
              key
            ] "roster-override" "selection roster cannot override a base field"
          ) collisions) (denApi.roster // checkedSelectionRoster);
        in
        builtins.seq roster (bind {
          inherit roster selectionContext;
          inherit (denApi) filePrincipals hostUserNames;
        });
      forTarget =
        { target }:
        let
          normalized = (import ./target.nix { inherit lib axiom krisis; }).normalize target;
        in
        builtins.seq normalized (
          bind (
            {
              direct = true;
              target = normalized;
            }
            // defaults { membership = { }; }
          )
        );
      withResolvers =
        {
          resolvers,
          filePrincipals,
          hostUserNames,
          selectionContext ? (_: { }),
        }:
        bind {
          resolvers = resolvers ownerships;
          inherit filePrincipals hostUserNames selectionContext;
        };
    in
    {
      inherit
        forRoster
        forDen
        forTarget
        withResolvers
        ownerships
        ;
    };
in
{ inherit configure; } // configure { }
