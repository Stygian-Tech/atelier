# Atelier Mail sync boundary

Mail sync will consume durable jobs for Gmail, JMAP, and IMAP/SMTP adapters. The shared Swift contracts model provider capabilities, cursors, Gmail expired-history reconciliation/watch renewal, JMAP state, IMAP UID validity, and idempotent mutations.

The Swift service is Gmail-first and names JMAP as the standards-based surface and IMAP/SMTP as the compatibility surface. It includes an executable, strict environment validation, typed durable job envelopes, executor registration, provider/job-kind checks, and privacy-preserving payload validation. Provider content stays encrypted in `mail.cached_headers` and `mail.cached_bodies`; only HMAC-derived references may cross into the public PDS.

## Credential-free Gmail-first core

`MarkdownMIMEBuilder` constructs deterministic protected MIME bytes without sending them. It renders a deliberately small Markdown subset (headings, lists, emphasis, strong text, inline code, and `http`/`https`/`mailto` links), escapes all source HTML, drops unsafe link destinations, produces `text/plain` and sanitized `text/html` alternatives, canonicalizes attachment order, uses content-derived MIME boundaries, emits CRLF, and uses wrapped base64 transfer encoding. Header values are either validated structured fields, RFC 2047 encoded words, or RFC 2231 parameters; CR/LF and control-character injection fail closed. Date and Message-ID are intentionally absent because a future provider adapter must supply them.

`GmailHistoryReconciler` is a pure cursor state machine. Inputs represent an already-collected complete History response, an expired `startHistoryId`, or completion of a protected full snapshot. Outputs are durable intents to apply opaque mutations, persist a cursor, or request a generation-bound full sync. Duplicate mutations and replayed batches are idempotent, normal non-contiguous Gmail history IDs are accepted, skipped request cursors and inconsistent responses require a full sync, and stale responses never move the cursor backward. The caller must persist the returned state and actions atomically in protected storage.

Neither core imports or constructs public PDS reference types. MIME, attachment bytes, provider resource IDs, and reconciliation state remain protected-provider data. The only public-facing boundary remains an opaque derived reference created elsewhere after an explicit disclosure decision.

No provider adapter or live provider call is present. Gmail OAuth/PKCE, authoritative profile lookup, History API pagination, MIME upload/send, Pub/Sub verification, watch renewal, and full-snapshot execution are explicitly absent. JMAP and IMAP configuration references are accepted only as protected-store references when those providers are explicitly enabled. Until a durable Postgres store and the selected provider adapters exist, readiness is false and the executable exits rather than pretending sync is available.
