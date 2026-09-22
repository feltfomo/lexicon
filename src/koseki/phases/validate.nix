# phase three reports and changes nothing. every problem in the declaration
# leaves in one pass
{
  lib,
  fx,
  krisis,
  types,
  vocabulary,
  bridge,
}:
let
  inherit (vocabulary) emit;

  replay = problems: fx.seq (map (problem: emit.${problem.code} problem.args) problems);

  kindOf = kinds: name: lib.findFirst (kind: kind.name == name) null kinds;

  recordFor =
    kind:
    fx.types.Record (
      lib.listToAttrs (
        map (description: lib.nameValuePair description.name (types.strip description.type)) kind.fields
      )
    );

  # at nix-effects 55ec2657, src/types/constructors.nix, a closed record
  # rejects an unknown key by returning false with no diagnostic and no path,
  # so the diff is ours to do
  unknownFields =
    kind: entity:
    let
      raw = if builtins.isAttrs entity.raw then entity.raw else { };
      offending = builtins.filter (key: !builtins.elem key kind.fieldNames) (builtins.attrNames raw);
    in
    fx.seq (
      map (
        key:
        let
          nearest = krisis.suggest key kind.fieldNames;
        in
        emit.unknown-field {
          at = entity.sourcePath ++ [ key ];
          context = {
            field = key;
            path = "${entity.path}.${key}";
          };
          notes = lib.optional (nearest != null) "did you mean '${nearest}'?";
        }
      ) offending
    );

  typeFailures =
    { provenance }:
    kind: entity:
    let
      subject = builtins.removeAttrs entity.value [ "name" ];
      collected = fx.effects.scope.runWith {
        handlers = fx.effects.typecheck.collecting;
        state = [ ];
      } ((recordFor kind).validate subject);
    in
    fx.bind collected (
      inner: fx.seq (map (bridge.translate { inherit entity provenance; }) inner.state)
    );

  requirements =
    kind: entity:
    fx.seq (
      lib.concatMap (
        requirement:
        let
          ready = builtins.all (name: entity.value ? ${name}) (requirement.needs or [ ]);
          verdict = builtins.tryEval (requirement.check entity.value);
          failed = ready && (!verdict.success || !verdict.value);
        in
        lib.optional failed (
          emit.requirement-failed {
            at = entity.sourcePath ++ lib.optional (requirement ? field) requirement.field;
            context = {
              requirement = requirement.name;
              field = requirement.field or entity.name;
            };
            # a predicate that throws is the requirement author's bug, and the
            # declaration reader needs to be told which one it is
            notes = lib.optional (!verdict.success) "the requirement check itself threw";
          }
        )
      ) kind.requirements
    );

  # a check is data the caller handed over, so a check that is the wrong
  # shape, throws, or hands back something other than findings is reported
  # as a malformed check and the run carries on
  nameOf =
    position: check:
    if builtins.isAttrs check && builtins.isString (check.name or null) then
      check.name
    else
      "checks[${toString position}]";

  malformed =
    position: name: produced: notes:
    emit.malformed-check {
      at = [
        "checks"
        position
      ];
      context = {
        check = name;
        inherit produced;
      };
      inherit notes;
    };

  # a path segment renders as a name or an index and nothing else
  segment = value: builtins.isString value || (builtins.isInt value && value >= 0);

  pathLike = value: builtins.isList value && builtins.all segment value;

  # the reporter joins entities and renders paths outside the tryEval, so a
  # finding is shape-checked before anything in it is coerced
  wellFormed =
    finding:
    builtins.isAttrs finding
    && builtins.isString (finding.detail or null)
    && builtins.isList (finding.entities or [ ])
    && builtins.all (
      entity: builtins.isString entity || builtins.isInt entity || builtins.isFloat entity
    ) (finding.entities or [ ])
    && builtins.isList (finding.paths or [ ])
    && builtins.all pathLike (finding.paths or [ ])
    && (!(finding ? at) || pathLike finding.at)
    && builtins.isAttrs (finding.context or { });

  # the entities a finding is about go in the context and the source paths
  # go to at and notes, so a reader can reach every end of what was compared.
  # the entity list arrives pre-joined because the message reads as prose,
  # and the tier's own keys land last so a finding cannot restate which
  # check it came from
  reportFinding =
    name: finding:
    emit.check-failed (
      {
        context = (finding.context or { }) // {
          check = name;
          inherit (finding) detail;
          entities = lib.concatStringsSep ", " (map toString (finding.entities or [ ]));
        };
        notes = map krisis.renderPath (finding.paths or [ ]);
      }
      // lib.optionalAttrs (finding ? at) { inherit (finding) at; }
    );

  # every check is wrapped on its own. one that throws costs its own
  # findings and never stops the checks after it
  runOne =
    registry: seen: position: check:
    let
      name = nameOf position check;

      attempt = builtins.tryEval (
        let
          produced = check.run registry;
        in
        if builtins.isList produced then builtins.deepSeq produced produced else produced
      );

      naming =
        lib.optional (builtins.isAttrs check && !builtins.isString (check.name or null)) (
          malformed position name "a check with no name" [ ]
        )
        ++ lib.optional (builtins.elem name seen) (
          malformed position name "a second check under a name already taken" [
            "an earlier check is already called ${name}"
          ]
        );

      findings =
        if !builtins.isAttrs check then
          [ (malformed position name "a ${builtins.typeOf check} rather than a check" [ ]) ]
        else if !builtins.isFunction (check.run or null) then
          [ (malformed position name "a check with no run function" [ ]) ]
        else if !attempt.success then
          [
            (malformed position name "an evaluation error" [
              "the check itself threw while it was running"
            ])
          ]
        else if !builtins.isList attempt.value then
          [ (malformed position name "a ${builtins.typeOf attempt.value}" [ ]) ]
        else
          map (
            finding:
            if wellFormed finding then
              reportFinding name finding
            else if builtins.isAttrs finding && builtins.isString (finding.detail or null) then
              malformed position name "a finding whose entities, paths, at or context are the wrong shape" [ ]
            else
              malformed position name "a finding carrying no detail" [ ]
          ) attempt.value;
    in
    fx.seq (naming ++ findings);

  # findings come out in check order and, within a check, in the order the
  # check returned them. nothing here sorts
  runChecks =
    checks: registry:
    let
      names = lib.imap0 nameOf checks;
    in
    fx.seq (
      lib.imap0 (position: check: runOne registry (lib.take position names) position check) checks
    );

  run =
    {
      kinds,
      provenance,
      checks ? [ ],
      problems ? [ ],
    }:
    registry:
    let
      perEntity =
        entity:
        let
          kind = kindOf kinds entity.kind;
        in
        fx.seq [
          (unknownFields kind entity)
          (typeFailures { inherit provenance; } kind entity)
          (requirements kind entity)
        ];
    in
    krisis.gate (
      fx.bind (fx.seq (
        [ (replay problems) ] ++ map perEntity registry.entities ++ [ (runChecks checks registry) ]
      )) (_: fx.pure registry)
    );
in
{
  inherit run;
}
