{
  lib,
  axiom,
  krisis,
}:
let
  report = import ../declarations/report.nix { inherit lib axiom krisis; };
  targets = import ../furnish/target.nix { inherit lib; };
  fields = lib.genAttrs [ "source" "destination" "names" "destinations" "label" "provenance" ] (
    _: { }
  );
  relative =
    value:
    builtins.isString value
    && !builtins.hasContext value
    && value != ""
    && !lib.hasPrefix "/" value
    && builtins.all (part: part != "" && part != "." && part != "..") (lib.splitString "/" value);
  root = value: relative value || targets.externalPath value;
  list =
    origin: name: predicate: values:
    if !builtins.isList values then
      axiom.validation.failure [ (report.at (origin ++ [ name ]) "link-list" "expected a list") ]
    else
      let
        indexed = lib.imap0 (index: value: { inherit index value; }) values;
        first = builtins.listToAttrs (
          map (entry: {
            name = entry.value;
            value = entry.index;
          }) (builtins.filter (entry: predicate entry.value) indexed)
        );
        checked = lib.imap0 (
          index: value:
          let
            path = origin ++ [
              name
              index
            ];
            valid = predicate value;
            duplicate = valid && first.${value} != index;
          in
          axiom.validation.fromDiagnostics (
            lib.optional (!valid) (report.at path "link-path" "expected a normalized plain path")
            ++ lib.optional duplicate (report.at path "link-duplicate" "duplicate path ${value}")
          ) value
        ) values;
      in
      axiom.validation.sequence checked;
  validate =
    origin: value:
    let
      grouped = value ? names || value ? destinations;
      mixed = grouped && value ? destination;
      formErrors =
        lib.optional mixed (
          report.at (
            origin ++ [ "destination" ]
          ) "link-form" "destination cannot be combined with names or destinations"
        )
        ++ lib.optionals grouped (
          lib.optional (!(value ? names)) (
            report.at (origin ++ [ "names" ]) "required" "grouped links require names"
          )
          ++ lib.optional (!(value ? destinations)) (
            report.at (origin ++ [ "destinations" ]) "required" "grouped links require destinations"
          )
        );
      schema = {
        source = report.field origin "source" targets.externalPath;
        label = {
          validate = builtins.isString;
          onInvalid = _: _: report.at (origin ++ [ "label" ]) "shape" "expected a string";
        };
        provenance = {
          validate = builtins.isString;
          onInvalid = _: _: report.at (origin ++ [ "provenance" ]) "shape" "expected a string";
        };
      }
      // (
        if grouped then
          {
            names = {
              parse = list origin "names" relative;
            };
            destinations = {
              parse = list origin "destinations" root;
            };
          }
        else
          { destination = report.field origin "destination" report.nonempty; }
      );
    in
    # form errors precede payload validation so an unusable form cannot force its source
    axiom.validation.andThen (_: (report.schema origin schema) value) (
      axiom.validation.fromDiagnostics formErrors value
    );
  expand =
    plan:
    let
      inherit (plan) value;
      base = removeAttrs value [
        "names"
        "destinations"
      ];
    in
    if !(value ? names) then
      [ value ]
    else
      builtins.concatLists (
        lib.imap0 (
          rootIndex: destination:
          lib.imap0 (
            nameIndex: name:
            base
            // {
              source = "${value.source}/${name}";
              destination = "${destination}/${name}";
              label =
                lib.optionalString (value ? label) "${value.label} "
                + "${krisis.renderPath plan.origin} destinations[${toString rootIndex}] ${destination} names[${toString nameIndex}] ${name}";
            }
          ) value.names
        ) value.destinations
      );
in
{
  inherit fields validate expand;
}
