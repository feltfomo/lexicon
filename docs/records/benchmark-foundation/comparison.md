# Lexicon evaluation benchmark

- baseline 736199d1ecababb0e558eaced2dacf585788a684 at 736199d1ecababb0e558eaced2dacf585788a684, snapshot /nix/store/5id1h7bmvzlxpmwxi05a9in08c65p5sh-source
- candidate worktree at 339c3a8872f51facba1ba0b623124c464589881d with uncommitted changes, snapshot /nix/store/0lhvnz5hn24i869ha2d03wlz6bmzwg8l-source
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
| fleet.den | 4 | accepted | 6031617 → 6031851 (+234, 0‰) | 9412482 → 9412735 (+253, 0‰) | 980399840 → 980409040 (+9200, 0‰) | 6043 → 6041 | within |
| fleet.den | 16 | accepted | 23585295 → 23586177 (+882, 0‰) | 36817668 → 36818581 (+913, 0‰) | 3861304752 → 3861334976 (+30224, 0‰) | 19405 → 19532 | within |
| fleet.den | 64 | accepted | 94239207 → 94242681 (+3474, 0‰) | 146549292 → 146552845 (+3553, 0‰) | 15417009424 → 15417123744 (+114320, 0‰) | 80170 → 77519 | within |
| subsystem.declarations.combined | 4 | accepted | 87873 → 87918 (+45, 0‰) | 120305 → 120361 (+56, 0‰) | 6151168 → 6154024 (+2856, 0‰) | 340 → 315 | within |
| subsystem.declarations.combined | 16 | accepted | 134001 → 134094 (+93, 0‰) | 174761 → 174865 (+104, 0‰) | 8813152 → 8817544 (+4392, 0‰) | 299 → 299 | within |
| subsystem.declarations.combined | 64 | accepted | 318513 → 318798 (+285, 0‰) | 392585 → 392881 (+296, 0‰) | 19461088 → 19471624 (+10536, 0‰) | 351 → 348 | within |
| subsystem.declarations.deep | 4 | accepted | 75236 → 75263 (+27, 0‰) | 104019 → 104055 (+36, 0‰) | 5366504 → 5368688 (+2184, 0‰) | 270 → 255 | within |
| subsystem.declarations.deep | 16 | accepted | 150050 → 150113 (+63, 0‰) | 189495 → 189567 (+72, 0‰) | 9479096 → 9482432 (+3336, 0‰) | 297 → 287 | within |
| subsystem.declarations.deep | 64 | accepted | 925946 → 926153 (+207, 0‰) | 1061319 → 1061535 (+216, 0‰) | 50870648 → 50878592 (+7944, 0‰) | 538 → 542 | within |
| subsystem.declarations.dynamic | 4 | accepted | 74789 → 74817 (+28, 0‰) | 104250 → 104287 (+37, 0‰) | 5367768 → 5369984 (+2216, 0‰) | 258 → 257 | within |
| subsystem.declarations.dynamic | 16 | accepted | 95069 → 95121 (+52, 0‰) | 128286 → 128347 (+61, 0‰) | 6532440 → 6535424 (+2984, 0‰) | 265 → 272 | within |
| subsystem.declarations.dynamic | 64 | accepted | 176189 → 176337 (+148, 0‰) | 224430 → 224587 (+157, 0‰) | 11191128 → 11197184 (+6056, 0‰) | 302 → 299 | within |
| subsystem.declarations.native | 4 | accepted | 51927 → 51941 (+14, 0‰) | 76517 → 76535 (+18, 0‰) | 3981368 → 3982960 (+1592, 0‰) | 252 → 246 | within |
| subsystem.declarations.native | 16 | accepted | 51963 → 51977 (+14, 0‰) | 76529 → 76547 (+18, 0‰) | 3983768 → 3985360 (+1592, 0‰) | 259 → 246 | within |
| subsystem.declarations.native | 64 | accepted | 52107 → 52121 (+14, 0‰) | 76577 → 76595 (+18, 0‰) | 3993368 → 3994960 (+1592, 0‰) | 245 → 251 | within |
| subsystem.declarations.prepared | 4 | accepted | 84128 → 84201 (+73, 0‰) | 117268 → 117350 (+82, 0‰) | 5983976 → 5987632 (+3656, 0‰) | 261 → 266 | within |
| subsystem.declarations.prepared | 16 | accepted | 214028 → 214665 (+637, +2‰) | 295828 → 296474 (+646, +2‰) | 14403176 → 14424880 (+21704, +1‰) | 310 → 312 | within |
| subsystem.declarations.prepared | 64 | accepted | 1885628 → 1894281 (+8653, +4‰) | 2645908 → 2654570 (+8662, +3‰) | 124549736 → 124827952 (+278216, +2‰) | 1003 → 973 | within |
| subsystem.declarations.single | 4 | accepted | 73568 → 73595 (+27, 0‰) | 102871 → 102907 (+36, 0‰) | 5301704 → 5303888 (+2184, 0‰) | 263 → 264 | within |
| subsystem.declarations.single | 16 | accepted | 93848 → 93899 (+51, 0‰) | 126907 → 126967 (+60, 0‰) | 6466376 → 6469328 (+2952, 0‰) | 275 → 272 | within |
| subsystem.declarations.single | 64 | accepted | 174968 → 175115 (+147, 0‰) | 223051 → 223207 (+156, 0‰) | 11125064 → 11131088 (+6024, 0‰) | 300 → 295 | within |
| subsystem.declarations.wide | 4 | accepted | 74723 → 74751 (+28, 0‰) | 104196 → 104233 (+37, 0‰) | 5365128 → 5367344 (+2216, 0‰) | 291 → 282 | within |
| subsystem.declarations.wide | 16 | accepted | 95003 → 95055 (+52, 0‰) | 128232 → 128293 (+61, 0‰) | 6529800 → 6532784 (+2984, 0‰) | 270 → 268 | within |
| subsystem.declarations.wide | 64 | accepted | 176123 → 176271 (+148, 0‰) | 224376 → 224533 (+157, 0‰) | 11188488 → 11194544 (+6056, 0‰) | 318 → 306 | within |
| subsystem.furnish.compile | 4 | accepted | 37611 → 37625 (+14, 0‰) | 57501 → 57519 (+18, 0‰) | 3026960 → 3028552 (+1592, 0‰) | 257 → 238 | within |
| subsystem.furnish.compile | 16 | accepted | 44907 → 44921 (+14, 0‰) | 67629 → 67647 (+18, 0‰) | 3537008 → 3538600 (+1592, 0‰) | 243 → 239 | within |
| subsystem.furnish.compile | 64 | accepted | 74167 → 74181 (+14, 0‰) | 108001 → 108019 (+18, 0‰) | 5576176 → 5577768 (+1592, 0‰) | 290 → 269 | within |
| subsystem.furnish.directory | 4 | accepted | 111781 → 111827 (+46, 0‰) | 148348 → 148407 (+59, 0‰) | 7667456 → 7670440 (+2984, 0‰) | 300 → 289 | within |
| subsystem.furnish.directory | 16 | accepted | 193825 → 193943 (+118, 0‰) | 243724 → 243855 (+131, 0‰) | 12408416 → 12413704 (+5288, 0‰) | 317 → 313 | within |
| subsystem.furnish.directory | 64 | accepted | 522001 → 522407 (+406, 0‰) | 625228 → 625647 (+419, 0‰) | 31372256 → 31386760 (+14504, 0‰) | 453 → 436 | within |
| subsystem.furnish.grouped | 4 | accepted | 56756 → 56772 (+16, 0‰) | 82015 → 82037 (+22, 0‰) | 4271376 → 4273128 (+1752, 0‰) | 265 → 257 | within |
| subsystem.furnish.grouped | 16 | accepted | 57620 → 57636 (+16, 0‰) | 82927 → 82949 (+22, 0‰) | 4324176 → 4325928 (+1752, 0‰) | 271 → 266 | within |
| subsystem.furnish.grouped | 64 | accepted | 61076 → 61092 (+16, 0‰) | 86575 → 86597 (+22, 0‰) | 4535376 → 4537128 (+1752, 0‰) | 266 → 269 | within |
| subsystem.furnish.index | 4 | accepted | 36655 → 36668 (+13, 0‰) | 56019 → 56036 (+17, 0‰) | 2953440 → 2955000 (+1560, 0‰) | 269 → 244 | within |
| subsystem.furnish.index | 16 | accepted | 41707 → 41720 (+13, 0‰) | 62535 → 62552 (+17, 0‰) | 3286464 → 3288024 (+1560, 0‰) | 247 → 250 | within |
| subsystem.furnish.index | 64 | accepted | 61079 → 61092 (+13, 0‰) | 88181 → 88198 (+17, 0‰) | 4598496 → 4600056 (+1560, 0‰) | 270 → 254 | within |
| subsystem.furnish.links | 4 | accepted | 58533 → 58549 (+16, 0‰) | 83834 → 83856 (+22, 0‰) | 4372432 → 4374184 (+1752, 0‰) | 262 → 270 | within |
| subsystem.furnish.links | 16 | accepted | 73701 → 73717 (+16, 0‰) | 99602 → 99624 (+22, 0‰) | 5240752 → 5242504 (+1752, 0‰) | 262 → 270 | within |
| subsystem.furnish.links | 64 | accepted | 134373 → 134389 (+16, 0‰) | 162674 → 162696 (+22, 0‰) | 8714032 → 8715784 (+1752, 0‰) | 284 → 289 | within |
| subsystem.furnish.shared | 4 | accepted | 142031 → 142164 (+133, 0‰) | 187562 → 187708 (+146, 0‰) | 9587152 → 9592920 (+5768, 0‰) | 295 → 304 | within |
| subsystem.furnish.shared | 16 | accepted | 718931 → 720384 (+1453, +2‰) | 918038 → 919504 (+1466, +1‰) | 45574576 → 45622584 (+48008, +1‰) | 514 → 509 | within |
| subsystem.furnish.shared | 64 | accepted | 9008291 → 9029424 (+21133, +2‰) | 11492102 → 11513248 (+21146, +1‰) | 566619952 → 567297720 (+677768, +1‰) | 3550 → 3539 | within |
| subsystem.ownerships.fleet-custom | 4 | accepted | 34865 → 34879 (+14, 0‰) | 54585 → 54605 (+20, 0‰) | 2857176 → 2858816 (+1640, 0‰) | 246 → 242 | within |
| subsystem.ownerships.fleet-custom | 16 | accepted | 38393 → 38407 (+14, 0‰) | 60081 → 60101 (+20, 0‰) | 3128664 → 3130304 (+1640, 0‰) | 243 → 245 | within |
| subsystem.ownerships.fleet-custom | 64 | accepted | 61145 → 61159 (+14, 0‰) | 93585 → 93605 (+20, 0‰) | 5067096 → 5068736 (+1640, 0‰) | 260 → 260 | within |
| subsystem.ownerships.fleet-matrix | 4 | accepted | 50192 → 50204 (+12, 0‰) | 72947 → 72963 (+16, 0‰) | 3780600 → 3782072 (+1472, 0‰) | 252 → 249 | within |
| subsystem.ownerships.fleet-matrix | 16 | accepted | 148532 → 148544 (+12, 0‰) | 200957 → 200973 (+16, 0‰) | 9836568 → 9838040 (+1472, 0‰) | 287 → 282 | within |
| subsystem.ownerships.fleet-matrix | 64 | accepted | 1987652 → 1987664 (+12, 0‰) | 2099717 → 2099733 (+16, 0‰) | 105899160 → 105900632 (+1472, 0‰) | 861 → 844 | within |
| subsystem.ownerships.fleet-prepared | 4 | accepted | 48184 → 48204 (+20, 0‰) | 69925 → 69951 (+26, 0‰) | 3639232 → 3641064 (+1832, 0‰) | 246 → 252 | within |
| subsystem.ownerships.fleet-prepared | 16 | accepted | 108064 → 108108 (+44, 0‰) | 149329 → 149379 (+50, 0‰) | 7360432 → 7363032 (+2600, 0‰) | 283 → 267 | within |
| subsystem.ownerships.fleet-prepared | 64 | accepted | 940864 → 941004 (+140, 0‰) | 1261825 → 1261971 (+146, 0‰) | 59627632 → 59633304 (+5672, 0‰) | 557 → 575 | within |
| subsystem.ownerships.fleet-resolve | 4 | accepted | 55782 → 55802 (+20, 0‰) | 78658 → 78684 (+26, 0‰) | 4038504 → 4040336 (+1832, 0‰) | 249 → 250 | within |
| subsystem.ownerships.fleet-resolve | 16 | accepted | 252414 → 252458 (+44, 0‰) | 313042 → 313092 (+50, 0‰) | 14847000 → 14849600 (+2600, 0‰) | 318 → 312 | within |
| subsystem.ownerships.fleet-resolve | 64 | accepted | 3334302 → 3334442 (+140, 0‰) | 3966418 → 3966564 (+146, 0‰) | 183314904 → 183320576 (+5672, 0‰) | 1306 → 1302 | within |
| subsystem.ownerships.fleet-trace | 4 | accepted | 45487 → 45501 (+14, 0‰) | 66227 → 66247 (+20, 0‰) | 3468032 → 3469672 (+1640, 0‰) | 250 → 242 | within |
| subsystem.ownerships.fleet-trace | 16 | accepted | 57367 → 57381 (+14, 0‰) | 80903 → 80923 (+20, 0‰) | 4154480 → 4156120 (+1640, 0‰) | 255 → 267 | within |
| subsystem.ownerships.fleet-trace | 64 | accepted | 104887 → 104901 (+14, 0‰) | 139607 → 139627 (+20, 0‰) | 6911792 → 6913432 (+1640, 0‰) | 263 → 277 | within |
| subsystem.ownerships.resolve | 4 | accepted | 43172 → 43186 (+14, 0‰) | 63439 → 63459 (+20, 0‰) | 3338360 → 3340000 (+1640, 0‰) | 247 → 244 | within |
| subsystem.ownerships.resolve | 16 | accepted | 48788 → 48802 (+14, 0‰) | 70855 → 70875 (+20, 0‰) | 3706808 → 3708448 (+1640, 0‰) | 256 → 248 | within |
| subsystem.ownerships.resolve | 64 | accepted | 79892 → 79906 (+14, 0‰) | 112039 → 112059 (+20, 0‰) | 6033080 → 6034720 (+1640, 0‰) | 266 → 262 | within |
| subsystem.praxis.diagnostics | 4 | accepted | 807669 → 807683 (+14, 0‰) | 853837 → 853855 (+18, 0‰) | 41281864 → 41283456 (+1592, 0‰) | 482 → 483 | within |
| subsystem.praxis.diagnostics | 16 | accepted | 3017469 → 3017483 (+14, 0‰) | 3140641 → 3140659 (+18, 0‰) | 151122712 → 151124304 (+1592, 0‰) | 1145 → 1157 | within |
| subsystem.praxis.diagnostics | 64 | accepted | 11856669 → 11856683 (+14, 0‰) | 12287857 → 12287875 (+18, 0‰) | 590512024 → 590513616 (+1592, 0‰) | 3632 → 3672 | within |
| subsystem.praxis.manifest | 4 | accepted | 109567 → 109581 (+14, 0‰) | 244052 → 244070 (+18, 0‰) | 42506616 → 42508208 (+1592, 0‰) | 626 → 651 | within |
| subsystem.praxis.manifest | 16 | accepted | 111595 → 111609 (+14, 0‰) | 247184 → 247202 (+18, 0‰) | 42652536 → 42654128 (+1592, 0‰) | 642 → 619 | within |
| subsystem.praxis.manifest | 64 | accepted | 119711 → 119725 (+14, 0‰) | 259714 → 259732 (+18, 0‰) | 43239192 → 43240784 (+1592, 0‰) | 641 → 622 | within |
| subsystem.praxis.selected | 4 | accepted | 161110 → 161124 (+14, 0‰) | 295570 → 295588 (+18, 0‰) | 45305688 → 45307280 (+1592, 0‰) | 659 → 657 | within |
| subsystem.praxis.selected | 16 | accepted | 237982 → 237996 (+14, 0‰) | 373318 → 373336 (+18, 0‰) | 49853560 → 49855152 (+1592, 0‰) | 662 → 671 | within |
| subsystem.praxis.selected | 64 | accepted | 545470 → 545484 (+14, 0‰) | 684310 → 684328 (+18, 0‰) | 68047672 → 68049264 (+1592, 0‰) | 786 → 790 | within |
| subsystem.registry.queries | 4 | accepted | 35859 → 35871 (+12, 0‰) | 54673 → 54686 (+13, 0‰) | 2890952 → 2892352 (+1400, 0‰) | 237 → 240 | within |
| subsystem.registry.queries | 16 | accepted | 48051 → 48063 (+12, 0‰) | 63229 → 63242 (+13, 0‰) | 3487160 → 3488560 (+1400, 0‰) | 248 → 248 | within |
| subsystem.registry.queries | 64 | accepted | 151795 → 151807 (+12, 0‰) | 117613 → 117626 (+13, 0‰) | 8122488 → 8123888 (+1400, 0‰) | 276 → 262 | within |
| subsystem.registry.summary | 4 | accepted | 34308 → 34320 (+12, 0‰) | 53056 → 53069 (+13, 0‰) | 2797488 → 2798888 (+1400, 0‰) | 240 → 239 | within |
| subsystem.registry.summary | 16 | accepted | 36876 → 36888 (+12, 0‰) | 55912 → 55925 (+13, 0‰) | 2957856 → 2959256 (+1400, 0‰) | 248 → 242 | within |
| subsystem.registry.summary | 64 | accepted | 47150 → 47162 (+12, 0‰) | 67336 → 67349 (+13, 0‰) | 3610880 → 3612280 (+1400, 0‰) | 241 → 241 | within |
| subsystem.theme.matugen | 4 | accepted | 93272 → 93300 (+28, 0‰) | 193122 → 193156 (+34, 0‰) | 38988472 → 38990608 (+2136, 0‰) | 417 → 415 | within |
| subsystem.theme.matugen | 16 | accepted | 164252 → 164328 (+76, 0‰) | 277794 → 277876 (+82, 0‰) | 43379896 → 43383568 (+3672, 0‰) | 443 → 449 | within |
| subsystem.theme.matugen | 64 | accepted | 448172 → 448440 (+268, 0‰) | 616482 → 616756 (+274, 0‰) | 60945592 → 60955408 (+9816, 0‰) | 549 → 555 | within |
| subsystem.toml.generate | 4 | rejected |  |  |  |  | unjudged |
| subsystem.toml.generate | 16 | rejected |  |  |  |  | unjudged |
| subsystem.toml.generate | 64 | rejected |  |  |  |  | unjudged |

