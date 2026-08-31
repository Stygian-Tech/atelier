---
title: Collaboration protocol
description: The cross-platform Automerge-over-Iroh contract.
---

> This page describes the intended collaboration protocol. The current Rust
> crates validate and package the wire contract, but do not yet operate a live
> Iroh transport, authenticated peer loop, or durable Railway anchor.

The Rust collaboration workspace defines one wire contract for Swift, Kotlin, WASM, and the Railway anchor. Every frame includes a protocol version, document identity, actor/device identity, epoch, operation identity, and replay protection.

Anchor-first synchronization provides reliable rendezvous. Direct peers are opportunistic. A peer must authenticate the recipient-bound invitation, prove DID/device binding, and pass the current ACL before exchanging document state.

Compaction retains automatic versions for 30 days plus named versions. Rejoining peers advertise heads and checkpoint compatibility so the engine can safely rebase or require a newer snapshot.
