# fx drops field metadata. defaults, derivations and declared dependencies
# live on the description, never on the type record
{ lib }:
let
  describe =
    spec:
    {
      inherit (spec) name type;
      dependsOn = spec.dependsOn or [ ];
    }
    // lib.optionalAttrs (spec ? default) { inherit (spec) default; }
    // lib.optionalAttrs (spec ? derive) { inherit (spec) derive; };

  hasDefault = description: description ? default;

  isDerived = description: description ? derive;

  defaultsOf =
    descriptions:
    lib.listToAttrs (
      map (description: lib.nameValuePair description.name description.default) (
        builtins.filter hasDefault descriptions
      )
    );
in
{
  inherit
    describe
    hasDefault
    isDerived
    defaultsOf
    ;
}