## Verdicts

- subsystem.toml.generate at 16: unjudged, the cell was rejected without a candidate failure
- subsystem.toml.generate at 4: unjudged, the cell was rejected without a candidate failure
- subsystem.toml.generate at 64: unjudged, the cell was rejected without a candidate failure

## Rejected cells

- subsystem.toml.generate at 4
  - 0-warmup-baseline exited 1
  - 0-warmup-baseline wrote no projection
  - the schedule did not complete in order, found 1 of 10 samples
- subsystem.toml.generate at 16
  - 0-warmup-baseline exited 1
  - 0-warmup-baseline wrote no projection
  - the schedule did not complete in order, found 1 of 10 samples
- subsystem.toml.generate at 64
  - 0-warmup-baseline exited 1
  - 0-warmup-baseline wrote no projection
  - the schedule did not complete in order, found 1 of 10 samples

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
| nrFunctionCalls | 6031617 → 6031851 (+234, 0‰) within | 23585295 → 23586177 (+882, 0‰) within | 94239207 → 94242681 (+3474, 0‰) within |
| nrPrimOpCalls | 2894597 → 2894610 (+13, 0‰) within | 11281949 → 11281974 (+25, 0‰) within | 44877437 → 44877510 (+73, 0‰) within |
| nrThunks | 9412482 → 9412735 (+253, 0‰) within | 36817668 → 36818581 (+913, 0‰) within | 146549292 → 146552845 (+3553, 0‰) within |
| values.number | 19075787 → 19076070 (+283, 0‰) within | 75116873 → 75117816 (+943, 0‰) within | 299412257 → 299415840 (+3583, 0‰) within |
| envs.number | 7059035 → 7059271 (+236, 0‰) within | 27591335 → 27592219 (+884, 0‰) within | 110253335 → 110256811 (+3476, 0‰) within |
| sets.number | 2402161 → 2402172 (+11, 0‰) within | 9434881 → 9434892 (+11, 0‰) within | 37591681 → 37591692 (+11, 0‰) within |
| list.elements | 2609316 → 2609326 (+10, 0‰) within | 10262688 → 10262698 (+10, 0‰) within | 41636496 → 41636506 (+10, 0‰) within |
| list.concats | 179926 → 179927 (+1, 0‰) within | 707266 → 707267 (+1, 0‰) within | 2816626 → 2816627 (+1, 0‰) within |
| nrOpUpdates | 631271 → 631273 (+2, 0‰) within | 2477255 → 2477257 (+2, 0‰) within | 9887111 → 9887113 (+2, 0‰) within |
| nrOpUpdateValuesCopied | 17873896 → 17873898 (+2, 0‰) within | 70831337 → 70831339 (+2, 0‰) within | 283560507 → 283560509 (+2, 0‰) within |
| heapBytes | 980399840 → 980409040 (+9200, 0‰) within | 3861304752 → 3861334976 (+30224, 0‰) within | 15417009424 → 15417123744 (+114320, 0‰) within |

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
| src/declarations.compileDeclaration | n/a → 41 of 6554 | n/a → 103 of 15823 | n/a → 443 of 65455 |
| src/declarations.prepareDeclaration | n/a → 3 of 6554 | n/a → 2 of 15823 | n/a → 2 of 65455 |
| src/furnish.compileManifest | n/a → 36 of 6554 | n/a → 98 of 15823 | n/a → 395 of 65455 |
| src/furnish.indexCollisions | n/a → 20 of 6554 | n/a → 57 of 15823 | n/a → 237 of 65455 |
| src/ownerships.mergeContributions | n/a → 0 of 6554 | n/a → 1 of 15823 | n/a → 7 of 65455 |
| src/ownerships.resolveContext | n/a → 0 of 6554 | n/a → 0 of 15823 | n/a → 1 of 65455 |
| src/program.inventoryDirectory | n/a → 0 of 6554 | n/a → 1 of 15823 | n/a → 0 of 65455 |
| src/program/theme.composeThemes | n/a → 6 of 6554 | n/a → 6 of 15823 | n/a → 24 of 65455 |

Applications by owner that moved

- 4: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 4: src/declarations 7672 → 7697 (+25, +3‰)
- 4: src/furnish 6919 → 6927 (+8, +1‰)
- 4: src/ownerships 16005 → 16185 (+180, +11‰)
- 4: src/program 362 → 363 (+1, +2‰)
- 4: src/program/theme 609 → 617 (+8, +13‰)
- 16: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 16: src/declarations 22816 → 22913 (+97, +4‰)
- 16: src/furnish 27199 → 27231 (+32, +1‰)
- 16: src/ownerships 42825 → 43533 (+708, +16‰)
- 16: src/program 1394 → 1395 (+1, 0‰)
- 16: src/program/theme 2433 → 2465 (+32, +13‰)
- 64: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 64: src/declarations 83392 → 83777 (+385, +4‰)
- 64: src/furnish 108319 → 108447 (+128, +1‰)
- 64: src/ownerships 155865 → 158685 (+2820, +18‰)
- 64: src/program 5522 → 5523 (+1, 0‰)
- 64: src/program/theme 9729 → 9857 (+128, +13‰)

| timing, baseline → candidate median | 4 | 16 | 64 |
| --- | --- | --- | --- |
| wallMs | 6043 → 6041 | 19405 → 19532 | 80170 → 77519 |
| cpuMs | 5929 → 5980 | 21944 → 22135 | 104431 → 102301 |
| peakRssKiB | 929668 → 929320 | 3275200 → 3275552 | 12509176 → 12508920 |
| heapSize | 721682432 → 721682432 | 2986606592 → 2986606592 | 11928866816 → 11928866816 |

Machines lumi, one-minute load at launch from 1.27 to 2.70.

### subsystem.declarations.combined

| counter | 4 | 16 | 64 |
| --- | --- | --- | --- |
| nrFunctionCalls | 87873 → 87918 (+45, 0‰) within | 134001 → 134094 (+93, 0‰) within | 318513 → 318798 (+285, 0‰) within |
| nrPrimOpCalls | 45464 → 45472 (+8, 0‰) within | 67568 → 67576 (+8, 0‰) within | 155984 → 155992 (+8, 0‰) within |
| nrThunks | 120305 → 120361 (+56, 0‰) within | 174761 → 174865 (+104, 0‰) within | 392585 → 392881 (+296, 0‰) within |
| values.number | 144926 → 145010 (+84, 0‰) within | 208742 → 208874 (+132, 0‰) within | 464006 → 464330 (+324, 0‰) within |
| envs.number | 102525 → 102572 (+47, 0‰) within | 154725 → 154820 (+95, 0‰) within | 363525 → 363812 (+287, 0‰) within |
| sets.number | 22723 → 22732 (+9, 0‰) within | 33427 → 33436 (+9, 0‰) within | 76243 → 76252 (+9, 0‰) within |
| list.elements | 30394 → 30404 (+10, 0‰) within | 41386 → 41396 (+10, 0‰) within | 85354 → 85364 (+10, 0‰) within |
| list.concats | 1902 → 1903 (+1, 0‰) within | 3270 → 3271 (+1, 0‰) within | 8742 → 8743 (+1, 0‰) within |
| nrOpUpdates | 4925 → 4927 (+2, 0‰) within | 7997 → 7999 (+2, 0‰) within | 20285 → 20287 (+2, 0‰) within |
| nrOpUpdateValuesCopied | 4940 → 4942 (+2, 0‰) within | 5540 → 5542 (+2, 0‰) within | 7940 → 7942 (+2, 0‰) within |
| heapBytes | 6151168 → 6154024 (+2856, 0‰) within | 8813152 → 8817544 (+4392, 0‰) within | 19461088 → 19471624 (+10536, 0‰) within |

| marker entries | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/declarations.compileDeclaration | candidate only, 3 | candidate only, 3 | candidate only, 3 |
| src/declarations.prepareDeclaration | candidate only, 1 | candidate only, 1 | candidate only, 1 |
| src/ownerships.mergeContributions | candidate only, 13 | candidate only, 37 | candidate only, 133 |
| src/ownerships.resolveContext | candidate only, 15 | candidate only, 39 | candidate only, 135 |
| src/program/theme.composeThemes | candidate only, 1 | candidate only, 1 | candidate only, 1 |

| inclusive samples, baseline → candidate | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/declarations.compileDeclaration | n/a → 12 of 106 | n/a → 31 of 143 | n/a → 78 of 184 |
| src/declarations.prepareDeclaration | n/a → 1 of 106 | n/a → 3 of 143 | n/a → 6 of 184 |
| src/ownerships.mergeContributions | n/a → 0 of 106 | n/a → 0 of 143 | n/a → 2 of 184 |
| src/ownerships.resolveContext | n/a → 1 of 106 | n/a → 1 of 143 | n/a → 0 of 184 |
| src/program/theme.composeThemes | n/a → 1 of 106 | n/a → 1 of 143 | n/a → 2 of 184 |

Applications by owner that moved

- 4: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 4: src/declarations 3335 → 3339 (+4, +1‰)
- 4: src/ownerships 9125 → 9153 (+28, +3‰)
- 4: src/program/theme 29 → 30 (+1, +34‰)
- 16: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 16: src/declarations 6191 → 6195 (+4, 0‰)
- 16: src/ownerships 19793 → 19869 (+76, +3‰)
- 16: src/program/theme 29 → 30 (+1, +34‰)
- 64: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 64: src/declarations 17615 → 17619 (+4, 0‰)
- 64: src/ownerships 62465 → 62733 (+268, +4‰)
- 64: src/program/theme 29 → 30 (+1, +34‰)

| timing, baseline → candidate median | 4 | 16 | 64 |
| --- | --- | --- | --- |
| wallMs | 340 → 315 | 299 → 299 | 351 → 348 |
| cpuMs | 217 → 212 | 192 → 192 | 240 → 233 |
| peakRssKiB | 68504 → 68848 | 71632 → 71588 | 82984 → 83096 |
| heapSize | 402915328 → 402915328 | 402915328 → 402915328 | 402915328 → 402915328 |

