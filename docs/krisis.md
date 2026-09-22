# krisis

krisis is how every other subsystem says something is wrong. A subsystem
declares the codes it can report, emits them as effect requests, and the
caller installs the policy that decides what a report means. Nothing throws
on a subsystem's behalf.

This file is the reference first and the usage guide second, so nobody has to
read `src/krisis/` to use it.

## Two failure classes, and they behave differently

Read this before writing your first vocabulary.

A **reported diagnostic** is data. It travels as an effect, a policy handles
it, and a caller chooses whether it ends the build. Every code in the tables
below is one of these.

A **thrown misuse** is not. krisis throws, with a message prefixed
`krisis: `, when the code using it is wrong rather than when the
configuration being checked is wrong. No policy catches these, no gate
replays them, and they take the evaluation down.

The throws, all of them:

| Where | When |
| --- | --- |
| `vocabulary` | any defect in the spec, with every problem joined by `; ` |
| an emitter | `message` came back as something other than a string |
| an emitter | the emit arguments aren't an attrset, or `context` isn't |
| `rendering.bounded` | an unknown option, or an option of the wrong type |
| `renderPath` | the path isn't a list, or a segment isn't a string or a non-negative integer |
| `suggest` family | input isn't a string, candidates aren't a list of strings, or `maxDistance` isn't a non-negative integer or null |

The split is deliberate. A misspelled field in someone's configuration is a
diagnostic; a misspelled key in your own vocabulary declaration is a bug in
your subsystem, and it fails at import rather than waiting for the code path
that would have reported it.

**krisis declares no codes of its own.** It's the mechanism. Every code in
the catalogue below belongs to a subsystem's vocabulary, and the namespace on
a code tells you which one.

## Reference

### Running a computation

`run` is the entry point (`src/krisis/default.nix`). It takes a policy and a
rendering, installs both as effect handlers alongside a halt handler, runs the
computation through `fx.run`, and hands the resulting `{ value, state }` to
the policy's `result` function:

```nix
krisis.run { } computation
krisis.run { policy = krisis.policy.count; } computation
krisis.run { policy = krisis.policy.pretty { long = true; } krisis.policy.collect; } computation
```

The defaults are `policy.collect` and `rendering.default`. The halt handler is
installed outside the policy's handlers, which is why a `gate` halts the run
even under a policy that would otherwise keep collecting.

### The diagnostic record

Every reported diagnostic is an attrset with a fixed set of fields:

| field | what's in it |
| --- | --- |
| `code` | namespace-qualified, like `kata/unknown-block` |
| `severity` | one of `error`, `warning`, `info` |
| `source` | which part of the emitting subsystem said this; defaults to the namespace |
| `at` | an already-rendered path string like `$.users[0].shell`, or `null` |
| `message` | the rendered human sentence |
| `notes` | a list of extra strings, often empty |
| `help` | a longer hint, or `null` |
| `rendered` | the one-line form, like `error: ports/unknown-port at $.services.web.port: unknown port 99999` |

`at` arrives as a list of path segments and leaves as a string; the emitter
runs it through `renderPath` before the diagnostic is built. The raw context
values an emitter was given are not carried on the record. They're rendered to
strings on the way in and then dropped, so a diagnostic never holds a live
reference to configuration data.

### Policies

A policy decides what a run returns. They live in `src/krisis/policy.nix` and
all of them pass the computation's own value through under `value`, so you can
collect diagnostics and still get your result.

| policy | result shape |
| --- | --- |
| `collect` | `{ diagnostics, total, hasErrors, halted, value }` |
| `inspect` | the same attrset, under a second name |
| `stopFirst` | collect's shape, but the first error aborts the rest of the computation |
| `count` | `{ total, bySeverity, byCode, hasErrors, halted, value }` |
| `pretty { long ? false }` | a function onto another policy; `{ report, lines, total, hasErrors, halted, value }` |

`collect` keeps every diagnostic in emission order
(`testCollectKeepsEveryDiagnostic` in `tests/krisis.nix`). `stopFirst` stops at
the first `error` and leaves warnings alone
(`testStopFirstHaltsOnTheFirstError`).

