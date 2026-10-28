# resolves one side of a comparison to a locked store snapshot, printed as
# store path and narHash. every sample then names the side by that locked
# reference, so samples evaluate in pure mode and a side can't drift mid-run.
# a revision comes from git. a working tree is copied without git metadata,
# scratch output or nested checkouts, which would otherwise feed earlier runs'
# records into the snapshot
{
  location,
  revision ? null,
}:
let
  ignored = [
    ".runtime"
    ".direnv"
    ".devenv"
    ".git"
  ];
  keep =
    path: type:
    let
      name = baseNameOf path;
    in
    !(builtins.elem name ignored)
    && !(builtins.match "result(-.*)?" name != null)
    && !(type == "directory" && builtins.pathExists "${path}/.git");
  reference =
    if revision == null then
      "path:"
      + builtins.unsafeDiscardStringContext (
        builtins.path {
          name = "source";
          path = /. + location;
          filter = keep;
        }
      )
    else
      "git+file://${location}?rev=${revision}";
  flake = builtins.getFlake reference;
in
"${builtins.unsafeDiscardStringContext flake.outPath} ${flake.narHash}"