Machines lumi, one-minute load at launch from 1.33 to 1.39.

### subsystem.declarations.deep

| counter | 4 | 16 | 64 |
| --- | --- | --- | --- |
| nrFunctionCalls | 75236 → 75263 (+27, 0‰) within | 150050 → 150113 (+63, 0‰) within | 925946 → 926153 (+207, 0‰) within |
| nrPrimOpCalls | 38709 → 38716 (+7, 0‰) within | 71535 → 71542 (+7, 0‰) within | 405879 → 405886 (+7, 0‰) within |
| nrThunks | 104019 → 104055 (+36, 0‰) within | 189495 → 189567 (+72, 0‰) within | 1061319 → 1061535 (+216, 0‰) within |
| values.number | 126129 → 126192 (+63, 0‰) within | 225417 → 225516 (+99, 0‰) within | 1236009 → 1236252 (+243, 0‰) within |
| envs.number | 88054 → 88083 (+29, 0‰) within | 172564 → 172629 (+65, 0‰) within | 1047724 → 1047933 (+209, 0‰) within |
| sets.number | 19355 → 19363 (+8, 0‰) within | 34871 → 34879 (+8, 0‰) within | 183335 → 183343 (+8, 0‰) within |
| list.elements | 27130 → 27140 (+10, 0‰) within | 43372 → 43382 (+10, 0‰) within | 207700 → 207710 (+10, 0‰) within |
| list.concats | 1599 → 1600 (+1, 0‰) within | 4527 → 4528 (+1, 0‰) within | 39279 → 39280 (+1, 0‰) within |
| nrOpUpdates | 4165 → 4167 (+2, 0‰) within | 9205 → 9207 (+2, 0‰) within | 63925 → 63927 (+2, 0‰) within |
| nrOpUpdateValuesCopied | 4733 → 4735 (+2, 0‰) within | 5688 → 5690 (+2, 0‰) within | 15288 → 15290 (+2, 0‰) within |
| heapBytes | 5366504 → 5368688 (+2184, 0‰) within | 9479096 → 9482432 (+3336, 0‰) within | 50870648 → 50878592 (+7944, 0‰) within |

| marker entries | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/declarations.compileDeclaration | candidate only, 1 | candidate only, 1 | candidate only, 1 |
| src/declarations.prepareDeclaration | candidate only, 1 | candidate only, 1 | candidate only, 1 |
| src/ownerships.mergeContributions | candidate only, 5 | candidate only, 17 | candidate only, 65 |
| src/ownerships.resolveContext | candidate only, 8 | candidate only, 32 | candidate only, 128 |

| inclusive samples, baseline → candidate | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/declarations.compileDeclaration | n/a → 6 of 95 | n/a → 30 of 121 | n/a → 311 of 423 |
| src/declarations.prepareDeclaration | n/a → 2 of 95 | n/a → 4 of 121 | n/a → 17 of 423 |
| src/ownerships.mergeContributions | n/a → 0 of 95 | n/a → 0 of 121 | n/a → 1 of 423 |
| src/ownerships.resolveContext | n/a → 0 of 95 | n/a → 0 of 121 | n/a → 0 of 423 |

Applications by owner that moved

- 4: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 4: src/declarations 2489 → 2491 (+2, 0‰)
- 4: src/ownerships 6824 → 6837 (+13, +1‰)
- 16: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 16: src/declarations 5429 → 5431 (+2, 0‰)
- 16: src/ownerships 31028 → 31077 (+49, +1‰)
- 64: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 64: src/declarations 22949 → 22951 (+2, 0‰)
- 64: src/ownerships 320804 → 320997 (+193, 0‰)

| timing, baseline → candidate median | 4 | 16 | 64 |
| --- | --- | --- | --- |
| wallMs | 270 → 255 | 297 → 287 | 538 → 542 |
| cpuMs | 159 → 160 | 183 → 185 | 400 → 419 |
| peakRssKiB | 67524 → 67352 | 72608 → 72664 | 121680 → 122124 |
| heapSize | 402915328 → 402915328 | 402915328 → 402915328 | 402915328 → 402915328 |

Machines lumi, one-minute load at launch from 1.35 to 1.67.

### subsystem.declarations.dynamic

| counter | 4 | 16 | 64 |
| --- | --- | --- | --- |
| nrFunctionCalls | 74789 → 74817 (+28, 0‰) within | 95069 → 95121 (+52, 0‰) within | 176189 → 176337 (+148, 0‰) within |
| nrPrimOpCalls | 38987 → 38994 (+7, 0‰) within | 48479 → 48486 (+7, 0‰) within | 86447 → 86454 (+7, 0‰) within |
| nrThunks | 104250 → 104287 (+37, 0‰) within | 128286 → 128347 (+61, 0‰) within | 224430 → 224587 (+157, 0‰) within |
| values.number | 126261 → 126325 (+64, 0‰) within | 154245 → 154333 (+88, 0‰) within | 266181 → 266365 (+184, 0‰) within |
| envs.number | 87671 → 87701 (+30, 0‰) within | 110711 → 110765 (+54, 0‰) within | 202871 → 203021 (+150, 0‰) within |
| sets.number | 19399 → 19407 (+8, 0‰) within | 23983 → 23991 (+8, 0‰) within | 42319 → 42327 (+8, 0‰) within |
| list.elements | 27303 → 27313 (+10, 0‰) within | 31995 → 32005 (+10, 0‰) within | 50763 → 50773 (+10, 0‰) within |
| list.concats | 1566 → 1567 (+1, 0‰) within | 2214 → 2215 (+1, 0‰) within | 4806 → 4807 (+1, 0‰) within |
| nrOpUpdates | 4147 → 4149 (+2, 0‰) within | 5419 → 5421 (+2, 0‰) within | 10507 → 10509 (+2, 0‰) within |
| nrOpUpdateValuesCopied | 4740 → 4742 (+2, 0‰) within | 4944 → 4946 (+2, 0‰) within | 5760 → 5762 (+2, 0‰) within |
| heapBytes | 5367768 → 5369984 (+2216, 0‰) within | 6532440 → 6535424 (+2984, 0‰) within | 11191128 → 11197184 (+6056, 0‰) within |

| marker entries | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/declarations.compileDeclaration | candidate only, 1 | candidate only, 1 | candidate only, 1 |
| src/declarations.prepareDeclaration | candidate only, 1 | candidate only, 1 | candidate only, 1 |
| src/ownerships.mergeContributions | candidate only, 6 | candidate only, 18 | candidate only, 66 |
| src/ownerships.resolveContext | candidate only, 8 | candidate only, 20 | candidate only, 68 |

| inclusive samples, baseline → candidate | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/declarations.compileDeclaration | n/a → 7 of 100 | n/a → 14 of 101 | n/a → 40 of 131 |
| src/declarations.prepareDeclaration | n/a → 1 of 100 | n/a → 1 of 101 | n/a → 1 of 131 |
| src/ownerships.mergeContributions | n/a → 0 of 100 | n/a → 1 of 101 | n/a → 0 of 131 |
| src/ownerships.resolveContext | n/a → 0 of 100 | n/a → 0 of 101 | n/a → 0 of 131 |

Applications by owner that moved

- 4: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 4: src/declarations 2492 → 2494 (+2, 0‰)
- 4: src/ownerships 6428 → 6442 (+14, +2‰)
- 16: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 16: src/declarations 3596 → 3598 (+2, 0‰)
- 16: src/ownerships 11732 → 11770 (+38, +3‰)
- 64: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 64: src/declarations 8012 → 8014 (+2, 0‰)
- 64: src/ownerships 32948 → 33082 (+134, +4‰)

| timing, baseline → candidate median | 4 | 16 | 64 |
| --- | --- | --- | --- |
| wallMs | 258 → 257 | 265 → 272 | 302 → 299 |
| cpuMs | 160 → 157 | 166 → 164 | 191 → 193 |
| peakRssKiB | 67424 → 66964 | 68352 → 68484 | 73324 → 73828 |
| heapSize | 402915328 → 402915328 | 402915328 → 402915328 | 402915328 → 402915328 |

Machines lumi, one-minute load at launch from 1.75 to 1.79.

### subsystem.declarations.native

| counter | 4 | 16 | 64 |
| --- | --- | --- | --- |
| nrFunctionCalls | 51927 → 51941 (+14, 0‰) within | 51963 → 51977 (+14, 0‰) within | 52107 → 52121 (+14, 0‰) within |
| nrPrimOpCalls | 26172 → 26177 (+5, 0‰) within | 26184 → 26189 (+5, 0‰) within | 26232 → 26237 (+5, 0‰) within |
| nrThunks | 76517 → 76535 (+18, 0‰) within | 76529 → 76547 (+18, 0‰) within | 76577 → 76595 (+18, 0‰) within |
| values.number | 93250 → 93294 (+44, 0‰) within | 93298 → 93342 (+44, 0‰) within | 93490 → 93534 (+44, 0‰) within |
| envs.number | 61523 → 61539 (+16, 0‰) within | 61559 → 61575 (+16, 0‰) within | 61703 → 61719 (+16, 0‰) within |
| sets.number | 14038 → 14045 (+7, 0‰) within | 14050 → 14057 (+7, 0‰) within | 14098 → 14105 (+7, 0‰) within |
| list.elements | 20351 → 20361 (+10, 0‰) within | 20375 → 20385 (+10, 0‰) within | 20471 → 20481 (+10, 0‰) within |
| list.concats | 1026 → 1027 (+1, 0‰) within | 1026 → 1027 (+1, 0‰) within | 1026 → 1027 (+1, 0‰) within |
| nrOpUpdates | 3174 → 3176 (+2, 0‰) within | 3174 → 3176 (+2, 0‰) within | 3174 → 3176 (+2, 0‰) within |
| nrOpUpdateValuesCopied | 4497 → 4499 (+2, 0‰) within | 4497 → 4499 (+2, 0‰) within | 4497 → 4499 (+2, 0‰) within |
| heapBytes | 3981368 → 3982960 (+1592, 0‰) within | 3983768 → 3985360 (+1592, 0‰) within | 3993368 → 3994960 (+1592, 0‰) within |

| marker entries | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/declarations.compileDeclaration | candidate only, 1 | candidate only, 1 | candidate only, 1 |
| src/declarations.prepareDeclaration | candidate only, 1 | candidate only, 1 | candidate only, 1 |

| inclusive samples, baseline → candidate | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/declarations.compileDeclaration | n/a → 0 of 86 | n/a → 0 of 86 | n/a → 0 of 86 |
| src/declarations.prepareDeclaration | n/a → 1 of 86 | n/a → 1 of 86 | n/a → 1 of 86 |

Applications by owner that moved

- 4: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 4: src/declarations 1559 → 1561 (+2, +1‰)
- 16: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 16: src/declarations 1559 → 1561 (+2, +1‰)
- 64: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 64: src/declarations 1559 → 1561 (+2, +1‰)

| timing, baseline → candidate median | 4 | 16 | 64 |
| --- | --- | --- | --- |
| wallMs | 252 → 246 | 259 → 246 | 245 → 251 |
| cpuMs | 151 → 152 | 155 → 153 | 149 → 150 |
| peakRssKiB | 65344 → 64984 | 64968 → 65268 | 65268 → 65196 |
| heapSize | 402915328 → 402915328 | 402915328 → 402915328 | 402915328 → 402915328 |

Machines lumi, one-minute load at launch from 1.72 to 1.79.

### subsystem.declarations.prepared

| counter | 4 | 16 | 64 |
| --- | --- | --- | --- |
| nrFunctionCalls | 84128 → 84201 (+73, 0‰) within | 214028 → 214665 (+637, +2‰) within | 1885628 → 1894281 (+8653, +4‰) within |
| nrPrimOpCalls | 44758 → 44765 (+7, 0‰) within | 124390 → 124397 (+7, 0‰) within | 1194598 → 1194605 (+7, 0‰) within |
| nrThunks | 117268 → 117350 (+82, 0‰) within | 295828 → 296474 (+646, +2‰) within | 2645908 → 2654570 (+8662, +3‰) within |
| values.number | 141120 → 141229 (+109, 0‰) within | 345588 → 346261 (+673, +1‰) within | 3032580 → 3041269 (+8689, +2‰) within |
| envs.number | 98620 → 98695 (+75, 0‰) within | 250864 → 251503 (+639, +2‰) within | 2222080 → 2230735 (+8655, +3‰) within |
| sets.number | 22126 → 22134 (+8, 0‰) within | 58174 → 58182 (+8, 0‰) within | 530686 → 530694 (+8, 0‰) within |
| list.elements | 29693 → 29703 (+10, 0‰) within | 64109 → 64119 (+10, 0‰) within | 524333 → 524343 (+10, 0‰) within |
| list.concats | 1716 → 1717 (+1, 0‰) within | 4224 → 4225 (+1, 0‰) within | 34416 → 34417 (+1, 0‰) within |
| nrOpUpdates | 4464 → 4466 (+2, 0‰) within | 9876 → 9878 (+2, 0‰) within | 77604 → 77606 (+2, 0‰) within |
| nrOpUpdateValuesCopied | 4852 → 4854 (+2, 0‰) within | 6220 → 6222 (+2, 0‰) within | 23212 → 23214 (+2, 0‰) within |
| heapBytes | 5983976 → 5987632 (+3656, 0‰) within | 14403176 → 14424880 (+21704, +1‰) within | 124549736 → 124827952 (+278216, +2‰) within |

| marker entries | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/declarations.compileDeclaration | candidate only, 4 | candidate only, 16 | candidate only, 64 |
| src/declarations.prepareDeclaration | candidate only, 1 | candidate only, 1 | candidate only, 1 |
| src/ownerships.mergeContributions | candidate only, 24 | candidate only, 288 | candidate only, 4224 |
| src/ownerships.resolveContext | candidate only, 32 | candidate only, 320 | candidate only, 4352 |

