{
  lib,
  krisis,
  axiom,
  resolve,
  resolveSystem,
  principalContexts,
}:
let
  ownerships = import ../../src/ownerships { inherit lib krisis axiom; };
  furnish = import ../../src/furnish {
    inherit
      lib
      krisis
      axiom
      resolve
      resolveSystem
      ;
  };
  inherit (furnish) contract;

  ctx = {
    host = {
      name = "khion";
      system = "x86_64-linux";
    };
    user.name = "feltfomo";
  };

  sample = {
    label = "sample-config";
    users = [ "feltfomo" ];
    filesystemNamespace = "x86_64-linux/khion";
    authority = {
      scope = "user";
      identity = "feltfomo";
    };
    managedRoot = "/home/feltfomo";
    destination = ".config/furnish/sample.conf";
    representation = contract.capabilities.symlink;
    source = {
      kind = "path";
      value = ./fixtures/example.conf;
    };
    provenance.source = "tests/furnish/default.nix";
  };

  mkExecutor =
    {
      identity,
      priority,
    }:
    {
      inherit
        identity
        priority
        ;
      enabled = true;
      protocolVersion = 1;
      capabilities = [
        contract.capabilities.lifecycleBaseline
        contract.capabilities.symlink
      ];
      materialize = declaration: {
        target = {
          kind = "retained";
          path = builtins.path {
            path = declaration.source.value;
            name = "furnish-${declaration.label}";
          };
        };
        cleanupStrategy = contract.strategies.exactSymlinkTarget;
        selfHealStrategy = contract.strategies.exactSymlinkTarget;
      };
    };

  preferredExecutor = mkExecutor {
    identity = "executor/a";
    priority = 10;
  };
  tiedExecutor = mkExecutor {
    identity = "executor/z";
    priority = 10;
  };
  unusedPoisonExecutor = {
    identity = "executor/unused";
    priority = 0;
    enabled = true;
    protocolVersion = 1;
    capabilities = [ "unrelated" ];
    materialize = throw "forced an unused executor implementation";
  };
  executors = [
    tiedExecutor
    unusedPoisonExecutor
    preferredExecutor
  ];

  compile =
    declarations:
    furnish.compile {
      inherit
        declarations
        executors
        ctx
        ;
    };

  sampleResult = compile [ sample ];
  sampleEntry = builtins.head sampleResult.manifestData;

  second = sample // {
    label = "other-config";
    destination = ".config/furnish/other.conf";
  };
  orderedA = compile [
    sample
    second
  ];
  orderedB = compile [
    second
    sample
  ];

  poisonDerivation = {
    type = "derivation";
    name = "poison-package";
    drvPath = throw "forced a derivation-shaped value";
    outPath = throw "forced a derivation-shaped value";
  };
  poisonSecret.token = throw "forced a secret-shaped value";
  poisonPayload = {
    package = poisonDerivation;
    secret = poisonSecret;
  };
  poisonType = {
    type = throw "forced a type-shaped value";
    token = throw "forced a type-shaped payload";
  };
  poisonNamedDerivation = {
    type = "derivation";
    name = throw "forced a derivation name";
    drvPath = throw "forced a derivation field";
  };
  poisonList = [
    "visible"
    (throw "forced a list payload")
  ];

  inactive = sample // {
    label = "inactive-poison";
    hosts = [ "lumi" ];
    destination = ".config/furnish/inactive.conf";
    source = sample.source // {
      value = throw "forced an inactive ownership payload";
    };
  };
  inactiveResult = compile [
    sample
    inactive
  ];

  noCapable = sample // {
    label = "no-capable-executor";
    source = sample.source // {
      value = poisonPayload;
    };
  };

  impossible = sample // {
    label = "ownership-impossible";
    users = [ "nobody" ];
    source = sample.source // {
      value = poisonPayload;
    };
  };

  explicitPolicy = sample // {
    label = "explicit-policy";
    onConflict = contract.conflictPolicies.sourceWins;
  };
  explicitPolicyEntry = builtins.head (compile [ explicitPolicy ]).manifestData;
  bogusPolicy = sample // {
    label = "bogus-policy";
    onConflict = "merge";
  };

  malformedShape = {
    label = 1;
    filesystemNamespace = false;
    authority = {
      scope = "unknown";
    };
    managedRoot = 1;
    destination = false;
    representation = "";
    source = {
      kind = 1;
      value = throw "forced malformed shape payload";
    };
    onConflict = "merge";
  };
  malformedShapeDiagnostics = furnish.core.shapeDiagnostics malformedShape;
  malformedShapeCodes = map (item: item.code) malformedShapeDiagnostics;

  malformedExecutor = {
    identity = 1;
    priority = "first";
    enabled = "yes";
    protocolVersion = false;
    capabilities = [ 1 ];
    materialize = throw "forced malformed executor implementation";
  };
  malformedExecutorResult = builtins.tryEval (
    builtins.deepSeq (furnish.core.validateExecutors [ malformedExecutor ]) true
  );
  malformedShapeResult = builtins.tryEval (builtins.deepSeq malformedShapeDiagnostics true);

  invalidArtifactExecutor = preferredExecutor // {
    identity = "executor/invalid-artifact";
    materialize = _: {
      target = { };
      cleanupStrategy = "unknown";
      selfHealStrategy = "unknown";
    };
  };

  untagged = removeAttrs sample [ "users" ];
  offUntaggedResult = furnish.compile {
    declarations = [ untagged ];
    inherit executors ctx;
    provider = furnish.core.offProvider;
  };
  offTaggedResult = furnish.compile {
    declarations = [ sample ];
    inherit executors ctx;
    provider = furnish.core.offProvider;
  };

  throws = value: !(builtins.tryEval (builtins.deepSeq value value)).success;

  inertCore = import ../../src/furnish/core.nix {
    inherit
      lib
      contract
      krisis
      axiom
      ;
    inherit (ownerships) claimKeys;
    resolve = throw "no-op forced the user ownership door";
    resolveSystem = throw "no-op forced the system ownership door";
  };
  raw = {
    ordinary = {
      enabled = true;
      values = [
        1
        2
      ];
    };
  };
  noOp = inertCore.compile { inherit raw; };

  systemCore = import ../../src/furnish/core.nix {
    inherit
      lib
      contract
      krisis
      axiom
      ;
    inherit (ownerships) claimKeys;
    resolve = throw "a system declaration used the user ownership door";
    # the stub mirrors the roster-bound door's merged-value contract: the
    # batched provider hands the resolver one unit tree whose leaves carry
    # per-declaration `value.entries` chunks under unique keys, and the merged
    # value unions every leaf's chunk.
    resolveSystem =
      units: _ctx:
      builtins.foldl' (merged: node: merged // node.value or { }) { } (
        builtins.concatMap (
          unit:
          let
            collect = node: [ node ] ++ builtins.concatMap collect (node.children or [ ]);
          in
          collect unit
        ) units
      );
  };
  systemDeclaration = (removeAttrs sample [ "users" ]) // {
    label = "system-config";
    filesystemNamespace = "x86_64-linux/khion";
    authority = {
      scope = "system";
      identity = "x86_64-linux/khion";
    };
    managedRoot = "/etc";
    destination = "furnish/sample.conf";
  };
  systemResult = systemCore.compile {
    declarations = [ systemDeclaration ];
    inherit executors ctx;
  };

  diagnosticText = furnish.core.renderDiagnostic (
    furnish.core.diagnostic "capability-selection" "no-capable-executor" "sample" "no executor matched"
  );

  principalByScope =
    scope: builtins.head (builtins.filter (p: p.authority.scope == scope) principalContexts);
  userPrincipal = principalByScope "user";
  systemPrincipal = principalByScope "system";
  hostPrincipals = [
    systemPrincipal
    userPrincipal
  ];

  # a second user principal built here rather than taken from principalcontexts,
  # which comes from a single-user host and so cannot show per-user counting.
  secondUserPrincipal = userPrincipal // {
    authority = {
      scope = "user";
      identity = "grandpa";
    };
    ctx = userPrincipal.ctx // {
      user.name = "grandpa";
    };
  };
  twoUserPrincipals = [
    userPrincipal
    secondUserPrincipal
  ];
  rootedUserPrincipal = userPrincipal // {
    managedRoot = "/srv/furnish/feltfomo";
  };

  userClaim = (removeAttrs sample [ "users" ]) // {
    label = "user-claim";
    managedRoot = "/tmp";
    destination = "furnish/shared.conf";
    source = sample.source // {
      value = throw "forced active host-index payload";
    };
    generator = throw "forced active host-index generator";
    executor = throw "forced active host-index executor";
    provenance.source = "user-source.nix";
  };
  systemClaim = (removeAttrs systemDeclaration [ "users" ]) // {
    label = "system-claim";
    managedRoot = "/tmp";
    destination = "/tmp/furnish/shared.conf";
    source = systemDeclaration.source // {
      value = throw "forced system host-index payload";
    };
    provenance.source = "system-source.nix";
  };
  inactiveHostClaim = userClaim // {
    label = "inactive-host-poison";
    hosts = [ "lumi" ];
    destination = "furnish/inactive.conf";
    source = userClaim.source // {
      value = throw "forced ownership-excluded host-index payload";
    };
  };
  secondUserClaim = userClaim // {
    label = "second-user-claim";
    provenance.source = "second-user-source.nix";
  };
  secondCollisionUser = userClaim // {
    label = "other-user-claim";
    destination = "furnish/other.conf";
    provenance.source = "other-user-source.nix";
  };
  secondCollisionSystem = systemClaim // {
    label = "other-system-claim";
    destination = "furnish/other.conf";
    provenance.source = "other-system-source.nix";
  };
  canonicalSpelling = userClaim // {
    label = "canonical-spelling";
    destination = "furnish/./nested/../shared.conf/";
    provenance.source = "canonical-source.nix";
  };
  escaping = userClaim // {
    label = "escaping";
    destination = "../../etc/escaped.conf";
  };

  projectHost =
    declarations:
    builtins.concatMap (
      principal: furnish.core.projectPrincipal { inherit declarations principal; }
    ) hostPrincipals;
  collisionText =
    declarations:
    furnish.core.renderDiagnostics (furnish.core.collisionDiagnostics (projectHost declarations));

  crossCollisionText = collisionText [
    userClaim
    systemClaim
  ];
  samePrincipalCollisionText = collisionText [
    userClaim
    secondUserClaim
  ];
  threeClaimantText = collisionText [
    userClaim
    secondUserClaim
    systemClaim
  ];
  aggregateCollisionText = collisionText [
    userClaim
    systemClaim
    secondCollisionUser
    secondCollisionSystem
  ];
  expectedCrossCollisionText = "furnish: collision-detection/duplicate-filesystem-identity: x86_64-linux/khion:/tmp/furnish/shared.conf: claimed by system/x86_64-linux/khion (system-claim at system-source.nix), user/feltfomo (user-claim at user-source.nix)";
  expectedSamePrincipalCollisionText = "furnish: collision-detection/duplicate-filesystem-identity: x86_64-linux/khion:/tmp/furnish/shared.conf: claimed by user/feltfomo (second-user-claim at second-user-source.nix), user/feltfomo (user-claim at user-source.nix)";

  collisionEvidence = aggregateCollisionText;

  # a hand-written record, frozen here so the generated files layer has to keep
  # producing it byte for byte.
  kittyRecord = {
    label = "kitty.files[0]";
    filesystemNamespace = "x86_64-linux/khion";
    authority = {
      scope = "user";
      identity = "feltfomo";
    };
    managedRoot = "/home/feltfomo";
    destination = ".config/kitty/kitty.conf";
    representation = "symlink";
    source = {
      kind = "path";
      value = ./fixtures/example.conf;
    };
    provenance.source = "modules/aspects/kitty.nix";
  };

  kittyEntry = {
    dest = ".config/kitty/kitty.conf";
    src = ./fixtures/example.conf;
    label = "kitty.files[0]";
    provenance = "modules/aspects/kitty.nix";
  };

  kittyGenerated = furnish.files.mkDeclarations {
    filesystemNamespace = "x86_64-linux/khion";
    principals = hostPrincipals;
    files = [ kittyEntry ];
  };

  systemOnlyGenerated = furnish.files.mkDeclarations {
    filesystemNamespace = "x86_64-linux/khion";
    principals = [ systemPrincipal ];
    files = [ kittyEntry ];
  };

  noPrincipalGenerated = furnish.files.mkDeclarations {
    filesystemNamespace = "x86_64-linux/khion";
    principals = [ ];
    files = [ kittyEntry ];
  };

  twoUserGenerated = furnish.files.mkDeclarations {
    filesystemNamespace = "x86_64-linux/khion";
    principals = twoUserPrincipals;
    files = [ kittyEntry ];
  };

  rootedUserGenerated = furnish.files.mkDeclarations {
    filesystemNamespace = "x86_64-linux/khion";
    principals = [ rootedUserPrincipal ];
    files = [ kittyEntry ];
  };

  invalidArtifactResult = builtins.tryEval (
    builtins.deepSeq (furnish.compile {
      declarations = [ sample ];
      executors = [ invalidArtifactExecutor ];
      inherit ctx;
    }) true
  );

  # the emission site's argument shape is what decides which scopes it runs
  # under, so it is pinned here next to the counting it produces.
  programSlice =
    (import ../../src/program.nix {
      inherit
        lib
        krisis
        axiom
        resolve
        resolveSystem
        ;
      # program's prepared door is not exercised here; the test resolver is
      # ctx-pure, so the prepared form is the same function.
      resolvePrepared = resolve;
      mkCoordinator = throw "the furnish tests forced the coordinator builder";
      filePrincipals = _: [ ];
      hostUserNames = _: [ ];
    })
      { files = [ kittyEntry ]; };
  nixosArgs = builtins.functionArgs programSlice.nixos;

  # kitty's label carries brackets a store path cannot hold, and runtime names
  # the artifact after the destination.
  destinationNamedExecutor =
    (mkExecutor {
      identity = "executor/a";
      priority = 10;
    })
    // {
      materialize = declaration: {
        target = {
          kind = "retained";
          path = builtins.path {
            path = declaration.source.value;
            name = "furnish-${baseNameOf declaration.filesystemIdentity.destination}";
          };
        };
        cleanupStrategy = contract.strategies.exactSymlinkTarget;
        selfHealStrategy = contract.strategies.exactSymlinkTarget;
      };
    };

  compileKitty =
    declarations:
    furnish.compile {
      inherit declarations ctx;
      executors = [ destinationNamedExecutor ];
    };

  manifestKeys = builtins.attrNames sampleEntry;
  artifactTarget = sampleEntry.target.path;
  manifestContext = builtins.getContext sampleResult.manifestJson;
  inherit (sampleResult) manifestDocument;

  tests = {
    "test ownerships facade keeps internals private and supplies furnish claim keys" = {
      expr =
        !(ownerships ? engine)
        && !(ownerships ? engineArgsFor)
        && !(ownerships ? resolveWith)
        && furnish.core.isOwnerTagged (lib.genAttrs ownerships.claimKeys (_: [ ]));
      expected = true;
    };
    "test safe rendering never traverses arbitrary attribute values" = {
      expr =
        krisis.safeRender poisonSecret == "<unrenderable value>"
        && krisis.safeRender poisonType == "<unrenderable value>"
        && krisis.safeShape poisonType == "{ token, type }";
      expected = true;
    };
    "test safe rendering tolerates poisoned derivation names" = {
      expr =
        krisis.safeRender poisonNamedDerivation == "<derivation ?>"
        && krisis.safeShape poisonNamedDerivation == "<derivation ?>";
      expected = true;
    };
    "test safe rendering keeps flat scalar lists and rejects unsafe list members" = {
      expr =
        krisis.safeRender [
          "visible"
          1
          true
          null
        ] == ''["visible",1,true,null]''
        && krisis.safeRender poisonList == "<unrenderable value>";
      expected = true;
    };
    "test sample manifest is byte-stable and entry order is canonical" = {
      expr =
        sampleResult.manifestJson == (compile [ sample ]).manifestJson
        && sampleResult.manifestPath == null
        && orderedA.manifestJson == orderedB.manifestJson
        &&
          map (entry: entry.filesystemIdentity.canonical) orderedA.manifestData == [
            "x86_64-linux/khion:/home/feltfomo/.config/furnish/other.conf"
            "x86_64-linux/khion:/home/feltfomo/.config/furnish/sample.conf"
          ];
      expected = true;
    };
    "test manifest keeps identity authority root and executor separate" = {
      expr =
        sampleEntry.filesystemIdentity == {
          namespace = "x86_64-linux/khion";
          destination = "/home/feltfomo/.config/furnish/sample.conf";
          canonical = "x86_64-linux/khion:/home/feltfomo/.config/furnish/sample.conf";
        }
        &&
          sampleEntry.authority == {
            scope = "user";
            identity = "feltfomo";
          }
        && sampleEntry.managedRoot == "/home/feltfomo"
        &&
          sampleEntry.executor == {
            identity = "executor/a";
            protocolVersion = 1;
          };
      expected = true;
    };
    "test manifest is safe serializable data with enum lifecycle strategies" = {
      expr =
        (builtins.tryEval (builtins.deepSeq (builtins.toJSON sampleResult.manifestData) true)).success
        &&
          manifestKeys == [
            "authority"
            "cleanupStrategy"
            "executor"
            "filesystemIdentity"
            "managedRoot"
            "onConflict"
            "provenance"
            "representation"
            "schemaVersion"
            "selfHealStrategy"
            "target"
          ]
        && sampleEntry.cleanupStrategy == "exact-symlink-target"
        && sampleEntry.selfHealStrategy == "exact-symlink-target"
        && !(sampleEntry ? source);
      expected = true;
    };
    "test a declaration naming no conflict policy still serializes the error policy" = {
      expr = !(sample ? onConflict) && sampleEntry.onConflict == contract.conflictPolicies.error;
      expected = true;
    };
    "test an explicit conflict policy reaches the manifest entry unchanged" = {
      expr = explicitPolicyEntry.onConflict;
      expected = contract.conflictPolicies.sourceWins;
    };
    "test a conflict policy outside the enum is refused by shape validation" = {
      expr = furnish.core.validateShape bogusPolicy;
      expectedError.type = "ThrownError";
      expectedError.msg = "furnish: shape-validation/on-conflict-value: bogus-policy: onConflict must be one of the declared conflict pol";
    };
    "test shape validation accumulates metadata errors without forcing source value" = {
      expr =
        malformedShapeResult.success
        && builtins.length malformedShapeDiagnostics >= 8
        && builtins.elem "shape-validation/label-type" malformedShapeCodes
        && builtins.elem "shape-validation/authority-identity" malformedShapeCodes
        && builtins.elem "shape-validation/on-conflict-value" malformedShapeCodes;
      expected = true;
    };
    "test executor metadata validation rejects malformed records before selection" = {
      expr = !malformedExecutorResult.success;
      expected = true;
    };
    "test selected executor artifacts must satisfy the lifecycle result contract" = {
      expr = !invalidArtifactResult.success;
      expected = true;
    };
    "test manifest document versions runtime diagnostics and carries entries" = {
      expr =
        manifestDocument.schemaVersion == contract.schemaVersion
        && manifestDocument.diagnosticContract == contract.runtimeDiagnostics
        && manifestDocument.entries == sampleResult.manifestData
        && contract.runtimeDiagnostics.schemaVersion == contract.diagnosticSchemaVersion
        && builtins.all builtins.isString (builtins.attrValues contract.runtimeDiagnostics.codes);
      expected = true;
    };
    "test native executor tuple is exact and has no fallback identity" = {
      expr = contract.executors.nativeSymlink;
      expected = {
        identity = "furnish/native-symlink";
        protocolVersion = 1;
        representation = contract.capabilities.symlink;
      };
    };
    "test manifest context pins a dedicated artifact object" = {
      expr =
        lib.hasPrefix "/nix/store/" artifactTarget
        && artifactTarget != toString ./fixtures/example.conf
        && builtins.elem (builtins.unsafeDiscardStringContext artifactTarget) (
          builtins.attrNames manifestContext
        );
      expected = true;
    };
    "test inactive ownership: deepSeq forces no inactive payload" = {
      expr = (builtins.tryEval (builtins.deepSeq inactiveResult.manifestData true)).success;
      expected = true;
    };
    "test inactive ownership: exactly one entry survives selection" = {
      expr = builtins.length inactiveResult.manifestData;
      expected = 1;
    };
    "test inactive ownership: surviving entry identity equals the sample entry" = {
      expr = (builtins.head inactiveResult.manifestData).filesystemIdentity.canonical;
      expected = sampleEntry.filesystemIdentity.canonical;
    };
    "test inactive ownership: manifest equals the sample-only manifest" = {
      expr = inactiveResult.manifestData;
      expected = sampleResult.manifestData;
    };
    "test unused executor: materialize stays unforced when a capable executor exists" = {
      expr = (builtins.tryEval (builtins.deepSeq sampleResult.manifestData true)).success;
      expected = true;
    };
    "test no capable executor is a structured furnish error without forcing payload" = {
      expr =
        throws (
          furnish.compile {
            declarations = [ noCapable ];
            executors = [ unusedPoisonExecutor ];
            inherit ctx;
          }
        )
        &&
          diagnosticText == "furnish: capability-selection/no-capable-executor: sample: no executor matched";
      expected = true;
    };
    "test duplicate executor identities fail before capability selection" = {
      expr = furnish.core.selectExecutor [
        preferredExecutor
        (
          preferredExecutor
          // {
            priority = 20;
            materialize = throw "forced duplicate executor implementation";
          }
        )
      ] sample;
      expectedError.type = "ThrownError";
      expectedError.msg = "furnish: executor-validation/identity-duplicate: executor/a: executor identity must be unique";
    };
    "test throwing provider callbacks fail through the furnish selection context" = {
      expr = furnish.core.compile {
        declarations = [ sample ];
        inherit executors ctx;
        provider.selectApplicable = _declarations: _ctx: throw "boom, provider selection failed";
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "boom, provider selection failed";
    };
    "test throwing executor callbacks fail through declaration and executor context" = {
      expr = furnish.compile {
        declarations = [ sample ];
        executors = [
          (
            preferredExecutor
            // {
              identity = "executor/evil";
              materialize = _declaration: throw "boom, materialization failed";
            }
          )
        ];
        inherit ctx;
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "boom, materialization failed";
    };
    "test ownership impossible errors propagate through furnish without a catch or wrapper" = {
      expr = compile [ impossible ];
      expectedError.type = "ThrownError";
      expectedError.msg = "ownerships: 1 ownership error\\(s\\):\n\\s*- unit 'ownership-impossible': axis 'user' claim can never be satisfied \\(disjoint nest or unknown name\\) \\(axis ";
    };
    "test off mode passes an untagged declaration byte-identical to enabled mode" = {
      expr =
        offUntaggedResult.manifestJson == (compile [ untagged ]).manifestJson
        && builtins.length offUntaggedResult.manifestData == 1;
      expected = true;
    };
    "test off mode rejects an owner-tagged declaration instead of silently passing it" = {
      expr = offTaggedResult;
      expectedError.type = "ThrownError";
      expectedError.msg = "furnish: ownership-selection/ownerships-disabled: sample-config: ownership claim requires the ownerships subsy";
    };
    "test empty declarations have one inert encoding and don't enter ownership" = {
      expr =
        noOp.manifestData == [ ]
        && noOp.manifestPath == null
        && noOp.manifestDocument.entries == [ ]
        && noOp.raw == raw;
      expected = true;
    };
    "test raw config is returned byte-for-byte adjacent to furnish output" = {
      expr = (furnish.compile { inherit raw; }).raw;
      expected = raw;
    };
    "test authority chooses the system ownership door" = {
      expr =
        (builtins.head systemResult.manifestData).authority.identity == "x86_64-linux/khion"
        &&
          (builtins.head systemResult.manifestData).filesystemIdentity.destination
          == "/etc/furnish/sample.conf";
      expected = true;
    };
    "test lexical normalization collapses equivalent in-root spellings" = {
      expr = (furnish.core.deriveDestination canonicalSpelling).filesystemIdentity.canonical;
      expected = "x86_64-linux/khion:/tmp/furnish/shared.conf";
    };
    "test lexical normalization still rejects managed-root escape" = {
      expr = furnish.core.deriveDestination escaping;
      expectedError.type = "ThrownError";
      expectedError.msg = "furnish: destination-validation/outside-managed-root: escaping: destination must remain beneath its managed ro";
    };
    "test single claims across principals build one deterministic host index" = {
      expr = builtins.attrNames (
        furnish.core.buildHostIndex {
          declarations = [
            userClaim
            (systemClaim // { destination = "furnish/system.conf"; })
            inactiveHostClaim
          ];
          principals = hostPrincipals;
        }
      );
      expected = [
        "x86_64-linux/khion:/tmp/furnish/shared.conf"
        "x86_64-linux/khion:/tmp/furnish/system.conf"
      ];
    };
    "test cross-principal collisions render the shared diagnostic" = {
      expr = crossCollisionText;
      expected = expectedCrossCollisionText;
    };
    "test same-principal collisions render the shared diagnostic" = {
      expr = samePrincipalCollisionText;
      expected = expectedSamePrincipalCollisionText;
    };
    "test the host index rejects a cross-principal collision" = {
      expr = furnish.core.buildHostIndex {
        declarations = [
          userClaim
          systemClaim
        ];
        principals = hostPrincipals;
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "furnish: collision-detection/duplicate-filesystem-identity: x86_64-linux/khion:/tmp/furnish/shared\\.conf: claim";
    };
    "test compile rejects a same-principal collision" = {
      expr = compile [
        userClaim
        secondUserClaim
      ];
      expectedError.type = "ThrownError";
      expectedError.msg = "furnish: collision-detection/duplicate-filesystem-identity: x86_64-linux/khion:/tmp/furnish/shared\\.conf: claim";
    };
    "test three claimants are all rendered in deterministic order" = {
      expr =
        lib.hasInfix "system/x86_64-linux/khion (system-claim at system-source.nix)" threeClaimantText
        && lib.hasInfix "user/feltfomo (second-user-claim at second-user-source.nix)" threeClaimantText
        && lib.hasInfix "user/feltfomo (user-claim at user-source.nix)" threeClaimantText;
      expected = true;
    };
    "test distinct collisions aggregate into one rendered report" = {
      expr =
        builtins.length (
          furnish.core.collisionDiagnostics (projectHost [
            userClaim
            systemClaim
            secondCollisionUser
            secondCollisionSystem
          ])
        ) == 2
        && lib.hasInfix "/tmp/furnish/other.conf" aggregateCollisionText
        && lib.hasInfix "/tmp/furnish/shared.conf" aggregateCollisionText;
      expected = true;
    };
    "test whole host index stays payload executor generator and exclusion lazy" = {
      expr =
        (builtins.tryEval (
          builtins.deepSeq (furnish.core.buildHostIndex {
            declarations = [
              userClaim
              inactiveHostClaim
            ];
            principals = hostPrincipals;
          }) true
        )).success;
      expected = true;
    };
    "test empty host index is inert" = {
      expr = furnish.core.buildHostIndex { principals = hostPrincipals; };
      expected = { };
    };
    "test the files layer generates the record kitty wrote by hand" = {
      expr = kittyGenerated;
      expected = [ kittyRecord ];
    };
    "test a home-relative entry takes no declaration from a system principal" = {
      expr = systemOnlyGenerated;
      expected = [ ];
    };
    "test hand-written and generated kitty records compile to one manifest" = {
      expr = (compileKitty [ kittyRecord ]).manifestJson;
      expected = (compileKitty kittyGenerated).manifestJson;
    };
    "test the files layer takes no claim key and counts one declaration per principal handed in" = {
      expr =
        builtins.length (
          furnish.files.mkDeclarations {
            filesystemNamespace = "x86_64-linux/khion";
            principals = hostPrincipals;
            files = [
              kittyEntry
              (kittyEntry // { dest = ".config/kitty/other.conf"; })
            ];
          }
        ) == 2
        && builtins.length twoUserGenerated == 2;
      expected = true;
    };
    "test one entry and one user principal make exactly one declaration" = {
      expr = furnish.files.mkDeclarations {
        filesystemNamespace = "x86_64-linux/khion";
        principals = [ userPrincipal ];
        files = [ kittyEntry ];
      };
      expected = [ kittyRecord ];
    };
    "test two user principals do not collapse onto one declaration" = {
      expr =
        map (declaration: declaration.authority.identity) twoUserGenerated == [
          "feltfomo"
          "grandpa"
        ]
        &&
          map (declaration: declaration.managedRoot) twoUserGenerated == [
            "/home/feltfomo"
            "/home/grandpa"
          ]
        && builtins.all (declaration: declaration.destination == kittyEntry.dest) twoUserGenerated;
      expected = true;
    };
    "test an explicit principal managed root overrides the conventional home" = {
      expr = (builtins.head rootedUserGenerated).managedRoot;
      expected = "/srv/furnish/feltfomo";
    };
    "test no principal at all is a host-scope zero, not the same zero as a system principal" = {
      expr = noPrincipalGenerated == [ ] && systemOnlyGenerated == [ ];
      expected = true;
    };
    "test the emission site names host and user with defaults so the class wrapper keeps it" = {
      expr = nixosArgs.host && nixosArgs.user;
      expected = true;
    };
    "test an empty file half generates an empty declaration set" = {
      expr = furnish.files.mkDeclarations {
        filesystemNamespace = "x86_64-linux/khion";
        principals = hostPrincipals;
      };
      expected = [ ];
    };
    "test a declaration naming no provenance source falls back to its own label" = {
      expr = (builtins.head (compile [ (removeAttrs sample [ "provenance" ]) ]).manifestData).provenance;
      expected = {
        declaration = "sample-config";
        source = "sample-config";
      };
    };
  };

in
{
  inherit
    tests
    sampleResult
    collisionEvidence
    ;
}
