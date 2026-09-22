# kata

kata is the declaration layer. It walks a tree of files, folds what they built
into one plain declaration, and hands that declaration down to the layer that
turns it into entities. It doesn't know where that layer lives and it doesn't
know how anything is emitted afterwards.

The wiring is in `src/default.nix`. The registry is imported there and passed
to kata as the `engine` argument, so no file under `src/kata/` names the
directory it came from. Emission is wired the same way in reverse: it's handed
the block registry and the constructors, and never reaches into kata.

A reader coming from a configuration sees four things kata owns. The
constructors a declaration file is called with (`entry`, `home`, `user`,
`host`), the block names those files write under, the `kata.nix` settings file
beside the configuration root, and most of the diagnostics a broken
configuration produces.

## A note on the name below kata

The subsystem kata hands its declaration to is the identity registry. Its
directory carries an internal name, `src/koseki/`, and `checks.source-hygiene`
in `flake.nix` greps `src/` for that name and fails on anything that isn't an
`import ./koseki` line. The reasoning is that it isn't a name a configuration
author should have to learn: from outside, the registry's doors are
re-exported at the root of the library and the name never appears.

These documents use it. Their reader is working on lexicon rather than with
it, and writing around the real directory name would make them worse at the
one job they have. Where precision doesn't need it, the descriptive phrase is
better, and that's what most of this file uses.

## Vocabulary

These are the words the rest of the file uses, and they're used in exactly
these senses.

**kind** is what a declaration is. There are four, registered as data in
`src/kata/kinds.nix`: `entry`, `home`, `user`, `host`. A kind says what it's
called, which collection its declarations land in, which kind it sits inside,
whether it takes a `declare` key, and whether kata holds its field schema.

**collection** is the plural key a kind's declarations land under in the folded
declaration. `entries`, `homes`, `users`, `hosts`.

**entry** is the kind named `entry`. A file built with the `entry`
constructor carries blocks and belongs to no particular machine.

**home** is the kind named `home`. Same shape, meant for a person's own
configuration rather than a machine's. It folds into a `homes` collection and
nothing in this tree emits it.

**host** and **user** are the two kinds whose field schema kata doesn't hold.
Their registrations carry `fields = null`, which is how the kata registry says
the layer below owns that schema. They're the kinds that take a `declare` key.

**block** is a registered destination for content. A block is a system that
consumes what declarations write to it. Four are registered:
`nixos`, `homeManager`, `furnish`, `theme`.

**interior** is the value written under a block name inside a declaration. The
interior belongs to the block, and the block's own validator is the only thing
that reads its shape.

**route** is a path of field names into an interior, declared by the block, at
whose end a claim is recognised. `furnish` declares four.

**claim** is a list of names written at a route, saying which hosts or users
the data around it reaches. The word is provisional.

**facet** is a block's interior considered as a unit of content that reaches
some entities and not others. It's also the generic word this file uses for
a block-carrying declaration, whether it was built as an `entry` or a `home`.
The code uses the word entry for that generic sense in `resolveEntry` and in
`registry.entries`.

**declaration** is the plain attrset the fold produces: collections at the top,
one key per named declaration inside. It could have been written by hand.

**construct** is what a constructor hands back. An inert tagged value, wrong or
right, that the reporter can still name and place.

**walk** is reading the trees off disk into a set of constructed values.
**fold** is turning that set into one declaration. **include** is the key that
pulls one declaration into another.

**settings file** is a file named after a subsystem, sitting beside the
configuration root, read before anything is walked. kata's is `kata.nix`.

**placement** in these documents means the emission sense only: whether a
block's compiled half reaches a module class or travels as carried data
(`src/emit/placement.nix`). `src/kata/compose.nix` uses the same word for
something else, the path in the declaration a payload is written at. This file
calls that the **written path**, which matches what provenance already reports
as `sourcePath`.

Two more collisions worth knowing before you read code. **declares flag** is
the boolean on a kind registration; **declare key** is what an author writes
inside a `host` or `user` spec. And **home** has three referents across the
tree: the kind, the `homeManager` block, and den's home class. Every use below
is qualified.

## Do I add a block or write an entry

A block is a destination. An entry is content sent to one. So the question is
really: is there a new consumer, or is there new content for a consumer that
already exists? Almost always it's the second, and the answer is a file.

A block registration is seven fields, listed in `src/kata/block.nix`: `name`,
`kinds` it's legal in, `before` edges, `claimable` routes, `codes` it can
report, a `validate` computation, and a `compile` pair. Adding one means
writing that file, adding it to the list in `src/kata/blocks/default.nix`, and
giving it an arm in `src/emit/placement.nix`. Growing kata has the rest.

