# ATProto implementation provenance

Atelier may extract narrowly scoped OAuth, DPoP, XRPC, secure-session, and
gateway logic from Stygian Tech's AnyPub, Presently, Social Wire, and related
projects. Every extraction must record its source repository, source commit,
original path, material modifications, and compatibility tests here before
merge. Selected extracted code is authorized for MIT reuse in Atelier; source
repository licensing remains otherwise unchanged.

## Bootstrap extraction: OAuth transport primitives

- AnyPub source commit: `e280b91b9ff0dc5996be4654a624816e157faebf`
  - `services/backend/Sources/App/Services/PKCE.swift`
  - `services/backend/Sources/App/Services/DPoP.swift`
- Presently source commit: `6d21c5a9031acdaa86960f7a136ed0f92a8fc938`
  - `apps/ios/Presently/OAuth/DPoP.swift`
- Social Wire source commit: `3f09b260c3f4511de516c438d8981d1cff037da2`
  - `apps/web/src/lib/atprotoOAuthScopes.ts` (progressive-scope design
    reference; no legacy namespace strings copied)

Atelier's `AtelierATProto` package retains only the reusable RFC 7636 PKCE,
ES256 DPoP proof, target normalization, and XRPC URL-building behavior. It
adds deterministic fixtures, explicit secure-storage guidance, Swift 6
sendability, and keeps PAR, callback validation, credential persistence,
nonce retry, and network execution outside the primitive layer so incomplete
OAuth behavior cannot be mistaken for a working session implementation.

The MIT `ATProtoPrimitiveKit` dependency is pinned to
`1105fb3c008a1048c40b9d1b71cc2cc8e51319b0`; `swift-crypto` is pinned to
`3.15.1` for the shared Linux/Apple cryptographic implementation. Atelier uses
the primitive package to validate XRPC NSIDs but preserves the caller's method
case because that pinned revision lowercases `NSID.absoluteString`, which would
otherwise corrupt conventional camel-case procedure names such as
`com.atproto.repo.getRecord`.
