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
  grouped-links-expand-destination-then-name =
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
  grouped-links-add-root-on-one-line =
    builtins.length (publish (group // { destinations = group.destinations ++ [ ".extra/skills" ]; }))
    == 12;
  grouped-links-accept-absolute-roots =
    (builtins.head (
      publish (
        group
        // {
          names = [ "nested/entry" ];
          destinations = [ "/srv/alice/skills" ];
        }
      )
    )).destination == "/srv/alice/skills/nested/entry";
  grouped-links-empty-dimensions-remain-inert =
    publish empty == [ ] && publish (group // { destinations = [ ]; }) == [ ];
  grouped-links-empty-still-validate-other-dimension =
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
  grouped-links-preserve-label-and-provenance = builtins.all (
    entry:
    lib.hasPrefix "editable skills $.furnish.links[0]" entry.label
    && entry.provenance.source == "skills checkout"
  ) labeled;
  grouped-links-generated-label-keeps-origin-and-dimensions =
    let
      entry = builtins.elemAt entries 4;
    in
    lib.hasInfix "$.furnish.links[0]" entry.label
    && lib.hasInfix "destinations[1] .codex/skills" entry.label
    && lib.hasInfix "names[1] nested/implementer" entry.label;
  grouped-links-callback-and-ancestor-claims =
    builtins.length (
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
    ) == 9;
  grouped-links-inactive-payloads-and-callbacks-stay-lazy =
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
  grouped-links-direct-rejects-registered-claims =
    fails (direct {
      furnish.links = [ (group // { roles = [ "desktop" ]; }) ];
    })
    && fails (
      declarations (direct {
        furnish.links = _: [ (group // { hosts = [ "khion" ]; }) ];
      })
    );
  grouped-links-mixed-form-rejects-before-payload =
    locations (
      group
      // {
        destination = "mixed";
        source = throw "mixed source";
      }
    ) == [ "$.furnish.links[4].destination" ];
  grouped-links-incomplete-form-rejects-before-payload =
    locations {
      names = [ ];
      source = throw "incomplete source";
    } == [ "$.furnish.links[4].destinations" ];
  grouped-links-reject-invalid-forms-through-public-api =
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
  grouped-links-accumulate-independent-indexed-errors =
    locations (
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
    ) == [
      "$.furnish.links[4].destinations[0]"
      "$.furnish.links[4].destinations[2]"
      "$.furnish.links[4].names[1]"
      "$.furnish.links[4].names[2]"
      "$.furnish.links[4].source"
    ];
  grouped-links-list-shapes-have-authored-fields =
    locations (
      group
      // {
        names = "wrong";
        destinations = { };
      }
    ) == [
      "$.furnish.links[4].destinations"
      "$.furnish.links[4].names"
    ];
  grouped-links-path-boundaries-fail =
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
  grouped-links-context-strings-fail =
    invalid (group // { source = "${pkgs.hello}/skills"; })
    && invalid (group // { names = [ "${pkgs.hello}" ]; })
    && invalid (group // { destinations = [ "${pkgs.hello}" ]; });
  grouped-links-cross-subsystem-collisions-use-common-backend = fails (compile collision)
    .manifestData;
  grouped-links-own-collisions-use-generated-label =
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
  grouped-links-authored-label-keeps-context-in-collision-diagnostic =
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
  grouped-links-final-containment-remains-authoritative =
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
  grouped-links-filtered-authored-index-survives-expansion =
    let
      resources = declarations (owned {
        furnish.links = [
          (group // { hosts = [ "lumi" ]; })
          group
        ];
      });
    in
    lib.hasInfix "$.furnish.links[1]" (builtins.head resources).label;
}
