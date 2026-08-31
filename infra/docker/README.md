# Local infrastructure and images

`compose.yaml` starts only disposable local Postgres and Redis dependencies.
The credentials are intentionally development-only and bind to loopback.
Redis persistence is disabled because Redis is never a durable Atelier source.

The Notes anchor image uses the pinned Rust MSRV. Its build is `--locked`; run
`cargo generate-lockfile --manifest-path packages/rust/Cargo.toml` with Rust
1.91 before deploying whenever dependency pins change.
