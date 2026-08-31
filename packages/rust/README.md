# Atelier Rust workspace

This workspace contains the shared Notes collaboration protocol and transport
boundary plus the Railway anchor binary. It currently pins Automerge `0.11`
and Iroh `1.1`; the combined dependency floor is Rust 1.91.

```sh
cargo test --manifest-path packages/rust/Cargo.toml --workspace
cargo build --manifest-path packages/rust/Cargo.toml \
  -p atelier-sync-bindings --release
cargo check --manifest-path packages/rust/Cargo.toml \
  -p atelier-sync-bindings --target wasm32-unknown-unknown
cargo test --manifest-path packages/rust/Cargo.toml \
  -p atelier-sync-transport --features iroh-endpoint
cargo test --manifest-path services/notes-sync-anchor/Cargo.toml
```

The optional Iroh feature binds Atelier's versioned ALPN and adapts a reliable
ordered bidirectional QUIC stream. It uses Iroh-managed relay selection and
does not contain a relay server. Persistence, DID/device authentication, and
invitation signature verification are explicit service integration hooks and
must be supplied before the anchor readiness gate is enabled.

`atelier-sync-bindings` exposes the canonical V1 JSON validation and
serialization contract through a versioned C ABI and `wasm-bindgen`. It
deliberately reports live Iroh transport as unavailable: the binding package is
not an endpoint, relay, authentication layer, persistence adapter, or native
application integration by itself.
