use crate::{DocumentId, Epoch, ProtocolError, ProtocolVersion};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Checkpoint {
    pub version: ProtocolVersion,
    pub document_id: DocumentId,
    pub epoch: Epoch,
    pub generation: u64,
    pub created_at_ms: u64,
    pub heads: Vec<String>,
    #[serde(with = "base64_bytes")]
    pub automerge: Vec<u8>,
    pub sha256: String,
}

impl Checkpoint {
    #[allow(clippy::too_many_arguments)]
    #[must_use]
    pub fn new(
        version: ProtocolVersion,
        document_id: DocumentId,
        epoch: Epoch,
        generation: u64,
        created_at_ms: u64,
        heads: Vec<String>,
        automerge: Vec<u8>,
    ) -> Self {
        let sha256 = digest(&automerge);
        Self {
            version,
            document_id,
            epoch,
            generation,
            created_at_ms,
            heads,
            automerge,
            sha256,
        }
    }

    pub fn validate(&self) -> Result<(), ProtocolError> {
        if self.version != ProtocolVersion::V1 || self.sha256 != digest(&self.automerge) {
            return Err(ProtocolError::InvalidCheckpoint);
        }
        Ok(())
    }

    pub fn encode(&self) -> Result<Vec<u8>, ProtocolError> {
        serde_json::to_vec(self).map_err(|error| ProtocolError::Encoding(error.to_string()))
    }

    pub fn decode(bytes: &[u8]) -> Result<Self, ProtocolError> {
        let checkpoint: Self = serde_json::from_slice(bytes)
            .map_err(|error| ProtocolError::Encoding(error.to_string()))?;
        checkpoint.validate()?;
        Ok(checkpoint)
    }
}

fn digest(bytes: &[u8]) -> String {
    hex::encode(Sha256::digest(bytes))
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
