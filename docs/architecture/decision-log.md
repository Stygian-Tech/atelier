# Architecture decision baseline

## Product boundary

Atelier ships five separate products across web, universal Apple, and Android:
Atelier, Notes, Mail, Calendar, and Tasks. Drive, Messaging, and standalone
Contacts/Files are deferred.

## Data ownership

First-party records use `diy.atelier.*` public PDS schemas until feature-gated
Permissioned Spaces support is available. UI must show explicit public-data
status. AppView discovery is user-scoped by default. Mail and provider-calendar
references are opaque; provider credentials and content stay protected.

## Runtime

Swift/Hummingbird and XRPC are the default service stack. Rust owns the shared
Automerge-over-Iroh Notes collaboration core and anchor. PostgreSQL owns durable
jobs and domain indexes; Redis is ephemeral.

## Delivery

All Atelier-owned compute deploys to one Railway project. Managed Iroh relays,
GCP, Postmark, Sentry, Plausible, and application stores are external services.
Development uses `*.testing.atelier.diy`; Production requires approval.