`count` is the cheap one. Its handler state holds codes and severities and
nothing else, no messages, because the effect trampoline `deepSeq`s handler
state between steps and carrying rendered strings there would force all of
them. `testCountTallies` pins the tallies.

`pretty` is a wrapper rather than a policy on its own: you apply it to a policy
and it adds `report` (one string) and `lines` (the same content as a list).
With `long = true` it also emits indented `note:` lines and a `help:` line
(`testPrettyRendersLines`, `testPrettyLongIncludesHelp`). One thing to watch:
the `pretty` result has no `diagnostics` key, so code that reaches for
`result.diagnostics` after wrapping in `pretty` gets an attribute error rather
than an empty list.

A halted run is marked with the sentinel `{ __krisisHalted = true; }`, and
`policy.wasHalted` tests a value for it.

### Renderings

A rendering is the handler that turns a configuration value into a string safe
to put in a message. It lives in `src/krisis/render.nix` and exists because a
value you're complaining about might be enormous, might be a derivation, or
might itself throw.

`rendering.bounded` takes a budget:

```nix
krisis.rendering.bounded {
  maxStringLength = 256;   # strings and paths truncate past this, with a … marker
  maxListItems = 32;       # lists of scalars show the first N, then (+N more)
  maxAttrs = 32;
  attrsets = "unrenderable"; # or "shape", which prints { a, b }
  fallback = "<unrenderable value>";
}
```

`rendering.default` is `bounded { }`. `rendering.strict` is a tighter budget
(`maxStringLength = 64`, `maxListItems = 8`, attrsets unrenderable).

Scalars go through `toJSON`. Derivations become `<derivation name>` without
being built. Functions become `<function>`. A value whose evaluation throws
costs you the fallback string instead of taking down the run
(`testPoisonValueFallsBack`). Turning attrsets on with `attrsets = "shape"`
gives you the key names only, never the values (`testAttrsetsCanBeShownAsShape`).

The budget itself is `deepSeq`-forced when the rendering is constructed, so a
budget with a bad option throws at the line where you wrote it rather than
later inside a message (`testMalformedBudgetIsTheCallersBug`). Because the
rendering is installed by `run` and not by the emitter, the caller controls how
much of their own data appears in a report
(`testInterpreterOwnsTheBudget`).

### Declaring a vocabulary

`vocabulary` (`src/krisis/vocabulary.nix`) takes a spec and gives back an
emitter bound to one namespace:

```nix
krisis.vocabulary {
  namespace = "ports";
  source = "ports";        # optional, defaults to the namespace
  severity = "error";      # optional vocabulary-wide default
  codes = {
    unknown-port = {
      message = given: "unknown port ${given.rendered.port}";
      severity = "warning";
      help = "ports run from 1 to 65535";
      notes = [ ];
    };
  };
}
```

The result is `{ namespace, source, catalogue, codes, emit, reserved }`.
`codes` holds the namespace-qualified names, so `codes.unknown-port` is the
string `"ports/unknown-port"` (`testCodesAreNamespaced`). `catalogue` is a list
of `{ code, severity, help, notes }` for every declared code, which is what you
would walk to generate documentation.

Construction validates, and it validates strictly. The namespace matches
`[a-z][a-z0-9-]*` (`testBadNamespaceIsRejected`) and code names match
`[a-z0-9]+(-[a-z0-9]+)*`. Declaration fields are closed: an unrecognised key
in a declaration throws, rather than being ignored as a future extension
(`testUnknownDeclarationFieldIsRejected`). `message` is required and is either
a string or a function of the emit arguments. Every spec defect found in one
pass is reported together, joined with `; `.

### Emitting

`report` sends one diagnostic, `reportAll` sends a list of them, and both live
in `src/krisis/emit.nix`. You call them through a vocabulary's `emit`:

```nix
vocab.emit.unknown-port {
  at = [ "services" "web" "port" ];
  context = { port = 99999; };
}
```

Six argument names are reserved and shape the diagnostic rather than the
message: `at`, `source`, `severity`, `notes`, `help`, `context`. Anything else
you pass goes through to the message function untouched, which is how kata
passes a `suggestion` alongside the offending key
(`testSuggestionReachesTheMessage`).

