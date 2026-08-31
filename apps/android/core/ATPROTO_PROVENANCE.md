# Android AT Protocol primitive provenance

The shared Android primitives are a clean Kotlin consolidation of behavior
already exercised in Stygian Tech applications. They use only Java/Android JCA
cryptography and do not copy an OAuth lifecycle into Atelier.

NSID validation follows the AT Protocol NSID specification: authority labels
are normalized to lowercase while the final, case-sensitive camel-case name is
preserved verbatim: <https://atproto.com/specs/nsid>.

Reviewed sources on 2026-08-30:

- AnyPub commit `f7401acb14441c5fa84105757a638711a9d47eaf`:
  `services/backend/Sources/App/Services/PKCE.swift`, `DPoP.swift`, and
  `ATProtoXRPCClient.swift` informed the S256, ES256, and explicit XRPC
  boundaries.
- Presently commit `6d21c5a9031acdaa86960f7a136ed0f92a8fc938`:
  `apps/android/app/src/main/java/tech/stygian/presently/oauth/DPoPKey.kt` and
  `ATProtoOAuthClient.kt` informed Android P-256/JCA handling, DER-to-JOSE
  conversion, `ath`, and query/fragment removal from `htu`.
- The Social Wire commit `3f09b260c3f4511de516c438d8981d1cff037da2`:
  `services/gateway/Sources/Gateway/Services/PreferenceSyncService.swift` and
  gateway XRPC routes informed the case-sensitive `/xrpc/{NSID}` boundary and
  separation between target construction and authenticated forwarding.

Atelier deliberately stops at primitives. OAuth discovery, PAR, authorization
callbacks, token exchange/refresh, DPoP nonce retries, Android Keystore session
lifecycles, secure token storage, HTTP execution, and response decoding are not
implemented by this module.
