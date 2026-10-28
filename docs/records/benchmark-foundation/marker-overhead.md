# Lexicon evaluation benchmark

- baseline 339c3a8 at 339c3a8872f51facba1ba0b623124c464589881d, snapshot /nix/store/3v18a7dp0gx7q081r8qdx5adgf5iby1b-source
- candidate worktree at 339c3a8872f51facba1ba0b623124c464589881d with uncommitted changes, snapshot /nix/store/1fk9v9h7hvbkmppk0crxbgb2sypg8i5c-source
- evaluator 2.34.8 at /nix/store/hxxgpmyg1g2z1jy063n4fbzvm4y9mk0l-nix-2.34.8, system x86_64-linux
- schedule warmup baseline, warmup candidate, measure baseline, measure candidate, measure candidate, measure baseline, measure baseline, measure candidate, profile baseline, profile candidate
- timeout 600 seconds per sample, killed with SIGKILL

Counters are exact for one evaluator and expression and come from the measured samples. A
counter that differs between samples of one side shows its median, is marked
nondeterministic and gets no verdict. Timing, marker samples and owner applications are
reported, never judged. A counter regresses when it moves past its budget's relative tolerance and absolute floor together.

Verdict: pass

## Summary

| workload | size | status | function calls | thunks | heap bytes | wall ms | verdict |
| --- | --- | --- | --- | --- | --- | --- | --- |
| fleet.den | 4 | accepted | 6031617 → 6031839 (+222, 0‰) | 9412482 → 9412722 (+240, 0‰) | 980399840 → 980407640 (+7800, 0‰) | 8970 → 9110 | within |
| fleet.den | 16 | accepted | 23585295 → 23586165 (+870, 0‰) | 36817668 → 36818568 (+900, 0‰) | 3861304752 → 3861333576 (+28824, 0‰) | 29879 → 30925 | within |
| fleet.den | 64 | accepted | 94239207 → 94242669 (+3462, 0‰) | 146549292 → 146552832 (+3540, 0‰) | 15417009424 → 15417122344 (+112920, 0‰) | 119269 → 119233 | within |

## Verdicts

Every judged counter stayed within budget or improved.

## Rejected cells

No cell was rejected.

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

### fleet.den

| counter | 4 | 16 | 64 |
| --- | --- | --- | --- |
| nrFunctionCalls | 6031617 → 6031839 (+222, 0‰) within | 23585295 → 23586165 (+870, 0‰) within | 94239207 → 94242669 (+3462, 0‰) within |
| nrPrimOpCalls | 2894597 → 2894606 (+9, 0‰) within | 11281949 → 11281970 (+21, 0‰) within | 44877437 → 44877506 (+69, 0‰) within |
| nrThunks | 9412482 → 9412722 (+240, 0‰) within | 36817668 → 36818568 (+900, 0‰) within | 146549292 → 146552832 (+3540, 0‰) within |
| values.number | 19075787 → 19076032 (+245, 0‰) within | 75116873 → 75117778 (+905, 0‰) within | 299412257 → 299415802 (+3545, 0‰) within |
| envs.number | 7059035 → 7059257 (+222, 0‰) within | 27591335 → 27592205 (+870, 0‰) within | 110253335 → 110256797 (+3462, 0‰) within |
| sets.number | 2402161 → 2402166 (+5, 0‰) within | 9434881 → 9434886 (+5, 0‰) within | 37591681 → 37591686 (+5, 0‰) within |
| list.elements | 2609316 → 2609316 (0, 0‰) within | 10262688 → 10262688 (0, 0‰) within | 41636496 → 41636496 (0, 0‰) within |
| list.concats | 179926 → 179926 (0, 0‰) within | 707266 → 707266 (0, 0‰) within | 2816626 → 2816626 (0, 0‰) within |
| nrOpUpdates | 631271 → 631271 (0, 0‰) within | 2477255 → 2477255 (0, 0‰) within | 9887111 → 9887111 (0, 0‰) within |
| nrOpUpdateValuesCopied | 17873896 → 17873896 (0, 0‰) within | 70831337 → 70831337 (0, 0‰) within | 283560507 → 283560507 (0, 0‰) within |
| heapBytes | 980399840 → 980407640 (+7800, 0‰) within | 3861304752 → 3861333576 (+28824, 0‰) within | 15417009424 → 15417122344 (+112920, 0‰) within |

