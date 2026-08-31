//! Atelier Notes' transport-independent collaboration protocol.
//!
//! The wire envelope is deliberately separate from Iroh. Automerge needs a
//! reliable, ordered byte stream; Iroh is one implementation of that stream.
//! Keeping this crate transport-free also lets Swift, Kotlin, WASM, and anchor
//! bindings share fixtures without claiming a network runtime is available.

#![cfg_attr(coverage_nightly, feature(coverage_attribute))]

mod anchor;
mod checkpoint;
mod document;
mod types;

pub use anchor::{
    AdmissionContext, AdmissionDecision, AdmissionPolicy, AnchorError, AnchorReplica, Durability,
    StaticAcl,
};
pub use checkpoint::Checkpoint;
pub use document::{NotesDocument, PeerSyncState};
pub use types::{
    DeviceId, Did, DocumentId, Envelope, Epoch, Invitation, MessageId, Payload, ProtocolError,
    ProtocolVersion, Role, ALPN_V1,
};
