# Atelier Mail

Atelier Mail is the first application scaffold for the Atelier Work suite at `atelierwork.space`.

The MVP is a SaaS-first mail client with:

- ATProto OAuth identity with DID as the primary account key.
- Server-side Gmail, JMAP, and IMAP provider access.
- A local normalized mail domain model backed by PostgreSQL.
- Private permissioned Lexicon concepts stored in Atelier KV until ATProto Permissioned Data is finalized.
- MCP hooks for agent access through an explicit grant model.
- A Next.js/shadcn/Tailwind web client inspired by the scalable Social Wire shell and the warmer Skej interaction style.

## Structure

- `apps/web` - Next.js 16 app shell for `mail.atelierwork.space`.
- `services/api` - Swift/Hummingbird service scaffold.
- `packages/swift` - extraction-ready Swift package boundaries.
- `packages/lexicons` - `space.atelierwork.*` draft schemas and validation tests.
- `infra` - local Docker Compose and operational scaffolding.
- `docs` - architecture and implementation notes.

## Local Commands

```bash
bun install
bun run verify
```

Swift checks:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test
```

Full verification:

```bash
bun run verify:all
```

Local deploy smoke:

```bash
docker compose -f infra/docker-compose.yml up --build
```

See `docs/deployment.md` for deployment environment and process details.
