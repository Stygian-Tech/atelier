use serde::{de::Error as _, Deserialize, Deserializer, Serialize};
use std::{fmt, str::FromStr};
use thiserror::Error;
use uuid::Uuid;

/// Iroh ALPN for the first Atelier Notes sync protocol.
pub const ALPN_V1: &[u8] = b"diy.atelier.notes.sync/1";

#[derive(Debug, Error)]
pub enum ProtocolError {
    #[error("invalid decentralized identifier")]
    InvalidDid,
    #[error("invalid identifier: {0}")]
    InvalidIdentifier(String),
    #[error("unsupported protocol version")]
    UnsupportedVersion,
    #[error("epoch overflow")]
    EpochOverflow,
    #[error("checkpoint integrity check failed")]
    InvalidCheckpoint,
    #[error("Automerge operation failed: {0}")]
    Automerge(String),
    #[error("wire encoding failed: {0}")]
    Encoding(String),
}

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum ProtocolVersion {
    #[default]
    V1,
}

impl ProtocolVersion {
    #[must_use]
    pub const fn alpn(self) -> &'static [u8] {
        match self {
            Self::V1 => ALPN_V1,
        }
    }
}

macro_rules! uuid_id {
    ($name:ident) => {
        #[derive(Clone, Copy, Debug, Eq, Hash, PartialEq, Serialize, Deserialize)]
        #[serde(transparent)]
        pub struct $name(Uuid);

        impl $name {
            #[must_use]
            pub fn new() -> Self {
                Self(Uuid::new_v4())
            }

            #[must_use]
            pub const fn from_uuid(value: Uuid) -> Self {
                Self(value)
            }

            #[must_use]
            pub const fn as_uuid(&self) -> &Uuid {
                &self.0
            }
        }

        impl Default for $name {
            fn default() -> Self {
                Self::new()
            }
        }

        impl fmt::Display for $name {
            fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
                self.0.fmt(formatter)
            }
        }

        impl FromStr for $name {
            type Err = ProtocolError;

            fn from_str(value: &str) -> Result<Self, Self::Err> {
                Uuid::parse_str(value)
                    .map(Self)
                    .map_err(|error| ProtocolError::InvalidIdentifier(error.to_string()))
            }
        }
    };
}

uuid_id!(DocumentId);
uuid_id!(MessageId);

#[derive(Clone, Debug, Eq, Hash, PartialEq, Serialize)]
#[serde(transparent)]
pub struct Did(String);

impl Did {
    pub fn parse(value: impl Into<String>) -> Result<Self, ProtocolError> {
        let value = value.into();
        if value.starts_with("did:") && value.len() > 5 && !value.chars().any(char::is_whitespace) {
            Ok(Self(value))
        } else {
            Err(ProtocolError::InvalidDid)
        }
    }

    #[must_use]
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl fmt::Display for Did {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.0.fmt(formatter)
    }
}

impl<'de> Deserialize<'de> for Did {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        let value = String::deserialize(deserializer)?;
        Self::parse(value).map_err(D::Error::custom)
    }
}

#[derive(Clone, Debug, Eq, Hash, PartialEq, Serialize)]
#[serde(transparent)]
pub struct DeviceId(String);

impl DeviceId {
    pub fn parse(value: impl Into<String>) -> Result<Self, ProtocolError> {
        let value = value.into();
        if !value.is_empty()
            && value.len() <= 128
            && value
                .chars()
                .all(|character| character.is_ascii_alphanumeric() || "-_.:".contains(character))
        {
            Ok(Self(value))
        } else {
            Err(ProtocolError::InvalidIdentifier("device id".to_owned()))
        }
    }

    #[must_use]
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl<'de> Deserialize<'de> for DeviceId {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        let value = String::deserialize(deserializer)?;
        Self::parse(value).map_err(D::Error::custom)
    }
}

#[derive(Clone, Copy, Debug, Default, Eq, Ord, PartialEq, PartialOrd, Serialize, Deserialize)]
#[serde(transparent)]
pub struct Epoch(u64);

impl Epoch {
    #[must_use]
    pub const fn new(value: u64) -> Self {
        Self(value)
    }

    #[must_use]
    pub const fn get(self) -> u64 {
        self.0
    }

    pub fn next(self) -> Result<Self, ProtocolError> {
        self.0
            .checked_add(1)
            .map(Self)
            .ok_or(ProtocolError::EpochOverflow)
    }
}

#[derive(Clone, Copy, Debug, Eq, Ord, PartialEq, PartialOrd, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Role {
    Viewer,
    Editor,
    Owner,
}

