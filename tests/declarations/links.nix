{
  lib,
  pkgs,
  direct,
  owned,
  declarations,
  fails,
  owners,
  furnish,
  executor,
  link,
}:
let
  group = {
    source = "/absent/editable/skills";
    names = [
      "architect"
      "nested/implementer"
      "orchestrator"
    ];
    destinations = [
      ".claude/skills"
      ".codex/skills"
      ".agents/skills"
    ];
  };
  publish =
    entry:
    declarations (direct {
      furnish.links = [ entry ];
    });
  entries = publish group;
  invalid = entry: fails (publish entry);
  validate =
    value:
    owners.validatePlan {
      kind = "external-link";
      origin = [
        "furnish"
        "links"
        4
      ];
      inherit value;
    };
  locations = value: map (diagnostic: diagnostic.primary.label) (validate value).diagnostics;
  compile =
    entries:
    furnish.compile {
      declarations = entries;
      executors = [ executor ];
      provider = furnish.core.offProvider;
    };
  collision = declarations (owned {
    bookmarks.entries = [ link ];
    furnish.links = [
      {
        source = "/elsewhere";
        names = [ "book" ];
        destinations = [ ".bookmarks" ];
      }
    ];
  });
  labeled = publish (
    group
    // {
      label = "editable skills";
      provenance = "skills checkout";
    }
  );
  empty = group // {
    names = [ ];
  };
