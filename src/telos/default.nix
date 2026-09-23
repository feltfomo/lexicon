# the output layer. it is handed the registry factory and the block contract
# rather than reaching for where they live, the same way emission is handed
# the block registry it reads
{
  lib,
  fx,
  krisis,
  t,
  block,
  factory,
  walk,
}:
let
  vocabulary = import ./vocabulary.nix {
    inherit krisis;
    inherit (walk) codes;
  };

  # the projection a declared output forgets through. it is the foundation
  # every shape here is built on rather than a reference beside them
  projection = import ./projection.nix { inherit lib fx krisis; };

  kinds = import ./kinds.nix { };

  projected = import ./projected.nix;

  types = import ./types.nix { inherit fx t; };

  settings = import ./settings.nix { inherit t; };

  construct = import ./construct.nix { inherit lib kinds types; };

  gather = import ./gather.nix {
    inherit
      lib
      fx
      vocabulary
      construct
      ;
  };

  blocks = import ./blocks {
    inherit
      lib
      fx
      krisis
      kinds
      factory
      vocabulary
      ;
  };

  assembly = import ./assemble.nix {
    inherit
      lib
      fx
      krisis
      block
      blocks
      vocabulary
      projected
      types
      ;
  };

  # the flake surface, and the one place a telos diagnostic becomes a nix
  # error. a flake attribute has nowhere to carry a diagnostic, so the whole
  # report is rendered and thrown at once rather than one code at a time
  outputs =
    {
      entries,
      hosts,
      systems,
      packageSets,
    }:
    let
      outcome = krisis.run { policy = krisis.policy.pretty { long = true; }; } (
        fx.bind (gather.run entries) (
          declarations:
          assembly.run {
            inherit
              declarations
              hosts
              systems
              packageSets
              ;
          }
        )
      );
    in
    if outcome.hasErrors || outcome.halted then
      throw "lexicon refused the declared outputs\n${outcome.report}"
    else
      outcome.value;
in
projection
// {
  inherit
    kinds
    blocks
    projected
    vocabulary
    outputs
    settings
    ;

  assemble = assembly.run;

  internal = {
    inherit types construct gather;

    # a block reports against the place it was written, and the place is
    # installed for the validator's extent. reading a block on its own means
    # opening that extent, so the installer telos was handed is offered here
    # rather than reached for a second time
    inherit (block) within;
  };
}
