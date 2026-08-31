use atelier_sync_protocol::{
    AnchorError, AnchorReplica, Checkpoint, DeviceId, Did, DocumentId, Durability, Envelope, Epoch,
    MessageId, NotesDocument, Payload, PeerSyncState, ProtocolError, ProtocolVersion, Role,
    StaticAcl,
};

fn did(value: &str) -> Result<Did, ProtocolError> {
    Did::parse(value)
}

fn device(value: &str) -> Result<DeviceId, ProtocolError> {
    DeviceId::parse(value)
}

fn fork_pair(markdown: &str) -> Result<(NotesDocument, NotesDocument), ProtocolError> {
    let mut origin = NotesDocument::new(DocumentId::new(), markdown)?;
    let checkpoint = origin.checkpoint(Epoch::new(1), 0, 1)?;
    Ok((
        NotesDocument::load(&checkpoint)?,
        NotesDocument::load(&checkpoint)?,
    ))
}

fn converge(
    left: &mut NotesDocument,
    right: &mut NotesDocument,
    left_state: &mut PeerSyncState,
    right_state: &mut PeerSyncState,
) -> Result<(), ProtocolError> {
    for _ in 0..100 {
        let left_message = left.next_sync_message(left_state);
        if let Some(message) = left_message.as_ref() {
            right.receive_sync_message(right_state, message)?;
        }

        let right_message = right.next_sync_message(right_state);
        if let Some(message) = right_message.as_ref() {
            left.receive_sync_message(left_state, message)?;
        }

        if left_message.is_none() && right_message.is_none() {
            return Ok(());
        }
    }
    Err(ProtocolError::Encoding(
        "sync did not quiesce within 100 exchanges".to_owned(),
    ))
}

#[test]
fn concurrent_markdown_changes_converge() -> Result<(), ProtocolError> {
    let (mut alice, mut bob) = fork_pair("middle")?;
    alice.splice_markdown(6, 0, "-alice")?;
    bob.splice_markdown(0, 0, "bob-")?;

    let mut alice_view = alice.clone();
    let mut bob_view = bob.clone();
    alice.merge(&mut bob_view)?;
    bob.merge(&mut alice_view)?;

    assert_eq!(alice.markdown()?, bob.markdown()?);
    assert!(alice.markdown()?.contains("alice"));
    assert!(alice.markdown()?.contains("bob"));
    Ok(())
}

#[test]
fn reconnect_uses_new_peer_state_and_catches_up() -> Result<(), ProtocolError> {
    let (mut anchor, mut mobile) = fork_pair("draft")?;
    mobile.splice_markdown(5, 0, " one")?;
    converge(
        &mut anchor,
        &mut mobile,
        &mut PeerSyncState::new(),
        &mut PeerSyncState::new(),
    )?;
    assert_eq!(anchor.markdown()?, "draft one");

    // The mobile client edits offline and reconnects with fresh stream state.
    mobile.splice_markdown(9, 0, " two")?;
    let mut anchor_reconnect = PeerSyncState::new();
    let mut mobile_reconnect = PeerSyncState::new();
    converge(
        &mut anchor,
        &mut mobile,
        &mut anchor_reconnect,
        &mut mobile_reconnect,
    )?;
    assert_eq!(anchor.markdown()?, mobile.markdown()?);
    assert_eq!(anchor.markdown()?, "draft one two");
    Ok(())
}

#[test]
fn revoked_devices_and_replayed_sequences_are_rejected() -> Result<(), ProtocolError> {
    let owner = did("did:plc:owner")?;
    let revoked = device("iphone-revoked")?;
    let document_id = DocumentId::new();
    let epoch = Epoch::new(3);
    let mut acl = StaticAcl::new(epoch);
    acl.grant(owner.clone(), Role::Owner);
    acl.revoke_device(revoked.clone());
    let document = NotesDocument::new(document_id, "safe")?;
    let mut anchor = AnchorReplica::new(document, acl, epoch);

    let envelope = Envelope {
        version: ProtocolVersion::V1,
        message_id: MessageId::new(),
        document_id,
        sender: owner.clone(),
        device_id: revoked,
        epoch,
        sequence: 1,
        sent_at_ms: 1,
        payload: Payload::Presence {
            state: "online".to_owned(),
        },
    };
    assert!(matches!(
        anchor.admit(&envelope),
        Err(AnchorError::Rejected("revoked device"))
    ));

    let active_device = device("mac-active")?;
    let active = Envelope {
        device_id: active_device,
        ..envelope
    };
    assert_eq!(
        anchor.admit(&active).expect("active owner admitted"),
        Role::Owner
    );
    assert!(matches!(
        anchor.admit(&active),
        Err(AnchorError::Rejected("replayed sequence"))
    ));
    Ok(())
}

