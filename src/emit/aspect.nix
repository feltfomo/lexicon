# the drop-in. a declaration written for this tree, projected into the value
# an aspect file hands the aspect system
#
# a claim has no meaning here. the aspect system decides which entity an
# aspect is placed against, so a claim at the top of a block narrows
# nothing. den v0.18.0, rev 5df0987, read 2026-09-21
{
  lib,
  fx,
  krisis,
  vocabulary,
  compile,
  construct,
  claimKeys,
  context,
}:
let
  inherit (vocabulary) emit;

  # the aspect system follows its own includes through its own resolver, so
  # a declaration handed in here may not carry this tree's
  includesIn =
    held:
    lib.optional (held.includes != [ ]) (
      emit.aspect-carries-includes {
        at = [ "includes" ];
        context = {
          includes = builtins.length held.includes;
        };
      }
    );

  # a claim deeper inside a block narrows something the block itself owns
  # and is honoured by whatever reads that block. only a claim at the top of
  # a block decides placement, which is the one this path cannot honour
  claimsIn =
    held:
    lib.concatMap (
      block:
      lib.concatMap (
        key:
        lib.optional (builtins.isAttrs held.blocks.${block} && held.blocks.${block} ? ${key}) (
          emit.aspect-carries-claim {
            at = [
              block
              key
            ];
            context = {
              inherit block;
              claim = key;
            };
          }
        )
      ) claimKeys
    ) (builtins.attrNames held.blocks);

  # the aspect system applies the entity itself, so nothing is bound here
  projected =
    held:
    lib.filterAttrs (_: modules: modules != [ ])
      (compile.project {
        inherit context;
        bound = { };
        interiors = held.blocks;
      }).classes;

  of =
    value:
    let
      held = construct.read value;
    in
    fx.bind (fx.seq (includesIn held ++ claimsIn held)) (_: fx.pure (projected held));

  # an aspect file cannot read a diagnostic stream, so the drop-in hands
  # back an aspect or throws the report it would have written
  toDenAspect =
    value:
    let
      outcome = krisis.run { policy = krisis.policy.pretty { long = true; }; } (of value);
    in
    if outcome.hasErrors then throw outcome.report else outcome.value;
in
{
  inherit of toDenAspect;
}
