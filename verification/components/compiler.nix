{
  project,
  component,
  size,
  bad,
  outputProjection ? "default",
}:
let
  inherit (project.inputs.nixpkgs) lib;
  pkgs = project.inputs.nixpkgs.legacyPackages.${builtins.currentSystem};
  mixed = builtins.elem component [
    "compiler-single"
    "compiler-combined"
  ];
  deep = component == "compiler-deep";
  extension =
    { definitions, axiom, ... }:
    let
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
            defaulted = {
              default = 7;
            };
          };
          inherit children;
          prepare = { structure, ... }: {
            inherit (structure) n;
            opaque = throw "unused compiler preparation";
          };
        };
      entry = record { };
      collection = definitions.collection {
        item = entry;
        contextual = true;
      };
      node =
        if deep then
          definitions.recursive (
            self:
            record {
              next = definitions.collection { item = self; };
            }
          )
        else
          definitions.record {
            children =
              if mixed then
                {
                  hm = definitions.forOutputs [ "homeManager" ] collection;
                  resources = definitions.forOutputs [ "resources" ] collection;
                }
              else
                {
                  entries = collection;
                  inactive = definitions.record { children.entries = collection; };
                };
          };
      projectEntry = value: metadata: origin: prepared: {
        inherit (value) n defaulted;
        tag = metadata.self.tag;
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
  configured = project.lib.lexicon.configure { extensions = [ extension ]; };
  inherit (configured) ownerships;
  roster = ownerships.toRoster [
    (ownerships.define.host "host" { system = builtins.currentSystem; })
    (ownerships.define.user "user" { hosts = [ "host" ]; })
  ];
  lexicon = configured.forRoster { inherit roster; };
  entry = index: {
    n = if bad then "bad" else index;
    metadata.tag = index + 10;
  };
  inactive = {
    when = _: false;
    n = throw "inactive compiler payload";
  };
  entries = [ inactive ] ++ builtins.genList entry size;
  nested =
    index:
    (entry index)
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
  raw =
    if deep then
      nested 0
    else if mixed then
      {
        hm = entries;
        resources =
          if component == "compiler-single" then
            _: throw "unrequested resource callback"
          else
            context:
            if context.config.marker == "resource" && context.output == "resources" then
              entries
            else
              throw "wrong resource bridge config";
      }
    else
      {
        entries = if component == "compiler-dynamic" then _: entries else entries;
        inactive = {
          when = _: false;
          entries = _: throw "inactive compiler callback";
        };
      };
  declaration = lexicon { sample = raw; };
  arguments = marker: {
    inherit pkgs lib;
    host = {
      name = "host";
      system = builtins.currentSystem;
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
  home = marker: (builtins.head (declaration.homeManager (arguments marker)).imports).observed;
  resources = builtins.concatMap (
    module:
    if builtins.isAttrs module && module ? lexicon && module.lexicon ? furnish then
      module.lexicon.furnish.declarations
    else
      [ ]
  ) (declaration.nixos (arguments "resource")).imports;
  projected =
    let
      dependencies = import (project.outPath + "/src/dependencies.nix") {
        inherit lib;
        axiom = project.inputs.axiom.lib.axiom { inherit lib; };
        krisisSource = project.inputs.krisis;
      };
      compiler = import (project.outPath + "/src/declarations") dependencies;
      environment = compiler.configure { extensions = [ extension ]; };
      prepared = (environment.bind { inherit roster; }).prepare { sample = raw; };
    in
    prepared.compile {
      scope = "user";
      outputs = if outputProjection == "missing" then [ ] else [ "unsupported" ];
      context = arguments 0 // {
        output = "homeManager";
      };
    };
in
if outputProjection != "default" then
  projected
else if component == "compiler-prepared" then
  builtins.genList home size
else if component == "compiler-combined" then
  {
    home = home "home";
    resources = map (entry: {
      inherit (entry) destination;
      source = entry.source.value;
    }) resources;
  }
else
  home 0
