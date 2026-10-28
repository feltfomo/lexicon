# the benchmark catalog and analysis, fed fixture records. no evaluator runs,
# so every rule the report applies is checked against records whose counters,
# failures and evaluators are chosen here
{ lib }:
let
  analysis = import ../../bench/analysis { inherit lib; };
  catalog = import ../../bench/workloads;

  store = builtins.storeDir;
  baselineSource = "${store}/00000000000000000000000000000000-source";
  candidateSource = "${store}/11111111111111111111111111111111-source";
  evaluator = {
    version = "2.34.8";
    outPath = "${store}/22222222222222222222222222222222-nix-2.34.8";
  };

  # counts split between two owners so the per-owner attribution has to sum them
  statistics =
    {
      calls ? 100,
      thunks ? 50,
      source,
    }:
    {
      nrFunctionCalls = calls;
      nrPrimOpCalls = 10;
      nrThunks = thunks;
      values = {
        number = 30;
        bytes = 480;
      };
      envs = {
        number = 20;
        bytes = 160;
      };
      sets = {
        number = 5;
        bytes = 120;
      };
      list = {
        elements = 7;
        concats = 2;
        bytes = 56;
      };
      nrOpUpdates = 3;
      nrOpUpdateValuesCopied = 9;
      cpuTime = 0.25;
      gc.heapSize = 4096;
      functions = [
        {
          file = "${source}/src/ownerships/engine.nix";
          line = 1;
          column = 1;
          count = calls - 40;
          name = null;
        }
        {
          file = "«github:feltfomo/krisis/c48e40834fe90299096d2988433b17f650c30c8a?narHash=sha256-x»/src/types.nix";
          line = 2;
          column = 3;
          count = 40;
          name = "closed";
        }
      ];
    };

  # one fixture sample. overrides replace runner metadata, statistics or the
  # projection, so a case states only what differs from a clean sample
  record =
    {
      order,
      phase,
      side,
      calls ? 100,
      thunks ? 50,
      meta ? { },
      source ? if side == "baseline" then baselineSource else candidateSource,
      stats ? statistics { inherit calls thunks source; },
      projection ? "same",
    }:
    analysis.sample {
      name = "${toString order}-${phase}-${side}";
      bench = candidateSource;
      meta = {
        inherit
          side
          phase
          order
          source
          evaluator
          ;
        exit = 0;
        timedOut = false;
        wallNs = 120000000 + order * 1000000;
        peakRssKiB = 2048;
        machine = "lumi";
        load = 0.5;
      }
      // meta;
      inherit stats projection;
    };

  # a full schedule where change picks each sample's overrides by its position
  cell =
    change:
    lib.imap0 (
      order: step:
      record (
        {
          inherit order;
          inherit (step) phase side;
        }
        // change order step
      )
    ) analysis.schedule;

  clean = cell (_: _: { });

  candidateCalls = cell (_: step: lib.optionalAttrs (step.side == "candidate") { calls = 130; });

  run = {
    baseline = {
      spec = "main";
      revision = "d682ad2";
      dirty = false;
      source = baselineSource;
      narHash = "sha256-b";
    };
    candidate = {
      spec = "worktree";
      revision = "d682ad2";
      dirty = true;
      source = candidateSource;
      narHash = "sha256-c";
    };
    bench = candidateSource;
    system = "x86_64-linux";
    timeoutSeconds = 600;
    inherit evaluator;
  };

  compared =
    cells:
    analysis.compare {
      inherit run cells;
      inherit (catalog) limits;
    };

  reasons = samples: (analysis.cell samples).reasons;