Values under `context` are sent through the render effect before the message
function runs, and the message function receives its arguments with a
`rendered` attrset added. That's why the example above writes
`given.rendered.port` and not `given.context.port`: by the time the message is
built, the number has already become a bounded string.

Severity resolves from the emit call, then the declaration, then the
vocabulary's default, then `error`. The diagnostic's `source` resolves from the
emit call, then the spec, then the namespace
(`testCollectSeesTheVocabularySeverityDefault`).

`gate` is the phase separator. It runs a computation under a local collecting
handler, replays the diagnostics it saw outward in order so the enclosing
policy still sees all of them, and then sends the halt effect if any of them
was an error. The effect of that is a barrier: work after the gate doesn't run
when work before it failed (`testGateStopsTheDependentPhase`), while warnings
pass through and the run continues (`testGateLetsWarningsThrough`).

### Helpers

`renderPath` (`src/krisis/path.nix`) turns a list of segments into the string
form that shows up in `at`. Strings become `.key`, non-negative integers become
`[n]`, and the whole thing hangs off `$`, so `[ "users" 0 "shell" ]` renders as
`$.users[0].shell` (`testRenderPath`).

`suggest` (`src/krisis/suggest.nix`) is the did-you-mean helper.
`editDistance` is `lib.strings.levenshtein`. `suggest input candidates` picks
the closest candidate within a threshold, or `null` if nothing is close
enough, and ties go to the first candidate in the list. `suggestWith` takes an
explicit `maxDistance` instead of the built-in threshold.

The threshold depends on the length of the **input**: at most four characters
allows a distance of 1, longer inputs allow 3. So `suggest "abc" [ "wxyz" ]`
is `null` (`testSuggestRespectsTheShortNameRadius`). See the sharp edges below
for what that does to typos in short keys.

`show` is the direct form of the rendering, used inside `vocabulary.nix` to
render context values.

### Effect names

The three effects krisis defines are exposed as `effects`:

| attribute | effect name |
| --- | --- |
| `reportEffect` | `krisis/report` |
| `haltEffect` | `krisis/halt` |
| `renderEffect` | `krisis/render` |

`severities` is the list `[ "error" "warning" "info" ]`, in that order.

### The code catalogue

Five vocabularies exist in the tree. Each file is the authoritative list of
its codes, including the message and help text; what follows is the shape of
each namespace and the things worth knowing before you read one.

| namespace | declared in | codes | notes |
| --- | --- | --- | --- |
| `kata` | `src/kata/vocabulary.nix` | 19 | all have producers; `unknown-block` is the only code that defaults to `warning`, and `strict` promotes it to an error |
| `kata`, per-block | the block files under `src/kata/blocks/` | 6 | same namespace, but `source` is the block name: `nixos-interior`, `home-manager-interior`, `furnish-unknown-field`, `furnish-malformed-field`, `theme-unknown-field`, `theme-malformed-field` |
| `lexicon` | `src/koseki/vocabulary.nix` | 22 | three are `info` (`derived-override`, `source-override`, `rename-repairing`); `unknown-host` and `unknown-user` are declared but nothing produces them |
| `settings` | `src/settings/vocabulary.nix` | 4 | `unknown-key`, `malformed-file`, `malformed-value`, `malformed-registration` |
| `emit` | `src/emit/vocabulary.nix` | 6 | `missing-capability`, `malformed-capability`, `unsupplyable-context-argument`, `aspect-carries-includes`, `aspect-carries-claim`, `malformed-emission` |

The namespace on a code is the subsystem that reported it, not the file the
mistake was in. A `lexicon/` code is about the identity registry's view of
your files even when the text lives in a kata document.

A handful of codes describe a contributor's bug rather than a configuration
author's mistake, because they can only fire if code in this repository
registered something wrong: `kata/malformed-registration`,
`kata/unknown-block-edge`, `kata/block-cycle`, `settings/malformed-registration`,
and `emit/unsupplyable-context-argument`. Seeing one of those in a report
means you're looking at a defect in lexicon, not in the configuration being
evaluated.

### Parts nothing in the tree calls

