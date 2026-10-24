{
  lib,
  axiom,
  compiler,
}:
let
  extension = { definitions, ... }: {
    name = "observed";
    metadata = [
      {
        name = "tag";
        field = {
          default = 0;
          parse = value: builtins.trace "compiler metadata" (axiom.validation.success value);
        };
      }
    ];
    blocks = [
      {
        name = "sample";
        scope = "user";
        outputs = [ "homeManager" ];
        node = definitions.record {
          children.entries = definitions.collection {
            contextual = true;
            item = definitions.record {
              fields = {
                id = {
                  parse =
                    value: builtins.trace "compiler parse ${toString value}" (axiom.validation.success (value + 1));
                };
                defaulted = {
                  default = 7;
                  normalize = value: builtins.trace "compiler normalize" value;
                };
              };
              prepare =
                { structure, ... }:
                builtins.trace "compiler preparation ${toString structure.id}" {
                  inherit (structure) id;
                  opaque = throw "compiler forced opaque preparation";
                };
            };
          };
          prepare = _: builtins.trace "compiler preparation root" { safe = true; };
        };
        lower =
          {
            value,
            metadata,
            origins,
            prepared,
            context,
          }:
          builtins.trace "compiler lowering" {
            homeManager = [
              {
                origin = origins.self;
                module = {
                  entries = lib.imap0 (index: entry: {
                    inherit (entry) id defaulted;
                    tag = (builtins.elemAt metadata.children.entries index).self.tag;
                    origin = (builtins.elemAt origins.children.entries index).self;
                    prepared = (builtins.elemAt prepared.children.entries index).self.id;
                  }) value.entries;
                  inherit (context) marker;
                  root = prepared.self.safe;
                };
              }
            ];
          };
      }
    ];
  };
  environment = compiler.configure { extensions = [ extension ]; };
  roster = environment.ownerships.toRoster [
    (environment.ownerships.define.host "host")
    (environment.ownerships.define.user "user" { hosts = [ "host" ]; })
  ];
  entries = [
    {
      when = _: false;
      id = throw "compiler inactive payload";
    }
    {
      id = 0;
      metadata.tag = 10;
    }
    {
      id = 1;
      metadata.tag = 11;
    }
  ];
  run =
    dynamic:
    let
      prepared = (environment.bind { inherit roster; }).prepare {
        sample.entries = if dynamic then _: builtins.trace "compiler callback" entries else entries;
      };
      compile =
        marker:
        (builtins.head
          (prepared.compile {
            scope = "user";
            context = {
              inherit marker;
              host.name = "host";
              user.name = "user";
            };
            outputs = [ "homeManager" ];
          }).homeManager
        ).module;
    in
    {
      first = compile 0;
      second = compile 1;
    };
  exceptional =
    name:
    let
      env = compiler.configure {
        extensions = [
          ({ definitions, ... }: {
            name = "exception";
            blocks = [
              {
                name = "sample";
                scope = "user";
                outputs = [ "homeManager" ];
                node = definitions.contextual (
                  definitions.record {
                    fields.id =
                      if name == "parse" then
                        {
                          parse = _: throw "compiler parse exception";
                        }
                      else
                        {
                          default = 0;
                          normalize = value: if name == "normalize" then throw "compiler normalize exception" else value;
                        };
                    prepare = _: if name == "preparation" then throw "compiler preparation exception" else { };
                  }
                );
                lower =
                  { value, prepared, ... }:
                  if name == "lowering" then
                    throw "compiler lowering exception"
                  else
                    builtins.seq value.id (builtins.seq prepared.self { homeManager = [ ]; });
              }
            ];
          })
        ];
      };
      prepared = (env.bind { direct = true; }).prepare {
        sample = if name == "callback" then _: throw "compiler callback exception" else { id = 0; };
      };
    in
    prepared.compile {
      scope = "user";
      context = { };
      outputs = [ "homeManager" ];
    };
in
{
  static = run false;
  dynamic = run true;
  exceptions = lib.genAttrs [ "parse" "normalize" "preparation" "lowering" "callback" ] exceptional;
}
