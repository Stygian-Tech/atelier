# Notes sync anchor

This service is the trusted, anchor-first process for Atelier Notes. The first
slice provides the versioned Automerge protocol, admission and epoch hooks,
checkpoint serialization, an optional Iroh endpoint adapter, and HTTP control
plane health endpoints.

The sibling `atelier-sync-bindings` crate packages the same canonical V1 wire
validation for C-compatible native hosts and WebAssembly. It does not connect
the anchor to those hosts or make Iroh available in a client; peer lifecycle,
authentication, persistence, and the anchor accept loop remain service work.

It deliberately does **not** advertise collaboration readiness. `/healthz`
proves that the process is alive; `/readyz` remains `503` because durable
checkpoint storage, admission verification, and the Iroh accept loop are not
constructed in this service slice. `ATELIER_ANCHOR_READY=1` records an operator
request but cannot override those code-level prerequisites. The baseline also
does not operate a custom Iroh relay.

Environment variables:

- `PORT` — injected by Railway; defaults to `8080` locally.
- `ATELIER_ENV` — `development`, `production`, or `test`.
- `ATELIER_ANCHOR_READY` — readiness request (`1` only); never sufficient by
  itself while runtime integrations are absent.
- `ATELIER_ANCHOR_PERSISTENCE_MODE` — reported storage mode.
- `ATELIER_ANCHOR_TRANSPORT_MODE` — reported transport mode.
- `RUST_LOG` — standard tracing filter.
