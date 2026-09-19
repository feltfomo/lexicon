# a subsystem declares its codes, emits them as effect requests, and the
# caller installs the policy that interprets them. nothing here throws on a
# subsystem's behalf
{ lib, fx }:
let
  severities = [
    "error"
    "warning"
    "info"
  ];

  path = import ./path.nix { inherit lib; };
  suggest = import ./suggest.nix { inherit lib; };
  render = import ./render.nix { inherit lib fx; };
  emit = import ./emit.nix { inherit fx; };

  policies = import ./policy.nix { inherit lib emit severities; };

  vocabulary = import ./vocabulary.nix {
    inherit
      lib
      fx
      emit
      render
      path
      severities
      ;
  };

  # halt sits outside the policies so a gate still ends the run under a
  # policy that otherwise keeps going
  haltHandler = {
    ${emit.haltEffect} =
      { state, ... }:
      {
        abort = policies.halted;
        inherit state;
      };
  };

  run =
    {
      policy ? policies.collect,
      rendering ? render.default,
    }:
    comp:
    let
      handlers = policy.handlers // rendering // haltHandler;
    in
    fx.run comp handlers policy.initial |> policy.result;
in
{
  inherit severities run;

  policy = policies;

  inherit (vocabulary) vocabulary;
  inherit (emit) gate report reportAll;
  inherit (path) renderPath;
  inherit (suggest) suggest suggestWith editDistance;

  inherit (render) show;
  rendering = {
    inherit (render) bounded default strict;
  };

  effects = {
    inherit (emit) reportEffect haltEffect;
    renderEffect = render.effect;
  };
}
