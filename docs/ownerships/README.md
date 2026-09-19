# Ownerships

Ownerships selects configuration for a user and host, then merges the matching pieces into one Nix value. A small list can describe shared settings, a person's additions, and machine-specific choices.

Start with plain data so you can see exactly what selection does. You can use the resulting values in your own configuration once you're happy with them.

## Reading order

1. [Preparation](../preparation.md), if Nix is new to you.
2. [Getting started](getting-started.md): select one editor preference and change it.
3. [Usage](usage.md): add users and hosts, narrow nested claims, choose merge behavior, and reuse files.
4. [A team's editing preferences](worked-example.md): work through a larger configuration built from those ideas.
5. [Inspection](inspection.md): find out why a unit applies and where its values contribute.

Keep the [reference](reference.md) nearby for field defaults, membership rules, errors, and resolver signatures. Its [advanced companion](advanced-reference.md) covers policy configuration and exported support functions; you can leave that until you need it.

All runnable examples are indexed under [examples](../../examples/README.md#ownerships). They use fictional people and machines, and the evaluation commands don't change host configuration.
