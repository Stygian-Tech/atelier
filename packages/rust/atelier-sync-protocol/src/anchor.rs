use crate::{
    Checkpoint, DeviceId, Did, DocumentId, Envelope, Epoch, NotesDocument, Payload, ProtocolError,
    Role,
};
use std::collections::{HashMap, HashSet};
use thiserror::Error;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Durability {
    Local,
    CollaboratorsConverged,
    PdsDurable,
}

#[derive(Clone, Debug)]
pub struct AdmissionContext<'a> {
    pub document_id: DocumentId,
    pub actor: &'a Did,
    pub device_id: &'a DeviceId,
    pub epoch: Epoch,
    pub required_role: Role,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum AdmissionDecision {
    Admit { role: Role },
    Deny { reason: &'static str },
}

pub trait AdmissionPolicy: Send + Sync {
    fn admit(&self, context: &AdmissionContext<'_>) -> AdmissionDecision;
}

#[derive(Clone, Debug)]
pub struct StaticAcl {
    current_epoch: Epoch,
    members: HashMap<Did, Role>,
    revoked_devices: HashSet<DeviceId>,
}

impl StaticAcl {
    #[must_use]
    pub fn new(current_epoch: Epoch) -> Self {
        Self {
            current_epoch,
            members: HashMap::new(),
            revoked_devices: HashSet::new(),
        }
    }

    pub fn grant(&mut self, actor: Did, role: Role) {
        self.members.insert(actor, role);
    }

    pub fn revoke_device(&mut self, device: DeviceId) {
        self.revoked_devices.insert(device);
    }

    pub fn rotate_epoch(&mut self, epoch: Epoch) {
        self.current_epoch = epoch;
    }
}

impl AdmissionPolicy for StaticAcl {
    fn admit(&self, context: &AdmissionContext<'_>) -> AdmissionDecision {
        if context.epoch != self.current_epoch {
            return AdmissionDecision::Deny {
                reason: "stale epoch",
            };
        }
        if self.revoked_devices.contains(context.device_id) {
            return AdmissionDecision::Deny {
                reason: "revoked device",
            };
        }
        match self.members.get(context.actor).copied() {
            Some(role) if role.allows(context.required_role) => AdmissionDecision::Admit { role },
            Some(_) => AdmissionDecision::Deny {
                reason: "insufficient role",
            },
            None => AdmissionDecision::Deny {
                reason: "unknown member",
            },
        }
    }
}

#[derive(Debug, Error)]
pub enum AnchorError {
    #[error("message targets a different document")]
    WrongDocument,
    #[error("message rejected: {0}")]
    Rejected(&'static str),
    #[error("invalid epoch transition")]
    InvalidEpoch,
    #[error(transparent)]
    Protocol(#[from] ProtocolError),
}

/// The trusted, anchor-first state for one Notes document.
///
/// Persistence and network I/O remain caller responsibilities. The anchor only
/// advances its durability marker after the caller reports a completed gate.
#[derive(Clone, Debug)]
pub struct AnchorReplica<P> {
    document: NotesDocument,
    policy: P,
    epoch: Epoch,
    generation: u64,
    durability: Durability,
    last_sequence: HashMap<DeviceId, u64>,
}

impl<P: AdmissionPolicy> AnchorReplica<P> {
    #[must_use]
    pub fn new(document: NotesDocument, policy: P, epoch: Epoch) -> Self {
        Self {
            document,
            policy,
            epoch,
            generation: 0,
            durability: Durability::Local,
            last_sequence: HashMap::new(),
        }
    }

    #[must_use]
    pub const fn durability(&self) -> Durability {
        self.durability
    }

    #[must_use]
    pub const fn epoch(&self) -> Epoch {
        self.epoch
    }

    #[must_use]
    pub const fn generation(&self) -> u64 {
        self.generation
    }

    pub fn markdown(&self) -> Result<String, AnchorError> {
        self.document.markdown().map_err(AnchorError::from)
    }

    pub fn admit(&mut self, envelope: &Envelope) -> Result<Role, AnchorError> {
        if envelope.document_id != self.document.id() {
            return Err(AnchorError::WrongDocument);
        }
        let context = AdmissionContext {
            document_id: envelope.document_id,
            actor: &envelope.sender,
            device_id: &envelope.device_id,
            epoch: envelope.epoch,
            required_role: envelope.payload.required_role(),
        };
        let role = match self.policy.admit(&context) {
            AdmissionDecision::Admit { role } => role,
            AdmissionDecision::Deny { reason } => return Err(AnchorError::Rejected(reason)),
        };
        let previous = self.last_sequence.get(&envelope.device_id).copied();
        if previous.is_some_and(|sequence| envelope.sequence <= sequence) {
            return Err(AnchorError::Rejected("replayed sequence"));
        }
        self.last_sequence
            .insert(envelope.device_id.clone(), envelope.sequence);
        Ok(role)
    }

    pub fn receive_checkpoint(&mut self, checkpoint: &Checkpoint) -> Result<(), AnchorError> {
        if checkpoint.document_id != self.document.id() {
            return Err(AnchorError::WrongDocument);
        }
        if checkpoint.epoch != self.epoch {
            return Err(AnchorError::InvalidEpoch);
        }
        let mut peer = NotesDocument::load(checkpoint)?;
        self.document.merge(&mut peer)?;
        self.durability = Durability::Local;
        Ok(())
    }

    pub fn apply_admitted(&mut self, envelope: &Envelope) -> Result<(), AnchorError> {
        self.admit(envelope)?;
        if let Payload::Checkpoint { checkpoint } = &envelope.payload {
            self.receive_checkpoint(checkpoint)?;
        }
        Ok(())
    }

    pub fn mark_collaborators_converged(&mut self) {
        self.durability = Durability::CollaboratorsConverged;
    }

    pub fn mark_pds_durable(&mut self) {
        self.durability = Durability::PdsDurable;
    }

    /// Produce Automerge's compact full-save format while preserving history,
    /// so an offline peer can still rejoin and exchange missing changes.
    pub fn compact_checkpoint(&mut self, now_ms: u64) -> Result<Checkpoint, AnchorError> {
        self.generation = self.generation.saturating_add(1);
        self.document
            .checkpoint(self.epoch, self.generation, now_ms)
            .map_err(AnchorError::from)
    }
}
