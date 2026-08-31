# Atelier Lexicons

`schemas/` is the single input tree for Atelier's generated TypeScript, Swift,
Kotlin, and compatibility contracts. Run:

```sh
bun run --cwd packages/lexicons generate
bun run --cwd packages/lexicons check:generated
```

Generation is deterministic and network-free. Before emitting output it checks:

- Lexicon version, identifiers, unique schema IDs, and `defs.main` shape;
- local and vendored `ref`/`refs` targets;
- permission-set collection targets;
- vendored identifiers, paths, and SHA-256 digests from
  `vendor/manifest.json`.

This is an intentionally scoped offline contract validator, not a replacement
for the official AT Protocol Lexicon implementation's complete schema and data
validation. `com.atproto.repo.strongRef` and the four Community Lexicon location
variants used by the pinned calendar event union are explicit external
allowlist entries. Their values remain typed as cross-language JSON where the
referenced schema is not vendored.

Standard AT Protocol repository records are represented with `publicData: true`
in every generated record catalog. This metadata is a disclosure boundary, not
an access-control claim.
