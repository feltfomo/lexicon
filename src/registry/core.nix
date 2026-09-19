# the fleet table and the closed-world lookups over it.
#
# two layers produce records: the lexicon declaration and an optional den input.
# they merge per field with lexicon winning, hosts.<name> = null removes a den
# host outright, and every record remembers which layers it came from. nothing
# is forced eagerly: reading root never builds the user table, and building the
# host table never forces a den user body.
{
  lib,
  axiom,
  krisis,
  fields,
  schema,
}:
let
  ownerships = import ../ownerships { inherit lib axiom krisis; };
  inherit (axiom) validation;
  inherit (fields)
    diagnostic
    hinted
    problem
    failOne
    finish
    ;

  canonicalId =
    system: name:
    axiom.canonical.qualified {
      namespace = system;
      inherit name;
    };

  sorted = builtins.sort (a: b: a < b);

  # ---------------------------------------------------------------- den layer

  aliasesFor =
    aliasMap: id: builtins.attrNames (lib.filterAttrs (_alias: ids: builtins.elem id ids) aliasMap);

  dimensionsFor =
    roster: hostId:
    lib.mapAttrs (_name: dimension: dimension.byHost.${hostId}) (
      lib.filterAttrs (_name: dimension: builtins.hasAttr hostId (dimension.byHost or { })) (
        roster.dimensions or { }
      )
    );

  # den ids are system/name and the registry keys hosts by bare name, so a den
  # fleet that reuses one name across systems has to rename before lexicon can
  # register it
  denHostsFrom =
    roster:
    let
      records = map (
        hostId:
        let
          name = roster.display.host.${hostId} or hostId;
          suffix = "/${name}";
        in
        {
          inherit name;
          system =
            if lib.hasSuffix suffix hostId then
              lib.removeSuffix suffix hostId
            else
              failOne (
                diagnostic hostId "den-host-id"
                  "den host id '${hostId}' does not end with its display name '${name}'"
              );
          aliases = aliasesFor (roster.aliases.host or { }) hostId;
          dimensions = dimensionsFor roster hostId;
        }
      ) roster.hosts;
      names = map (record: record.name) records;
    in
    if lib.unique names != names then
      failOne (problem {
        code = "den-host-name-conflict";
        message = "den declares the same host name on more than one system";
        help = "registry host names are unique across the fleet; rename one of them in den";
      })
    else
      builtins.listToAttrs (
        map (record: {
          inherit (record) name;
          value = record;
        }) records
      );

  denUsersFrom =
    roster: denHosts:
    let
      nameById = builtins.listToAttrs (
        map (host: {
          name = canonicalId host.system host.name;
          value = host.name;
        }) (builtins.attrValues denHosts)
      );
      hostsFor =
        userId:
        map (hostId: nameById.${hostId}) (
          builtins.filter (hostId: builtins.elem userId (roster.membership.${hostId} or [ ])) (
            builtins.attrNames nameById
          )
        );
    in
    builtins.listToAttrs (
      map (
        userId:
        let
          name = roster.display.user.${userId} or userId;
        in
        {
          inherit name;
          value = {
            inherit name;
            id = userId;
            aliases = aliasesFor (roster.aliases.user or { }) userId;
            hosts = hostsFor userId;
            home = null;
            on = { };
          };
        }
      ) roster.users
    );

  denLayer =
    den:
    if den == null then
      {
        hosts = { };
        users = { };
      }
    else
      let
        inherit
          (import ../den.nix {
            inherit
              lib
              axiom
              krisis
              den
              ;
          })
          roster
          ;
        hosts = denHostsFrom roster;
      in
      {
        inherit hosts;
        users = denUsersFrom roster hosts;
      };

  # ------------------------------------------------------------ lexicon layer

  # a user written under a host is the same registration written from the other
  # side: it adds membership, and a home there, without a second top-level entry
  usersFromHosts =
    hosts:
    let
      entries = builtins.concatMap (
        host:
        map (userName: {
          inherit userName;
          hostName = host.name;
          declaration = host.users.${userName};
        }) (builtins.attrNames host.users)
      ) (builtins.attrValues hosts);
      firstSet = group: read: lib.findFirst (value: value != null) null (map read group);
    in
    lib.mapAttrs (userName: group: {
      name = userName;
      id = firstSet group (entry: entry.declaration.id);
      aliases = firstSet group (entry: entry.declaration.aliases);
      home = null;
      hosts = map (entry: entry.hostName) group;
      on = builtins.listToAttrs (
        map (entry: {
          name = entry.hostName;
          value = {
            inherit (entry.declaration) home;
          };
        }) (builtins.filter (entry: entry.declaration.home != null) group)
      );
    }) (builtins.groupBy (entry: entry.userName) entries);

  # ----------------------------------------------------------------- merging

  pick = over: under: if over != null then over else under;

  mergeHost = under: over: {
    inherit (over) name;
    system = pick over.system under.system;
    aliases = pick over.aliases under.aliases;
    dimensions = (under.dimensions or { }) // over.dimensions;
  };

  # the two user sources inside the lexicon layer are additive, because a host
  # block and a users block describe one registration together
  mergeDeclaredUser = under: over: {
    inherit (over) name;
    id = pick over.id under.id;
    aliases = pick over.aliases under.aliases;
    home = pick over.home under.home;
    hosts =
      if over.hosts == null then
        under.hosts
      else
        lib.unique ((if under.hosts == null then [ ] else under.hosts) ++ over.hosts);
    on = (under.on or { }) // over.on;
  };

  # across layers lexicon replaces rather than extends, so a list written here
  # is the whole answer and den can never add to it
  mergeLayerUser = under: over: {
    inherit (over) name;
    id = pick over.id under.id;
    aliases = pick over.aliases under.aliases;
    home = pick over.home under.home;
    hosts = pick over.hosts under.hosts;
    on = (under.on or { }) // over.on;
  };

  originOf =
    inDen: inLexicon:
    if inDen && inLexicon then
      "both"
    else if inDen then
      "den"
    else
      "lexicon";

  mergeLayers =
    {
      den,
      lexicon,
      excluded,
      merge,
    }:
    let
      names = builtins.filter (name: !(builtins.elem name excluded)) (
        lib.unique (builtins.attrNames den ++ builtins.attrNames lexicon)
      );
    in
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value =
          let
            inDen = den ? ${name};
            inLexicon = lexicon ? ${name};
            merged =
              if inDen && inLexicon then
                merge den.${name} lexicon.${name}
              else if inDen then
                den.${name}
              else
                lexicon.${name};
          in
          merged // { origin = originOf inDen inLexicon; };
      }) names
    );

  # -------------------------------------------------------------- dimensions

  dimensionDefaults =
    space:
    lib.mapAttrs (_name: dimension: dimension.default) (
      lib.filterAttrs (_name: dimension: dimension.default != null) space
    );

  # declaring a dimension space turns on closed-world checking for dimensions.
  # a configuration that declares none is saying it does not model them, so an
  # inherited den fleet can still carry its own without being rejected here
  dimensionDiagnostics =
    space: host:
    if space == { } then
      [ ]
    else
      let
        declared = builtins.attrNames space;
        subject = "hosts.${host.name}";
        unknown = builtins.concatMap (
          name:
          validation.optional (!(space ? ${name})) (
            hinted subject "unknown-dimension" "host '${host.name}' sets undeclared dimension '${name}'" name
              declared
          )
        ) (builtins.attrNames host.dimensions);
        values = builtins.concatMap (
          name:
          let
            value = host.dimensions.${name};
          in
          validation.optional (space ? ${name} && !(builtins.elem value space.${name}.values)) (
            hinted subject "dimension-value"
              "host '${host.name}' sets dimension '${name}' to '${value}', which is not a declared value"
              value
              space.${name}.values
          )
        ) (builtins.attrNames host.dimensions);
        missing = builtins.concatMap (
          name:
          validation.optional (space.${name}.required && !(host.dimensions ? ${name})) (
            diagnostic subject "dimension-required"
              "host '${host.name}' is missing required dimension '${name}'"
          )
        ) declared;
      in
      validation.collect [
        unknown
        values
        missing
      ];

  # -------------------------------------------------------------- host table

  hostRecord =
    space: defaultSystem: host:
    let
      system = if host.system != null then host.system else defaultSystem;
      dimensions = dimensionDefaults space // host.dimensions;
      diagnostics = validation.collect [
        (validation.optional (system == null) (problem {
          code = "host-system-missing";
          message = "host '${host.name}' has no system";
          primary.label = "hosts.${host.name}";
          help = "set hosts.${host.name}.system, or set defaultSystem once for the whole registry";
        }))
        (dimensionDiagnostics space (host // { inherit dimensions; }))
      ];
    in
    validation.fromDiagnostics diagnostics {
      inherit (host) name origin;
      inherit dimensions;
      system = if system == null then "" else system;
      id = if system == null then host.name else canonicalId system host.name;
      aliases = if host.aliases == null then [ host.name ] else host.aliases;
    };

  # -------------------------------------------------------------- user table

  userRecord =
    hostTable: user:
    let
      subject = "users.${user.name}";
      known = builtins.attrNames hostTable;
      hosts = if user.hosts == null then [ ] else user.hosts;
      unknownHosts = builtins.concatMap (
        name:
        validation.optional (!(hostTable ? ${name})) (
          hinted subject "unknown-host" "user '${user.name}' lives on unregistered host '${name}'" name known
        )
      ) hosts;
      strayHomes = builtins.concatMap (
        name:
        validation.optional (!(builtins.elem name hosts)) (
          hinted subject "unknown-host"
            "user '${user.name}' sets a home on '${name}', which is not one of that user's hosts"
            name
            hosts
        )
      ) (builtins.attrNames user.on);
      home = if user.home == null then "/home/${user.name}" else user.home;
    in
    validation.fromDiagnostics
      (validation.collect [
        unknownHosts
        strayHomes
      ])
      {
        inherit (user) name origin;
        inherit home;
        id = if user.id == null then user.name else user.id;
        aliases = if user.aliases == null then [ user.name ] else user.aliases;
        hosts = sorted hosts;
        homeByHost = builtins.listToAttrs (
          map (host: {
            name = host;
            value = user.on.${host}.home or home;
          }) hosts
        );
      };

  # ------------------------------------------------------------ name clashes

  duplicates =
    registrations: code: describe:
    (axiom.registry.compile {
      inherit registrations;
      keyOf = registration: registration.key;
      onDuplicate =
        key: _entries:
        problem {
          inherit code;
          message = describe key;
        };
    }).diagnostics;

  aliasRegistrations =
    records:
    builtins.concatMap (
      record: map (alias: { key = alias; }) (lib.unique ([ record.name ] ++ record.aliases))
    ) records;

  clashDiagnostics =
    hosts: users:
    validation.collect [
      (duplicates (aliasRegistrations (builtins.attrValues hosts)) "alias-conflict" (
        key: "host name or alias '${key}' is registered more than once"
      ))
      (duplicates (aliasRegistrations (builtins.attrValues users)) "alias-conflict" (
        key: "user name or alias '${key}' is registered more than once"
      ))
      (duplicates (map (user: { key = user.id; }) (builtins.attrValues users)) "user-id-conflict" (
        key: "user id '${key}' belongs to more than one registered user"
      ))
    ];

  # ----------------------------------------------------------------- lookups

  indexBy =
    records:
    builtins.listToAttrs (
      builtins.concatMap (
        record:
        map (alias: {
          name = alias;
          value = record;
        }) (lib.unique ([ record.name ] ++ record.aliases ++ (record.idAliases or [ ])))
      ) records
    );

  make =
    declaration:
    let
      layer = denLayer declaration.den;

      declaredHosts = lib.filterAttrs (_name: host: host != null) declaration.hosts;
      excluded = builtins.attrNames (lib.filterAttrs (_name: host: host == null) declaration.hosts);

      strayExclusions = builtins.concatMap (
        name:
        validation.optional (!(layer.hosts ? ${name})) (
          hinted "hosts.${name}" "exclude-no-match" "hosts.${name} = null excludes a host no layer declares"
            name
            (builtins.attrNames layer.hosts)
        )
      ) excluded;

      sugarUsers = usersFromHosts declaredHosts;
      declaredUsers = builtins.listToAttrs (
        map (name: {
          inherit name;
          value =
            if sugarUsers ? ${name} && declaration.users ? ${name} then
              mergeDeclaredUser sugarUsers.${name} declaration.users.${name}
            else
              sugarUsers.${name} or declaration.users.${name};
        }) (lib.unique (builtins.attrNames sugarUsers ++ builtins.attrNames declaration.users))
      );

      mergedHosts = mergeLayers {
        den = layer.hosts;
        lexicon = lib.mapAttrs (_name: host: removeAttrs host [ "users" ]) declaredHosts;
        inherit excluded;
        merge = mergeHost;
      };

      # den only knew these users through their hosts, so excluding a host also
      # withdraws the membership it implied, and a user left with nothing was
      # never registered here in the first place
      denUsers = lib.filterAttrs (_name: user: user.hosts != [ ]) (
        lib.mapAttrs (
          _name: user: user // { hosts = builtins.filter (host: !(builtins.elem host excluded)) user.hosts; }
        ) layer.users
      );

      mergedUsers = mergeLayers {
        den = denUsers;
        lexicon = declaredUsers;
        excluded = [ ];
        merge = mergeLayerUser;
      };

      hostResults = validation.traverseAttrs (
        _name: hostRecord declaration.dimensions declaration.defaultSystem
      ) mergedHosts;

      hosts = finish (
        validation.fromDiagnostics (validation.collect [
          strayExclusions
          hostResults.diagnostics
        ]) (hostResults.value or { })
      );

      users = finish (validation.traverseAttrs (_name: userRecord hosts) mergedUsers);

      # name clashes are a property of the whole table, so they are one gate
      # every lookup passes through rather than a per-record check
      checked = finish (validation.fromDiagnostics (clashDiagnostics hosts users) true);

      hostIndex = indexBy (builtins.attrValues hosts);
      userIndex = indexBy (map (user: user // { idAliases = [ user.id ]; }) (builtins.attrValues users));

      knowsHost = name: builtins.seq checked (hostIndex ? ${name});
      knowsUser = name: builtins.seq checked (userIndex ? ${name});

      # an excluded name is never offered back as a spelling suggestion: the
      # answer to a removed host is not the removed host
      hostFor =
        name:
        if knowsHost name then
          hostIndex.${name}
        else if builtins.elem name excluded then
          failOne (problem {
            code = "host-excluded";
            message = "host '${name}' is excluded from this registry";
            help = "remove hosts.${name} = null to register it again";
          })
        else
          failOne (
            hinted "registry" "unknown-host" "'${name}' is not a registered host" name (
              builtins.attrNames hostIndex
            )
          );

      userFor =
        name:
        if knowsUser name then
          userIndex.${name}
        else
          failOne (
            hinted "registry" "unknown-user" "'${name}' is not a registered user" name (
              builtins.attrNames userIndex
            )
          );

      usersOn =
        hostName:
        let
          record = hostFor hostName;
        in
        builtins.filter (entry: builtins.elem record.name entry.hosts) (builtins.attrValues users);

      hostsFor = userName: map hostFor (userFor userName).hosts;

      homeFor =
        {
          host,
          user,
        }:
        let
          hostRecordFor = hostFor host;
          userRecordFor = userFor user;
        in
        if builtins.elem hostRecordFor.name userRecordFor.hosts then
          userRecordFor.homeByHost.${hostRecordFor.name}
        else
          failOne (problem {
            code = "unknown-user";
            message = "user '${userRecordFor.name}' is not registered on host '${hostRecordFor.name}'";
            help = "add '${hostRecordFor.name}' to users.${userRecordFor.name}.hosts";
          });

      hostsWhere =
        selector:
        builtins.filter (
          record:
          builtins.all (name: (record.dimensions.${name} or null) == selector.${name}) (
            builtins.attrNames selector
          )
        ) (builtins.attrValues hosts);

      forSystem = system: builtins.filter (record: record.system == system) (builtins.attrValues hosts);

      context =
        raw:
        let
          selection = schema.context raw;
          record = hostFor selection.host;
        in
        {
          host = record;
        }
        // lib.optionalAttrs (selection.user != null) {
          user =
            let
              chosen = userFor selection.user;
            in
            if builtins.elem record.name chosen.hosts then
              chosen
            else
              failOne (problem {
                code = "unknown-user";
                message = "user '${chosen.name}' is not registered on host '${record.name}'";
                help = "add '${record.name}' to users.${chosen.name}.hosts";
              });
        };

      # kept until ownerships reads its world from this table directly
      roster =
        let
          hostDeclarations = map (
            record:
            ownerships.define.host record.name {
              inherit (record) system dimensions aliases;
            }
          ) (builtins.attrValues hosts);
          userDeclarations = map (
            record:
            ownerships.define.user record.name {
              inherit (record) id aliases;
              hosts = map (name: (hostFor name).id) record.hosts;
            }
          ) (builtins.attrValues users);
        in
        ownerships.toRoster (hostDeclarations ++ userDeclarations);
    in
    {
      inherit (declaration) root runtimeRoot;
      inherit
        hosts
        users
        excluded
        roster
        usersOn
        hostsFor
        homeFor
        hostsWhere
        forSystem
        context
        ;
      host = hostFor;
      user = userFor;
      knows = {
        host = knowsHost;
        user = knowsUser;
      };
      systems = sorted (lib.unique (map (record: record.system) (builtins.attrValues hosts)));
      check = builtins.deepSeq [
        hosts
        users
        checked
      ] true;
      summary = {
        systems = sorted (lib.unique (map (record: record.system) (builtins.attrValues hosts)));
        hosts = sorted (builtins.attrNames hosts);
        users = sorted (builtins.attrNames users);
      };
    };
in
{
  inherit make;
}