#[test]
fn compact_checkpoint_preserves_offline_rejoin_history() -> Result<(), ProtocolError> {
    let document_id = DocumentId::new();
    let epoch = Epoch::new(2);
    let mut original = NotesDocument::new(document_id, "base")?;
    let base = original.checkpoint(epoch, 0, 1)?;
    let mut offline = NotesDocument::load(&base)?;
    offline.splice_markdown(4, 0, " offline")?;

    let owner = did("did:plc:owner")?;
    let mut acl = StaticAcl::new(epoch);
    acl.grant(owner, Role::Owner);
    let mut anchor = AnchorReplica::new(NotesDocument::load(&base)?, acl, epoch);
    anchor.mark_collaborators_converged();
    assert_eq!(anchor.durability(), Durability::CollaboratorsConverged);

    let compact = anchor
        .compact_checkpoint(2)
        .map_err(|error| ProtocolError::Encoding(error.to_string()))?;
    assert_eq!(compact.generation, 1);
    let mut reloaded = NotesDocument::load(&compact)?;
    reloaded.merge(&mut offline)?;
    assert_eq!(reloaded.markdown()?, "base offline");
    Ok(())
}

#[test]
fn corrupted_checkpoint_is_refused() -> Result<(), ProtocolError> {
    let mut document = NotesDocument::new(DocumentId::new(), "integrity")?;
    let checkpoint = document.checkpoint(Epoch::new(1), 0, 1)?;
    let encoded = checkpoint.encode()?;
    let mut decoded: Checkpoint = Checkpoint::decode(&encoded)?;
    decoded.automerge.push(0);
    assert!(matches!(
        decoded.validate(),
        Err(ProtocolError::InvalidCheckpoint)
    ));
    Ok(())
}

#[test]
fn acl_and_anchor_reject_wrong_document_stale_epoch_and_missing_roles() -> Result<(), ProtocolError>
{
    let document_id = DocumentId::new();
    let owner = did("did:plc:owner")?;
    let viewer = did("did:plc:viewer")?;
    let unknown = did("did:plc:unknown")?;
    let current_epoch = Epoch::new(5);
    let mut acl = StaticAcl::new(Epoch::new(4));
    acl.grant(owner.clone(), Role::Owner);
    acl.grant(viewer.clone(), Role::Viewer);
    acl.rotate_epoch(current_epoch);
    let mut anchor = AnchorReplica::new(
        NotesDocument::new(document_id, "protected")?,
        acl,
        current_epoch,
    );

    let base = Envelope {
        version: ProtocolVersion::V1,
        message_id: MessageId::new(),
        document_id,
        sender: owner.clone(),
        device_id: device("mac-owner")?,
        epoch: current_epoch,
        sequence: 1,
        sent_at_ms: 1,
        payload: Payload::Presence {
            state: "online".to_owned(),
        },
    };

    assert!(matches!(
        anchor.admit(&Envelope {
            document_id: DocumentId::new(),
            ..base.clone()
        }),
        Err(AnchorError::WrongDocument)
    ));
    assert!(matches!(
        anchor.admit(&Envelope {
            epoch: Epoch::new(4),
            ..base.clone()
        }),
        Err(AnchorError::Rejected("stale epoch"))
    ));
    assert!(matches!(
        anchor.admit(&Envelope {
            sender: viewer,
            device_id: device("ipad-viewer")?,
            payload: Payload::Sync {
                message: vec![1, 2, 3],
            },
            ..base.clone()
        }),
        Err(AnchorError::Rejected("insufficient role"))
    ));
    assert!(matches!(
        anchor.admit(&Envelope {
            sender: unknown,
            device_id: device("unknown-device")?,
            ..base
        }),
        Err(AnchorError::Rejected("unknown member"))
    ));
    assert_eq!(anchor.epoch(), current_epoch);
    assert_eq!(anchor.generation(), 0);
    assert_eq!(
        anchor
            .markdown()
            .map_err(|error| ProtocolError::Encoding(error.to_string()))?,
        "protected"
    );
    Ok(())
}

