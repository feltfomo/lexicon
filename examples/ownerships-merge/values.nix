{ lexicon }:
let
  ownerships = lexicon.lib.ownerships { };
  roster = ownerships.toRoster [
    (ownerships.define.host "laptop")
    (ownerships.define.user "alice" { hosts = [ "laptop" ]; })
  ];
  context = {
    host.name = "laptop";
    user.name = "alice";
  };
  units = [
    {
      label = "shared editor";
      tools = [ "git" ];
      editor = {
        command = "helix";
        wrap = true;
      };
    }
    {
      label = "alice's tools";
      users = [ "alice" ];
      tools = [
        "git"
        "ripgrep"
      ];
      editor.tabWidth = 2;
    }
  ];
  conflicting = [
    {
      label = "shared editor";
      editor = {
        command = "helix";
        wrap = true;
      };
    }
    {
      label = "chosen editor";
      editor.command = "vim";
    }
  ];
  resolve = ownerships.mkResolve roster;
  # strict scalars expose disagreement while lists keep declaration order
  strictOrdered = {
    listStrategy = "ordered-concat";
    scalarPolicy =
      path: left: right:
      if left.value == right.value then left.value else throw "different values at ${path}";
    attrsetTreatment = "deep";
  };
in
{
  inherit
    roster
    units
    context
    conflicting
    ;
  combined = resolve units context;
  conflict = resolve conflicting context;
  # this profile changes only the conflicting leaf
  replaced = ownerships.mkResolveProfiled {
    profileForPath = path: if path == "editor.command" then "last-wins" else null;
  } roster conflicting context;
  # selecting the parent path replaces the whole editor subtree
  wholeEditor = ownerships.mkResolveProfiled {
    profileForPath = path: if path == "editor" then "last-wins" else null;
  } roster conflicting context;
  # a named profile changes list behavior only for tools
  deduplicated = ownerships.mkResolveProfiled {
    profiles = {
      strict-ordered = strictOrdered;
      unique-tools = strictOrdered // {
        listStrategy = "dedup-union";
      };
    };
    profileForPath = path: if path == "tools" then "unique-tools" else null;
  } roster units context;
}