| inclusive samples, baseline → candidate | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/declarations.compileDeclaration | n/a → 9 of 98 | n/a → 53 of 152 | n/a → 720 of 993 |
| src/declarations.prepareDeclaration | n/a → 1 of 98 | n/a → 2 of 152 | n/a → 8 of 993 |
| src/ownerships.mergeContributions | n/a → 0 of 98 | n/a → 1 of 152 | n/a → 5 of 993 |
| src/ownerships.resolveContext | n/a → 0 of 98 | n/a → 0 of 152 | n/a → 1 of 993 |

Applications by owner that moved

- 4: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 4: src/declarations 3170 → 3175 (+5, +1‰)
- 4: src/ownerships 7658 → 7714 (+56, +7‰)
- 16: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 16: src/declarations 11690 → 11707 (+17, +1‰)
- 16: src/ownerships 27602 → 28210 (+608, +22‰)
- 64: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 64: src/declarations 120650 → 120715 (+65, 0‰)
- 64: src/ownerships 262898 → 271474 (+8576, +32‰)

| timing, baseline → candidate median | 4 | 16 | 64 |
| --- | --- | --- | --- |
| wallMs | 261 → 266 | 310 → 312 | 1003 → 973 |
| cpuMs | 168 → 164 | 207 → 207 | 841 → 801 |
| peakRssKiB | 67680 → 67956 | 77284 → 76964 | 197516 → 197892 |
| heapSize | 402915328 → 402915328 | 402915328 → 402915328 | 402915328 → 402915328 |

Machines lumi, one-minute load at launch from 1.75 to 1.87.

### subsystem.declarations.single

| counter | 4 | 16 | 64 |
| --- | --- | --- | --- |
| nrFunctionCalls | 73568 → 73595 (+27, 0‰) within | 93848 → 93899 (+51, 0‰) within | 174968 → 175115 (+147, 0‰) within |
| nrPrimOpCalls | 38470 → 38477 (+7, 0‰) within | 47962 → 47969 (+7, 0‰) within | 85930 → 85937 (+7, 0‰) within |
| nrThunks | 102871 → 102907 (+36, 0‰) within | 126907 → 126967 (+60, 0‰) within | 223051 → 223207 (+156, 0‰) within |
| values.number | 124657 → 124720 (+63, 0‰) within | 152641 → 152728 (+87, 0‰) within | 264577 → 264760 (+183, 0‰) within |
| envs.number | 86297 → 86326 (+29, 0‰) within | 109337 → 109390 (+53, 0‰) within | 201497 → 201646 (+149, 0‰) within |
| sets.number | 19161 → 19169 (+8, 0‰) within | 23745 → 23753 (+8, 0‰) within | 42081 → 42089 (+8, 0‰) within |
| list.elements | 27088 → 27098 (+10, 0‰) within | 31780 → 31790 (+10, 0‰) within | 50548 → 50558 (+10, 0‰) within |
| list.concats | 1517 → 1518 (+1, 0‰) within | 2165 → 2166 (+1, 0‰) within | 4757 → 4758 (+1, 0‰) within |
| nrOpUpdates | 4075 → 4077 (+2, 0‰) within | 5347 → 5349 (+2, 0‰) within | 10435 → 10437 (+2, 0‰) within |
| nrOpUpdateValuesCopied | 4734 → 4736 (+2, 0‰) within | 4938 → 4940 (+2, 0‰) within | 5754 → 5756 (+2, 0‰) within |
| heapBytes | 5301704 → 5303888 (+2184, 0‰) within | 6466376 → 6469328 (+2952, 0‰) within | 11125064 → 11131088 (+6024, 0‰) within |

| marker entries | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/declarations.compileDeclaration | candidate only, 1 | candidate only, 1 | candidate only, 1 |
| src/declarations.prepareDeclaration | candidate only, 1 | candidate only, 1 | candidate only, 1 |
| src/ownerships.mergeContributions | candidate only, 6 | candidate only, 18 | candidate only, 66 |
| src/ownerships.resolveContext | candidate only, 7 | candidate only, 19 | candidate only, 67 |

| inclusive samples, baseline → candidate | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/declarations.compileDeclaration | n/a → 6 of 96 | n/a → 12 of 101 | n/a → 34 of 135 |
| src/declarations.prepareDeclaration | n/a → 1 of 96 | n/a → 2 of 101 | n/a → 6 of 135 |
| src/ownerships.mergeContributions | n/a → 0 of 96 | n/a → 0 of 101 | n/a → 0 of 135 |
| src/ownerships.resolveContext | n/a → 0 of 96 | n/a → 0 of 101 | n/a → 0 of 135 |

Applications by owner that moved

- 4: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 4: src/declarations 2457 → 2459 (+2, 0‰)
- 4: src/ownerships 5992 → 6005 (+13, +2‰)
- 16: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 16: src/declarations 3561 → 3563 (+2, 0‰)
- 16: src/ownerships 11296 → 11333 (+37, +3‰)
- 64: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 64: src/declarations 7977 → 7979 (+2, 0‰)
- 64: src/ownerships 32512 → 32645 (+133, +4‰)

| timing, baseline → candidate median | 4 | 16 | 64 |
| --- | --- | --- | --- |
| wallMs | 263 → 264 | 275 → 272 | 300 → 295 |
| cpuMs | 160 → 162 | 170 → 170 | 192 → 194 |
| peakRssKiB | 67028 → 66844 | 68516 → 68420 | 73552 → 73420 |
| heapSize | 402915328 → 402915328 | 402915328 → 402915328 | 402915328 → 402915328 |

Machines lumi, one-minute load at launch from 1.87 to 1.89.

### subsystem.declarations.wide

| counter | 4 | 16 | 64 |
| --- | --- | --- | --- |
| nrFunctionCalls | 74723 → 74751 (+28, 0‰) within | 95003 → 95055 (+52, 0‰) within | 176123 → 176271 (+148, 0‰) within |
| nrPrimOpCalls | 38967 → 38974 (+7, 0‰) within | 48459 → 48466 (+7, 0‰) within | 86427 → 86434 (+7, 0‰) within |
| nrThunks | 104196 → 104233 (+37, 0‰) within | 128232 → 128293 (+61, 0‰) within | 224376 → 224533 (+157, 0‰) within |
| values.number | 126201 → 126265 (+64, 0‰) within | 154185 → 154273 (+88, 0‰) within | 266121 → 266305 (+184, 0‰) within |
| envs.number | 87604 → 87634 (+30, 0‰) within | 110644 → 110698 (+54, 0‰) within | 202804 → 202954 (+150, 0‰) within |
| sets.number | 19390 → 19398 (+8, 0‰) within | 23974 → 23982 (+8, 0‰) within | 42310 → 42318 (+8, 0‰) within |
| list.elements | 27301 → 27311 (+10, 0‰) within | 31993 → 32003 (+10, 0‰) within | 50761 → 50771 (+10, 0‰) within |
| list.concats | 1566 → 1567 (+1, 0‰) within | 2214 → 2215 (+1, 0‰) within | 4806 → 4807 (+1, 0‰) within |
| nrOpUpdates | 4149 → 4151 (+2, 0‰) within | 5421 → 5423 (+2, 0‰) within | 10509 → 10511 (+2, 0‰) within |
| nrOpUpdateValuesCopied | 4741 → 4743 (+2, 0‰) within | 4945 → 4947 (+2, 0‰) within | 5761 → 5763 (+2, 0‰) within |
| heapBytes | 5365128 → 5367344 (+2216, 0‰) within | 6529800 → 6532784 (+2984, 0‰) within | 11188488 → 11194544 (+6056, 0‰) within |

| marker entries | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/declarations.compileDeclaration | candidate only, 1 | candidate only, 1 | candidate only, 1 |
| src/declarations.prepareDeclaration | candidate only, 1 | candidate only, 1 | candidate only, 1 |
| src/ownerships.mergeContributions | candidate only, 6 | candidate only, 18 | candidate only, 66 |
| src/ownerships.resolveContext | candidate only, 8 | candidate only, 20 | candidate only, 68 |

| inclusive samples, baseline → candidate | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/declarations.compileDeclaration | n/a → 6 of 94 | n/a → 13 of 109 | n/a → 36 of 138 |
| src/declarations.prepareDeclaration | n/a → 1 of 94 | n/a → 2 of 109 | n/a → 7 of 138 |
| src/ownerships.mergeContributions | n/a → 0 of 94 | n/a → 0 of 109 | n/a → 0 of 138 |
| src/ownerships.resolveContext | n/a → 0 of 94 | n/a → 0 of 109 | n/a → 1 of 138 |

Applications by owner that moved

- 4: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 4: src/declarations 2486 → 2488 (+2, 0‰)
- 4: src/ownerships 6428 → 6442 (+14, +2‰)
- 16: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 16: src/declarations 3590 → 3592 (+2, 0‰)
- 16: src/ownerships 11732 → 11770 (+38, +3‰)
- 64: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 64: src/declarations 8006 → 8008 (+2, 0‰)
- 64: src/ownerships 32948 → 33082 (+134, +4‰)

| timing, baseline → candidate median | 4 | 16 | 64 |
| --- | --- | --- | --- |
| wallMs | 291 → 282 | 270 → 268 | 318 → 306 |
| cpuMs | 173 → 166 | 164 → 174 | 209 → 200 |
| peakRssKiB | 67096 → 67288 | 68292 → 68368 | 73508 → 73516 |
| heapSize | 402915328 → 402915328 | 402915328 → 402915328 | 402915328 → 402915328 |

Machines lumi, one-minute load at launch from 1.83 to 1.90.

### subsystem.furnish.compile

| counter | 4 | 16 | 64 |
| --- | --- | --- | --- |
| nrFunctionCalls | 37611 → 37625 (+14, 0‰) within | 44907 → 44921 (+14, 0‰) within | 74167 → 74181 (+14, 0‰) within |
| nrPrimOpCalls | 17249 → 17254 (+5, 0‰) within | 23003 → 23008 (+5, 0‰) within | 45949 → 45954 (+5, 0‰) within |
| nrThunks | 57501 → 57519 (+18, 0‰) within | 67629 → 67647 (+18, 0‰) within | 108001 → 108019 (+18, 0‰) within |
| values.number | 70803 → 70847 (+44, 0‰) within | 82971 → 83015 (+44, 0‰) within | 131503 → 131547 (+44, 0‰) within |
| envs.number | 44881 → 44897 (+16, 0‰) within | 53521 → 53537 (+16, 0‰) within | 88157 → 88173 (+16, 0‰) within |
| sets.number | 9821 → 9828 (+7, 0‰) within | 11969 → 11976 (+7, 0‰) within | 20561 → 20568 (+7, 0‰) within |
| list.elements | 14794 → 14804 (+10, 0‰) within | 18070 → 18080 (+10, 0‰) within | 31174 → 31184 (+10, 0‰) within |
| list.concats | 838 → 839 (+1, +1‰) within | 1006 → 1007 (+1, 0‰) within | 1678 → 1679 (+1, 0‰) within |
| nrOpUpdates | 2140 → 2142 (+2, 0‰) within | 2404 → 2406 (+2, 0‰) within | 3460 → 3462 (+2, 0‰) within |
| nrOpUpdateValuesCopied | 4141 → 4143 (+2, 0‰) within | 4309 → 4311 (+2, 0‰) within | 4981 → 4983 (+2, 0‰) within |
| heapBytes | 3026960 → 3028552 (+1592, 0‰) within | 3537008 → 3538600 (+1592, 0‰) within | 5576176 → 5577768 (+1592, 0‰) within |

| marker entries | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/furnish.compileManifest | candidate only, 1 | candidate only, 1 | candidate only, 1 |
| src/furnish.indexCollisions | candidate only, 1 | candidate only, 1 | candidate only, 1 |

| inclusive samples, baseline → candidate | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/furnish.compileManifest | n/a → 0 of 76 | n/a → 0 of 80 | n/a → 0 of 102 |
| src/furnish.indexCollisions | n/a → 3 of 76 | n/a → 6 of 80 | n/a → 12 of 102 |

Applications by owner that moved

- 4: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 4: src/furnish 328 → 330 (+2, +6‰)
- 16: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 16: src/furnish 1312 → 1314 (+2, +1‰)
- 64: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 64: src/furnish 5324 → 5326 (+2, 0‰)

| timing, baseline → candidate median | 4 | 16 | 64 |
| --- | --- | --- | --- |
| wallMs | 257 → 238 | 243 → 239 | 290 → 269 |
| cpuMs | 148 → 149 | 150 → 147 | 183 → 160 |
| peakRssKiB | 63064 → 63008 | 63348 → 63372 | 65748 → 65888 |
| heapSize | 402915328 → 402915328 | 402915328 → 402915328 | 402915328 → 402915328 |

Machines lumi, one-minute load at launch from 1.83 to 2.01.

### subsystem.furnish.directory

| counter | 4 | 16 | 64 |
| --- | --- | --- | --- |
| nrFunctionCalls | 111781 → 111827 (+46, 0‰) within | 193825 → 193943 (+118, 0‰) within | 522001 → 522407 (+406, 0‰) within |
| nrPrimOpCalls | 54628 → 54637 (+9, 0‰) within | 94444 → 94453 (+9, 0‰) within | 253708 → 253717 (+9, 0‰) within |
| nrThunks | 148348 → 148407 (+59, 0‰) within | 243724 → 243855 (+131, 0‰) within | 625228 → 625647 (+419, 0‰) within |
| values.number | 179455 → 179543 (+88, 0‰) within | 292735 → 292895 (+160, 0‰) within | 745855 → 746303 (+448, 0‰) within |
| envs.number | 130586 → 130634 (+48, 0‰) within | 223118 → 223238 (+120, 0‰) within | 593246 → 593654 (+408, 0‰) within |
| sets.number | 26755 → 26765 (+10, 0‰) within | 45811 → 45821 (+10, 0‰) within | 122035 → 122045 (+10, 0‰) within |
| list.elements | 37966 → 37976 (+10, 0‰) within | 58282 → 58292 (+10, 0‰) within | 139546 → 139556 (+10, 0‰) within |
| list.concats | 2091 → 2092 (+1, 0‰) within | 4431 → 4432 (+1, 0‰) within | 13791 → 13792 (+1, 0‰) within |
| nrOpUpdates | 6006 → 6008 (+2, 0‰) within | 12006 → 12008 (+2, 0‰) within | 36006 → 36008 (+2, 0‰) within |
| nrOpUpdateValuesCopied | 7170 → 7172 (+2, 0‰) within | 8502 → 8504 (+2, 0‰) within | 13830 → 13832 (+2, 0‰) within |
| heapBytes | 7667456 → 7670440 (+2984, 0‰) within | 12408416 → 12413704 (+5288, 0‰) within | 31372256 → 31386760 (+14504, 0‰) within |

