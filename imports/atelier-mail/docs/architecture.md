# Atelier Mail Architecture

## Product Boundary

Atelier Mail is a mail client, not a mail host. Provider traffic is server-side only. Mail content remains in provider systems and in the local PostgreSQL cache needed for the product experience. Mail bodies are not written to ATProto records or the private permissioned KV store.

## Identity

Users sign in with ATProto OAuth. The primary user key is the DID. The platform stores a DID document cache, handle cache, session state, and OAuth lifecycle metadata in PostgreSQL.

## Namespace

All Atelier Lexicon concepts use `space.atelierwork.*`.

Initial draft namespaces:

- `space.atelierwork.platform.*`
- `space.atelierwork.mail.*`
- `space.atelierwork.workspace.*`
- `space.atelierwork.tasks.*`

These schemas define data contracts. They do not imply every record is stored on a PDS.

## Private Permissioned Store

Until ATProto Permissioned Data is finalized, private permissioned concepts are stored in Atelier KV. The KV store is typed, schema-versioned, encrypted by owner boundary, and migration-ready.

KV is appropriate for:

- user preferences
- provider descriptors without secrets
- MCP grants
- cross-app references
- linked-thread metadata

KV is not appropriate for:

- provider refresh tokens
- provider access tokens
- mail bodies
- attachments
- sensitive message excerpts

Provider secrets use account-scoped KMS envelope encryption and remain in the relational secret store.

## Service Shape

The first deployment is one Swift/Hummingbird API binary with logical modules:

- API/auth
- provider connection flows
- mail sync and indexing
- Gmail push ingress
- KV access
- MCP registry

Domain logic lives in extraction-ready Swift packages so the deployment can later split into independently versioned services.

## Client Shape

The web app uses Next.js, shadcn, Tailwind, and lucide icons. The layout follows Social Wire's dense, scalable app shell and Skej's warmer personality: refined workspace chrome, compact rows, friendly status details, subtle motion, and no marketing landing page for signed-in users.
