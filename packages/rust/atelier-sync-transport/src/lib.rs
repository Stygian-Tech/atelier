//! Ordered transport boundary for Atelier Notes sync.
//!
//! The default build has a deterministic in-memory transport for protocol and
//! binding tests. The optional `iroh-endpoint` feature enables an endpoint and
//! stream adapter using Iroh's managed relays; Atelier does not run a relay.

use async_trait::async_trait;
use atelier_sync_protocol::{Envelope, ProtocolError, ProtocolVersion};
use thiserror::Error;
use tokio::sync::mpsc;

const MEMORY_CHANNEL_CAPACITY: usize = 64;

#[derive(Debug, Error)]
pub enum TransportError {
    #[error("transport is closed")]
    Closed,
    #[error("frame exceeds the configured maximum")]
    FrameTooLarge,
    #[error("transport failure: {0}")]
    Transport(String),
    #[error(transparent)]
    Protocol(#[from] ProtocolError),
}

#[async_trait]
pub trait OrderedSession: Send {
    fn version(&self) -> ProtocolVersion;
    async fn send(&mut self, envelope: &Envelope) -> Result<(), TransportError>;
    async fn receive(&mut self) -> Result<Envelope, TransportError>;
}

/// A paired, reliable ordered session used by protocol tests and native FFI
/// conformance harnesses. It is not a production network fallback.
pub struct MemorySession {
    sender: mpsc::Sender<Vec<u8>>,
    receiver: mpsc::Receiver<Vec<u8>>,
}

impl MemorySession {
    #[must_use]
    pub fn pair() -> (Self, Self) {
        let (left_to_right_tx, left_to_right_rx) = mpsc::channel(MEMORY_CHANNEL_CAPACITY);
        let (right_to_left_tx, right_to_left_rx) = mpsc::channel(MEMORY_CHANNEL_CAPACITY);
        (
            Self {
                sender: left_to_right_tx,
                receiver: right_to_left_rx,
            },
            Self {
                sender: right_to_left_tx,
                receiver: left_to_right_rx,
            },
        )
    }
}

#[async_trait]
impl OrderedSession for MemorySession {
    fn version(&self) -> ProtocolVersion {
        ProtocolVersion::V1
    }

    async fn send(&mut self, envelope: &Envelope) -> Result<(), TransportError> {
        self.sender
            .send(envelope.encode()?)
            .await
            .map_err(|_| TransportError::Closed)
    }

    async fn receive(&mut self) -> Result<Envelope, TransportError> {
        let bytes = self.receiver.recv().await.ok_or(TransportError::Closed)?;
        Envelope::decode(&bytes).map_err(TransportError::from)
    }
}

#[cfg(feature = "iroh-endpoint")]
pub mod iroh_endpoint {
    use super::{OrderedSession, TransportError};
    use async_trait::async_trait;
    use atelier_sync_protocol::{Envelope, ProtocolVersion, ALPN_V1};
    use iroh::{
        endpoint::{presets, RecvStream, SendStream},
        Endpoint, EndpointAddr,
    };

    pub const DEFAULT_MAX_FRAME_BYTES: usize = 8 * 1024 * 1024;

    /// Iroh endpoint configured only for Atelier's versioned ALPN. Relay
    /// selection remains Iroh-managed; this adapter does not provide a relay.
    #[derive(Debug)]
    pub struct IrohTransport {
        endpoint: Endpoint,
        max_frame_bytes: usize,
    }

    impl IrohTransport {
        pub async fn bind() -> Result<Self, TransportError> {
            let endpoint = Endpoint::builder(presets::N0)
                .alpns(vec![ALPN_V1.to_vec()])
                .bind()
                .await
                .map_err(|error| TransportError::Transport(error.to_string()))?;
            Ok(Self {
                endpoint,
                max_frame_bytes: DEFAULT_MAX_FRAME_BYTES,
            })
        }

        #[must_use]
        pub fn endpoint(&self) -> &Endpoint {
            &self.endpoint
        }

        pub async fn connect(&self, address: EndpointAddr) -> Result<IrohSession, TransportError> {
            let connection = self
                .endpoint
                .connect(address, ALPN_V1)
                .await
                .map_err(|error| TransportError::Transport(error.to_string()))?;
            let (send, receive) = connection
                .open_bi()
                .await
                .map_err(|error| TransportError::Transport(error.to_string()))?;
            Ok(IrohSession::new(send, receive, self.max_frame_bytes))
        }

        pub async fn accept(&self) -> Result<IrohSession, TransportError> {
            let incoming = self.endpoint.accept().await.ok_or(TransportError::Closed)?;
            let connection = incoming
                .await
                .map_err(|error| TransportError::Transport(error.to_string()))?;
            let (send, receive) = connection
                .accept_bi()
                .await
                .map_err(|error| TransportError::Transport(error.to_string()))?;
            Ok(IrohSession::new(send, receive, self.max_frame_bytes))
        }

        pub async fn close(self) {
            self.endpoint.close().await;
        }
    }

    #[derive(Debug)]
    pub struct IrohSession {
        send: SendStream,
        receive: RecvStream,
        max_frame_bytes: usize,
    }

    impl IrohSession {
        fn new(send: SendStream, receive: RecvStream, max_frame_bytes: usize) -> Self {
            Self {
                send,
                receive,
                max_frame_bytes,
            }
        }
    }

    #[async_trait]
    impl OrderedSession for IrohSession {
        fn version(&self) -> ProtocolVersion {
            ProtocolVersion::V1
        }

        async fn send(&mut self, envelope: &Envelope) -> Result<(), TransportError> {
            let frame = envelope.encode()?;
            let length = u32::try_from(frame.len()).map_err(|_| TransportError::FrameTooLarge)?;
            if frame.len() > self.max_frame_bytes {
                return Err(TransportError::FrameTooLarge);
            }
            self.send
                .write_all(&length.to_be_bytes())
                .await
                .map_err(|error| TransportError::Transport(error.to_string()))?;
            self.send
                .write_all(&frame)
                .await
                .map_err(|error| TransportError::Transport(error.to_string()))
        }

        async fn receive(&mut self) -> Result<Envelope, TransportError> {
            let mut length = [0_u8; 4];
            self.receive
                .read_exact(&mut length)
                .await
                .map_err(|error| TransportError::Transport(error.to_string()))?;
            let length = u32::from_be_bytes(length) as usize;
            if length > self.max_frame_bytes {
                return Err(TransportError::FrameTooLarge);
            }
            let mut frame = vec![0_u8; length];
            self.receive
                .read_exact(&mut frame)
                .await
                .map_err(|error| TransportError::Transport(error.to_string()))?;
            Envelope::decode(&frame).map_err(TransportError::from)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use atelier_sync_protocol::{DeviceId, Did, DocumentId, Epoch, MessageId, Payload};

    #[tokio::test]
    async fn memory_transport_round_trips_the_wire_envelope() -> Result<(), TransportError> {
        let (mut sender, mut receiver) = MemorySession::pair();
        let envelope = Envelope {
            version: ProtocolVersion::V1,
            message_id: MessageId::new(),
            document_id: DocumentId::new(),
            sender: Did::parse("did:plc:alice")?,
            device_id: DeviceId::parse("macbook")?,
            epoch: Epoch::new(1),
            sequence: 1,
            sent_at_ms: 100,
            payload: Payload::Sync {
                message: vec![1, 2, 3],
            },
        };

        sender.send(&envelope).await?;
        assert_eq!(receiver.receive().await?, envelope);
        Ok(())
    }
}
