# fx hands over a flat failure record carrying a Position list. at nix-effects
# 55ec2657, src/effects/typecheck.nix and src/types/foundation.nix, neither the
# reason strings nor the position tags are reachable from a value, so both
# switches end in a default arm that reports rather than throws. every failure
# becomes exactly one diagnostic
{ lib, vocabulary }:
let
  inherit (vocabulary) emit;

  codeFor =
    reason:
    if reason == "missing-field" then
      "missing-field"
    else if reason == "shape-mismatch" || reason == "predicate-failed" then
      "invalid-value"
    else if reason == "extra-field" then
      "unknown-field"
    else
      null;

  segmentOf =
    position:
    let
      tag = position.tag or null;
    in
    if tag == "Field" && position ? name then
      {
        ok = true;
        part = position.name;
      }
    else if (tag == "Elem" || tag == "Index" || tag == "Item") && position ? idx then
      {
        ok = true;
        part = position.idx;
      }
    else
      {
        ok = false;
        part = position.segment or "?";
      };

  # the value the author actually wrote, not the normalized one
  valueAt =
    raw: parts:
    builtins.foldl' (
      current: part:
      if builtins.isAttrs current && builtins.isString part && current ? ${part} then
        current.${part}
      else
        null
    ) raw parts;

  translate =
    { entity, provenance }:
    failure:
    let
      positions = failure.path or [ ];
      segments = map segmentOf positions;
      mapped = builtins.all (segment: segment.ok) segments;
      parts = map (segment: segment.part) segments;
      code = codeFor (failure.reason or "");

      normalized = lib.concatStringsSep "." ([ entity.path ] ++ map toString parts);
      recorded = provenance.${normalized} or null;
      at = if recorded != null then recorded.sourcePath else entity.sourcePath ++ parts;

      named = if parts == [ ] then entity.name else toString (lib.last parts);
      typeName = failure.typeName or "?";
    in
    if code == null || !mapped then
      emit.unmapped-blame {
        at = entity.sourcePath;
        notes = [
          "reason: ${toString (failure.reason or "unknown")}"
          "blame: ${lib.concatMapStrings (position: position.segment or "?") positions}"
        ];
        context = {
          path = normalized;
        };
      }
    else if code == "missing-field" then
      emit.missing-field {
        inherit at;
        context = {
          field = named;
          type = typeName;
          path = normalized;
        };
      }
    else if code == "unknown-field" then
      emit.unknown-field {
        inherit at;
        context = {
          field = named;
          path = normalized;
        };
      }
    else
      emit.invalid-value {
        inherit at;
        context = {
          field = named;
          type = typeName;
          value = valueAt entity.raw parts;
          path = normalized;
        };
      };
in
{
  inherit translate;
}
