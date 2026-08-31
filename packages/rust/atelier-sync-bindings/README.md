# Atelier collaboration bindings

This crate packages the canonical `atelier-sync-protocol` V1 envelope and
checkpoint validation for native and WebAssembly hosts.

Native builds emit an `rlib`, `cdylib`, and `staticlib`. The versioned C header
at `include/atelier_collaboration_v1.h` is suitable for a Swift module map or an
Android NDK/JNI adapter. The API accepts UTF-8 JSON, returns canonical JSON in a
library-owned buffer, and requires the matching V1 free function. Kotlin/JVM JNI
glue and Apple XCFramework packaging remain host build tasks; this crate does
not claim those artifacts already exist.

`wasm32-unknown-unknown` builds contain equivalent `wasm-bindgen` exports for
capabilities plus envelope/checkpoint canonicalization. Generating and
publishing JavaScript/TypeScript glue with the matching `wasm-bindgen` CLI
remains a host build task; generated glue is not checked in as source.

Both targets report live Iroh transport as unavailable. The existing optional
Iroh endpoint adapter remains in `atelier-sync-transport`; hosts still need to
provide peer identity, invitation verification, ACL state, connection lifecycle,
durable checkpoint storage, and PDS persistence before enabling collaboration.

```sh
cargo test --manifest-path packages/rust/Cargo.toml --workspace --all-targets --locked
cargo build --manifest-path packages/rust/Cargo.toml \
  --package atelier-sync-bindings --release --locked
cargo check --manifest-path packages/rust/Cargo.toml \
  --package atelier-sync-bindings --target wasm32-unknown-unknown --locked
```
