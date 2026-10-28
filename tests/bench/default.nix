# the benchmark catalog and analysis, fed fixture records. no evaluator runs,
# so every rule the report applies is checked against records whose counters,
# profiles, failures and evaluators are chosen here
{ lib }:
let
  analysis = import ../../bench/analysis { inherit lib; };
  catalog = import ../../bench/workloads;
  schedule = import ../../bench/runner/schedule.nix;

  store = builtins.storeDir;
  baselineSource = "${store}/00000000000000000000000000000000-source";
  candidateSource = "${store}/11111111111111111111111111111111-source";
  evaluator = {
    version = "2.34.8";
    outPath = "${store}/22222222222222222222222222222222-nix-2.34.8";
  };

  # both sides mark resolveContext, at different lines. the baseline alone marks
  # mergeContributions and the candidate alone marks indexCollisions
  markerAt = source: owner: name: line: {
    inherit owner name line;
    region = "${owner}.${name}";
    file = "${source}/${owner}/markers.nix";
  };
  markers = {
    baseline = [
      (markerAt baselineSource "src/ownerships" "mergeContributions" 5)
      (markerAt baselineSource "src/ownerships" "resolveContext" 4)
    ];
    candidate = [
      (markerAt candidateSource "src/furnish" "indexCollisions" 4)
      (markerAt candidateSource "src/ownerships" "resolveContext" 5)
    ];
  };

  # counts split between two owners so the per-owner attribution has to sum them.
  # each of the side's markers is entered `entered` times, taken from the first
  # owner's count, and `extra` entries are added beside them
  statistics =
    {
      calls ? 100,
      thunks ? 50,
      entered ? 0,
      extra ? [ ],
      side,
      source,
    }:
    let
      markerEntries = lib.optionals (entered > 0) (
        map (marker: {
          inherit (marker) file line name;
          column = 23;
          count = entered;
        }) markers.${side}
      );
      added = builtins.foldl' (sum: entry: sum + entry.count) 0 (markerEntries ++ extra);
    in
    {
      nrFunctionCalls = calls;
      nrPrimOpCalls = 10;
      primops.add = 10;
      attributes = null;
      nrLookups = 0;
      nrAvoided = 0;
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
          count = calls - 40 - added;
          name = null;
        }
        {
          file = "«github:feltfomo/krisis/c48e40834fe90299096d2988433b17f650c30c8a?narHash=sha256-x»/src/types.nix";
          line = 2;
          column = 3;
          count = 40;
          name = "closed";
        }
      ]
      ++ markerEntries
      ++ extra;
    };

  # a profile as the runner reduces it. each name's count already holds every
  # stack with that frame once, which checks.bench-reduce pins over raw stacks
  reduced = {
    total = 18;
    inclusive = {
      mergeContributions = 7;
      indexCollisions = 4;
      resolveContext = 9;
    };
  };

  # one fixture sample. overrides replace runner metadata, statistics, the
  # profile or the projection, so a case states only what differs from a clean
  # sample. a profiling sample has a profile and no statistics
  record =
    {
      order,
      phase,
      side,
      calls ? 100,
      thunks ? 50,
      entered ? 0,
      extra ? [ ],
      meta ? { },
      source ? if side == "baseline" then baselineSource else candidateSource,
      stats ?
        if phase == "profile" then
          null
        else
          statistics {
            inherit
              calls
              thunks
              entered
              extra
              side
              source
              ;
          },
      profile ? if phase == "profile" then reduced else null,
      projection ? "same",
    }:
    analysis.sample {
      name = "${toString order}-${phase}-${side}";
      bench = candidateSource;
      expected = {
        inherit
          side
          phase
          order
          source
          evaluator
          ;
        workload = "fixture";
        size = 4;
      };
      meta = {
        inherit
          side
          phase
          order
          source
          evaluator
          ;
        workload = "fixture";
        size = 4;
        exit = 0;
        timedOut = false;
        wallNs = 120000000 + order * 1000000;
        peakRssKiB = 2048;
        machine = "lumi";
        load = 0.5;
      }
      // meta;
      inherit
        stats
        profile
        projection
        markers
        ;
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
    ) schedule;

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
    profileFrequency = 1000;
    inherit schedule evaluator;
  };

  budgetsWith = tolerance: {
    evaluator = "2.34.8";
    counters = lib.genAttrs (map (counter: counter.name) analysis.counters) (_: tolerance);
  };

  budgets = budgetsWith {
    permille = 5;
    floor = 20;
  };

  comparedWith =
    budgets: cells:
    analysis.compare {
      inherit
        run
        cells
        markers
        budgets
        ;
      inherit (catalog) limits;
    };

  compared = comparedWith budgets;

  calibrationRun =
    cells:
    (compared cells)
    // {
      run = run // {
        candidate = run.baseline;
      };
    };

  judged = samples: analysis.cell { inherit schedule markers; } samples;

  reasons = samples: (judged samples).reasons;

  badStatistics =
    changed:
    cell (
      order: _:
      lib.optionalAttrs (order == 0) {
        stats =
          (statistics {
            side = "baseline";
            source = baselineSource;
          })
          // changed;
      }
    );
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
          result = judged clean;
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
          result = judged candidateCalls;
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
        (judged (cell (_: step: lib.optionalAttrs (step.phase == "warmup") { calls = 900; })))
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
                  builtins.filter (s: s.side == "candidate" && s.phase == "measure") (lib.take order schedule)
                )
              );
            }
          );
          result = (judged moving).counters;
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
        "the schedule did not complete in order, found 3 of 10 samples"
      ];
    };

    "test repeated sample orders reject even when adjacent phase and side match" = {
      expr = reasons (map (sample: if sample.order == 4 then sample // { order = 3; } else sample) clean);
      expected = [ "the schedule did not complete in order, found 10 of 10 samples" ];
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
                side = "baseline";
                source = baselineSource;
              }
              // {
                nrFunctionCalls = 99;
              };
          }
        )
      );
      expected = [ "0-warmup-baseline function counts do not sum to nrFunctionCalls" ];
    };

    "test a malformed record names its missing fields" = {
      expr = builtins.head (
        reasons (
          [
            (analysis.sample {
              name = "0-warmup-baseline";
              bench = candidateSource;
              expected = {
                workload = "fixture";
                size = 4;
                order = 0;
                side = "baseline";
                phase = "warmup";
                source = baselineSource;
                inherit evaluator;
              };
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
      expected = "0-warmup-baseline has a malformed record missing workload, size, order, exit, timedOut, wallNs, peakRssKiB, machine, load, source, evaluator";
    };

    "test copied samples must match their source and cell identity" = {
      expr = reasons (
        cell (
          order: _:
          lib.optionalAttrs (order == 0) {
            meta = {
              workload = "another-workload";
              size = 16;
              order = 1;
              source = candidateSource;
            };
          }
        )
      );
      expected = [
        "0-warmup-baseline metadata differs from its run or cell in workload, size, order, source"
      ];
    };

    "test malformed metadata rejects a sample before reading its statistics" = {
      expr = reasons (
        cell (
          order: _:
          lib.optionalAttrs (order == 0) {
            meta.timedOut = "false";
            stats = throw "malformed metadata forced statistics";
          }
        )
      );
      expected = [ "0-warmup-baseline has malformed metadata fields timedOut" ];
    };

    "test primop counts must sum to the evaluator total" = {
      expr = reasons (badStatistics {
        primops.add = 9;
      });
      expected = [ "0-warmup-baseline primop counts do not sum to nrPrimOpCalls" ];
    };

    "test malformed function counts and positions reject attribution" = {
      expr =
        map
          (
            entry:
            reasons (badStatistics {
              functions = [ entry ];
            })
          )
          [
            {
              name = null;
              count = -1;
            }
            {
              name = null;
              count = 1;
              line = 1;
            }
            {
              name = null;
              count = 1;
              file = "";
              line = 1;
              column = 0;
            }
            {
              name = null;
              count = 1;
              line = 0;
              column = 0;
            }
            {
              name = null;
              count = 1;
              line = 1;
              column = -1;
            }
            {
              name = 42;
              count = 1;
            }
          ];
      expected = builtins.genList (_: [ "0-warmup-baseline function count entries are malformed" ]) 6;
    };

    "test malformed primop and evaluator counters accumulate" = {
      expr = reasons (badStatistics {
        primops.add = 0;
        nrLookups = -1;
      });
      expected = [
        "0-warmup-baseline statistics lack natural counters nrLookups"
        "0-warmup-baseline primop counts are malformed"
      ];
    };

    # failed admission suppresses instrumentation and aggregate counter demand
    "test a rejected cell never forces counters" = {
      expr =
        (judged (
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

    "test discovery finds owner markers by name and skips test and hidden trees" = {
      expr = map (marker: {
        inherit (marker) region line;
        file = baseNameOf marker.file;
      }) (analysis.discover ./fixtures/tree);
      expected = [
        {
          region = "src/alpha.first";
          line = 3;
          file = "markers.nix";
        }
        {
          region = "src/alpha.second";
          line = 4;
          file = "markers.nix";
        }
        {
          region = "src/alpha/beta.third";
          line = 3;
          file = "markers.nix";
        }
      ];
    };

    "test marker entries compare a shared region and name one-sided ones" = {
      expr =
        let
          result = judged (
            cell (
              _: step: {
                entered = if step.side == "baseline" then 3 else 5;
              }
            )
          );
        in
        lib.mapAttrs (
          _: region:
          {
            inherit (region) _tag;
          }
          // lib.optionalAttrs (region._tag == "both") { inherit (region) change; }
          // lib.optionalAttrs (region._tag == "baselineOnly") { entries = region.baseline.value; }
          // lib.optionalAttrs (region._tag == "candidateOnly") { entries = region.candidate.value; }
        ) result.markers;
      expected = {
        "src/ownerships.resolveContext" = {
          _tag = "both";
          change = 2;
        };
        "src/ownerships.mergeContributions" = {
          _tag = "baselineOnly";
          entries = 3;
        };
        "src/furnish.indexCollisions" = {
          _tag = "candidateOnly";
          entries = 5;
        };
      };
    };

    "test inclusive samples map each marker name to its region" = {
      expr = (judged clean).sampled;
      expected = {
        baseline = {
          "src/ownerships.resolveContext" = {
            _tag = "sampled";
            samples = 9;
            total = 18;
          };
          "src/ownerships.mergeContributions" = {
            _tag = "sampled";
            samples = 7;
            total = 18;
          };
        };
        candidate = {
          "src/ownerships.resolveContext" = {
            _tag = "sampled";
            samples = 9;
            total = 18;
          };
          "src/furnish.indexCollisions" = {
            _tag = "sampled";
            samples = 4;
            total = 18;
          };
        };
      };
    };

    "test a marker name another applied lambda shares is ambiguous" = {
      expr =
        (judged (
          cell (
            _: step:
            lib.optionalAttrs (step.side == "candidate") {
              extra = [
                {
                  file = "${candidateSource}/src/ownerships/engine.nix";
                  line = 30;
                  column = 3;
                  count = 1;
                  name = "resolveContext";
                }
              ];
            }
          )
        )).sampled.candidate."src/ownerships.resolveContext";
      expected._tag = "ambiguous";
    };

    "test a profiling sample without a profile rejects the cell" = {
      expr = reasons (cell (order: _: lib.optionalAttrs (order == 9) { profile = null; }));
      expected = [ "9-profile-candidate wrote no profile" ];
    };

    "test malformed reduced counts reject a profiling cell" = {
      expr = reasons (
        cell (
          order: _:
          lib.optionalAttrs (order == 9) {
            profile = {
              total = 3;
              inclusive.resolveContext = 4;
            };
          }
        )
      );
      expected = [ "9-profile-candidate has a malformed reduced profile" ];
    };

    "test malformed candidate instrumentation fails beside a clean cell" = {
      expr =
        map
          (
            broken:
            (compared {
              "subsystem.ownerships.resolve"."4" = clean;
              "subsystem.ownerships.resolve"."16" = broken;
            }).verdict._tag
          )
          [
            (cell (
              order: _:
              lib.optionalAttrs (order == 3) {
                stats =
                  (statistics {
                    side = "candidate";
                    source = candidateSource;
                  })
                  // {
                    primops.add = 9;
                  };
              }
            ))
            (cell (
              order: _:
              lib.optionalAttrs (order == 9) {
                profile = {
                  total = 3;
                  inclusive.resolveContext = 4;
                };
              }
            ))
          ];
      expected = [
        "fail"
        "fail"
      ];
    };

    "test a counter past its relative tolerance and floor regresses" = {
      expr =
        let
          inherit
            (
              (compared {
                "subsystem.ownerships.resolve"."4" = candidateCalls;
              })
            )
            verdict
            ;
        in
        {
          inherit (verdict) _tag;
          calls = verdict.byCell."subsystem.ownerships.resolve"."4".nrFunctionCalls;
          thunks = verdict.byCell."subsystem.ownerships.resolve"."4".nrThunks;
          regressions = map (entry: { inherit (entry) counter change permille; }) verdict.regressions;
        };
      expected = {
        _tag = "fail";
        calls = "regression";
        thunks = "within";
        regressions = [
          {
            counter = "nrFunctionCalls";
            change = 30;
            permille = 300;
          }
        ];
      };
    };

    "test a move under the absolute floor stays within budget" = {
      expr =
        let
          inherit
            (
              (comparedWith
                (budgetsWith {
                  permille = 5;
                  floor = 31;
                })
                {
                  "subsystem.ownerships.resolve"."4" = candidateCalls;
                }
              )
            )
            verdict
            ;
        in
        {
          inherit (verdict) _tag;
          calls = verdict.byCell."subsystem.ownerships.resolve"."4".nrFunctionCalls;
        };
      expected = {
        _tag = "pass";
        calls = "within";
      };
    };

    "test a fractional permille beyond tolerance regresses before display rounding" = {
      expr =
        (comparedWith
          (budgetsWith {
            permille = 5;
            floor = 2000;
          })
          {
            "subsystem.ownerships.resolve"."4" = cell (
              _: step: { calls = if step.side == "baseline" then 1000000 else 1005999; }
            );
          }
        ).verdict.byCell."subsystem.ownerships.resolve"."4".nrFunctionCalls;
      expected = "regression";
    };

    "test an empty budget cannot pass a comparison" = {
      expr =
        (comparedWith (budgets // { counters = { }; }) {
          "subsystem.ownerships.resolve"."4" = clean;
        }).verdict._tag;
      expected = "uncalibrated";
    };

    "test a comparison with only rejected baseline cells cannot pass" = {
      expr =
        (compared {
          "subsystem.ownerships.resolve"."4" = cell (
            order: _: lib.optionalAttrs (order == 0) { meta.exit = 1; }
          );
        }).verdict._tag;
      expected = "uncalibrated";
    };

    "test an empty comparison cannot pass" = {
      expr = (compared { }).verdict._tag;
      expected = "uncalibrated";
    };

    "test attribution changes alone do not fail the aggregate gate" = {
      expr =
        (compared {
          "subsystem.ownerships.resolve"."4" = cell (
            _: step: {
              calls = 1000;
              entered = if step.side == "baseline" then 1 else 50;
            }
          );
        }).verdict._tag;
      expected = "pass";
    };

    "test an improvement past both tolerances passes" = {
      expr =
        let
          inherit
            (
              (compared {
                "subsystem.ownerships.resolve"."4" = cell (
                  _: step: lib.optionalAttrs (step.side == "candidate") { calls = 60; }
                );
              })
            )
            verdict
            ;
        in
        {
          inherit (verdict) _tag;
          calls = verdict.byCell."subsystem.ownerships.resolve"."4".nrFunctionCalls;
        };
      expected = {
        _tag = "pass";
        calls = "improvement";
      };
    };

    "test a nondeterministic counter gets no verdict" = {
      expr =
        (compared {
          "subsystem.ownerships.resolve"."4" = cell (
            order: step: lib.optionalAttrs (step.side == "candidate" && order == 7) { thunks = 500; }
          );
        }).verdict.byCell."subsystem.ownerships.resolve"."4".nrThunks;
      expected = "unjudged";
    };

    "test a candidate failure fails and a baseline failure is unjudged" = {
      expr =
        let
          inherit
            (
              (compared {
                "subsystem.toml.generate"."4" = cell (order: _: lib.optionalAttrs (order == 0) { meta.exit = 1; });
                "subsystem.toml.generate"."16" = cell (order: _: lib.optionalAttrs (order == 3) { meta.exit = 1; });
              })
            )
            verdict
            ;
        in
        {
          inherit (verdict) _tag candidateFailures unjudged;
        };
      expected = {
        _tag = "fail";
        candidateFailures = [
          {
            workload = "subsystem.toml.generate";
            size = "16";
          }
        ];
        unjudged = [
          {
            workload = "subsystem.toml.generate";
            size = "4";
          }
        ];
      };
    };

    "test budgets from another evaluator judge nothing" = {
      expr =
        (comparedWith (budgets // { evaluator = "2.33.0"; }) {
          "subsystem.ownerships.resolve"."4" = candidateCalls;
        }).verdict;
      expected = {
        _tag = "uncalibrated";
        reason = "budgets were calibrated on 2.33.0 and the records come from 2.34.8";
      };
    };

    "test the report states the verdict, regressions and marker regions" = {
      expr =
        let
          text = analysis.render (compared {
            "subsystem.ownerships.resolve"."4" = cell (
              _: step:
              {
                entered = 2;
              }
              // lib.optionalAttrs (step.side == "candidate") { calls = 130; }
            );
          });
        in
        map (fragment: lib.hasInfix fragment text) [
          "Verdict: fail"
          "| nrFunctionCalls | 100 → 130 (+30, +300‰) regression |"
          "- subsystem.ownerships.resolve at 4: nrFunctionCalls +30 (+300‰), budget 5‰ and 20"
          "| src/ownerships.mergeContributions | baseline only, 2 |"
          "| src/ownerships.resolveContext | 9 of 18 → 9 of 18 |"
        ];
      expected = [
        true
        true
        true
        true
        true
      ];
    };

    "test calibration doubles the noise it saw and keeps the policy floor" = {
      expr =
        let
          budgets = analysis.calibrate [
            (calibrationRun {
              "subsystem.ownerships.resolve"."4" = candidateCalls;
            })
          ];
        in
        {
          inherit (budgets) evaluator;
          calls = removeAttrs budgets.counters.nrFunctionCalls [ "observed" ];
          heap = removeAttrs budgets.counters.heapBytes [ "observed" ];
        };
      expected = {
        evaluator = "2.34.8";
        calls = {
          permille = 600;
          floor = 2000;
        };
        heap = {
          permille = 50;
          floor = 65536;
        };
      };
    };

    "test calibration refuses runs from two evaluators" = {
      expr =
        (analysis.calibrate [
          (calibrationRun { "subsystem.ownerships.resolve"."4" = clean; })
          (
            (calibrationRun { "subsystem.ownerships.resolve"."4" = clean; })
            // {
              run = run // {
                candidate = run.baseline;
                evaluator = evaluator // {
                  version = "2.33.0";
                };
              };
            }
          )
        ]).evaluator;
      expectedError.type = "ThrownError";
      expectedError.msg = "calibration needs runs from one evaluator, these come from 2.34.8 at ${evaluator.outPath}, 2.33.0 at ${evaluator.outPath}";
    };

    "test calibration refuses changed content at the same revision" = {
      expr =
        (analysis.calibrate [
          (compared { "subsystem.ownerships.resolve"."4" = clean; })
        ]).evaluator;
      expectedError.type = "ThrownError";
      expectedError.msg = "calibration needs clean, identical source content at one revision on both sides of every run";
    };

    "test calibration refuses distinct clean snapshots at the same revision" = {
      expr =
        (analysis.calibrate [
          (
            (calibrationRun { "subsystem.ownerships.resolve"."4" = clean; })
            // {
              run = run // {
                candidate = run.candidate // {
                  dirty = false;
                };
              };
            }
          )
        ]).evaluator;
      expectedError.type = "ThrownError";
      expectedError.msg = "calibration needs clean, identical source content at one revision on both sides of every run";
    };

    "test calibration refuses different evaluator builds at the same version" = {
      expr =
        (analysis.calibrate [
          (calibrationRun { "subsystem.ownerships.resolve"."4" = clean; })
          (
            (calibrationRun { "subsystem.ownerships.resolve"."4" = clean; })
            // {
              run = run // {
                candidate = run.baseline;
                evaluator = evaluator // {
                  outPath = "another-evaluator";
                };
              };
            }
          )
        ]).evaluator;
      expectedError.type = "ThrownError";
      expectedError.msg = "calibration needs runs from one evaluator, these come from 2.34.8 at ${evaluator.outPath}, 2.34.8 at another-evaluator";
    };

    "test calibration refuses a rejected cell beside an accepted one" = {
      expr =
        (analysis.calibrate [
          (calibrationRun {
            "subsystem.ownerships.resolve"."4" = clean;
            "subsystem.ownerships.resolve"."16" = cell (
              order: _: lib.optionalAttrs (order == 0) { meta.exit = 1; }
            );
          })
        ]).evaluator;
      expectedError.type = "ThrownError";
      expectedError.msg = "calibration contains rejected cells, subsystem.ownerships.resolve at 16";
    };

    "test calibration refuses a counter without deterministic observations" = {
      expr =
        (analysis.calibrate [
          (calibrationRun {
            "subsystem.ownerships.resolve"."4" = cell (order: _: { thunks = if order == 7 then 51 else 50; });
          })
        ]).evaluator;
      expectedError.type = "ThrownError";
      expectedError.msg = "calibration has no deterministic observations for counters nrThunks";
    };

    "test the report lists counters excluded for nondeterminism" = {
      expr = lib.hasInfix "nrThunks is nondeterministic and unjudged" (
        analysis.render (compared {
          "subsystem.ownerships.resolve"."4" = cell (order: _: { thunks = if order == 7 then 51 else 50; });
        })
      );
      expected = true;
    };
  };
}
