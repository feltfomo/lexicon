# Lexicon evaluation benchmark

- baseline main at 736199d1ecababb0e558eaced2dacf585788a684, snapshot /nix/store/5id1h7bmvzlxpmwxi05a9in08c65p5sh-source
- candidate worktree at 339c3a8872f51facba1ba0b623124c464589881d with uncommitted changes, snapshot /nix/store/0lhvnz5hn24i869ha2d03wlz6bmzwg8l-source
- evaluator 2.34.8 at /nix/store/hxxgpmyg1g2z1jy063n4fbzvm4y9mk0l-nix-2.34.8, system x86_64-linux
- schedule warmup baseline, warmup candidate, measure baseline, measure candidate, measure candidate, measure baseline, measure baseline, measure candidate, profile baseline, profile candidate
- timeout 600 seconds per sample, killed with SIGKILL

Counters are exact for one evaluator and expression and come from the measured samples. A
counter that differs between samples of one side shows its median, is marked
nondeterministic and gets no verdict. Timing, marker samples and owner applications are
reported, never judged. A counter regresses when it moves past its budget's relative tolerance and absolute floor together.

Verdict: fail

## Summary

| workload | size | status | function calls | thunks | heap bytes | wall ms | verdict |
| --- | --- | --- | --- | --- | --- | --- | --- |
| subsystem.ownerships.resolve | 4 | rejected |  |  |  |  | candidate failed |

## Verdicts

- subsystem.ownerships.resolve at 4: the candidate failed

## Rejected cells

- subsystem.ownerships.resolve at 4
  - 3-measure-candidate metadata differs from its run or cell in source

## Declared limits

- fleet.plain is declared and can't run, fleet.plain waits on the plain host, band 6

## Markers

- baseline defines no marker
- candidate src/declarations.compileDeclaration, src/declarations.prepareDeclaration, src/furnish.compileManifest, src/furnish.indexCollisions, src/ownerships.mergeContributions, src/ownerships.resolveContext, src/praxis.compileProject, src/praxis.normalizeCommands, src/program.inventoryDirectory, src/program/theme.composeThemes, src/toml.renderDocument

Marker entries are exact call counts of each marker's lambda. Inclusive samples count the
profiler stacks that hold a marker's frame, out of every stack sampled in that side's one
profiling run, at 1000 samples a second at most. A
marker forces only its argument's weak head normal form, so later demand on the value isn't
inside it. A region is ambiguous when another applied lambda shares its marker's name.

## Workloads

### subsystem.ownerships.resolve

Every size was rejected.
