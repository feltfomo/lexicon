# the declaration compiler. native demands size home manager fields through a
# direct target. the other cases run one registered extension block over size
# entries or recursive levels with parse callbacks, defaults, metadata and lazy
# preparation. inactive entries carry throwing payloads and an inactive branch a
# throwing callback, so demand stays selected-only on both sides
{
  api,
  lib,
  pkgs,
  system,
  size,
  records,
  ...
}:
let
  target = {
    host.name = "host";
    host.system = "x86_64-linux";
    user.name = "user";
  };

  extension =
    shape:
    { definitions, axiom, ... }:
    let
      mixed = shape == "mixed";
      deep = shape == "deep";
      integer = {
        required = true;
        onMissing = _: {
          code = "compiler/required";
          severity = "error";
          message = "missing integer";
        };
        parse =
          value:
          if builtins.isInt value then
            axiom.validation.success (value + 1)
          else
            axiom.validation.failure [
              {
                code = "compiler/integer";
                severity = "error";
                message = "expected integer";
              }
            ];
      };
      record =
        children:
        definitions.record {
          fields = {
            n = integer;
            defaulted.default = 7;
          };
          inherit children;
          prepare =
            { structure, ... }:
            {
              inherit (structure) n;
              opaque = throw "unused compiler preparation";
            };
        };
      collection = definitions.collection {
        item = record { };
        contextual = true;
      };
      node =
        if deep then
          definitions.recursive (self: record { next = definitions.collection { item = self; }; })
        else if mixed then
          definitions.record {
            children = {
              hm = definitions.forOutputs [ "homeManager" ] collection;
              resources = definitions.forOutputs [ "resources" ] collection;
            };
          }
        else
          definitions.record {
            children = {
              entries = collection;
              inactive = definitions.record { children.entries = collection; };
            };
          };
      projectEntry = value: metadata: origin: prepared: {
        inherit (value) n defaulted;
        inherit (metadata.self) tag;
        origin = origin.self;
        prepared = prepared.self.n;
      };
      walk =
        value: metadata: origins: prepared:
        [ (projectEntry value metadata origins prepared) ]
        ++ lib.concatLists (
          lib.imap0 (
            index: child:
            walk child (builtins.elemAt metadata.children.next index)
              (builtins.elemAt origins.children.next index)
              (builtins.elemAt prepared.children.next index)
          ) (value.next or [ ])
        );
      entries =
        field: value: metadata: origins: prepared:
        lib.imap0 (
          index: entry:
          projectEntry entry (builtins.elemAt metadata.children.${field} index) (builtins.elemAt
            origins.children.${field}
            index
          ) (builtins.elemAt prepared.children.${field} index)
        ) value.${field};
    in
    {
      name = "component-compiler";
      metadata = [
        {
          name = "tag";
          field = {
            default = 0;
            validate = builtins.isInt;
          };
        }
      ];
      blocks = [
        {
          name = "sample";
          scope = "user";
          outputs = [ "homeManager" ] ++ lib.optional mixed "resources";
          inherit node;
          lower =
            {
              value,
              metadata,
              origins,
              prepared,
              context,
            }:
            if context.output == "resources" then
              {
                resources = lib.imap0 (index: entry: {
                  kind = "external-link";
                  value = {
                    source = "/external/${toString entry.n}";
                    destination = ".sample/${toString entry.n}";
                  };
                  origin = (builtins.elemAt origins.children.resources index).self;
                }) value.resources;
              }
            else
              {
                homeManager = [
                  {
                    origin = origins.self;
                    module.observed = {
                      entries =
                        if deep then
                          walk value metadata origins prepared
                        else
                          entries (if mixed then "hm" else "entries") value metadata origins prepared;
                      context = context.config.marker;
                      inherit (context) output;
                    };
                  }
                ];
              };
        }
      ];
    };

  compile =
    shape: raw:
    let
      configured = api.lexicon.configure { extensions = [ (extension shape) ]; };
      inherit (configured) ownerships;
      roster = ownerships.toRoster [
        (ownerships.define.host "host" { inherit system; })
        (ownerships.define.user "user" { hosts = [ "host" ]; })
      ];
    in
    configured.forRoster { inherit roster; } { sample = raw; };

  entry = index: {
    n = index;
    metadata.tag = index + 10;
  };
  inactive = {
    when = _: false;
    n = throw "inactive compiler payload";
  };
  entries = [ inactive ] ++ builtins.genList entry size;
  nested =
    index:
    entry index
    // {
      next =
        if index + 1 < size then
          [
            inactive
            (nested (index + 1))
          ]
        else
          [ ];
    };

  flat =
    collected:
    compile "flat" {
      entries = collected;
      inactive = {
        when = _: false;
        entries = _: throw "inactive compiler callback";
      };
    };

  mixed =
    resources:
    compile "mixed" {
      hm = entries;
      inherit resources;
    };

  arguments = marker: {
    inherit pkgs lib;
    host = {
      name = "host";
      inherit system;
    };
    user = {
      name = "user";
      home = "/home/user";
    };
    config = {
      inherit marker;
      networking.hostName = "host";
      lexicon.furnish.declarations = [ ];
    };
  };

  home =
    declaration: marker: (builtins.head (declaration.homeManager (arguments marker)).imports).observed;

  # native imports also hold module functions, which carry no declarations
  resourceDeclarations =
    module:
    if builtins.isAttrs module && module ? lexicon && module.lexicon ? furnish then
      module.lexicon.furnish.declarations
    else
      [ ];

  combined = mixed (
    context:
    if context.config.marker == "resource" && context.output == "resources" then
      entries
    else
      throw "wrong resource bridge config"
  );
in
{
  native =
    (
      (api.lexicon.forTarget { inherit target; } { homeManager.environment = records (_: true); })
      .homeManager
      { inherit lib pkgs; }
    ).imports;

  wide = home (flat entries) 0;

  deep = home (compile "deep" (nested 0)) 0;

  prepared = builtins.genList (home (flat entries)) size;

  dynamic = home (flat (_: entries)) 0;

  single = home (mixed (_: throw "unrequested resource callback")) 0;

  combined = {
    home = home combined "home";
    resources = map (entry: {
      inherit (entry) destination;
      source = entry.source.value;
    }) (lib.concatMap resourceDeclarations (combined.nixos (arguments "resource")).imports);
  };
}
