# Rosters, descriptors, relations, and extension

The roster is the data boundary between ownership semantics and whatever
backend knows about your fleet. Descriptors define how author syntax, context
entities, registry axes, and roster projections connect.

## Roster shape

```nix
{
  hosts = [ "x86_64-linux/khion" ];
  users = [ "feltfomo" ];

  membership = {
    "x86_64-linux/khion" = [ "feltfomo" ];
  };

  usersWithUnknownMembership = [ ];

  aliases = {
    host.khion = [ "x86_64-linux/khion" ];
    user.feltfomo = [ "feltfomo" ];
  };

  display = {
    host."x86_64-linux/khion" = "khion";
    user.feltfomo = "feltfomo";
  };

  dimensions = {
    gpu = {
      members = [ "nvidia" ];
      byHost."x86_64-linux/khion" = "nvidia";
    };
  };
}
```

Canonical IDs drive selection, membership, matrix keys, diffs, and diagnostics.
`display` is presentation metadata and nothing depends on it.

## Standalone declarations

```nix
roster = ownerships.toRoster [
  (ownerships.define.host "khion" {
    system = "x86_64-linux";
    aliases = [ "khion" "desktop" ];
    dimensions.gpu = "nvidia";
  })

  (ownerships.define.user "feltfomo" {
    id = "feltfomo";
    hosts = [ "khion" ];
  })
];
```

`define.user` distinguishes three states, and the difference matters:

| `hosts` | Meaning |
| --- | --- |
| `null` | membership unknown |
| `[ ]` | known to live on no host |
| non-empty | known membership |

Unknown membership can rescue a cross-axis relation, because the roster cannot
prove incompatibility. Known-empty membership cannot — it is a positive claim
that the pairing is impossible.

User host references may use canonical IDs or unique aliases. Unknown and
ambiguous aliases fail during roster construction rather than at selection.

## Descriptor contract

```nix
roleDescriptor = axes.mkSetDescriptor {
  name = "role";
  includeKey = "roles";
  excludeKey = "exceptRoles";
  includeOrder = 60;
  excludeOrder = 70;
  allowedScopes = [ "user" ];
  roster = {
    membersField = "roles";
    define = name: {
      kind = "role";
      inherit name;
    };
    project = { declarations, ... }: { roles = ...; };
  };
};
```

A descriptor owns a unique axis name, unique ordered author keys, key shape
validation and parsing, axis construction from a roster, allowed scopes and
their diagnostic wording, context claim and label projection, an optional
roster declaration and projector, and optional leaf stages.

`mkPredicateDescriptor` creates a select-only predicate axis with no roster
projector and no `ctxKey` entity.

Descriptor validation rejects malformed records, duplicate names, duplicate
author keys, and duplicate key order.

## Axis contract

The engine sees only registered methods — `top`, `narrow`, `observe`,
`satisfiable`, `select`, `isTop`, `ctxKey`, `ambiguous`. It never branches on
`host`, `user`, `when`, or any custom name.

For set axes, claims carry include/exclude polarity. Narrowing is intersection
for two includes, union for two excludes, and difference for mixed polarity.

## Relations

```nix
{
  name = "host-role-membership";
  leftAxis = "host";
  rightAxis = "role";
  unknownFor = roster: {
    left = [ ];
    right = [ ];
  };
  compatibleFor = roster: host: role: builtins.elem role (roster.roleMembership.${host} or [ ]);
  reason = hosts: roles: "no compatible host/role pair";
}
```

The generic checker applies these rules in order:

- a global side skips the relation;
- an empty side is left to same-axis satisfiability;
- any modeled unknown member rescues the relation;
- any compatible pair satisfies it;
- otherwise the leaf is impossible.

Relation validation rejects malformed records, duplicate names, and unknown
axes.

## Adding an axis

1. Define one descriptor.
1. Add it to the descriptor list for the surface you want.
1. Add standalone roster projection if the axis has finite members.
1. Add relation data separately when compatibility spans axes.
1. Prove author syntax, scope restrictions, context demand, selection, roster
   projection, and diagnostics.
1. Prove the production defaults are unchanged when the descriptor is test-only.

Do not edit `compose`, the pipeline, selection, or matrix to add an axis. If
you find yourself needing to, the descriptor contract is missing something and
that is the thing to fix.

## Adding a relation

Prove the known-compatible pair, the known-incompatible pair, global left and
right sides, empty sides, unknown-member rescue, and the diagnostic wording and
order.

Keep compatibility in relation data and shared semantics in
`engine.mkRelationCheck`.

## Adding a projection

A projection is a row in the projections table in `surface.nix`. Add the row
and the named doors, the scope guard, and the unknown-projection message all
pick it up. Add a row to the door table too if the combination deserves a
name. See [doors](doors.md).

Building an enclosing unit around someone else's claim needs
`surface.projectClaims`, which narrows a claim into a scope so the scope guard
does not reject it for carrying an axis that scope cannot bind. This is how the
program layer hangs system slices under a declaration's own claim. It is a
surface seam, not part of the facade.

## Den federation boundary

The whole-fleet adapter is `src/den.nix`. It normalizes den hosts and users
into the same declaration and projector path used standalone. No Ownerships
source file inspects den internals.

It takes `den` as a function argument rather than importing it, so lexicon
carries the integration without taking den as an input. The consumer supplies
its own den, and its host files populate the fleet.

Host dimensions stay roster metadata unless a deliberate descriptor exposes
them as author syntax. Adding dimensions must not silently widen the public
claim-key set.