| marker entries | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/declarations.compileDeclaration | candidate only, 2 | candidate only, 2 | candidate only, 2 |
| src/declarations.prepareDeclaration | candidate only, 1 | candidate only, 1 | candidate only, 1 |
| src/ownerships.mergeContributions | candidate only, 11 | candidate only, 35 | candidate only, 131 |
| src/ownerships.resolveContext | candidate only, 15 | candidate only, 51 | candidate only, 195 |
| src/program.inventoryDirectory | candidate only, 4 | candidate only, 16 | candidate only, 64 |
| src/program/theme.composeThemes | candidate only, 1 | candidate only, 1 | candidate only, 1 |

| inclusive samples, baseline → candidate | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/declarations.compileDeclaration | n/a → 13 of 134 | n/a → 33 of 148 | n/a → 124 of 282 |
| src/declarations.prepareDeclaration | n/a → 3 of 134 | n/a → 6 of 148 | n/a → 21 of 282 |
| src/ownerships.mergeContributions | n/a → 0 of 134 | n/a → 0 of 148 | n/a → 1 of 282 |
| src/ownerships.resolveContext | n/a → 0 of 134 | n/a → 0 of 148 | n/a → 1 of 282 |
| src/program.inventoryDirectory | n/a → 0 of 134 | n/a → 0 of 148 | n/a → 0 of 282 |
| src/program/theme.composeThemes | n/a → 2 of 134 | n/a → 2 of 148 | n/a → 1 of 282 |

Applications by owner that moved

- 4: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 4: src/declarations 3269 → 3272 (+3, 0‰)
- 4: src/ownerships 10380 → 10406 (+26, +2‰)
- 4: src/program 246 → 250 (+4, +16‰)
- 4: src/program/theme 29 → 30 (+1, +34‰)
- 16: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 16: src/declarations 8033 → 8036 (+3, 0‰)
- 16: src/ownerships 27924 → 28010 (+86, +3‰)
- 16: src/program 978 → 994 (+16, +16‰)
- 16: src/program/theme 29 → 30 (+1, +34‰)
- 64: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 64: src/declarations 27089 → 27092 (+3, 0‰)
- 64: src/ownerships 98100 → 98426 (+326, +3‰)
- 64: src/program 3906 → 3970 (+64, +16‰)
- 64: src/program/theme 29 → 30 (+1, +34‰)

| timing, baseline → candidate median | 4 | 16 | 64 |
| --- | --- | --- | --- |
| wallMs | 300 → 289 | 317 → 313 | 453 → 436 |
| cpuMs | 198 → 187 | 211 → 213 | 341 → 319 |
| peakRssKiB | 70228 → 70172 | 75532 → 75484 | 96268 → 96372 |
| heapSize | 402915328 → 402915328 | 402915328 → 402915328 | 402915328 → 402915328 |

Machines lumi, one-minute load at launch from 1.93 to 2.01.

### subsystem.furnish.grouped

| counter | 4 | 16 | 64 |
| --- | --- | --- | --- |
| nrFunctionCalls | 56756 → 56772 (+16, 0‰) within | 57620 → 57636 (+16, 0‰) within | 61076 → 61092 (+16, 0‰) within |
| nrPrimOpCalls | 28792 → 28798 (+6, 0‰) within | 29248 → 29254 (+6, 0‰) within | 31072 → 31078 (+6, 0‰) within |
| nrThunks | 82015 → 82037 (+22, 0‰) within | 82927 → 82949 (+22, 0‰) within | 86575 → 86597 (+22, 0‰) within |
| values.number | 100151 → 100200 (+49, 0‰) within | 101375 → 101424 (+49, 0‰) within | 106271 → 106320 (+49, 0‰) within |
| envs.number | 66825 → 66843 (+18, 0‰) within | 67785 → 67803 (+18, 0‰) within | 71625 → 71643 (+18, 0‰) within |
| sets.number | 15249 → 15257 (+8, 0‰) within | 15477 → 15485 (+8, 0‰) within | 16389 → 16397 (+8, 0‰) within |
| list.elements | 21783 → 21793 (+10, 0‰) within | 22179 → 22189 (+10, 0‰) within | 23763 → 23773 (+10, 0‰) within |
| list.concats | 1091 → 1092 (+1, 0‰) within | 1103 → 1104 (+1, 0‰) within | 1151 → 1152 (+1, 0‰) within |
| nrOpUpdates | 3596 → 3598 (+2, 0‰) within | 3788 → 3790 (+2, 0‰) within | 4556 → 4558 (+2, 0‰) within |
| nrOpUpdateValuesCopied | 4610 → 4612 (+2, 0‰) within | 4730 → 4732 (+2, 0‰) within | 5210 → 5212 (+2, 0‰) within |
| heapBytes | 4271376 → 4273128 (+1752, 0‰) within | 4324176 → 4325928 (+1752, 0‰) within | 4535376 → 4537128 (+1752, 0‰) within |

| marker entries | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/declarations.compileDeclaration | candidate only, 2 | candidate only, 2 | candidate only, 2 |
| src/declarations.prepareDeclaration | candidate only, 1 | candidate only, 1 | candidate only, 1 |
| src/program/theme.composeThemes | candidate only, 1 | candidate only, 1 | candidate only, 1 |

| inclusive samples, baseline → candidate | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/declarations.compileDeclaration | n/a → 2 of 97 | n/a → 1 of 90 | n/a → 2 of 94 |
| src/declarations.prepareDeclaration | n/a → 1 of 97 | n/a → 1 of 90 | n/a → 1 of 94 |
| src/program/theme.composeThemes | n/a → 1 of 97 | n/a → 1 of 90 | n/a → 1 of 94 |

Applications by owner that moved

- 4: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 4: src/declarations 2057 → 2060 (+3, +1‰)
- 4: src/program/theme 29 → 30 (+1, +34‰)
- 16: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 16: src/declarations 2057 → 2060 (+3, +1‰)
- 16: src/program/theme 29 → 30 (+1, +34‰)
- 64: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 64: src/declarations 2057 → 2060 (+3, +1‰)
- 64: src/program/theme 29 → 30 (+1, +34‰)

| timing, baseline → candidate median | 4 | 16 | 64 |
| --- | --- | --- | --- |
| wallMs | 265 → 257 | 271 → 266 | 266 → 269 |
| cpuMs | 161 → 160 | 165 → 162 | 159 → 158 |
| peakRssKiB | 66192 → 65780 | 65824 → 65744 | 65868 → 66136 |
| heapSize | 402915328 → 402915328 | 402915328 → 402915328 | 402915328 → 402915328 |

Machines lumi, one-minute load at launch from 1.86 to 1.94.

### subsystem.furnish.index

| counter | 4 | 16 | 64 |
| --- | --- | --- | --- |
| nrFunctionCalls | 36655 → 36668 (+13, 0‰) within | 41707 → 41720 (+13, 0‰) within | 61079 → 61092 (+13, 0‰) within |
| nrPrimOpCalls | 16368 → 16373 (+5, 0‰) within | 19974 → 19979 (+5, 0‰) within | 34189 → 34194 (+5, 0‰) within |
| nrThunks | 56019 → 56036 (+17, 0‰) within | 62535 → 62552 (+17, 0‰) within | 88181 → 88198 (+17, 0‰) within |
| values.number | 69044 → 69087 (+43, 0‰) within | 76952 → 76995 (+43, 0‰) within | 108166 → 108209 (+43, 0‰) within |
| envs.number | 43727 → 43742 (+15, 0‰) within | 49643 → 49658 (+15, 0‰) within | 72471 → 72486 (+15, 0‰) within |
| sets.number | 9525 → 9532 (+7, 0‰) within | 10953 → 10960 (+7, 0‰) within | 16665 → 16672 (+7, 0‰) within |
| list.elements | 14314 → 14324 (+10, 0‰) within | 16426 → 16436 (+10, 0‰) within | 24874 → 24884 (+10, 0‰) within |
| list.concats | 826 → 827 (+1, +1‰) within | 970 → 971 (+1, +1‰) within | 1546 → 1547 (+1, 0‰) within |
| nrOpUpdates | 2122 → 2124 (+2, 0‰) within | 2338 → 2340 (+2, 0‰) within | 3202 → 3204 (+2, 0‰) within |
| nrOpUpdateValuesCopied | 4124 → 4126 (+2, 0‰) within | 4244 → 4246 (+2, 0‰) within | 4724 → 4726 (+2, 0‰) within |
| heapBytes | 2953440 → 2955000 (+1560, 0‰) within | 3286464 → 3288024 (+1560, 0‰) within | 4598496 → 4600056 (+1560, 0‰) within |

| marker entries | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/furnish.indexCollisions | candidate only, 1 | candidate only, 1 | candidate only, 1 |

| inclusive samples, baseline → candidate | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/furnish.indexCollisions | n/a → 5 of 87 | n/a → 7 of 85 | n/a → 12 of 86 |

Applications by owner that moved

- 4: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 4: src/furnish 200 → 201 (+1, +5‰)
- 16: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 16: src/furnish 908 → 909 (+1, +1‰)
- 64: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 64: src/furnish 2904 → 2905 (+1, 0‰)

| timing, baseline → candidate median | 4 | 16 | 64 |
| --- | --- | --- | --- |
| wallMs | 269 → 244 | 247 → 250 | 270 → 254 |
| cpuMs | 157 → 146 | 150 → 149 | 165 → 169 |
| peakRssKiB | 63204 → 62732 | 63260 → 63224 | 64612 → 64680 |
| heapSize | 402915328 → 402915328 | 402915328 → 402915328 | 402915328 → 402915328 |

Machines lumi, one-minute load at launch from 1.81 to 1.88.

### subsystem.furnish.links

| counter | 4 | 16 | 64 |
| --- | --- | --- | --- |
| nrFunctionCalls | 58533 → 58549 (+16, 0‰) within | 73701 → 73717 (+16, 0‰) within | 134373 → 134389 (+16, 0‰) within |
| nrPrimOpCalls | 29643 → 29649 (+6, 0‰) within | 37371 → 37377 (+6, 0‰) within | 68283 → 68289 (+6, 0‰) within |
| nrThunks | 83834 → 83856 (+22, 0‰) within | 99602 → 99624 (+22, 0‰) within | 162674 → 162696 (+22, 0‰) within |
| values.number | 102511 → 102560 (+49, 0‰) within | 122935 → 122984 (+49, 0‰) within | 204631 → 204680 (+49, 0‰) within |
| envs.number | 68754 → 68772 (+18, 0‰) within | 85278 → 85296 (+18, 0‰) within | 151374 → 151392 (+18, 0‰) within |
| sets.number | 15647 → 15655 (+8, 0‰) within | 19163 → 19171 (+8, 0‰) within | 33227 → 33235 (+8, 0‰) within |
| list.elements | 22343 → 22353 (+10, 0‰) within | 27083 → 27093 (+10, 0‰) within | 46043 → 46053 (+10, 0‰) within |
| list.concats | 1117 → 1118 (+1, 0‰) within | 1333 → 1334 (+1, 0‰) within | 2197 → 2198 (+1, 0‰) within |
| nrOpUpdates | 3736 → 3738 (+2, 0‰) within | 5176 → 5178 (+2, 0‰) within | 10936 → 10938 (+2, 0‰) within |
| nrOpUpdateValuesCopied | 4583 → 4585 (+2, 0‰) within | 4787 → 4789 (+2, 0‰) within | 5603 → 5605 (+2, 0‰) within |
| heapBytes | 4372432 → 4374184 (+1752, 0‰) within | 5240752 → 5242504 (+1752, 0‰) within | 8714032 → 8715784 (+1752, 0‰) within |

| marker entries | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/declarations.compileDeclaration | candidate only, 2 | candidate only, 2 | candidate only, 2 |
| src/declarations.prepareDeclaration | candidate only, 1 | candidate only, 1 | candidate only, 1 |
| src/program/theme.composeThemes | candidate only, 1 | candidate only, 1 | candidate only, 1 |

| inclusive samples, baseline → candidate | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/declarations.compileDeclaration | n/a → 2 of 92 | n/a → 5 of 103 | n/a → 14 of 116 |
| src/declarations.prepareDeclaration | n/a → 1 of 92 | n/a → 3 of 103 | n/a → 8 of 116 |
| src/program/theme.composeThemes | n/a → 2 of 92 | n/a → 1 of 103 | n/a → 1 of 116 |

Applications by owner that moved

- 4: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 4: src/declarations 2305 → 2308 (+3, +1‰)
- 4: src/program/theme 29 → 30 (+1, +34‰)
- 16: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 16: src/declarations 4105 → 4108 (+3, 0‰)
- 16: src/program/theme 29 → 30 (+1, +34‰)
- 64: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 64: src/declarations 11305 → 11308 (+3, 0‰)
- 64: src/program/theme 29 → 30 (+1, +34‰)

| timing, baseline → candidate median | 4 | 16 | 64 |
| --- | --- | --- | --- |
| wallMs | 262 → 270 | 262 → 270 | 284 → 289 |
| cpuMs | 163 → 167 | 163 → 171 | 183 → 186 |
| peakRssKiB | 65852 → 65812 | 67196 → 67124 | 70976 → 70736 |
| heapSize | 402915328 → 402915328 | 402915328 → 402915328 | 402915328 → 402915328 |

Machines lumi, one-minute load at launch from 1.81 to 1.83.

### subsystem.furnish.shared

