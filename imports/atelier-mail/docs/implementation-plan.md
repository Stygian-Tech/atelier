# Implementation Plan

## Phase 0: Foundation

- Initialize monorepo tooling, CI, Docker Compose, docs, and environment template.
- Scaffold Next.js web app, Swift API service, Swift package boundaries, and Lexicon package.
- Add PostgreSQL migrations for identity, mail, private KV, provider secrets, MCP grants, jobs, sync cursors, and audit events.

## Phase 1: Identity And Platform Core

- Implement ATProto OAuth, DID/handle cache, tenant/user/session tables, auth middleware, audit logging, and OpenAPI contract.
- Keep browser traffic provider-agnostic; provider access happens through the Swift service.

## Phase 2: Private Permissioned Store

- Implement typed KV records using `space.atelierwork.*` schema names.
- Add schema versioning, migration hooks, encryption metadata, and an adapter boundary for future ATProto Permissioned Data.

## Phase 3: Gmail Vertical Slice

- Implement Gmail OAuth, envelope-encrypted tokens, initial sync, normalized thread/message/mailbox data, actions, and Postgres FTS.

## Phase 4: Web Client Shell

- Ship the usable three-pane mail workspace: sidebar, virtualized thread list, reader, account filters, responsive collapse, skeleton states, keyboard actions, and compose entry points.

## Phase 5+: Sync, Compose, Providers, MCP

- Add Gmail History API and Pub/Sub webhook ingress.
- Add TipTap compose and send.
- Add JMAP and IMAP adapters.
- Expose read-only MCP tools, gated write tools, MyContextProtocol registration, and cross-app references.