Four worked cases from the committed mock.

`mock/modules/git.nix` is a home. Git config belongs to a person, not to a
machine, and building it as a home keeps it out of every host's module list.
The proof in `mock/_boilerplate/proof.nix` pins the entries reaching each host
as `accounts`, `desk`, `hardware`, `system`, with `monitors` on tower only.
`git` isn't in that list on any host, which is the point. It's also why the
refusal tree has a copy: `mock/refusals/entries/modules/git.nix` is the same
home carrying a `nixos` block, and it comes back as
`kata/disallowed-block` at `$."modules/git.nix".nixos`, because the `nixos`
block registers `kinds = [ "entry" ]` and nothing else.

`mock/modules/monitors.nix` is an entry carrying a narrowed facet. Its
`furnish` block opens with `hosts = [ "tower" ]`, and that claim at the top of
the block is what decides where the facet goes. The proof pins
`targets.native.<host>.carried ? monitors` as true on tower and false on the
other three. Nothing about it is a new destination, so it isn't a block.

`mock/modules/hardware.nix` is an entry that reads a host field. Its `nixos`
interior is a function of the module arguments, and it picks one block of
settings out of `mock/_boilerplate/hardware.nix` by comparing `host.hardware`
against each key with `lib.mkIf`. The `hardware` field isn't one the identity
model carries; `mock/lexicon.nix` contributes it at the door, alongside
`stateVersion`. This is what narrowing looks like when the block has no
claimable route; what's currently uneven has the reason there are two
mechanisms for one idea.

`mock/modules/desk.nix` is one entry declaring into three blocks at once,
`nixos`, `furnish` and `theme`. Nothing pairs them up. A file is a unit of
authorship, not a unit of destination, and the fold writes whatever blocks it
finds as long as the kind is allowed to carry them.

### The claimable asymmetry

One of the four blocks declares claimable routes. `furnish` declares four:
the top of the block, `files`, `directories`, and `directories` then `files`.
`nixos`, `homeManager` and `theme` declare none.

For the two module blocks the registration says why. A module is routinely a
function, and there's nothing to walk until its arguments exist. The claim
walker agrees from the other side: `src/kata/claims.nix` reports
`kata/unwalkable-claim-route` when a declared route has to pass through a
function, so declaring a route over a module interior would produce that
diagnostic rather than a narrowing.

`theme` is the interesting one. Its interior is plain data all the way down,
so a route over it would walk, and its registration doesn't say why it
declares none. Treat that as an open question rather than a rule.

Separately, `theme` carries `before = [ "furnish" ]`. That's ordering, not
narrowing, and it's there because the artifact a renderer writes is placed by
the block below it. `lib.toposort` in `src/kata/blocks/default.nix` turns the
edges into `blocks.order`, and `testKataOrderingIsNotTheDeclaredOrder` in
`tests/kata.nix` pins that the result differs from the list as written.

What the asymmetry means for a fifth block: whether you declare a route is a
question about your interior, not about parity with the others. If the data
you want narrowed sits behind a function at use time, a route won't reach it,
and the narrowing has to happen inside the interior the way `hardware.nix`
does it.

## Where things go

The walk reads whatever trees the settings file names. The default is one,
`modules`, from the schema in `src/kata/settings.nix`. The mock names three:

```nix
# mock/kata.nix
_: {
  roots = [
    "hosts"
    "users"
    "modules"
  ];
}
```

Three trees because the three hold different kinds of thing. `hosts/` holds
one file per machine, `users/` one file per person, `modules/` the content
that gets sent to blocks. kata doesn't enforce any of that. A `host` built
under `modules/` would work; the split is for the reader.

Each tree is read whole and recursively. `modules/tools/editor.nix` in
`tests/fixtures/cross` lands as the name `editor`, and
`testWalkStampsEachFileWithItsOwnOrigin` pins its origin as the relative path.
A name is the filename with `.nix` dropped, so two files anywhere in any root
that reduce to the same name collide. Both files get named in the diagnostic
and neither quietly wins (`kata/entry-name-collision`,
`testTwoFilesOnOneNameAreBothNamed`).

The other settings key is `exclude`, a list of paths relative to a walk root,
naming a file or a directory. An exclusion that covers nothing is reported as
`kata/excluded-path-missing`, placed on the key that holds it.

### Host field, entry content, or narrowing

Three things that look similar when you're staring at a config and aren't.

