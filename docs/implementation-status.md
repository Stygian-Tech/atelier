# Implementation status

Atelier is in the bootstrap phase. The repository is not a public beta, and no
Production deployment, provider callback, store build, or DNS record is active.

## Implemented foundation

- imported Atelier Mail history and the tracked AnyPub Markdown editor with
  provenance;
- Bun/Turborepo workspace with five buildable Next.js product surfaces;
- buildable static Astro marketing and status sites plus Starlight docs;
- shared web design tokens and product shells with explicit public-PDS
  disclosure;
- five universal SwiftUI targets and five Android Compose targets with shared
  local/offline/editor contracts;
- canonical `diy.atelier.*` Lexicons and generated cross-language contract
  foundations;
- pinned Swift and Kotlin ATProto primitives with a shared PKCE/DPoP/XRPC
  conformance fixture and cryptographic ES256 signature verification;
- a protected-data-only Gmail History reconciliation state machine and
  deterministic Markdown-to-multipart MIME builder; neither performs provider
  network calls or claims a configured Gmail adapter;
- Hummingbird API and JSON-RPC MCP bootstrap control planes that fail closed
  while persistence, authentication, and domain executors are absent;
- PostgreSQL domain/RLS/job migrations, local PostgreSQL and Redis, Railway
  source templates, inactive Marque manifests, GCP templates, and redaction
  policy;
- versioned Rust Automerge/Iroh protocol and a deliberately not-ready Notes
  anchor control plane.

## Required before Development can be called usable

- real ATProto OAuth/PKCE/DPoP sessions and PDS/AppView persistence;
- durable worker database driver and domain executors;
- Gmail adapter, OAuth callback, Pub/Sub verification, History API pagination,
  atomic persistence around the existing reconciliation reducer, encrypted
  cache/search, and provider upload/send around the existing MIME builder;
- JMAP and IMAP/SMTP adapters after Gmail parity;
- lossless iCalendar model and Google, Microsoft, and CalDAV adapters;
- complete Notes filesystem/SQLite/checkpoint integration and the Iroh accept,
  identity, ACL, and persistence loops;
- complete Tasks operations, collaboration, relationships, and Home command
  workflows;
- authenticated web BFFs, native network clients, notification delivery,
  account deletion/purge, and Permissioned Spaces migration execution;
- Development Railway, GCP, Postmark, Sentry, Plausible, and Marque resources,
  each provisioned only after its approval and credential gate.

## Release boundaries

`dev` may feed the persistent Railway Development environment only after its
service dependencies exist and readiness probes pass. Production, production
DNS, OAuth/provider webhook cutovers, source-repository archival, final store
artwork, signing, and store uploads all require separate explicit approval.
Public GitHub publication also remains blocked on resolving redistribution
terms for the vendored Community Calendar Lexicon records; their publisher
records currently declare no license, and Atelier does not treat those bytes as
MIT-covered.

The coordinated beta gate remains all-or-nothing across Atelier, Notes, Mail,
Calendar, and Tasks. Passing a build or a health check for one surface is not a
beta-readiness claim.
