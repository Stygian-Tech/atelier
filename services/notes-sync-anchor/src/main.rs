use atelier_sync_protocol::{ProtocolVersion, ALPN_V1};
use axum::{extract::State, http::StatusCode, response::IntoResponse, routing::get, Json, Router};
use serde::Serialize;
use std::{env, net::SocketAddr, sync::Arc};
use tower_http::trace::TraceLayer;
use tracing::{info, warn};
use tracing_subscriber::EnvFilter;

const SERVICE: &str = "notes-sync-anchor";

#[derive(Clone, Debug)]
struct RuntimeState {
    ready: bool,
    readiness_requested: bool,
    environment: String,
    persistence_mode: String,
    transport_mode: String,
}

#[derive(Clone, Copy, Debug, Default)]
struct RuntimePrerequisites {
    durable_checkpoint_store: bool,
    admission_verifier: bool,
    iroh_accept_loop: bool,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct StatusBody {
    status: &'static str,
    service: &'static str,
    version: &'static str,
    protocol: &'static str,
    environment: String,
    persistence_mode: String,
    transport_mode: String,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    init_tracing();
    let port = env::var("PORT")
        .unwrap_or_else(|_| "8080".to_owned())
        .parse::<u16>()?;
    let state = Arc::new(RuntimeState::from_env());

    if state.readiness_requested {
        warn!(
            "anchor readiness was requested but remains unavailable until persistence, admission, and the Iroh accept loop are constructed"
        );
    } else {
        warn!(
            "anchor readiness is unavailable; persistence, admission, and the Iroh accept loop are not constructed"
        );
    }
    info!(
        environment = %state.environment,
        persistence_mode = %state.persistence_mode,
        transport_mode = %state.transport_mode,
        "starting Notes sync anchor control plane"
    );

    let app = Router::new()
        .route("/healthz", get(health))
        .route("/readyz", get(ready))
        .route("/version", get(version))
        .layer(TraceLayer::new_for_http())
        .with_state(state);
    let address = SocketAddr::from(([0, 0, 0, 0], port));
    let listener = tokio::net::TcpListener::bind(address).await?;
    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await?;
    Ok(())
}

impl RuntimeState {
    fn from_env() -> Self {
        let readiness_requested = env::var("ATELIER_ANCHOR_READY").as_deref() == Ok("1");
        let prerequisites = RuntimePrerequisites::default();
        Self {
            ready: prerequisites.is_ready(readiness_requested),
            readiness_requested,
            environment: env::var("ATELIER_ENV").unwrap_or_else(|_| "development".to_owned()),
            persistence_mode: env::var("ATELIER_ANCHOR_PERSISTENCE_MODE")
                .unwrap_or_else(|_| "unconfigured".to_owned()),
            transport_mode: env::var("ATELIER_ANCHOR_TRANSPORT_MODE")
                .unwrap_or_else(|_| "interface-only".to_owned()),
        }
    }

    fn status(&self, value: &'static str) -> StatusBody {
        StatusBody {
            status: value,
            service: SERVICE,
            version: env!("CARGO_PKG_VERSION"),
            protocol: std::str::from_utf8(ProtocolVersion::V1.alpn())
                .unwrap_or("diy.atelier.notes.sync/1"),
            environment: self.environment.clone(),
            persistence_mode: self.persistence_mode.clone(),
            transport_mode: self.transport_mode.clone(),
        }
    }
}

impl RuntimePrerequisites {
    const fn is_ready(self, requested: bool) -> bool {
        requested
            && self.durable_checkpoint_store
            && self.admission_verifier
            && self.iroh_accept_loop
    }
}

async fn health(State(state): State<Arc<RuntimeState>>) -> impl IntoResponse {
    (StatusCode::OK, Json(state.status("healthy")))
}

async fn ready(State(state): State<Arc<RuntimeState>>) -> impl IntoResponse {
    if state.ready {
        (StatusCode::OK, Json(state.status("ready")))
    } else {
        (
            StatusCode::SERVICE_UNAVAILABLE,
            Json(state.status("not-ready")),
        )
    }
}

async fn version(State(state): State<Arc<RuntimeState>>) -> impl IntoResponse {
    debug_assert_eq!(ProtocolVersion::V1.alpn(), ALPN_V1);
    (StatusCode::OK, Json(state.status("version")))
}

async fn shutdown_signal() {
    if let Err(error) = tokio::signal::ctrl_c().await {
        warn!(%error, "failed to install shutdown signal handler");
    }
}

fn init_tracing() {
    let filter = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| EnvFilter::new("notes_sync_anchor=info,tower_http=info"));
    tracing_subscriber::fmt()
        .with_env_filter(filter)
        .json()
        .with_current_span(false)
        .with_span_list(false)
        .init();
}

#[cfg(test)]
mod tests {
    use super::RuntimePrerequisites;

    #[test]
    fn readiness_request_cannot_bypass_unavailable_integrations() {
        assert!(!RuntimePrerequisites::default().is_ready(true));
    }

    #[test]
    fn readiness_requires_every_runtime_integration() {
        let incomplete = RuntimePrerequisites {
            durable_checkpoint_store: true,
            admission_verifier: true,
            iroh_accept_loop: false,
        };
        assert!(!incomplete.is_ready(true));

        let complete = RuntimePrerequisites {
            durable_checkpoint_store: true,
            admission_verifier: true,
            iroh_accept_loop: true,
        };
        assert!(!complete.is_ready(false));
        assert!(complete.is_ready(true));
    }
}