in
{
  "test grouped links expand destination then name" = {
    expr =
      map (entry: {
        inherit (entry) destination;
        source = entry.source.value;
      }) entries == builtins.concatMap (
        destination:
        map (name: {
          destination = "${destination}/${name}";
          source = "${group.source}/${name}";
        }) group.names
      ) group.destinations
      && builtins.length entries == 9;
    expected = true;
  };
  "test grouped links add root on one line" = {
    expr = builtins.length (
      publish (group // { destinations = group.destinations ++ [ ".extra/skills" ]; })
    );
    expected = 12;
  };
  "test grouped links accept absolute roots" = {
    expr =
      (builtins.head (
        publish (
          group
          // {
            names = [ "nested/entry" ];
            destinations = [ "/srv/alice/skills" ];
          }
        )
      )).destination;
    expected = "/srv/alice/skills/nested/entry";
  };
  "test grouped links empty dimensions remain inert" = {
    expr = publish empty == [ ] && publish (group // { destinations = [ ]; }) == [ ];
    expected = true;
  };
  "test grouped links empty still validate other dimension" = {
    expr =
      invalid (empty // { destinations = [ "bad/../root" ]; })
      && invalid (
        group
        // {
          destinations = [ ];
          names = [
            "repeat"
            "repeat"
          ];
        }
      )
      && invalid (empty // { source = "relative"; });
    expected = true;
  };
  "test grouped links preserve label and provenance" = {
    expr = builtins.all (
      entry:
      lib.hasPrefix "editable skills $.furnish.links[0]" entry.label
      && entry.provenance.source == "skills checkout"
    ) labeled;
    expected = true;
  };
  "test grouped links generated label keeps origin and dimensions" = {
    expr =
      let
        entry = builtins.elemAt entries 4;
      in
      lib.hasInfix "$.furnish.links[0]" entry.label
      && lib.hasInfix "destinations[1] .codex/skills" entry.label
      && lib.hasInfix "names[1] nested/implementer" entry.label;
    expected = true;
  };
  "test grouped links callback and ancestor claims" = {
    expr = builtins.length (
      declarations (owned {
        hosts = [ "khion" ];
        furnish = {
          roles = [ "desktop" ];
          links = { user, ... }: [
            (
              group
              // {
                source = "/editable/${user.name}";
                hosts = [ "khion" ];
                when = ctx: ctx.role.name == "desktop";
              }
            )
          ];
        };
      })
    );
    expected = 9;
  };
  "test grouped links inactive payloads and callbacks stay lazy" = {
    expr =
      declarations (owned {
        furnish.links = [
          (
            group
            // {
              roles = [ "laptop" ];
              source = throw "inactive source";
              names = throw "inactive names";
              destinations = throw "inactive roots";
            }
          )
        ];
      }) == [ ]
      &&
        declarations (owned {
          hosts = [ "lumi" ];
          furnish.links = _: throw "inactive collection";
        }) == [ ];
    expected = true;
  };
  "test grouped links direct rejects registered claims" = {
    expr =
      fails (direct {
        furnish.links = [ (group // { roles = [ "desktop" ]; }) ];
      })
      && fails (
        declarations (direct {
          furnish.links = _: [ (group // { hosts = [ "khion" ]; }) ];
        })
      );
    expected = true;
  };
  "test grouped links mixed form rejects before payload" = {
    expr = locations (
      group
      // {
        destination = "mixed";
        source = throw "mixed source";
      }
    );
    expected = [ "$.furnish.links[4].destination" ];
  };
  "test grouped links incomplete form rejects before payload" = {
    expr = locations {
      names = [ ];
      source = throw "incomplete source";
    };
    expected = [ "$.furnish.links[4].destinations" ];
  };
  "test grouped links reject invalid forms through public api" = {
    expr =
      invalid (group // { destination = "mixed"; })
      && invalid {
        source = "/root";
        names = [ ];
      }
      && invalid {
        source = "/root";
        destinations = [ ];
      }
      && invalid { source = "/root"; };
    expected = true;
  };
  "test grouped links accumulate independent indexed errors" = {
    expr = locations (
      group
      // {
        source = "relative";
        names = [
          "valid"
          "../bad"
          "valid"
        ];
        destinations = [
          "bad//root"
          ".ok"
          ".ok"
        ];
      }
    );
    expected = [
      "$.furnish.links[4].destinations[0]"
      "$.furnish.links[4].destinations[2]"
      "$.furnish.links[4].names[1]"
      "$.furnish.links[4].names[2]"
      "$.furnish.links[4].source"
    ];
  };
  "test grouped links list shapes have authored fields" = {
    expr = locations (
      group
      // {
        names = "wrong";
        destinations = { };
      }
    );
    expected = [
      "$.furnish.links[4].destinations"
      "$.furnish.links[4].names"
    ];
  };
  "test grouped links path boundaries fail" = {
    expr =
      builtins.all (name: invalid (group // { names = [ name ]; })) [
        ""
        "/absolute"
        "."
        ".."
        "a/../b"
        "a/./b"
        "a//b"
        "a/"
        1
        ./fixtures
      ]
      && builtins.all (destination: invalid (group // { destinations = [ destination ]; })) [
        ""
        "/"
        "/a/../b"
        "a/./b"
        "a//b"
        "a/"
        1
        ./fixtures
      ]
      && builtins.all (source: invalid (group // { inherit source; })) [
        ""
        "/"
        "/a/../b"
        "/a//b"
        "/a/"
        "relative"
        1
        ./fixtures
        pkgs.hello
      ];
    expected = true;
  };
  "test grouped links context strings fail" = {
    expr =
      invalid (group // { source = "${pkgs.hello}/skills"; })
      && invalid (group // { names = [ "${pkgs.hello}" ]; })
      && invalid (group // { destinations = [ "${pkgs.hello}" ]; });
    expected = true;
  };
  "test grouped links cross subsystem collisions use common backend" = {
    expr = fails (compile collision).manifestData;
    expected = true;
  };
  "test grouped links own collisions use generated label" = {
    expr =
      let
        resources = publish (
          group
          // {
            names = [
              "a/b"
              "b"
            ];
            destinations = [
              ".x"
              ".x/a"
            ];
          }
        );
      in
      fails (compile resources).manifestData;
    expected = true;
  };
  "test grouped links authored label keeps context in collision diagnostic" = {
    expr =
      let
        resources = publish (
          group
          // {
            label = "editable skills";
            names = [
              "a/b"
              "b"
            ];
            destinations = [
              ".x"
              ".x/a"
            ];
          }
        );
        projections = map (
          entry: furnish.core.indexProjection (furnish.core.deriveDestination entry)
        ) resources;
        text = furnish.core.renderDiagnostics (furnish.core.collisionDiagnostics projections);
      in
      lib.hasInfix "editable skills $.furnish.links[0] destinations[0] .x names[0] a/b" text
      && lib.hasInfix "editable skills $.furnish.links[0] destinations[1] .x/a names[1] b" text;
    expected = true;
  };
  "test grouped links final containment remains authoritative" = {
    expr =
      fails
        (compile (
          publish (
            group
            // {
              names = [ "entry" ];
              destinations = [ "/outside" ];
            }
          )
        )).manifestData;
    expected = true;
  };
  "test grouped links filtered authored index survives expansion" = {
    expr =
      let
        resources = declarations (owned {
          furnish.links = [
            (group // { hosts = [ "lumi" ]; })
            group
          ];
        });
      in
      lib.hasInfix "$.furnish.links[1]" (builtins.head resources).label;
    expected = true;
  };
}
