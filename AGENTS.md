# Lexicon changes

Read [declaration syntax](src/lexicon/syntax.md) and the
[definition contract](src/lexicon/definitions.md) before extending the DSL.
Built-ins and external subsystems use one registered compiler. New annotations
belong to the configured Ownerships vocabulary. Native module bodies stay opaque.

Use Axiom's `src` schemas, validation and registry helpers and Krisis diagnostics.
Don't import Axiom's `language` implementation. Keep evaluation pure; live filesystem
operations belong to the existing runtime owners.

Follow the [comment guide](../odyssey-fixes/doc-for-ai/ai-doc-and-comment-patterns.md)
when it's available. Source comments explain non-obvious constraints, use lowercase
and contain no colons. Review all comments in a touched file.

Run focused flake checks, then `nix develop path:. -c lexicon-praxis --non-interactive gate`.
Use `path:.` to include new files before staging. Never stage or commit without the
user approving the complete commit preview.