A **host field** is something the machine is. `system`, `stateVersion`,
`hardware` in the mock. It's written in the host's `declare` key, it's
available to every module through the `host` argument, and if the identity
model doesn't carry it, it arrives as a contribution at the door.

**Entry content** is what to configure. It goes in a file under a walk root,
under a block name.

A **narrowing** is which entities a piece of entry content reaches. It goes
next to the content, as a claim, when the block declares a route for it.

The test for the first against the third: if every machine reads the value and
does something different with it, it's a host field. If some machines don't
want the content at all, it's a narrowing.

### `_boilerplate/`

`mock/_boilerplate/` isn't a walk root, so nothing in it is read as a
declaration. Two things live there. `hardware.nix` is a plain attrset of
stand-in disk and bootloader settings, imported directly by the entry that
uses it, standing in for the generated hardware configuration a real machine
would have. `proof.nix` is the harness: it opens the door, walks, prepares,
emits, and compares the result against pinned expectations.

Both are things a configuration needs to have somewhere and neither is a
declaration. That's what the directory is for. The leading underscore is
convention, not a rule kata reads; keeping it out of `roots` is what keeps it
out of the walk.

## The pipeline

Four stages, and knowing which one refuses you is most of debugging a
configuration.

**walk** turns trees into constructed values. `src/kata/walk.nix` runs four
named phases: `discover` reads the file lists off the roots, `screen` applies
the exclusions, `name-resolve` groups files by name and refuses collisions,
`tie` imports each file with `lib.fix` so any file can name any other through
the `lexicon` argument. `readDir` and `import` are the whole of its contact
with disk. It decides nothing about content, and it can't: at `tie` time the
values haven't been looked at yet.

**fold** turns that set into one declaration. Composition runs first
(`src/kata/compose.nix`), following every `includes` list to everything it
reaches, refusing cycles, and working out the written path for each value.
Then five phases in `src/kata/fold.nix`: `registry-check` replays defects in
the block registry, `construct-shape` checks each value is a construction and
blames the field that isn't, `kind-resolve` looks each kind up, `block-check`
hands each interior to its block's validator and each claim route to the
claim walker, and `place` writes the payloads at their paths. What leaves is
a declaration plus the place each part gets diagnosed at.

**prepare** is fold plus claim resolution plus handing down.
`src/kata/resolve.nix` sifts each claim against the names the declaration
actually holds (`claim-sift`) and settles what survives into a reach per block
(`claim-settle`). Then `handDown` opens the registry's own run, replays its
diagnostics onto the caller's stream so there's one report to read, and comes
back with `{ registry, claims }`.

**emit** takes that pair. `src/emit/default.nix` checks backend registrations,
weighs each backend's declared capabilities against what the door was handed,
and runs the backends that are supplied. A backend short a capability reaches
no host and says so rather than failing.

Each of walk, fold, resolve and emission is wrapped in `krisis.gate`. A gate
replays what was reported inside it and then halts if any of it was an error,
so a run reports the first stage that failed and not the stages after it.
This is why fixing one diagnostic sometimes reveals four more.

### The six pinned refusals

`mock/_boilerplate/proof.nix` runs three deliberately broken trees through the
same door as the fleet and pins what comes back, as code and place. They're
worth reading in order, because they land at four different points.

`refusals/entries` produces four, all from the fold:

```
kata/disallowed-block        $."modules/git.nix".nixos
kata/unknown-block           $."modules/shell.nix".nixso
kata/nixos-interior          $."modules/system.nix".nixos
kata/malformed-construction  $."modules/tower.nix".system
```

The first is a home carrying a block registered only for entries. The second
is a typo in a block name, which is a warning by default because a walker can
reasonably reach a declaration naming a subsystem that isn't registered yet,
and an error under `strict`. The third is the `nixos` block's own validator
refusing a string where a module belongs, placed at the entry rather than at
the block's own idea of where it is, because `block.within` installs the
entry's prefix for the validator's extent. The fourth is a host writing
`system` outside its `declare` key: a kind that takes `declare` takes that key
and `includes` and nothing else, so a stray key is named where it was written.

`refusals/fleet` produces one, from claim resolution:

```
kata/unknown-claimed-host    $."modules/desk.nix".furnish.hosts
```

The claim is well formed. It names `towor` and the fleet declares `tower`.
That can't be answered by looking at one file, which is why it happens after
the fold rather than inside it, and why the diagnostic is placed at the file
the claim was written in rather than at the name it landed under in the
declaration.

`refusals/fields` produces one, and it isn't kata's:

```
lexicon/unknown-field        $.hosts.tower.users.warden.shel
```