| marker entries | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/declarations.compileDeclaration | candidate only, 24 | candidate only, 96 | candidate only, 384 |
| src/declarations.prepareDeclaration | candidate only, 1 | candidate only, 1 | candidate only, 1 |
| src/furnish.compileManifest | candidate only, 4 | candidate only, 16 | candidate only, 64 |
| src/furnish.indexCollisions | candidate only, 4 | candidate only, 16 | candidate only, 64 |
| src/ownerships.mergeContributions | candidate only, 84 | candidate only, 324 | candidate only, 1284 |
| src/ownerships.resolveContext | candidate only, 96 | candidate only, 384 | candidate only, 1536 |
| src/program.inventoryDirectory | candidate only, 1 | candidate only, 1 | candidate only, 1 |
| src/program/theme.composeThemes | candidate only, 8 | candidate only, 32 | candidate only, 128 |

| inclusive samples, baseline → candidate | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/declarations.compileDeclaration | n/a → 48 of 7046 | n/a → 152 of 23534 | n/a → 580 of 91250 |
| src/declarations.prepareDeclaration | n/a → 3 of 7046 | n/a → 3 of 23534 | n/a → 3 of 91250 |
| src/furnish.compileManifest | n/a → 41 of 7046 | n/a → 136 of 23534 | n/a → 530 of 91250 |
| src/furnish.indexCollisions | n/a → 23 of 7046 | n/a → 81 of 23534 | n/a → 332 of 91250 |
| src/ownerships.mergeContributions | n/a → 1 of 7046 | n/a → 1 of 23534 | n/a → 2 of 91250 |
| src/ownerships.resolveContext | n/a → 1 of 7046 | n/a → 0 of 23534 | n/a → 0 of 91250 |
| src/program.inventoryDirectory | n/a → 0 of 7046 | n/a → 0 of 23534 | n/a → 0 of 91250 |
| src/program/theme.composeThemes | n/a → 2 of 7046 | n/a → 8 of 23534 | n/a → 28 of 91250 |

Applications by owner that moved

- 4: src/declarations 7672 → 7697 (+25, +3‰)
- 4: src/furnish 6919 → 6927 (+8, +1‰)
- 4: src/ownerships 16005 → 16185 (+180, +11‰)
- 4: src/program 362 → 363 (+1, +2‰)
- 4: src/program/theme 609 → 617 (+8, +13‰)
- 16: src/declarations 22816 → 22913 (+97, +4‰)
- 16: src/furnish 27199 → 27231 (+32, +1‰)
- 16: src/ownerships 42825 → 43533 (+708, +16‰)
- 16: src/program 1394 → 1395 (+1, 0‰)
- 16: src/program/theme 2433 → 2465 (+32, +13‰)
- 64: src/declarations 83392 → 83777 (+385, +4‰)
- 64: src/furnish 108319 → 108447 (+128, +1‰)
- 64: src/ownerships 155865 → 158685 (+2820, +18‰)
- 64: src/program 5522 → 5523 (+1, 0‰)
- 64: src/program/theme 9729 → 9857 (+128, +13‰)

| timing, baseline → candidate median | 4 | 16 | 64 |
| --- | --- | --- | --- |
| wallMs | 8970 → 9110 | 29879 → 30925 | 119269 → 119233 |
| cpuMs | 8265 → 8328 | 31287 → 31853 | 141234 → 141674 |
| peakRssKiB | 929432 → 929784 | 3275448 → 3275548 | 12525888 → 12507828 |
| heapSize | 721682432 → 721682432 | 2986606592 → 2986606592 | 11945644032 → 11928866816 |

Machines lumi, one-minute load at launch from 1.69 to 4.88.
