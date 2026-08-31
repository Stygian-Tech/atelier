---
title: Atelier Notes
---

> This page describes the MVP contract. The bootstrap has a versioned Rust wire
> protocol and cross-platform bindings, not a live Iroh endpoint or durable
> collaborative note store.

The local source of a note is a real Markdown file. SQLite indexes support search and backlinks, while app-managed sidecars hold Automerge checkpoints and collaboration metadata.

The UI reports three states independently:

1. the local file was saved;
2. active collaborators converged;
3. the materialized PDS record reached current heads.

The shared Rust engine uses a versioned ALPN, recipient-bound invitations, DID/device authentication, ACL checks, epoch rotation, and a trusted Railway anchor. Managed Iroh relays provide reachability; Atelier does not operate a custom relay during MVP.
