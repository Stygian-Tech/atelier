//! Cross-platform packaging for Atelier's canonical collaboration wire format.
//!
//! This crate intentionally exports validation and deterministic serialization
//! only. It does not link an Iroh endpoint, authenticate a peer, or persist a
//! checkpoint. Those capabilities remain explicit host integration seams.

#![deny(unsafe_op_in_unsafe_fn)]
#![cfg_attr(coverage_nightly, feature(coverage_attribute))]

use atelier_sync_protocol::{Checkpoint, Envelope, Payload, ProtocolError, ProtocolVersion};
use std::str;
use thiserror::Error;

#[cfg(not(target_arch = "wasm32"))]
#[allow(unsafe_code)]
pub mod ffi;

#[cfg(target_arch = "wasm32")]
mod wasm;

/// Version of the exported C and JavaScript binding contract.
pub const BINDING_ABI_VERSION_V1: u32 = 1;

/// Deterministic capability document returned by every binding target.
pub const CAPABILITIES_V1_JSON: &str = r#"{"abiVersion":1,"protocolVersion":"v1","alpn":"diy.atelier.notes.sync/1","liveIrohTransport":{"available":false,"reason":"not-linked-in-cross-platform-core"}}"#;

/// A validation or canonicalization failure at the binding boundary.
#[derive(Debug, Error)]
pub enum CollaborationCoreError {
    /// The input was not a valid V1 envelope.
    #[error("invalid V1 envelope: {0}")]
    InvalidEnvelope(ProtocolError),
    /// The input was not a valid V1 checkpoint.
    #[error("invalid V1 checkpoint: {0}")]
    InvalidCheckpoint(ProtocolError),
    /// The protocol serializer emitted bytes that were not UTF-8.
    #[error("protocol serializer emitted invalid UTF-8")]
    InvalidUtf8,
}

/// Parse, validate, and emit a V1 envelope using the canonical Rust field order.
pub fn canonicalize_envelope_v1(input: &str) -> Result<String, CollaborationCoreError> {
    let envelope =
        Envelope::decode(input.as_bytes()).map_err(CollaborationCoreError::InvalidEnvelope)?;
    if let Payload::Checkpoint { checkpoint } = &envelope.payload {
        checkpoint
            .validate()
            .map_err(CollaborationCoreError::InvalidCheckpoint)?;
    }
    encoded_json(
        envelope
            .encode()
            .map_err(CollaborationCoreError::InvalidEnvelope)?,
    )
}

/// Parse, integrity-check, and emit a V1 Automerge checkpoint canonically.
pub fn canonicalize_checkpoint_v1(input: &str) -> Result<String, CollaborationCoreError> {
    let checkpoint =
        Checkpoint::decode(input.as_bytes()).map_err(CollaborationCoreError::InvalidCheckpoint)?;
    encoded_json(
        checkpoint
            .encode()
            .map_err(CollaborationCoreError::InvalidCheckpoint)?,
    )
}

/// Return the ALPN attached to the protocol version packaged by these bindings.
#[must_use]
pub fn protocol_alpn_v1() -> &'static str {
    str::from_utf8(ProtocolVersion::V1.alpn()).unwrap_or("diy.atelier.notes.sync/1")
}

/// Return an honest, deterministic capability document for host feature gates.
#[must_use]
pub const fn capabilities_v1_json() -> &'static str {
    CAPABILITIES_V1_JSON
}

/// Live Iroh is deliberately outside this packaging crate.
#[must_use]
pub const fn live_iroh_transport_available_v1() -> bool {
    false
}

fn encoded_json(bytes: Vec<u8>) -> Result<String, CollaborationCoreError> {
    String::from_utf8(bytes).map_err(|_| CollaborationCoreError::InvalidUtf8)
}

#[cfg(test)]
#[cfg_attr(coverage_nightly, coverage(off))]
mod tests {
    use super::*;

    const ENVELOPE_FIXTURE: &str = include_str!("../fixtures/v1/envelope-presence.json");
    const CHECKPOINT_FIXTURE: &str = include_str!("../fixtures/v1/checkpoint.json");

    fn fixture_bytes(value: &str) -> &str {
        value.strip_suffix('\n').unwrap_or(value)
    }

    #[test]
    fn envelope_fixture_is_the_canonical_serialization() -> Result<(), CollaborationCoreError> {
        let expected = fixture_bytes(ENVELOPE_FIXTURE);
        assert_eq!(canonicalize_envelope_v1(expected)?, expected);
        Ok(())
    }

    #[test]
    fn checkpoint_fixture_is_integrity_checked_and_canonical() -> Result<(), CollaborationCoreError>
    {
        let expected = fixture_bytes(CHECKPOINT_FIXTURE);
        assert_eq!(canonicalize_checkpoint_v1(expected)?, expected);
        Ok(())
    }

    #[test]
    fn corrupted_nested_checkpoint_is_rejected() {
        let envelope = fixture_bytes(include_str!(
            "../fixtures/v1/envelope-corrupt-checkpoint.json"
        ));
        assert!(matches!(
            canonicalize_envelope_v1(envelope),
            Err(CollaborationCoreError::InvalidCheckpoint(_))
        ));
    }

    #[test]
    fn envelope_deserialization_cannot_bypass_identifier_validation() {
        let valid = fixture_bytes(ENVELOPE_FIXTURE);
        let invalid_did = valid.replace("did:plc:alice", "not-a-did");
        assert!(matches!(
            canonicalize_envelope_v1(&invalid_did),
            Err(CollaborationCoreError::InvalidEnvelope(_))
        ));

        let invalid_device = valid.replace("macbook", "device with spaces");
        assert!(matches!(
            canonicalize_envelope_v1(&invalid_device),
            Err(CollaborationCoreError::InvalidEnvelope(_))
        ));
    }

    #[test]
    fn capabilities_fail_closed_without_transport() {
        assert!(!live_iroh_transport_available_v1());
        assert_eq!(protocol_alpn_v1(), "diy.atelier.notes.sync/1");
        assert_eq!(
            capabilities_v1_json(),
            r#"{"abiVersion":1,"protocolVersion":"v1","alpn":"diy.atelier.notes.sync/1","liveIrohTransport":{"available":false,"reason":"not-linked-in-cross-platform-core"}}"#
        );
    }
}
