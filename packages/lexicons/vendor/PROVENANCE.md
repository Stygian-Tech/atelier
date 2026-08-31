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
  The authoritative `_lexicon.calendar.lexicon.community` DNS record identifies
  `did:plc:mtr7qrqtcyseedx3jyr5o7db`, whose handle is
  `lexicons.lexicon.community`, as the publisher. Lexicon Community's canonical
  source repository licenses every schema under MIT, copyright 2024 Lexicon
  Community. The complete notice is retained in
  `licenses/LEXICON-COMMUNITY-MIT.txt`.

  The published event record is the repository schema from commit
  `ddcaad28aa7850aa15618f79d8c41460b6df6736`, and the RSVP record is the
  repository schema from commit
  `3740ff13906b1f91573b1ebee79d498a7bc4cc0f`. ATProto publication adds only the
  `$type: com.atproto.lexicon.schema` record discriminator; canonicalized source
  and published JSON otherwise match. These intentionally pinned record
  versions may differ from later repository revisions. Updating them is a
  compatibility decision separate from their redistribution license.

Retrieval date: 2026-08-30. Publisher URLs, record CIDs, immutable canonical
source commits, license links, digests, and the narrow allowlist of
intentionally unvendored external references live in `manifest.json`.