impl Role {
    #[must_use]
    pub const fn allows(self, required: Self) -> bool {
        self as u8 >= required as u8
    }
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Invitation {
    pub version: ProtocolVersion,
    pub invitation_id: MessageId,
    pub document_id: DocumentId,
    pub inviter: Did,
    pub recipient: Did,
    pub role: Role,
    pub epoch: Epoch,
    pub expires_at_ms: u64,
    /// Random, signed invitation material. It is not an access token by itself.
    pub nonce: String,
}

impl Invitation {
    #[must_use]
    pub fn is_valid_for(&self, recipient: &Did, epoch: Epoch, now_ms: u64) -> bool {
        self.version == ProtocolVersion::V1
            && &self.recipient == recipient
            && self.epoch == epoch
            && now_ms < self.expires_at_ms
            && !self.nonce.is_empty()
    }
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "camelCase")]
pub enum Payload {
    Hello {
        invitation: Option<Invitation>,
        heads: Vec<String>,
    },
    /// An encoded `automerge::sync::Message` for a reliable ordered stream.
    Sync {
        #[serde(with = "base64_bytes")]
        message: Vec<u8>,
    },
    Checkpoint {
        checkpoint: crate::Checkpoint,
    },
    Ack {
        acknowledged: MessageId,
        persisted_to_pds: bool,
    },
    Presence {
        state: String,
    },
    Revoke {
        device_id: DeviceId,
        effective_epoch: Epoch,
    },
    Error {
        code: String,
        retryable: bool,
    },
}

