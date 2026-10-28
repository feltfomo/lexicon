{
  lib,
  context ? "context-free",
}:
let
  render = import ../../src/toml/render.nix;
  node = kind: value: { inherit kind value; };
  scalar = node "scalar";
  table = node "table";
  array = node "array";
  inline = attrs: node "inline" (table attrs);
  tables = attrs: node "tables" (array (map table attrs));
  literal = node "literal";
  fixture = encoded: expected: {
    inherit encoded expected;
    rendered = render encoded;
  };
  del = builtins.fromJSON ''"\u007f"'';
  spelling = "1979-05-27t07:32:00.123400Z";
  comment = "0x1_0 # trailing\r\n# standalone\r\n";
  fixtures = {
    keys =
      fixture
        (table {
          "" = scalar "empty key";
          "a.b" = table { "c.d" = table { "" = scalar 1; }; };
          __lexiconToml = scalar "ordinary application key";
          quoted = scalar "quote \" slash \\ tab\t newline\n${del}";
        })
        {
          "" = "empty key";
          "a.b"."c.d"."" = 1;
          __lexiconToml = "ordinary application key";
          quoted = "quote \" slash \\ tab\t newline\n${del}";
        };
    empty =
      fixture
        (table {
          list = array [ ];
          inline = inline { };
          table = table { };
          tables = tables [ ];
        })
        {
          list = [ ];
          inline = { };
          table = { };
          tables = [ ];
        };
    numbers =
      fixture
        (table {
          minimum = scalar (-9223372036854775807 - 1);
          maximum = scalar 9223372036854775807;
          float = node "float" "1";
          precise = node "float" "1.2345678901234567";
          exponent = node "float" "1e-100";
          boolean = scalar false;
        })
        {
          minimum = -9223372036854775807 - 1;
          maximum = 9223372036854775807;
          float = 1.0;
          precise = 1.2345678901234567;
          exponent = 1.0e-100;
          boolean = false;
        };
    arrays =
      fixture
        (table {
          mixed = array [
            (scalar 1)
            (scalar "two")
            (scalar true)
            (table { x = scalar 3; })
            (array [ (table { y = scalar 4; }) ])
          ];
          automatic = array [
            (table { n = scalar 1; })
            (table { n = scalar 2; })
          ];
          explicit = tables [
            {
              name = scalar "first";
              child = tables [ { enabled = scalar true; } ];
            }
            { }
          ];
          inline = inline {
            table = table { x = scalar 1; };
            tables = tables [ { nested = tables [ { y = scalar true; } ]; } ];
            empty = table { };
          };
        })
        {
          mixed = [
            1
            "two"
            true
            { x = 3; }
            [ { y = 4; } ]
          ];
          automatic = [
            { n = 1; }
            { n = 2; }
          ];
          explicit = [
            {
              name = "first";
              child = [ { enabled = true; } ];
            }
            { }
          ];
          inline = {
            table = {
              x = 1;
            };
            tables = [ { nested = [ { y = true; } ]; } ];
            empty = { };
          };
        };
    comments =
      fixture
        (table {
          inline = inline {
            first = literal comment;
            next = scalar 2;
          };
          mixed = array [
            (literal "1 # no final newline")
            (literal "'''literal\r\nstring'''")
            (literal "[1,\r\n# inner array\r\n2]")
            (literal "{\r\n# inner inline\r\nx=3,\r\n}")
            (literal "\"\"\"basic\nstring\"\"\" # after multiline")
            (scalar 4)
          ];
          next = scalar true;
        })
        {
          inline = {
            first = 16;
            next = 2;
          };
          mixed = [
            1
            "literal\r\nstring"
            [
              1
              2
            ]
            { x = 3; }
            "basic\nstring"
            4
          ];
          next = true;
        };
    context =
      fixture
        (table {
          executable = scalar context;
          literal = literal (builtins.toJSON context);
        })
        {
          executable = context;
          literal = context;
        };
  };
  raw = render (table {
    date = literal spelling;
    values = array (
      map literal [
        "inf"
        "-inf"
        "nan"
        "-0.0"
      ]
    );
  });
  ordered = render (table {
    a = table { leaf = literal "1"; };
    b = literal "2";
    c = array [ (literal "3") ];
    d = tables [ { leaf = literal "4"; } ];
  });
  opaque = render (table {
    literal = literal "1";
    scalar = scalar (throw "renderer forced scalar payload during metadata demand");
  });
  document = "# retained\r\nnumber = 0x1_0\r\nstamp = ${spelling}\r\n";
  tests = {
    "test empty root" = {
      expr = (render (table { })).text;
      expected = "";
    };
    "test scalar keys are sorted" = {
      expr =
        (render (table {
          z = scalar 2;
          a = scalar 1;
        })).text;
      expected = "\"a\" = 1\n\"z\" = 2\n";
    };
    "test each component is quoted" = {
      expr = lib.hasInfix ''["a.b"."c.d"]'' fixtures.keys.rendered.text;
      expected = true;
    };
    "test del is escaped" = {
      expr =
        lib.hasInfix "\\u007f" fixtures.keys.rendered.text
        && !(lib.hasInfix del fixtures.keys.rendered.text);
      expected = true;
    };
    "test float retains type and precision" = {
      expr =
        lib.hasInfix ''"float" = 1.0'' fixtures.numbers.rendered.text
        && lib.hasInfix "1.2345678901234567" fixtures.numbers.rendered.text
        && lib.hasInfix "1e-100" fixtures.numbers.rendered.text;
      expected = true;
    };
    "test automatic and explicit tables" = {
      expr =
        lib.hasInfix ''[["automatic"]]'' fixtures.arrays.rendered.text
        && lib.hasInfix ''[["explicit"."child"]]'' fixtures.arrays.rendered.text;
      expected = true;
    };
    "test inline does not open table headers" = {
      expr = !(lib.hasInfix ''[["inline"'' fixtures.arrays.rendered.text);
      expected = true;
    };
    "test raw spelling survives" = {
      expr = lib.hasInfix spelling raw.text && lib.hasInfix "-0.0" raw.text;
      expected = true;
    };
    "test comments end before separators" = {
      expr =
        lib.hasInfix "${comment}\n," fixtures.comments.rendered.text
        && lib.hasInfix "1 # no final newline\n," fixtures.comments.rendered.text;
      expected = true;
    };
    "test metadata retains original order and paths" = {
      expr = map (entry: entry.path) ordered.literals;
      expected = [
        [
          "a"
          "leaf"
        ]
        [ "b" ]
        [
          "c"
          0
        ]
        [
          "d"
          0
          "leaf"
        ]
      ];
    };
    "test metadata retains original text" = {
      expr = (builtins.head fixtures.comments.rendered.literals).text;
      expected = comment;
    };
    "test metadata does not force scalar payload" = {
      expr = (builtins.head opaque.literals).text;
      expected = "1";
    };
    "test document is byte preserved" = {
      expr = (render (node "document" document)).text;
      expected = document;
    };
    "test document metadata is opaque" = {
      expr = (render (node "document" (throw "forced document text"))).literals;
      expected = [ ];
    };
    "test context survives both results" = {
      expr =
        builtins.getContext fixtures.context.rendered.text == builtins.getContext context
        &&
          builtins.getContext (builtins.head fixtures.context.rendered.literals).text
          == builtins.getContext context;
      expected = true;
    };
    "test malformed toml stays unvalidated" = {
      expr =
        (render (table {
          value = literal "broken=[";
        })).literals;
      expected = [
        {
          path = [ "value" ];
          text = "broken=[";
        }
      ];
    };
  };
in
{
  inherit tests fixtures;
}
