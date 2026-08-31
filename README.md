# Atelier

Atelier is an ATProto productivity suite comprising Atelier, Atelier Notes,
Atelier Mail, Atelier Calendar, and Atelier Tasks. This monorepo contains the
web, Apple, Android, backend, protocol, collaboration, documentation, and
deployment sources for the suite.

The repository currently contains a buildable bootstrap foundation, not the
finished MVP or a public beta. See [implementation status](docs/implementation-status.md)
for the live boundary between landed foundations and required product work.

> [!IMPORTANT]
> Until ATProto Permissioned Spaces are supported and enabled, first-party
> Atelier records written to a standard PDS are public and readable. The apps
> must disclose that fact at onboarding and on affected records. Provider
> credentials, Gmail content, and external-calendar details are never written
> to public PDS records by default.

## Repository map

- `apps/web` — five Next.js product applications
- `apps/marketing` — static Astro marketing site
- `apps/docs` — Astro Starlight documentation
- `apps/status` — public status surface
- `apps/apple` — five universal SwiftUI applications
- `apps/android` — five Android Compose applications
- `services` — Swift services, sync workers, Notes anchor, and MCP backplane
- `packages` — shared contracts, editors, clients, design tokens, and Rust code
- `infra` — Railway, Marque, GCP, observability, and local infrastructure

## Development

Install the pinned toolchains with `mise install`, then:

```sh
bun install
bun run verify
bun run verify:swift
bun run verify:rust
bun run verify:android
bun run verify:database
```

Local infrastructure is defined under `infra/docker`. Provider integrations
remain disabled until their environment-specific credentials and approvals are
present.

## Release policy

Feature branches merge into protected `dev`. Railway Development deploys from
`dev`. Production deploys, provider callback cutovers, and Marque production
DNS changes require explicit approval and never follow automatically from a
Development success. The eight-surface foundation-preview Production rollout
was explicitly authorized on 2026-08-31; that approval does not cover the
unfinished API, MCP, sync, data, or provider-callback services.

## License

Atelier is available under the [MIT License](LICENSE). Imported and extracted
source provenance is documented under `docs/provenance`; third-party license
boundaries are recorded in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