| counter | 4 | 16 | 64 |
| --- | --- | --- | --- |
| nrFunctionCalls | 142031 → 142164 (+133, 0‰) within | 718931 → 720384 (+1453, +2‰) within | 9008291 → 9029424 (+21133, +2‰) within |
| nrPrimOpCalls | 73794 → 73803 (+9, 0‰) within | 427866 → 427875 (+9, 0‰) within | 5645754 → 5645763 (+9, 0‰) within |
| nrThunks | 187562 → 187708 (+146, 0‰) within | 918038 → 919504 (+1466, +1‰) within | 11492102 → 11513248 (+21146, +1‰) within |
| values.number | 225724 → 225899 (+175, 0‰) within | 1093216 → 1094711 (+1495, +1‰) within | 13669744 → 13690919 (+21175, +1‰) within |
| envs.number | 165228 → 165363 (+135, 0‰) within | 823824 → 825279 (+1455, +1‰) within | 10298208 → 10319343 (+21135, +2‰) within |
| sets.number | 35208 → 35218 (+10, 0‰) within | 190668 → 190678 (+10, 0‰) within | 2454108 → 2454118 (+10, 0‰) within |
| list.elements | 46025 → 46035 (+10, 0‰) within | 201713 → 201723 (+10, 0‰) within | 2474705 → 2474715 (+10, 0‰) within |
| list.concats | 2589 → 2590 (+1, 0‰) within | 13221 → 13222 (+1, 0‰) within | 156549 → 156550 (+1, 0‰) within |
| nrOpUpdates | 7730 → 7732 (+2, 0‰) within | 44558 → 44560 (+2, 0‰) within | 574910 → 574912 (+2, 0‰) within |
| nrOpUpdateValuesCopied | 7873 → 7875 (+2, 0‰) within | 21373 → 21375 (+2, 0‰) within | 225133 → 225135 (+2, 0‰) within |
| heapBytes | 9587152 → 9592920 (+5768, 0‰) within | 45574576 → 45622584 (+48008, +1‰) within | 566619952 → 567297720 (+677768, +1‰) within |

| marker entries | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/declarations.compileDeclaration | candidate only, 8 | candidate only, 32 | candidate only, 128 |
| src/declarations.prepareDeclaration | candidate only, 1 | candidate only, 1 | candidate only, 1 |
| src/ownerships.mergeContributions | candidate only, 44 | candidate only, 560 | candidate only, 8384 |
| src/ownerships.resolveContext | candidate only, 60 | candidate only, 816 | candidate only, 12480 |
| src/program.inventoryDirectory | candidate only, 4 | candidate only, 16 | candidate only, 64 |
| src/program/theme.composeThemes | candidate only, 4 | candidate only, 16 | candidate only, 64 |

| inclusive samples, baseline → candidate | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/declarations.compileDeclaration | n/a → 19 of 130 | n/a → 176 of 370 | n/a → 2293 of 3623 |
| src/declarations.prepareDeclaration | n/a → 3 of 130 | n/a → 7 of 370 | n/a → 21 of 3623 |
| src/ownerships.mergeContributions | n/a → 1 of 130 | n/a → 0 of 370 | n/a → 22 of 3623 |
| src/ownerships.resolveContext | n/a → 0 of 130 | n/a → 0 of 370 | n/a → 10 of 3623 |
| src/program.inventoryDirectory | n/a → 0 of 130 | n/a → 0 of 370 | n/a → 0 of 3623 |
| src/program/theme.composeThemes | n/a → 1 of 130 | n/a → 3 of 370 | n/a → 4 of 3623 |

Applications by owner that moved

- 4: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 4: src/declarations 5204 → 5213 (+9, +1‰)
- 4: src/ownerships 13032 → 13136 (+104, +7‰)
- 4: src/program 738 → 742 (+4, +5‰)
- 4: src/program/theme 113 → 117 (+4, +35‰)
- 16: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 16: src/declarations 41828 → 41861 (+33, 0‰)
- 16: src/ownerships 74304 → 75680 (+1376, +18‰)
- 16: src/program 10818 → 10834 (+16, +1‰)
- 16: src/program/theme 449 → 465 (+16, +35‰)
- 64: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 64: src/declarations 574244 → 574373 (+129, 0‰)
- 64: src/ownerships 849312 → 870176 (+20864, +24‰)
- 64: src/program 169218 → 169282 (+64, 0‰)
- 64: src/program/theme 1793 → 1857 (+64, +35‰)

| timing, baseline → candidate median | 4 | 16 | 64 |
| --- | --- | --- | --- |
| wallMs | 295 → 304 | 514 → 509 | 3550 → 3539 |
| cpuMs | 194 → 191 | 387 → 385 | 3198 → 3226 |
| peakRssKiB | 72476 → 72508 | 112288 → 112272 | 488460 → 488248 |
| heapSize | 402915328 → 402915328 | 402915328 → 402915328 | 402915328 → 402915328 |

Machines lumi, one-minute load at launch from 1.51 to 1.92.

### subsystem.ownerships.fleet-custom

| counter | 4 | 16 | 64 |
| --- | --- | --- | --- |
| nrFunctionCalls | 34865 → 34879 (+14, 0‰) within | 38393 → 38407 (+14, 0‰) within | 61145 → 61159 (+14, 0‰) within |
| nrPrimOpCalls | 15108 → 15114 (+6, 0‰) within | 17052 → 17058 (+6, 0‰) within | 24828 → 24834 (+6, 0‰) within |
| nrThunks | 54585 → 54605 (+20, 0‰) within | 60081 → 60101 (+20, 0‰) within | 93585 → 93605 (+20, 0‰) within |
| values.number | 66905 → 66951 (+46, 0‰) within | 73307 → 73353 (+46, 0‰) within | 114755 → 114801 (+46, 0‰) within |
| envs.number | 41761 → 41777 (+16, 0‰) within | 46165 → 46181 (+16, 0‰) within | 75301 → 75317 (+16, 0‰) within |
| sets.number | 9187 → 9194 (+7, 0‰) within | 10543 → 10550 (+7, 0‰) within | 21727 → 21734 (+7, 0‰) within |
| list.elements | 13407 → 13417 (+10, 0‰) within | 14379 → 14389 (+10, 0‰) within | 21147 → 21157 (+10, 0‰) within |
| list.concats | 807 → 808 (+1, +1‰) within | 903 → 904 (+1, +1‰) within | 1287 → 1288 (+1, 0‰) within |
| nrOpUpdates | 2138 → 2140 (+2, 0‰) within | 2582 → 2584 (+2, 0‰) within | 7238 → 7240 (+2, 0‰) within |
| nrOpUpdateValuesCopied | 4127 → 4129 (+2, 0‰) within | 4439 → 4441 (+2, 0‰) within | 8567 → 8569 (+2, 0‰) within |
| heapBytes | 2857176 → 2858816 (+1640, 0‰) within | 3128664 → 3130304 (+1640, 0‰) within | 5067096 → 5068736 (+1640, 0‰) within |

| marker entries | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/ownerships.mergeContributions | candidate only, 1 | candidate only, 1 | candidate only, 1 |
| src/ownerships.resolveContext | candidate only, 1 | candidate only, 1 | candidate only, 1 |

| inclusive samples, baseline → candidate | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/ownerships.mergeContributions | n/a → 0 of 80 | n/a → 0 of 79 | n/a → 1 of 88 |
| src/ownerships.resolveContext | n/a → 0 of 80 | n/a → 0 of 79 | n/a → 0 of 88 |

Applications by owner that moved

- 4: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 4: src/ownerships 541 → 543 (+2, +3‰)
- 16: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 16: src/ownerships 1987 → 1989 (+2, +1‰)
- 64: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 64: src/ownerships 14971 → 14973 (+2, 0‰)

| timing, baseline → candidate median | 4 | 16 | 64 |
| --- | --- | --- | --- |
| wallMs | 246 → 242 | 243 → 245 | 260 → 260 |
| cpuMs | 148 → 148 | 144 → 145 | 151 → 158 |
| peakRssKiB | 63244 → 63324 | 63932 → 63348 | 66656 → 66160 |
| heapSize | 402915328 → 402915328 | 402915328 → 402915328 | 402915328 → 402915328 |

Machines lumi, one-minute load at launch from 1.40 to 1.53.

### subsystem.ownerships.fleet-matrix

| counter | 4 | 16 | 64 |
| --- | --- | --- | --- |
| nrFunctionCalls | 50192 → 50204 (+12, 0‰) within | 148532 → 148544 (+12, 0‰) within | 1987652 → 1987664 (+12, 0‰) within |
| nrPrimOpCalls | 25470 → 25474 (+4, 0‰) within | 98760 → 98764 (+4, 0‰) within | 1214160 → 1214164 (+4, 0‰) within |
| nrThunks | 72947 → 72963 (+16, 0‰) within | 200957 → 200973 (+16, 0‰) within | 2099717 → 2099733 (+16, 0‰) within |
| values.number | 89008 → 89049 (+41, 0‰) within | 234910 → 234951 (+41, 0‰) within | 2398198 → 2398239 (+41, 0‰) within |
| envs.number | 59652 → 59666 (+14, 0‰) within | 179544 → 179558 (+14, 0‰) within | 2346792 → 2346806 (+14, 0‰) within |
| sets.number | 12499 → 12505 (+6, 0‰) within | 35029 → 35035 (+6, 0‰) within | 368509 → 368515 (+6, 0‰) within |
| list.elements | 18479 → 18489 (+10, 0‰) within | 45977 → 45987 (+10, 0‰) within | 454049 → 454059 (+10, 0‰) within |
| list.concats | 1199 → 1200 (+1, 0‰) within | 4475 → 4476 (+1, 0‰) within | 52139 → 52140 (+1, 0‰) within |
| nrOpUpdates | 2370 → 2372 (+2, 0‰) within | 4050 → 4052 (+2, 0‰) within | 22290 → 22292 (+2, 0‰) within |
| nrOpUpdateValuesCopied | 4192 → 4194 (+2, 0‰) within | 4864 → 4866 (+2, 0‰) within | 13312 → 13314 (+2, 0‰) within |
| heapBytes | 3780600 → 3782072 (+1472, 0‰) within | 9836568 → 9838040 (+1472, 0‰) within | 105899160 → 105900632 (+1472, 0‰) within |

No marker was entered.


Applications by owner that moved

- 4: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 16: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 64: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)

| timing, baseline → candidate median | 4 | 16 | 64 |
| --- | --- | --- | --- |
| wallMs | 252 → 249 | 287 → 282 | 861 → 844 |
| cpuMs | 152 → 152 | 182 → 185 | 696 → 679 |
| peakRssKiB | 64556 → 64864 | 71208 → 71192 | 180276 → 180176 |
| heapSize | 402915328 → 402915328 | 402915328 → 402915328 | 402915328 → 402915328 |

Machines lumi, one-minute load at launch from 1.45 to 1.53.

### subsystem.ownerships.fleet-prepared

| counter | 4 | 16 | 64 |
| --- | --- | --- | --- |
| nrFunctionCalls | 48184 → 48204 (+20, 0‰) within | 108064 → 108108 (+44, 0‰) within | 940864 → 941004 (+140, 0‰) within |
| nrPrimOpCalls | 23802 → 23808 (+6, 0‰) within | 71022 → 71028 (+6, 0‰) within | 766782 → 766788 (+6, 0‰) within |
| nrThunks | 69925 → 69951 (+26, 0‰) within | 149329 → 149379 (+50, 0‰) within | 1261825 → 1261971 (+146, 0‰) within |
| values.number | 85574 → 85626 (+52, 0‰) within | 177986 → 178062 (+76, 0‰) within | 1480754 → 1480926 (+172, 0‰) within |
| envs.number | 57101 → 57123 (+22, 0‰) within | 128789 → 128835 (+46, 0‰) within | 1129781 → 1129923 (+142, 0‰) within |
| sets.number | 11982 → 11989 (+7, 0‰) within | 26310 → 26317 (+7, 0‰) within | 227622 → 227629 (+7, 0‰) within |
| list.elements | 17670 → 17680 (+10, 0‰) within | 34032 → 34042 (+10, 0‰) within | 267960 → 267970 (+10, 0‰) within |
| list.concats | 1097 → 1098 (+1, 0‰) within | 2909 → 2910 (+1, 0‰) within | 27437 → 27438 (+1, 0‰) within |
| nrOpUpdates | 2354 → 2356 (+2, 0‰) within | 3986 → 3988 (+2, 0‰) within | 22034 → 22036 (+2, 0‰) within |
| nrOpUpdateValuesCopied | 4180 → 4182 (+2, 0‰) within | 4816 → 4818 (+2, 0‰) within | 13120 → 13122 (+2, 0‰) within |
| heapBytes | 3639232 → 3641064 (+1832, 0‰) within | 7360432 → 7363032 (+2600, 0‰) within | 59627632 → 59633304 (+5672, 0‰) within |

| marker entries | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/ownerships.mergeContributions | candidate only, 4 | candidate only, 16 | candidate only, 64 |
| src/ownerships.resolveContext | candidate only, 4 | candidate only, 16 | candidate only, 64 |

| inclusive samples, baseline → candidate | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/ownerships.mergeContributions | n/a → 0 of 83 | n/a → 0 of 104 | n/a → 0 of 408 |
| src/ownerships.resolveContext | n/a → 0 of 83 | n/a → 0 of 104 | n/a → 0 of 408 |

Applications by owner that moved

- 4: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 4: src/ownerships 4528 → 4536 (+8, +1‰)
- 16: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 16: src/ownerships 24304 → 24336 (+32, +1‰)
- 64: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 64: src/ownerships 281968 → 282096 (+128, 0‰)

| timing, baseline → candidate median | 4 | 16 | 64 |
| --- | --- | --- | --- |
| wallMs | 246 → 252 | 283 → 267 | 557 → 575 |
| cpuMs | 153 → 152 | 173 → 172 | 428 → 436 |
| peakRssKiB | 64236 → 64716 | 68204 → 68336 | 125548 → 125572 |
| heapSize | 402915328 → 402915328 | 402915328 → 402915328 | 402915328 → 402915328 |

Machines lumi, one-minute load at launch from 1.41 to 1.46.

### subsystem.ownerships.fleet-resolve