in
{
  tests = {
    "test the catalog lists every family without forcing a case" = {
      expr = {
        hasDen = builtins.elem "fleet.den" catalog.names;
        hasPlain = builtins.elem "fleet.plain" catalog.names;
        plainRunnable = builtins.elem "fleet.plain" catalog.runnable;
        subsystems = builtins.length (builtins.filter (lib.hasPrefix "subsystem.") catalog.names);
      };
      expected = {
        hasDen = true;
        hasPlain = true;
        plainRunnable = false;
        subsystems = 26;
      };
    };

    "test the plain fleet is a recorded limit that fails explicitly" = {
      expr = catalog.project {
        project = throw "the plain fleet forced a lexicon source";
        system = "x86_64-linux";
        size = 4;
        name = "fleet.plain";
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "fleet.plain waits on the plain host, band 6";
    };

    "test an unknown workload is refused before any source is read" = {
      expr = catalog.project {
        project = throw "an unknown workload forced a lexicon source";
        system = "x86_64-linux";
        size = 4;
        name = "subsystem.nothing.here";
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "unknown benchmark workload subsystem.nothing.here";
    };

    "test an unsized workload is refused" = {
      expr = catalog.project {
        project = throw "an unsized workload forced a lexicon source";
        system = "x86_64-linux";
        size = 5;
        name = "subsystem.toml.generate";
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "benchmark workload subsystem.toml.generate has no size 5";
    };

    "test a clean cell aggregates equal counters into zero deltas" = {
      expr =
        let
          result = analysis.cell clean;
        in
        {
          inherit (result) _tag;
          calls = result.counters.nrFunctionCalls;
          heap = result.counters.heapBytes.candidate.value;
          wall = result.timing.wallMs;
        };
      expected = {
        _tag = "accepted";
        calls = {
          baseline = {
            value = 100;
            deterministic = true;
          };
          candidate = {
            value = 100;
            deterministic = true;
          };
          change = 0;
          permille = 0;
          nondeterministic = false;
        };
        heap = 816;
        wall = {
          baseline = 125;
          candidate = 124;
        };
      };
    };

    "test a candidate change reports its delta and per-owner attribution" = {
      expr =
        let
          result = analysis.cell candidateCalls;
        in
        {
          calls = {
            inherit (result.counters.nrFunctionCalls) change permille nondeterministic;
          };
          owners = lib.mapAttrs (_: entry: entry.change) result.owners;
        };
      expected = {
        calls = {
          change = 30;
          permille = 300;
          nondeterministic = false;
        };
        owners = {
          "src/ownerships" = 30;
          "github:feltfomo/krisis" = 0;
        };
      };
    };

    "test warm-up samples never reach the aggregate" = {
      expr =
        (analysis.cell (cell (_: step: lib.optionalAttrs (step.phase == "warmup") { calls = 900; })))
        .counters.nrFunctionCalls.change;
      expected = 0;
    };

    "test a counter that moves within one side is flagged and keeps its median" = {
      expr =
        let
          thunks = [
            50
            53
            51
          ];
          moving = cell (
            order: step:
            lib.optionalAttrs (step.side == "candidate" && step.phase == "measure") {
              thunks = builtins.elemAt thunks (
                builtins.length (
                  builtins.filter (s: s.side == "candidate" && s.phase == "measure") (
                    lib.take order analysis.schedule
                  )
                )
              );
            }
          );
          result = (analysis.cell moving).counters;
        in
        {
          thunks = {
            inherit (result.nrThunks) change nondeterministic;
            inherit (result.nrThunks.candidate) value deterministic;
          };
          callsFlagged = result.nrFunctionCalls.nondeterministic;
        };
      expected = {
        thunks = {
          change = 1;
          nondeterministic = true;
          value = 51;
          deterministic = false;
        };
        callsFlagged = false;
      };
    };

    "test every failed sample is listed and the projection check is skipped" = {
      expr = reasons (
        cell (
          order: _:
          if order == 2 then
            {
              meta.exit = 1;
              projection = null;
            }
          else if order == 5 then
            {
              meta = {
                exit = 137;
                timedOut = true;
              };
              stats = null;
              projection = null;
            }
          else if order == 6 then
            { projection = "different"; }
          else
            { }
        )
      );
      expected = [
        "2-measure-baseline exited 1"
        "2-measure-baseline wrote no projection"
        "5-measure-baseline timed out"
        "5-measure-baseline wrote no statistics"
        "5-measure-baseline wrote no projection"
      ];
    };

    "test a projection that differs between sides rejects the cell" = {
      expr = reasons (
        cell (_: step: lib.optionalAttrs (step.side == "candidate") { projection = "other"; })
      );
      expected = [ "the baseline and candidate projections differ" ];
    };

    "test a projection that differs within one side rejects the cell" = {
      expr = reasons (cell (order: _: lib.optionalAttrs (order == 7) { projection = "other"; }));
      expected = [ "the candidate projection differs between its samples" ];
    };

    "test a cell cut short by a failure is incomplete" = {
      expr = reasons (lib.take 3 (cell (order: _: lib.optionalAttrs (order == 2) { meta.exit = 1; })));
      expected = [
        "2-measure-baseline exited 1"
        "the schedule ran 3 of 8 samples in order"
      ];
    };

    "test call counts that don't sum to nrFunctionCalls reject the record" = {
      expr = reasons (
        cell (
          order: step:
          lib.optionalAttrs (order == 0) {
            stats =
              statistics {
                calls = 100;
                thunks = 50;
                source = baselineSource;
              }
              // {
                nrFunctionCalls = 99;
              };
          }
        )
      );
      expected = [ "0-warmup-baseline call counts sum to 100, not nrFunctionCalls" ];
    };

    "test a malformed record names its missing fields" = {
      expr = builtins.head (
        reasons (
          [
            (analysis.sample {
              name = "0-warmup-baseline";
              bench = candidateSource;
              meta = {
                side = "baseline";
                phase = "warmup";
              };
              stats = null;
              projection = null;
            })
          ]
          ++ lib.drop 1 clean
        )
      );
      expected = "0-warmup-baseline has a malformed record missing exit, timedOut, wallNs, machine, load, source, evaluator";
    };

    # record validation reads nrFunctionCalls and the call counts, nothing else
    "test a rejected cell never forces counters" = {
      expr =
        (analysis.cell (
          cell (
            order: _:
            if order == 1 then
              { meta.exit = 1; }
            else
              {
                stats = {
                  nrFunctionCalls = 0;
                  nrThunks = throw "a rejected cell forced its counters";
                  functions = [ ];
                };
              }
          )
        ))._tag;
      expected = "rejected";
    };

    "test records from another evaluator refuse the comparison" = {
      expr = compared {
        "subsystem.toml.generate"."4" = cell (
          order: _:
          lib.optionalAttrs (order == 4) {
            meta.evaluator = evaluator // {
              version = "2.95.4";
            };
          }
        );
      };
      expected = {
        _tag = "refused";
        reasons = [
          "records come from different evaluators: 2.34.8 at ${evaluator.outPath}, 2.95.4 at ${evaluator.outPath}"
        ];
      };
    };

    "test a dirty baseline refuses the comparison" = {
      expr =
        (analysis.compare {
          run = run // {
            baseline = run.baseline // {
              dirty = true;
            };
          };
          cells = { };
          limits = { };
        }).reasons;
      expected = [ "the baseline source main was dirty" ];
    };

    "test a refused comparison renders as a thrown refusal" = {
      expr = analysis.render {
        _tag = "refused";
        reasons = [ "records come from different evaluators: a, b" ];
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "benchmark comparison refused, records come from different evaluators: a, b";
    };

    "test the report names deltas, rejections and declared limits" = {
      expr =
        let
          text = analysis.render (compared {
            "subsystem.ownerships.resolve" = {
              "4" = candidateCalls;
              "16" = cell (order: _: lib.optionalAttrs (order == 3) { meta.exit = 1; });
            };
          });
        in
        map (fragment: lib.hasInfix fragment text) [
          "| subsystem.ownerships.resolve | 4 | accepted | 100 → 130 (+30, +300‰) |"
          "  - 3-measure-candidate exited 1"
          "- fleet.plain is declared and can't run, fleet.plain waits on the plain host, band 6"
          "- 4: src/ownerships 60 → 90 (+30, +500‰)"
        ];
      expected = [
        true
        true
        true
        true
      ];
    };

    "test owners drop revisions and store hashes" = {
      expr =
        map
          (analysis.ownerOf {
            source = baselineSource;
            bench = candidateSource;
          })
          [
            "«github:nix-community/nixpkgs.lib/0e79af5e3d4dcfcd676ab5ba3f95d2e3352e078c?narHash=x»/lib/modules.nix"
            "${store}/33333333333333333333333333333333-home-manager/nixos/default.nix"
            "${candidateSource}/bench/workloads/subsystem/toml.nix"
            "${baselineSource}/src/furnish/core.nix"
            "«path:/somewhere»/default.nix"
            "/elsewhere/default.nix"
            null
          ];
      expected = [
        "github:nix-community/nixpkgs.lib"
        "store:home-manager"
        "bench/workloads/subsystem"
        "src/furnish"
        "path:/somewhere"
        "other"
        "unpositioned"
      ];
    };
  };
}
