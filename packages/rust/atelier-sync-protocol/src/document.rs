use crate::{Checkpoint, DocumentId, Epoch, ProtocolError, ProtocolVersion};
use automerge::{
    sync::{self, SyncDoc},
    transaction::Transactable,
    AutoCommit, ObjType, ReadDoc, Value, ROOT,
};

const DOCUMENT_ID_KEY: &str = "documentId";
const MARKDOWN_KEY: &str = "markdown";
const SCHEMA_VERSION_KEY: &str = "schemaVersion";
const DOCUMENT_SCHEMA_VERSION: u64 = 1;

/// Per-connection Automerge sync state. Create a fresh value on reconnect.
#[derive(Debug, Default)]
pub struct PeerSyncState {
    inner: sync::State,
}

impl PeerSyncState {
    #[must_use]
    pub fn new() -> Self {
        Self {
            inner: sync::State::new(),
        }
    }
}

#[derive(Clone, Debug)]
pub struct NotesDocument {
    id: DocumentId,
    inner: AutoCommit,
}

impl NotesDocument {
    pub fn new(id: DocumentId, markdown: &str) -> Result<Self, ProtocolError> {
        let mut inner = AutoCommit::new();
        inner
            .put(ROOT, DOCUMENT_ID_KEY, id.to_string())
            .map_err(automerge_error)?;
        inner
            .put(ROOT, SCHEMA_VERSION_KEY, DOCUMENT_SCHEMA_VERSION)
            .map_err(automerge_error)?;
        let text = inner
            .put_object(ROOT, MARKDOWN_KEY, ObjType::Text)
            .map_err(automerge_error)?;
        if !markdown.is_empty() {
            inner
                .splice_text(&text, 0, 0, markdown)
                .map_err(automerge_error)?;
        }
        inner.commit();
        Ok(Self { id, inner })
    }

    pub fn load(checkpoint: &Checkpoint) -> Result<Self, ProtocolError> {
        checkpoint.validate()?;
        let inner = AutoCommit::load(&checkpoint.automerge).map_err(automerge_error)?;
        let stored_id = inner
            .get(ROOT, DOCUMENT_ID_KEY)
            .map_err(automerge_error)?
            .and_then(|(value, _)| value.to_str().map(str::to_owned))
            .ok_or(ProtocolError::InvalidCheckpoint)?;
        if stored_id != checkpoint.document_id.to_string() {
            return Err(ProtocolError::InvalidCheckpoint);
        }
        Ok(Self {
            id: checkpoint.document_id,
            inner,
        })
    }

    #[must_use]
    pub const fn id(&self) -> DocumentId {
        self.id
    }

    pub fn markdown(&self) -> Result<String, ProtocolError> {
        let (_, text) = self.markdown_object()?;
        self.inner.text(&text).map_err(automerge_error)
    }

    pub fn replace_markdown(&mut self, markdown: &str) -> Result<(), ProtocolError> {
        let (length, text) = self.markdown_object()?;
        self.inner
            .splice_text(&text, 0, length as isize, markdown)
            .map_err(automerge_error)?;
        self.inner.commit();
        Ok(())
    }

    pub fn splice_markdown(
        &mut self,
        position: usize,
        delete: isize,
        value: &str,
    ) -> Result<(), ProtocolError> {
        let (length, text) = self.markdown_object()?;
        if position > length || delete < 0 || position.saturating_add(delete as usize) > length {
            return Err(ProtocolError::InvalidIdentifier(
                "markdown splice range".to_owned(),
            ));
        }
        self.inner
            .splice_text(&text, position, delete, value)
            .map_err(automerge_error)?;
        self.inner.commit();
        Ok(())
    }

    pub fn merge(&mut self, other: &mut Self) -> Result<(), ProtocolError> {
        if self.id != other.id {
            return Err(ProtocolError::InvalidIdentifier(
                "cannot merge different documents".to_owned(),
            ));
        }
        self.inner
            .merge(&mut other.inner)
            .map_err(automerge_error)?;
        Ok(())
    }

    /// Generate the next Automerge protocol message for a reliable, ordered stream.
    pub fn next_sync_message(&mut self, peer: &mut PeerSyncState) -> Option<Vec<u8>> {
        self.inner
            .sync()
            .generate_sync_message(&mut peer.inner)
            .map(|message| message.encode())
    }

    pub fn receive_sync_message(
        &mut self,
        peer: &mut PeerSyncState,
        bytes: &[u8],
    ) -> Result<(), ProtocolError> {
        let message = sync::Message::decode(bytes)
            .map_err(|error| ProtocolError::Encoding(error.to_string()))?;
        self.inner
            .sync()
            .receive_sync_message(&mut peer.inner, message)
            .map_err(automerge_error)
    }

    pub fn checkpoint(
        &mut self,
        epoch: Epoch,
        generation: u64,
        created_at_ms: u64,
    ) -> Result<Checkpoint, ProtocolError> {
        let heads = self
            .inner
            .get_heads()
            .into_iter()
            .map(|head| head.to_string())
            .collect();
        let bytes = self.inner.save_and_verify().map_err(automerge_error)?;
        Ok(Checkpoint::new(
            ProtocolVersion::V1,
            self.id,
            epoch,
            generation,
            created_at_ms,
            heads,
            bytes,
        ))
    }

    fn markdown_object(&self) -> Result<(usize, automerge::ObjId), ProtocolError> {
        match self
            .inner
            .get(ROOT, MARKDOWN_KEY)
            .map_err(automerge_error)?
        {
            Some((Value::Object(ObjType::Text), object)) => {
                let length = self.inner.length(&object);
                Ok((length, object))
            }
            _ => Err(ProtocolError::InvalidCheckpoint),
        }
    }
}

fn automerge_error(error: automerge::AutomergeError) -> ProtocolError {
    ProtocolError::Automerge(error.to_string())
}