| counter | 4 | 16 | 64 |
| --- | --- | --- | --- |
| nrFunctionCalls | 55782 → 55802 (+20, 0‰) within | 252414 → 252458 (+44, 0‰) within | 3334302 → 3334442 (+140, 0‰) within |
| nrPrimOpCalls | 26722 → 26728 (+6, 0‰) within | 125398 → 125404 (+6, 0‰) within | 1663462 → 1663468 (+6, 0‰) within |
| nrThunks | 78658 → 78684 (+26, 0‰) within | 313042 → 313092 (+50, 0‰) within | 3966418 → 3966564 (+146, 0‰) within |
| values.number | 95360 → 95412 (+52, 0‰) within | 362084 → 362160 (+76, 0‰) within | 4524980 → 4525152 (+172, 0‰) within |
| envs.number | 65667 → 65689 (+22, 0‰) within | 290943 → 290989 (+46, 0‰) within | 3815727 → 3815869 (+142, 0‰) within |
| sets.number | 13382 → 13389 (+7, 0‰) within | 52214 → 52221 (+7, 0‰) within | 653942 → 653949 (+7, 0‰) within |
| list.elements | 19063 → 19073 (+10, 0‰) within | 60073 → 60083 (+10, 0‰) within | 697873 → 697883 (+10, 0‰) within |
| list.concats | 1394 → 1395 (+1, 0‰) within | 8534 → 8535 (+1, 0‰) within | 120614 → 120615 (+1, 0‰) within |
| nrOpUpdates | 2930 → 2932 (+2, 0‰) within | 15506 → 15508 (+2, 0‰) within | 215570 → 215572 (+2, 0‰) within |
| nrOpUpdateValuesCopied | 4286 → 4288 (+2, 0‰) within | 6974 → 6976 (+2, 0‰) within | 49406 → 49408 (+2, 0‰) within |
| heapBytes | 4038504 → 4040336 (+1832, 0‰) within | 14847000 → 14849600 (+2600, 0‰) within | 183314904 → 183320576 (+5672, 0‰) within |

| marker entries | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/ownerships.mergeContributions | candidate only, 4 | candidate only, 16 | candidate only, 64 |
| src/ownerships.resolveContext | candidate only, 4 | candidate only, 16 | candidate only, 64 |

| inclusive samples, baseline → candidate | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/ownerships.mergeContributions | n/a → 0 of 83 | n/a → 0 of 148 | n/a → 0 of 1186 |
| src/ownerships.resolveContext | n/a → 0 of 83 | n/a → 0 of 148 | n/a → 1 of 1186 |

Applications by owner that moved

- 4: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 4: src/ownerships 8316 → 8324 (+8, 0‰)
- 16: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 16: src/ownerships 96504 → 96536 (+32, 0‰)
- 64: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 64: src/ownerships 1480296 → 1480424 (+128, 0‰)

| timing, baseline → candidate median | 4 | 16 | 64 |
| --- | --- | --- | --- |
| wallMs | 249 → 250 | 318 → 312 | 1306 → 1302 |
| cpuMs | 152 → 152 | 213 → 210 | 1092 → 1095 |
| peakRssKiB | 64696 → 64664 | 76752 → 76372 | 259880 → 259768 |
| heapSize | 402915328 → 402915328 | 402915328 → 402915328 | 402915328 → 402915328 |

Machines lumi, one-minute load at launch from 1.42 to 1.56.

### subsystem.ownerships.fleet-trace

| counter | 4 | 16 | 64 |
| --- | --- | --- | --- |
| nrFunctionCalls | 45487 → 45501 (+14, 0‰) within | 57367 → 57381 (+14, 0‰) within | 104887 → 104901 (+14, 0‰) within |
| nrPrimOpCalls | 21601 → 21607 (+6, 0‰) within | 28201 → 28207 (+6, 0‰) within | 54601 → 54607 (+6, 0‰) within |
| nrThunks | 66227 → 66247 (+20, 0‰) within | 80903 → 80923 (+20, 0‰) within | 139607 → 139627 (+20, 0‰) within |
| values.number | 81329 → 81375 (+46, 0‰) within | 98093 → 98139 (+46, 0‰) within | 165149 → 165195 (+46, 0‰) within |
| envs.number | 53834 → 53850 (+16, 0‰) within | 67658 → 67674 (+16, 0‰) within | 122954 → 122970 (+16, 0‰) within |
| sets.number | 11304 → 11311 (+7, 0‰) within | 13848 → 13855 (+7, 0‰) within | 24024 → 24031 (+7, 0‰) within |
| list.elements | 16938 → 16948 (+10, 0‰) within | 19836 → 19846 (+10, 0‰) within | 32868 → 32878 (+10, 0‰) within |
| list.concats | 1025 → 1026 (+1, 0‰) within | 1469 → 1470 (+1, 0‰) within | 3245 → 3246 (+1, 0‰) within |
| nrOpUpdates | 2304 → 2306 (+2, 0‰) within | 3000 → 3002 (+2, 0‰) within | 5784 → 5786 (+2, 0‰) within |
| nrOpUpdateValuesCopied | 4163 → 4165 (+2, 0‰) within | 4355 → 4357 (+2, 0‰) within | 5123 → 5125 (+2, 0‰) within |
| heapBytes | 3468032 → 3469672 (+1640, 0‰) within | 4154480 → 4156120 (+1640, 0‰) within | 6911792 → 6913432 (+1640, 0‰) within |

| marker entries | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/ownerships.mergeContributions | candidate only, 1 | candidate only, 1 | candidate only, 1 |
| src/ownerships.resolveContext | candidate only, 1 | candidate only, 1 | candidate only, 1 |

| inclusive samples, baseline → candidate | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/ownerships.mergeContributions | n/a → 0 of 81 | n/a → 0 of 85 | n/a → 0 of 103 |
| src/ownerships.resolveContext | n/a → 0 of 81 | n/a → 0 of 85 | n/a → 0 of 103 |

Applications by owner that moved

- 4: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 4: src/ownerships 3722 → 3724 (+2, 0‰)
- 16: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 16: src/ownerships 9014 → 9016 (+2, 0‰)
- 64: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 64: src/ownerships 30182 → 30184 (+2, 0‰)

| timing, baseline → candidate median | 4 | 16 | 64 |
| --- | --- | --- | --- |
| wallMs | 250 → 242 | 255 → 267 | 263 → 277 |
| cpuMs | 144 → 147 | 161 → 154 | 169 → 176 |
| peakRssKiB | 63968 → 64476 | 64916 → 64844 | 67980 → 68204 |
| heapSize | 402915328 → 402915328 | 402915328 → 402915328 | 402915328 → 402915328 |

Machines lumi, one-minute load at launch from 1.47 to 1.51.

### subsystem.ownerships.resolve

| counter | 4 | 16 | 64 |
| --- | --- | --- | --- |
| nrFunctionCalls | 43172 → 43186 (+14, 0‰) within | 48788 → 48802 (+14, 0‰) within | 79892 → 79906 (+14, 0‰) within |
| nrPrimOpCalls | 20265 → 20271 (+6, 0‰) within | 22977 → 22983 (+6, 0‰) within | 33825 → 33831 (+6, 0‰) within |
| nrThunks | 63439 → 63459 (+20, 0‰) within | 70855 → 70875 (+20, 0‰) within | 112039 → 112059 (+20, 0‰) within |
| values.number | 78126 → 78172 (+46, 0‰) within | 86736 → 86782 (+46, 0‰) within | 137016 → 137062 (+46, 0‰) within |
| envs.number | 51169 → 51185 (+16, 0‰) within | 57925 → 57941 (+16, 0‰) within | 96469 → 96485 (+16, 0‰) within |
| sets.number | 10847 → 10854 (+7, 0‰) within | 12503 → 12510 (+7, 0‰) within | 24887 → 24894 (+7, 0‰) within |
| list.elements | 16366 → 16376 (+10, 0‰) within | 17674 → 17684 (+10, 0‰) within | 25786 → 25796 (+10, 0‰) within |
| list.concats | 929 → 930 (+1, +1‰) within | 1085 → 1086 (+1, 0‰) within | 1709 → 1710 (+1, 0‰) within |
| nrOpUpdates | 2188 → 2190 (+2, 0‰) within | 2752 → 2754 (+2, 0‰) within | 7888 → 7890 (+2, 0‰) within |
| nrOpUpdateValuesCopied | 4143 → 4145 (+2, 0‰) within | 4491 → 4493 (+2, 0‰) within | 8763 → 8765 (+2, 0‰) within |
| heapBytes | 3338360 → 3340000 (+1640, 0‰) within | 3706808 → 3708448 (+1640, 0‰) within | 6033080 → 6034720 (+1640, 0‰) within |

| marker entries | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/ownerships.mergeContributions | candidate only, 1 | candidate only, 1 | candidate only, 1 |
| src/ownerships.resolveContext | candidate only, 1 | candidate only, 1 | candidate only, 1 |

| inclusive samples, baseline → candidate | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/ownerships.mergeContributions | n/a → 0 of 80 | n/a → 0 of 82 | n/a → 1 of 94 |
| src/ownerships.resolveContext | n/a → 0 of 80 | n/a → 0 of 82 | n/a → 0 of 94 |

Applications by owner that moved

- 4: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 4: src/ownerships 2768 → 2770 (+2, 0‰)
- 16: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 16: src/ownerships 5750 → 5752 (+2, 0‰)
- 64: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 64: src/ownerships 24878 → 24880 (+2, 0‰)

| timing, baseline → candidate median | 4 | 16 | 64 |
| --- | --- | --- | --- |
| wallMs | 247 → 244 | 256 → 248 | 266 → 262 |
| cpuMs | 151 → 148 | 154 → 154 | 163 → 159 |
| peakRssKiB | 64004 → 64012 | 64440 → 64504 | 67580 → 67444 |
| heapSize | 402915328 → 402915328 | 402915328 → 402915328 | 402915328 → 402915328 |

Machines lumi, one-minute load at launch from 1.51 to 1.79.

### subsystem.praxis.diagnostics

| counter | 4 | 16 | 64 |
| --- | --- | --- | --- |
| nrFunctionCalls | 807669 → 807683 (+14, 0‰) within | 3017469 → 3017483 (+14, 0‰) within | 11856669 → 11856683 (+14, 0‰) within |
| nrPrimOpCalls | 219525 → 219530 (+5, 0‰) within | 804501 → 804506 (+5, 0‰) within | 3144405 → 3144410 (+5, 0‰) within |
| nrThunks | 853837 → 853855 (+18, 0‰) within | 3140641 → 3140659 (+18, 0‰) within | 12287857 → 12287875 (+18, 0‰) within |
| values.number | 888590 → 888634 (+44, 0‰) within | 3238934 → 3238978 (+44, 0‰) within | 12640310 → 12640354 (+44, 0‰) within |
| envs.number | 961409 → 961425 (+16, 0‰) within | 3591389 → 3591405 (+16, 0‰) within | 14111309 → 14111325 (+16, 0‰) within |
| sets.number | 129367 → 129374 (+7, 0‰) within | 472699 → 472706 (+7, 0‰) within | 1846027 → 1846034 (+7, 0‰) within |
| list.elements | 98295 → 98305 (+10, 0‰) within | 341139 → 341149 (+10, 0‰) within | 1315395 → 1315405 (+10, 0‰) within |
| list.concats | 4326 → 4327 (+1, 0‰) within | 14490 → 14491 (+1, 0‰) within | 55146 → 55147 (+1, 0‰) within |
| nrOpUpdates | 15495 → 15497 (+2, 0‰) within | 53547 → 53549 (+2, 0‰) within | 205755 → 205757 (+2, 0‰) within |
| nrOpUpdateValuesCopied | 16539 → 16541 (+2, 0‰) within | 51755 → 51757 (+2, 0‰) within | 192803 → 192805 (+2, 0‰) within |
| heapBytes | 41281864 → 41283456 (+1592, 0‰) within | 151122712 → 151124304 (+1592, 0‰) within | 590512024 → 590513616 (+1592, 0‰) within |

| marker entries | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/praxis.compileProject | candidate only, 1 | candidate only, 1 | candidate only, 1 |
| src/praxis.normalizeCommands | candidate only, 1 | candidate only, 1 | candidate only, 1 |

| inclusive samples, baseline → candidate | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/praxis.compileProject | n/a → 60 of 313 | n/a → 60 of 963 | n/a → 58 of 3534 |
| src/praxis.normalizeCommands | n/a → 60 of 313 | n/a → 60 of 963 | n/a → 58 of 3534 |

Applications by owner that moved

- 4: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 4: src/praxis 3268 → 3270 (+2, 0‰)
- 16: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 16: src/praxis 11788 → 11790 (+2, 0‰)
- 64: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 64: src/praxis 45868 → 45870 (+2, 0‰)

| timing, baseline → candidate median | 4 | 16 | 64 |
| --- | --- | --- | --- |
| wallMs | 482 → 483 | 1145 → 1157 | 3632 → 3672 |
| cpuMs | 360 → 365 | 962 → 959 | 3321 → 3342 |
| peakRssKiB | 106912 → 106856 | 227564 → 227528 | 488716 → 488724 |
| heapSize | 402915328 → 402915328 | 402915328 → 402915328 | 402915328 → 402915328 |

Machines lumi, one-minute load at launch from 1.51 to 1.79.

### subsystem.praxis.manifest

| counter | 4 | 16 | 64 |
| --- | --- | --- | --- |
| nrFunctionCalls | 109567 → 109581 (+14, 0‰) within | 111595 → 111609 (+14, 0‰) within | 119711 → 119725 (+14, 0‰) within |
| nrPrimOpCalls | 67127 → 67132 (+5, 0‰) within | 68711 → 68716 (+5, 0‰) within | 75048 → 75053 (+5, 0‰) within |
| nrThunks | 244052 → 244070 (+18, 0‰) within | 247184 → 247202 (+18, 0‰) within | 259714 → 259732 (+18, 0‰) within |
| values.number | 716575 → 716619 (+44, 0‰) within | 720115 → 720159 (+44, 0‰) within | 734277 → 734321 (+44, 0‰) within |
| envs.number | 135208 → 135224 (+16, 0‰) within | 137716 → 137732 (+16, 0‰) within | 147752 → 147768 (+16, 0‰) within |
| sets.number | 44077 → 44084 (+7, 0‰) within | 44653 → 44660 (+7, 0‰) within | 46957 → 46964 (+7, 0‰) within |
| list.elements | 54154 → 54164 (+10, 0‰) within | 54718 → 54728 (+10, 0‰) within | 56974 → 56984 (+10, 0‰) within |
| list.concats | 4047 → 4048 (+1, 0‰) within | 4083 → 4084 (+1, 0‰) within | 4227 → 4228 (+1, 0‰) within |
| nrOpUpdates | 21762 → 21764 (+2, 0‰) within | 21858 → 21860 (+2, 0‰) within | 22242 → 22244 (+2, 0‰) within |
| nrOpUpdateValuesCopied | 1197854 → 1197856 (+2, 0‰) within | 1197922 → 1197924 (+2, 0‰) within | 1198378 → 1198380 (+2, 0‰) within |
| heapBytes | 42506616 → 42508208 (+1592, 0‰) within | 42652536 → 42654128 (+1592, 0‰) within | 43239192 → 43240784 (+1592, 0‰) within |

