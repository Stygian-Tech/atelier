# Vendored Lexicon provenance

These schemas are inputs to Atelier's offline contract generator. The generator
verifies every vendored file's identifier and SHA-256 digest before producing
TypeScript, Swift, Kotlin, or compatibility-fixture output.

- `at.markpub.markdown` and `at.markpub.text` are pinned to Markpub commit
  `9b53a3a8f93d7c627abb64b5b6e4bf42140ce7c0` from the upstream MIT repository.
  The manifest records both the upstream byte digest and the locally normalized
  digest; the only normalization is one final line feed.
- `community.lexicon.calendar.event` and
  `community.lexicon.calendar.rsvp` are pinned to the publisher DID and record
  CIDs embedded in `sourceVersion`. Their byte digests cover the vendored JSON.
  The published Lexicon records do not declare a license, so no license is
  inferred here.

Retrieval date: 2026-08-30. URLs, immutable versions, digests, and the narrow
allowlist of intentionally unvendored external references live in
`manifest.json`.