Everything above is public and supported. Some of it has no caller yet.
Nothing in `src/`, `mock/`, or `tests/` reaches for:

- `severities`
- `policy.inspect`, `policy.halted`, `policy.wasHalted`
- `rendering.strict`
- `show`, reached only indirectly as `render.show` from inside `vocabulary.nix`
- `suggestWith`, `editDistance`
- `effects`
- the vocabulary result's `catalogue` and `reserved`

These are untested in practice. They're implemented and they read correctly,
but no test pins their behaviour and no caller has exercised them, so the
first contributor to use one is the first real user of it.

## Usage

### Declaring codes for a new subsystem

The pattern every subsystem here follows: one `vocabulary.nix` next to the
code it serves, holding the whole namespace, imported by the modules that
emit. `src/settings/vocabulary.nix` is the smallest example and a reasonable
thing to copy.

Put the message text in the declaration rather than at the call site. A code's
message is written once and read in reports, so keeping it in the vocabulary
means you can read all of a subsystem's complaints in one file, and the emit
call stays about the position and the offending value.

### Where position comes from

An emitter passes `at` as a list of segments, and most of the time it doesn't
know the whole list. kata's block validators are the clearest case: a
validator sees only the interior it was handed, and `src/kata/block.nix`
installs a path prefix for the validator's dynamic extent, so a diagnostic
raised inside a block lands at the entry the block sits in without the block
knowing where that is.

For diagnostics about a declaration rather than a value inside one, kata uses
the file's relative origin, tracked as `where` on the stamp in
`src/kata/fold.nix`. For a value that came from no file at all, it uses the key
the value was written under. Either way the author sees a location they can
search for.

### Choosing a policy

If you're evaluating configuration and want to show the author everything
that's wrong, `pretty` over `collect` gives you a report string in one call.
If you need to branch on the outcome, `collect` and check `hasErrors`. If a
later phase would only produce noise once an earlier one failed, don't switch
policies; put a `gate` between the phases and keep collecting.

`count` is for when you want to know the shape of the failure without paying
to render it, and `stopFirst` is for the case where the first error is the only
interesting one.

### Reading a rendered report

One line looks like this:

```
error: ports/unknown-port at $.services.web.port: unknown port 99999
```

Severity, then the namespaced code, then the position, then the message. The
` at ...` part disappears when a diagnostic has no position, which happens for
complaints about a whole file or a registration rather than about a value.
Under `pretty { long = true; }` each line can be followed by indented `note:`
lines and a `help:` line drawn from the declaration.

Reading one in anger: the namespace tells you which subsystem is unhappy, the
position tells you where to look in the configuration, and the code is the
string to grep for in `src/*/vocabulary.nix` when the message alone isn't
enough. The vocabulary entry is where the reasoning lives.

## Sharp edges

### A gated pipeline stops at the first failing phase

`gate` collects the diagnostics of the phase it wraps and then halts if any
were errors. With several gates in sequence, the run stops at the first one
whose phase failed, and the phases after it never report. That's the point,
but it means a report from a gated pipeline is not a complete list of
everything wrong with a configuration; it's everything wrong up to and
including the first failing phase. Fixing those can reveal a new batch.

### `policy.pretty` has no `diagnostics` key

`pretty` swaps the diagnostic list for `report` and `lines`. Code written
against `collect` and later switched to `pretty` will fail on
`result.diagnostics` with an attribute error. If you want both the structured
list and the rendered text, keep `collect` and render the lines yourself, or
run the computation once per policy.

### The suggester's radius reads the input, not the candidate

The distance threshold is computed from the length of the string the author
wrote: at most four characters allows a distance of 1, anything longer allows
3. `testSuggestRespectsTheShortNameRadius` pins this, and
`krisis.suggest "abc" [ "wxyz" ]` is `null`.

The consequence shows up on short keys. A one-character typo in a short key
gets a suggestion; a two-character typo in the same key gets silence, because
the short input pulled the radius down to 1. The author sees a bare unknown-key
complaint with no hint, on exactly the kind of key where a hint would have been
obvious. `suggestWith` and the `maxDistance` argument are the escape hatch when
a call site knows its keys are short.