#[test]
fn admitted_checkpoints_preserve_durability_boundaries() -> Result<(), ProtocolError> {
    let document_id = DocumentId::new();
    let epoch = Epoch::new(7);
    let owner = did("did:plc:owner")?;
    let mut initial = NotesDocument::new(document_id, "base")?;
    let initial_checkpoint = initial.checkpoint(epoch, 0, 1)?;
    let mut acl = StaticAcl::new(epoch);
    acl.grant(owner.clone(), Role::Owner);
    let mut anchor = AnchorReplica::new(NotesDocument::load(&initial_checkpoint)?, acl, epoch);

    let mut other_document = NotesDocument::new(DocumentId::new(), "other")?;
    let wrong_document = other_document.checkpoint(epoch, 1, 2)?;
    assert!(matches!(
        anchor.receive_checkpoint(&wrong_document),
        Err(AnchorError::WrongDocument)
    ));

    let mut peer = NotesDocument::load(&initial_checkpoint)?;
    peer.replace_markdown("peer edit")?;
    let stale_epoch = peer.checkpoint(Epoch::new(6), 1, 2)?;
    assert!(matches!(
        anchor.receive_checkpoint(&stale_epoch),
        Err(AnchorError::InvalidEpoch)
    ));

    let checkpoint = peer.checkpoint(epoch, 1, 3)?;
    let checkpoint_envelope = Envelope {
        version: ProtocolVersion::V1,
        message_id: MessageId::new(),
        document_id,
        sender: owner.clone(),
        device_id: device("mac-owner")?,
        epoch,
        sequence: 1,
        sent_at_ms: 3,
        payload: Payload::Checkpoint { checkpoint },
    };
    anchor
        .apply_admitted(&checkpoint_envelope)
        .map_err(|error| ProtocolError::Encoding(error.to_string()))?;
    assert_eq!(anchor.durability(), Durability::Local);
    assert_eq!(
        anchor
            .markdown()
            .map_err(|error| ProtocolError::Encoding(error.to_string()))?,
        "peer edit"
    );

    anchor.mark_pds_durable();
    assert_eq!(anchor.durability(), Durability::PdsDurable);
    anchor
        .apply_admitted(&Envelope {
            message_id: MessageId::new(),
            sequence: 2,
            payload: Payload::Presence {
                state: "online".to_owned(),
            },
            ..checkpoint_envelope
        })
        .map_err(|error| ProtocolError::Encoding(error.to_string()))?;
    assert_eq!(anchor.durability(), Durability::PdsDurable);
    Ok(())
}

#[test]
fn document_mutations_reject_invalid_ranges_ids_and_frames() -> Result<(), ProtocolError> {
    let document_id = DocumentId::new();
    let mut empty = NotesDocument::new(document_id, "")?;
    assert_eq!(empty.markdown()?, "");
    empty.replace_markdown("abc")?;
    assert_eq!(empty.markdown()?, "abc");

    for (position, delete) in [(4, 0), (0, -1), (2, 2)] {
        assert!(matches!(
            empty.splice_markdown(position, delete, "x"),
            Err(ProtocolError::InvalidIdentifier(_))
        ));
    }

    let mut other = NotesDocument::new(DocumentId::new(), "other")?;
    assert!(matches!(
        empty.merge(&mut other),
        Err(ProtocolError::InvalidIdentifier(_))
    ));
    assert!(matches!(
        empty.receive_sync_message(&mut PeerSyncState::new(), b"not-an-automerge-frame"),
        Err(ProtocolError::Encoding(_))
    ));

    let checkpoint = empty.checkpoint(Epoch::new(1), 0, 1)?;
    let mismatched = Checkpoint::new(
        checkpoint.version,
        DocumentId::new(),
        checkpoint.epoch,
        checkpoint.generation,
        checkpoint.created_at_ms,
        checkpoint.heads,
        checkpoint.automerge,
    );
    assert!(matches!(
        NotesDocument::load(&mismatched),
        Err(ProtocolError::InvalidCheckpoint)
    ));
    Ok(())
}
