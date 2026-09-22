# names that meant something in an earlier shape of the surface and mean
# nothing now. both the declaration read and the contribution read build
# their note from here, and nothing here is ever a candidate the suggester
# may hand back
{ lib }:
let
  moved = {
    extend = "extensions arrive at the door now, as the contributions argument, a list of functions of the instance";
  };
in
{
  noteFor = key: lib.optional (moved ? ${key}) moved.${key};
}