This is where the boundary falls. kata checked the shape of the construction,
the kind, the blocks and the claims, found nothing wrong, and handed a
declaration down. The misspelled field sits inside a `declare` key, which is
the half of the declaration kata deliberately holds no schema for. The path is
the written path rather than a filename, because by then the file isn't the
thing being read. When you're staring at a diagnostic and wondering which
subsystem to go argue with, the namespace on the code answers it.

## Narrowing

Narrowing is scope on carried data. A facet names which entities its data
reaches, the name lands at a route its block declared, and everything else is
ordinary block data.

The keys come off the kind registry. Every kind whose registration sets the
declares flag contributes its collection as a claim key, which today gives
`hosts` and `users` (`src/kata/claims.nix`,
`testKataClaimKeysComeOffTheKindRegistry`). Nothing hardcodes either word.

Three things follow from "recognised only at a declared route".

A claim at a declared route has to be a list of names, and isn't guessed at
if it isn't. `testKataClaimIsReadAtADeclaredRoute` writes `hosts =
"workstation"` three levels inside a furnish directory group and gets
`kata/malformed-claim` at
`$.desktop.furnish.directories[0].files[0].hosts`.

The same shape at a route nobody declared is left alone. A `homeManager`
interior holding `users.ada` is a module writing to a `users` option, not a
claim, and `testKataClaimShapedValueOffRouteIsLeftAlone` pins that it reports
nothing. This is the reason routes are declared rather than inferred from key
names.

A route that has to pass through a function is a defect in the route, not in
the value under it, and it's reported once per route that stopped there
(`kata/unwalkable-claim-route`).

### Top of the block against deeper in

A claim at the top of a block decides where that block goes. A claim deeper
inside narrows something the block itself owns, and whatever reads the block
honours it. `reachOf` in `src/kata/resolve.nix` collects only the claims whose
position is the block itself; the deeper ones are resolved, reported against
the fleet the same way, and left in the interior for the consumer.

The den drop-in is the clearest case of the difference mattering. The aspect
system decides for itself which entity an aspect is placed against, so a
claim at the top of a block is something that path can't honour, and
`src/emit/aspect.nix` refuses it with `emit/aspect-carries-claim` rather than
silently dropping it.

### The name

`claim` is provisional. An ownerships subsystem doesn't exist in this tree
yet, and when it does, ownership is a relation between an entity and a thing
it owns, which isn't what's happening here. What's happening here is scope: a
facet saying which entities it reaches.

So expect the name to move and the concept to stay. The concept is stable
enough to build on. The word is a placeholder that outlived the sketch it came
from, and it's currently spelled into a user-visible diagnostic code
(`kata/unknown-claimed-host`) and pinned in the mock's proof, so moving it
isn't free. Nothing in this sub-phase renames anything.

## Growing kata

### A fifth block

One file plus two entries in data. The file is a registration of the seven
fields in `src/kata/block.nix`, it goes in the list at the bottom of
`src/kata/blocks/default.nix`, and it needs an arm in
`src/emit/placement.nix` saying whether its compiled half is a module class or
carried data. A block with no arm in that table surfaces where its placement
is read rather than where it was registered, which is a worse diagnostic than
it sounds.

Nothing else changes. Legality is read off the block, so naming a kind in
`kinds` reaches that kind without the kind's own registration moving
(`allowedIn` in `src/kata/blocks/default.nix`). No core file carries a branch
naming a block.

The registry reads itself for defects and reports them on the caller's stream,
so a registration mistake arrives as a diagnostic instead of an evaluation
failure. An unknown field gets `kata/malformed-registration` with a
suggestion, an ordering edge naming nothing gets `kata/unknown-block-edge`,
and a cycle in the edges gets `kata/block-cycle` with the declared order left
standing so the rest of the pass still reports
(`testKataRegistrationReportsAnUnknownField`, `...AnUnknownEdge`,
`...ACycle`).

### Contributions widen the schema

A contribution is a function of the instance handed to the door, coming back
with fields to add to a kind the layer below holds:

```nix
# mock/lexicon.nix
contributedFields =
  { t, ... }:
  {
    fields = {
      host = [
        { name = "stateVersion"; type = t.String; }
        { name = "hardware"; type = t.String; }
      ];
      user = [
        { name = "elevated"; type = t.Bool; default = false; }
      ];
    };
  };