impl Payload {
    #[must_use]
    pub const fn required_role(&self) -> Role {
        match self {
            Self::Hello { .. } | Self::Presence { .. } => Role::Viewer,
            Self::Sync { .. } | Self::Checkpoint { .. } | Self::Ack { .. } => Role::Editor,
            Self::Revoke { .. } => Role::Owner,
            Self::Error { .. } => Role::Viewer,
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Envelope {
    pub version: ProtocolVersion,
    pub message_id: MessageId,
    pub document_id: DocumentId,
    pub sender: Did,
    pub device_id: DeviceId,
    pub epoch: Epoch,
    pub sequence: u64,
    pub sent_at_ms: u64,
    pub payload: Payload,
}

impl Envelope {
    pub fn encode(&self) -> Result<Vec<u8>, ProtocolError> {
        serde_json::to_vec(self).map_err(|error| ProtocolError::Encoding(error.to_string()))
    }

    pub fn decode(bytes: &[u8]) -> Result<Self, ProtocolError> {
        let envelope: Self = serde_json::from_slice(bytes)
            .map_err(|error| ProtocolError::Encoding(error.to_string()))?;
        if envelope.version != ProtocolVersion::V1 {
            return Err(ProtocolError::UnsupportedVersion);
        }
        Ok(envelope)
    }
}

mod base64_bytes {
    use base64::{engine::general_purpose::STANDARD, Engine as _};
    use serde::{de::Error as _, Deserialize, Deserializer, Serializer};

    pub fn serialize<S>(bytes: &[u8], serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        serializer.serialize_str(&STANDARD.encode(bytes))
    }

    pub fn deserialize<'de, D>(deserializer: D) -> Result<Vec<u8>, D::Error>
    where
        D: Deserializer<'de>,
    {
        let value = String::deserialize(deserializer)?;
        STANDARD.decode(value).map_err(D::Error::custom)
    }
}

#[cfg(test)]
#[cfg_attr(coverage_nightly, coverage(off))]
mod tests {
    use super::*;

    #[test]
    fn invitations_are_bound_to_recipient_and_epoch() -> Result<(), ProtocolError> {
        let alice = Did::parse("did:plc:alice")?;
        let bob = Did::parse("did:plc:bob")?;
        let invitation = Invitation {
            version: ProtocolVersion::V1,
            invitation_id: MessageId::new(),
            document_id: DocumentId::new(),
            inviter: alice,
            recipient: bob.clone(),
            role: Role::Editor,
            epoch: Epoch::new(4),
            expires_at_ms: 200,
            nonce: "signed-random-material".to_owned(),
        };

        assert!(invitation.is_valid_for(&bob, Epoch::new(4), 199));
        assert!(!invitation.is_valid_for(&bob, Epoch::new(5), 199));
        assert!(!invitation.is_valid_for(&Did::parse("did:plc:mallory")?, Epoch::new(4), 199));
        assert!(!invitation.is_valid_for(&bob, Epoch::new(4), 200));

        let mut empty_nonce = invitation;
        empty_nonce.nonce.clear();
        assert!(!empty_nonce.is_valid_for(&bob, Epoch::new(4), 199));
        Ok(())
    }

    #[test]
    fn identifiers_epochs_and_roles_enforce_boundaries() -> Result<(), ProtocolError> {
        let uuid = Uuid::nil();
        let document_id = DocumentId::from_uuid(uuid);
        let message_id = MessageId::from_uuid(uuid);
        assert_eq!(document_id.as_uuid(), &uuid);
        assert_eq!(message_id.as_uuid(), &uuid);
        assert_eq!(document_id.to_string().parse::<DocumentId>()?, document_id);
        assert_eq!(message_id.to_string().parse::<MessageId>()?, message_id);
        assert_ne!(DocumentId::default(), document_id);
        assert_ne!(MessageId::default(), message_id);
        assert!("not-a-uuid".parse::<DocumentId>().is_err());
        assert!("not-a-uuid".parse::<MessageId>().is_err());

        let did = Did::parse("did:plc:alice")?;
        assert_eq!(did.as_str(), "did:plc:alice");
        assert_eq!(did.to_string(), "did:plc:alice");
        for invalid in ["did:", "did:plc:two words", ""] {
            assert!(matches!(
                Did::parse(invalid),
                Err(ProtocolError::InvalidDid)
            ));
        }

        let device = DeviceId::parse("device-1_test.example:mobile")?;
        assert_eq!(device.as_str(), "device-1_test.example:mobile");
        assert!(DeviceId::parse("").is_err());
        assert!(DeviceId::parse("x".repeat(129)).is_err());
        assert!(DeviceId::parse("device/invalid").is_err());

        assert_eq!(Epoch::new(8).get(), 8);
        assert_eq!(Epoch::new(8).next()?, Epoch::new(9));
        assert!(matches!(
            Epoch::new(u64::MAX).next(),
            Err(ProtocolError::EpochOverflow)
        ));
        assert!(Role::Owner.allows(Role::Editor));
        assert!(!Role::Viewer.allows(Role::Editor));
        Ok(())
    }

    #[test]
    fn payload_roles_and_sync_encoding_are_stable() -> Result<(), ProtocolError> {
        let document_id = DocumentId::new();
        let payloads = [
            (
                Payload::Hello {
                    invitation: None,
                    heads: vec![],
                },
                Role::Viewer,
            ),
            (
                Payload::Sync {
                    message: vec![0, 1, 2, 255],
                },
                Role::Editor,
            ),
            (
                Payload::Checkpoint {
                    checkpoint: crate::Checkpoint::new(
                        ProtocolVersion::V1,
                        document_id,
                        Epoch::new(1),
                        0,
                        1,
                        vec![],
                        vec![],
                    ),
                },
                Role::Editor,
            ),
            (
                Payload::Ack {
                    acknowledged: MessageId::new(),
                    persisted_to_pds: false,
                },
                Role::Editor,
            ),
            (
                Payload::Presence {
                    state: "online".to_owned(),
                },
                Role::Viewer,
            ),
            (
                Payload::Revoke {
                    device_id: DeviceId::parse("revoked")?,
                    effective_epoch: Epoch::new(2),
                },
                Role::Owner,
            ),
            (
                Payload::Error {
                    code: "retry".to_owned(),
                    retryable: true,
                },
                Role::Viewer,
            ),
        ];

        for (payload, role) in payloads {
            assert_eq!(payload.required_role(), role);
        }

        let envelope = Envelope {
            version: ProtocolVersion::V1,
            message_id: MessageId::new(),
            document_id,
            sender: Did::parse("did:plc:alice")?,
            device_id: DeviceId::parse("macbook")?,
            epoch: Epoch::new(1),
            sequence: 1,
            sent_at_ms: 1,
            payload: Payload::Sync {
                message: vec![0, 1, 2, 255],
            },
        };
        let encoded = envelope.encode()?;
        assert_eq!(Envelope::decode(&encoded)?, envelope);
        assert!(matches!(
            Envelope::decode(b"{not-json"),
            Err(ProtocolError::Encoding(_))
        ));

        let invalid_base64 = String::from_utf8(encoded)
            .map_err(|error| ProtocolError::Encoding(error.to_string()))?
            .replace("AAEC/w==", "***");
        assert!(matches!(
            Envelope::decode(invalid_base64.as_bytes()),
            Err(ProtocolError::Encoding(_))
        ));
        Ok(())
    }
}
