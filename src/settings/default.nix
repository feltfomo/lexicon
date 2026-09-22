# the settings layer. a subsystem declares the filename it answers to and the
# keys it takes, and those files are read from the configuration root before
# anything walks. this layer is total over the registrations it is handed and
# names none of them
{
  lib,
  fx,
  krisis,
  t,
  arrows,
}:
let
  vocabulary = import ./vocabulary.nix { inherit krisis; };
  types = import ./types.nix { inherit fx t; };

  inherit (vocabulary) emit;
  inherit (arrows) traverse sum;

  Held = t.bless (
    fx.types.Record {
      file = t.String;
      registration = types.Registration;
      given = t.Any;
    }
  );

  # a file beside the configuration root, or nothing there at all
  Presence = sum {
    absent = types.Registration;
    present = Held;
  };

  # what the file handed back, sorted once where it arrives so nothing below
  # asks the question a second time
  Given = sum {
    malformed = t.Any;
    wellShaped = t.Attrs;
  };

  # pathExists and import are the one place this layer reaches disk, and they
  # stay builtins rather than becoming effects
  presenceOf =
    library: root: registration:
    let
      file = root + "/${registration.filename}";
    in
    if builtins.pathExists file then
      Presence.inject.present {
        inherit registration;
        file = registration.filename;
        given = import file {
          inherit library;
          root = toString root;
        };
      }
    else
      Presence.inject.absent registration;

  givenOf =
    value:
    if builtins.isAttrs value then Given.inject.wellShaped value else Given.inject.malformed value;

  defaultsOf = registration: lib.mapAttrs (_: declared: declared.default) registration.schema;

  shapeOf =
    registration:
    t.bless (fx.types.Record (lib.mapAttrs (_: declared: declared.type) registration.schema));

  unknownKey =
    held: key:
    emit.unknown-key {
      at = [
        held.file
        key
      ];
      context = {
        inherit key;
        inherit (held) file;
        subsystem = held.registration.name;
      };
      notes =
        let
          nearest = krisis.suggest key (builtins.attrNames held.registration.schema);
        in
        lib.optional (nearest != null) "did you mean '${nearest}'?";
    };

  # fx hands over a flat failure record carrying a Position list, the same
  # shape the layers below read, so a bad value is named by the key under it
  segmentOf =
    position: if (position.tag or null) == "Field" && position ? name then position.name else null;

  blameOf =
    held: failure:
    let
      parts = builtins.filter (part: part != null) (map segmentOf (failure.path or [ ]));
    in
    emit.malformed-value {
      at = [ held.file ] ++ parts;
      context = {
        inherit (held) file;
        key = if parts == [ ] then held.file else lib.last parts;
        expected = failure.typeName or "?";
      };
    };

  readWellShaped =
    held: given:
    let
      unknown = builtins.filter (key: !(held.registration.schema ? ${key})) (builtins.attrNames given);

      offered = defaultsOf held.registration // builtins.removeAttrs given unknown;

      # the same declared type decides the blame and decides what survives
      sound = lib.filterAttrs (key: value: held.registration.schema.${key}.type.check value) offered;

      merged = defaultsOf held.registration // sound;
    in
    fx.bind (fx.seq (map (unknownKey held) unknown)) (
      _:
      fx.bind
        (fx.effects.scope.runWith {
          handlers = fx.effects.typecheck.collecting;
          state = [ ];
        } ((shapeOf held.registration).validate offered))
        (checked: fx.bind (fx.seq (map (blameOf held) checked.state)) (_: fx.pure merged))
    );

  readPresent =
    held:
    Given.case {
      malformed =
        _:
        fx.bind (emit.malformed-file {
          at = [ held.file ];
          context = {
            inherit (held) file;
          };
        }) (_: fx.pure (defaultsOf held.registration));

      wellShaped = readWellShaped held;
    } (givenOf held.given);

  sliceOf =
    library: root: registration:
    fx.map (slice: lib.nameValuePair registration.name slice) (
      Presence.case {
        absent = missing: fx.pure (defaultsOf missing);
        present = readPresent;
      } (presenceOf library root registration)
    );

  registrationBlame =
    failure:
    let
      parts = builtins.filter (part: part != null) (map segmentOf (failure.path or [ ]));
    in
    emit.malformed-registration {
      at = parts;
      context = {
        field = if parts == [ ] then "a registration" else lib.last parts;
        expected = failure.typeName or "?";
      };
    };

  vetted =
    registrations:
    fx.bind
      (fx.effects.scope.runWith {
        handlers = fx.effects.typecheck.collecting;
        state = [ ];
      } (fx.seq (map types.Registration.validate registrations)))
      (
        checked:
        fx.bind (fx.seq (map registrationBlame checked.state)) (
          _: fx.pure (builtins.filter types.Registration.check registrations)
        )
      );

  load =
    {
      registrations,
      library,
      root,
    }:
    fx.bind (vetted registrations) (
      sound: fx.map lib.listToAttrs (traverse (sliceOf library root) sound)
    );
in
{
  inherit load vocabulary;
  inherit (types) Registration;
}