| marker entries | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/praxis.compileProject | candidate only, 1 | candidate only, 1 | candidate only, 1 |
| src/praxis.normalizeCommands | candidate only, 1 | candidate only, 1 | candidate only, 1 |

| inclusive samples, baseline → candidate | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/praxis.compileProject | n/a → 62 of 398 | n/a → 61 of 373 | n/a → 63 of 404 |
| src/praxis.normalizeCommands | n/a → 0 of 398 | n/a → 0 of 373 | n/a → 0 of 404 |

Applications by owner that moved

- 4: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 4: src/praxis 299 → 301 (+2, +6‰)
- 16: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 16: src/praxis 791 → 793 (+2, +2‰)
- 64: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 64: src/praxis 2761 → 2763 (+2, 0‰)

| timing, baseline → candidate median | 4 | 16 | 64 |
| --- | --- | --- | --- |
| wallMs | 626 → 651 | 642 → 619 | 641 → 622 |
| cpuMs | 407 → 431 | 429 → 421 | 420 → 416 |
| peakRssKiB | 120392 → 120112 | 120164 → 120420 | 120868 → 120972 |
| heapSize | 402915328 → 402915328 | 402915328 → 402915328 | 402915328 → 402915328 |

Machines lumi, one-minute load at launch from 1.39 to 1.46.

### subsystem.praxis.selected

| counter | 4 | 16 | 64 |
| --- | --- | --- | --- |
| nrFunctionCalls | 161110 → 161124 (+14, 0‰) within | 237982 → 237996 (+14, 0‰) within | 545470 → 545484 (+14, 0‰) within |
| nrPrimOpCalls | 86205 → 86210 (+5, 0‰) within | 123393 → 123398 (+5, 0‰) within | 272145 → 272150 (+5, 0‰) within |
| nrThunks | 295570 → 295588 (+18, 0‰) within | 373318 → 373336 (+18, 0‰) within | 684310 → 684328 (+18, 0‰) within |
| values.number | 775763 → 775807 (+44, 0‰) within | 873995 → 874039 (+44, 0‰) within | 1266923 → 1266967 (+44, 0‰) within |
| envs.number | 194493 → 194509 (+16, 0‰) within | 281157 → 281173 (+16, 0‰) within | 627813 → 627829 (+16, 0‰) within |
| sets.number | 54828 → 54835 (+7, 0‰) within | 74292 → 74299 (+7, 0‰) within | 152148 → 152155 (+7, 0‰) within |
| list.elements | 66171 → 66181 (+10, 0‰) within | 93891 → 93901 (+10, 0‰) within | 204771 → 204781 (+10, 0‰) within |
| list.concats | 4379 → 4380 (+1, 0‰) within | 5075 → 5076 (+1, 0‰) within | 7859 → 7860 (+1, 0‰) within |
| nrOpUpdates | 22762 → 22764 (+2, 0‰) within | 24250 → 24252 (+2, 0‰) within | 30202 → 30204 (+2, 0‰) within |
| nrOpUpdateValuesCopied | 1198741 → 1198743 (+2, 0‰) within | 1199689 → 1199691 (+2, 0‰) within | 1203649 → 1203651 (+2, 0‰) within |
| heapBytes | 45305688 → 45307280 (+1592, 0‰) within | 49853560 → 49855152 (+1592, 0‰) within | 68047672 → 68049264 (+1592, 0‰) within |

| marker entries | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/praxis.compileProject | candidate only, 1 | candidate only, 1 | candidate only, 1 |
| src/praxis.normalizeCommands | candidate only, 1 | candidate only, 1 | candidate only, 1 |

| inclusive samples, baseline → candidate | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/praxis.compileProject | n/a → 59 of 412 | n/a → 66 of 439 | n/a → 58 of 529 |
| src/praxis.normalizeCommands | n/a → 59 of 412 | n/a → 66 of 439 | n/a → 58 of 529 |

Applications by owner that moved

- 4: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 4: src/praxis 3576 → 3578 (+2, 0‰)
- 16: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 16: src/praxis 12972 → 12974 (+2, 0‰)
- 64: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 64: src/praxis 50556 → 50558 (+2, 0‰)

| timing, baseline → candidate median | 4 | 16 | 64 |
| --- | --- | --- | --- |
| wallMs | 659 → 657 | 662 → 671 | 786 → 790 |
| cpuMs | 440 → 439 | 457 → 459 | 551 → 561 |
| peakRssKiB | 124376 → 124120 | 129268 → 128980 | 149144 → 149236 |
| heapSize | 402915328 → 402915328 | 402915328 → 402915328 | 402915328 → 402915328 |

Machines lumi, one-minute load at launch from 1.36 to 1.58.

### subsystem.registry.queries

| counter | 4 | 16 | 64 |
| --- | --- | --- | --- |
| nrFunctionCalls | 35859 → 35871 (+12, 0‰) within | 48051 → 48063 (+12, 0‰) within | 151795 → 151807 (+12, 0‰) within |
| nrPrimOpCalls | 15594 → 15598 (+4, 0‰) within | 21762 → 21766 (+4, 0‰) within | 63842 → 63846 (+4, 0‰) within |
| nrThunks | 54673 → 54686 (+13, 0‰) within | 63229 → 63242 (+13, 0‰) within | 117613 → 117626 (+13, 0‰) within |
| values.number | 67399 → 67437 (+38, 0‰) within | 79663 → 79701 (+38, 0‰) within | 171919 → 171957 (+38, 0‰) within |
| envs.number | 42761 → 42775 (+14, 0‰) within | 55877 → 55891 (+14, 0‰) within | 163317 → 163331 (+14, 0‰) within |
| sets.number | 9380 → 9386 (+6, 0‰) within | 11588 → 11594 (+6, 0‰) within | 26180 → 26186 (+6, 0‰) within |
| list.elements | 13988 → 13998 (+10, 0‰) within | 19418 → 19428 (+10, 0‰) within | 74258 → 74268 (+10, 0‰) within |
| list.concats | 856 → 857 (+1, +1‰) within | 1132 → 1133 (+1, 0‰) within | 2236 → 2237 (+1, 0‰) within |
| nrOpUpdates | 2158 → 2160 (+2, 0‰) within | 2470 → 2472 (+2, 0‰) within | 3718 → 3720 (+2, 0‰) within |
| nrOpUpdateValuesCopied | 4133 → 4135 (+2, 0‰) within | 4301 → 4303 (+2, 0‰) within | 4973 → 4975 (+2, 0‰) within |
| heapBytes | 2890952 → 2892352 (+1400, 0‰) within | 3487160 → 3488560 (+1400, 0‰) within | 8122488 → 8123888 (+1400, 0‰) within |

No marker was entered.


Applications by owner that moved

- 4: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 16: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 64: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)

| timing, baseline → candidate median | 4 | 16 | 64 |
| --- | --- | --- | --- |
| wallMs | 237 → 240 | 248 → 248 | 276 → 262 |
| cpuMs | 145 → 144 | 152 → 145 | 170 → 178 |
| peakRssKiB | 62624 → 62508 | 63524 → 63292 | 68572 → 68444 |
| heapSize | 402915328 → 402915328 | 402915328 → 402915328 | 402915328 → 402915328 |

Machines lumi, one-minute load at launch from 1.45 to 1.53.

### subsystem.registry.summary

| counter | 4 | 16 | 64 |
| --- | --- | --- | --- |
| nrFunctionCalls | 34308 → 34320 (+12, 0‰) within | 36876 → 36888 (+12, 0‰) within | 47150 → 47162 (+12, 0‰) within |
| nrPrimOpCalls | 14639 → 14643 (+4, 0‰) within | 16271 → 16275 (+4, 0‰) within | 22800 → 22804 (+4, 0‰) within |
| nrThunks | 53056 → 53069 (+13, 0‰) within | 55912 → 55925 (+13, 0‰) within | 67336 → 67349 (+13, 0‰) within |
| values.number | 65304 → 65342 (+38, 0‰) within | 68892 → 68930 (+38, 0‰) within | 83244 → 83282 (+38, 0‰) within |
| envs.number | 41015 → 41029 (+14, 0‰) within | 43967 → 43981 (+14, 0‰) within | 55777 → 55791 (+14, 0‰) within |
| sets.number | 8972 → 8978 (+6, 0‰) within | 9668 → 9674 (+6, 0‰) within | 12452 → 12458 (+6, 0‰) within |
| list.elements | 13251 → 13261 (+10, 0‰) within | 14385 → 14395 (+10, 0‰) within | 20361 → 20371 (+10, 0‰) within |
| list.concats | 782 → 783 (+1, +1‰) within | 854 → 855 (+1, +1‰) within | 1142 → 1143 (+1, 0‰) within |
| nrOpUpdates | 2094 → 2096 (+2, 0‰) within | 2214 → 2216 (+2, 0‰) within | 2694 → 2696 (+2, 0‰) within |
| nrOpUpdateValuesCopied | 4097 → 4099 (+2, 0‰) within | 4157 → 4159 (+2, 0‰) within | 4397 → 4399 (+2, 0‰) within |
| heapBytes | 2797488 → 2798888 (+1400, 0‰) within | 2957856 → 2959256 (+1400, 0‰) within | 3610880 → 3612280 (+1400, 0‰) within |

No marker was entered.


Applications by owner that moved

- 4: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 16: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 64: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)

| timing, baseline → candidate median | 4 | 16 | 64 |
| --- | --- | --- | --- |
| wallMs | 240 → 239 | 248 → 242 | 241 → 241 |
| cpuMs | 141 → 144 | 155 → 146 | 149 → 151 |
| peakRssKiB | 62528 → 62612 | 62708 → 62620 | 63540 → 63540 |
| heapSize | 402915328 → 402915328 | 402915328 → 402915328 | 402915328 → 402915328 |

Machines lumi, one-minute load at launch from 1.38 to 1.45.

### subsystem.theme.matugen

| counter | 4 | 16 | 64 |
| --- | --- | --- | --- |
| nrFunctionCalls | 93272 → 93300 (+28, 0‰) within | 164252 → 164328 (+76, 0‰) within | 448172 → 448440 (+268, 0‰) within |
| nrPrimOpCalls | 51287 → 51293 (+6, 0‰) within | 89783 → 89789 (+6, 0‰) within | 243767 → 243773 (+6, 0‰) within |
| nrThunks | 193122 → 193156 (+34, 0‰) within | 277794 → 277876 (+82, 0‰) within | 616482 → 616756 (+274, 0‰) within |
| values.number | 659754 → 659815 (+61, 0‰) within | 764142 → 764251 (+109, 0‰) within | 1181694 → 1181995 (+301, 0‰) within |
| envs.number | 109271 → 109301 (+30, 0‰) within | 188219 → 188297 (+78, 0‰) within | 504011 → 504281 (+270, 0‰) within |
| sets.number | 30819 → 30827 (+8, 0‰) within | 49527 → 49535 (+8, 0‰) within | 124359 → 124367 (+8, 0‰) within |
| list.elements | 36643 → 36653 (+10, 0‰) within | 58747 → 58757 (+10, 0‰) within | 147163 → 147173 (+10, 0‰) within |
| list.concats | 1787 → 1788 (+1, 0‰) within | 3227 → 3228 (+1, 0‰) within | 8987 → 8988 (+1, 0‰) within |
| nrOpUpdates | 10285 → 10287 (+2, 0‰) within | 14989 → 14991 (+2, 0‰) within | 33805 → 33807 (+2, 0‰) within |
| nrOpUpdateValuesCopied | 1161650 → 1161652 (+2, 0‰) within | 1162622 → 1162624 (+2, 0‰) within | 1166510 → 1166512 (+2, 0‰) within |
| heapBytes | 38988472 → 38990608 (+2136, 0‰) within | 43379896 → 43383568 (+3672, 0‰) within | 60945592 → 60955408 (+9816, 0‰) within |

| marker entries | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/declarations.compileDeclaration | candidate only, 8 | candidate only, 32 | candidate only, 128 |
| src/declarations.prepareDeclaration | candidate only, 4 | candidate only, 16 | candidate only, 64 |
| src/program/theme.composeThemes | candidate only, 4 | candidate only, 16 | candidate only, 64 |

| inclusive samples, baseline → candidate | 4 | 16 | 64 |
| --- | --- | --- | --- |
| src/declarations.compileDeclaration | n/a → 4 of 223 | n/a → 20 of 245 | n/a → 62 of 357 |
| src/declarations.prepareDeclaration | n/a → 4 of 223 | n/a → 6 of 245 | n/a → 31 of 357 |
| src/program/theme.composeThemes | n/a → 1 of 223 | n/a → 6 of 245 | n/a → 14 of 357 |

Applications by owner that moved

- 4: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 4: src/declarations 3661 → 3673 (+12, +3‰)
- 4: src/program/theme 276 → 280 (+4, +14‰)
- 16: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 16: src/declarations 10549 → 10597 (+48, +4‰)
- 16: src/program/theme 1020 → 1036 (+16, +15‰)
- 64: github:nix-community/nixpkgs.lib 13697 → 13709 (+12, 0‰)
- 64: src/declarations 38101 → 38293 (+192, +5‰)
- 64: src/program/theme 3996 → 4060 (+64, +16‰)

| timing, baseline → candidate median | 4 | 16 | 64 |
| --- | --- | --- | --- |
| wallMs | 417 → 415 | 443 → 449 | 549 → 555 |
| cpuMs | 277 → 278 | 302 → 308 | 393 → 393 |
| peakRssKiB | 110520 → 110660 | 115588 → 115672 | 135108 → 135168 |
| heapSize | 402915328 → 402915328 | 402915328 → 402915328 | 402915328 → 402915328 |

Machines lumi, one-minute load at launch from 1.36 to 1.43.

### subsystem.toml.generate

Every size was rejected.