```

It widens the schema. It doesn't reopen the declaration surface: no
contribution adds a kind, a block, a claim key or a constructor. A field name
already declared comes back as `lexicon/field-collision` naming both writers,
because which of the two to rename is the caller's call
(`testKataACollidingCallerContributionIsReported`). Without the contribution
the same field is `lexicon/unknown-field`
(`testKataTheSameFieldWithoutTheContributionIsUnknown`).

### What a configuration can feel

Four changes, in rough order of how quietly they break something.

**A route withdrawn** is the quiet one. A claim at a route that no longer
exists stops being a claim and becomes ordinary block data, which is exactly
the behaviour that makes off-route keys safe. Nothing is reported. The facet
widens to everything and the configuration keeps building.

**A default changed** moves values in entities nobody edited. The provenance
map is the thing that makes this readable after the fact:
`registry.originOf` answers with the place a field was written, and answers
with nothing for a field lexicon filled, which is how introspection tells the
two apart.

**A kind's parent changed** moves where an included declaration lands. Today
`user` names `host` as its parent and `users` as its container, so a host
including a user writes it at `hosts.<host>.users.<user>`. Change either and
every configuration that included that kind writes somewhere else.

**A diagnostic code renamed** breaks anything pinned on codes. That includes
the mock's own proof, which compares code strings.

### Making a rename survivable

`src/koseki/retired.nix` is the mechanism. It maps a key that meant something
in an earlier shape of the surface to a note explaining where it went:

```nix
moved = {
  extend = "extensions arrive at the door now, as the contributions argument, a list of functions of the instance";
};
```

Both the declaration read and the contribution read build their note from
there, so a caller still writing the old key gets told where it went instead
of getting a bare unknown-key diagnostic. A retired name is deliberately never
a candidate the suggester can hand back, so nothing ever suggests a spelling
that stopped working.

The pattern generalises. A rename is survivable when the old name still
produces a diagnostic that names the new one, and it's a silent break when the
old name lands in a bucket the code treats as ordinary data.

## What's currently uneven

**`includes` is one key doing two things.** Which one depends on the kind of
the value it reached, decided by `edgeOf` in `src/kata/compose.nix`. A host
including a user is `Edge.within`: the user is placed inside that host, at
`hosts.<host>.users.<user>`, and a user included by two hosts lands under both
from one file (`testAnIncludedUserLandsUnderEveryHostThatIncludesIt`). An
entry including an entry is `Edge.beside`: the included entry is pulled into
the walk and lands in its own collection, and pulling it in twice lands it
once (`testAnEntryPulledTwoWaysLandsOnce`). So the same word means "selects"
in one place and "reaches" in the other. It isn't two keys disagreeing, it's
one key whose meaning is read off the kind registry, and an include that
crosses the wrong way is `kata/misplaced-include`.

**`nixos` isn't claimable**, so a `nixos` interior reaches every host its
entry reaches, and the narrowing has to happen inside the module. That's what
`mock/modules/hardware.nix` is doing with `lib.mkIf` over a host field. It
works and it's the intended shape for now, but it means two mechanisms for
one idea depending on which block you're writing into.

**`host.users` is the raw declaration.** The identity model's `host` kind
declares `users` as a plain attrset, and normalization fills it with exactly
what was written. The user entities, with their defaults filled and their
derived fields computed, are built beside it and reached through the
registry's own accessors. A module reading `host.users` is reading the
authored text, so a contributed default doesn't appear there. That's why
`mock/modules/accounts.nix` writes `written.elevated or false` and guards
`written ? shell` instead of trusting the schema.

**Nothing emits homes.** The `home` kind is registered, carries three blocks,
folds into a `homes` collection and is contributed to the registry with the
rest. Emission walks `prepared.registry.entries` and never looks at it. den's
registration says why in one line: the home class is placed against a user,
and this tree places hosts. A home you write today is a declaration that
parks. Introspection does report it, so it isn't invisible, just unconsumed.

**The users half of a claim is resolved and then ignored.** Both claim keys
are sifted against the fleet, reported against, and carried through to
emission. `carriedFor` in `src/emit/default.nix` reads `claim.hosts` and
nothing else, on the stated grounds that this tree places no user, so a facet
reaches every user of a host it reaches. Writing `users = [ "warden" ]` on a
block today gets you a diagnostic if the name is wrong and no narrowing if
the name is right.

One smaller thing, in the layer below rather than in kata:
`lexicon/unknown-host` and `lexicon/unknown-user` are declared in the
vocabulary and nothing in `src/` produces them. The vocabulary file says this
is deliberate, that codes whose producers arrive in a later pass are
registered up front so the catalogue doesn't change meaning under a caller.
Worth knowing before you go hunting for the code path that emits them.
