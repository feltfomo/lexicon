# the door a configuration comes through. the settings files beside the root
# are read first, then what the wiring handed over is run against the slices.
# the library half is whole before any of it
{
  fx,
  krisis,
  settings,
  library,
  registrations,
  walk,
  preparation,
  emission,
}:
let
  configure =
    {
      root,
      policy ? krisis.policy.collect,
      rendering ? krisis.rendering.default,
      capabilities ? { },
      contributions ? [ ],
    }:
    let
      walked = krisis.run { inherit policy rendering; } (
        fx.bind (settings.load {
          inherit registrations library root;
        }) (walk root)
      );
    in
    walked
    // {
      # one knot spans every root, and what fell under whose roots is handed
      # on beside it. the arrow below is given owned, so the door itself
      # names no subsystem
      value = walked.value.entries;

      inherit (walked.value) owned;

      # a contribution and a capability are held for this call and reach no
      # library half, because a settings file is read before the walk
      prepare = preparation {
        inherit policy rendering contributions;
        inherit (walked.value) owned;
      };

      emit = emission { inherit policy rendering capabilities; };
    };
in
{
  inherit configure;
}
