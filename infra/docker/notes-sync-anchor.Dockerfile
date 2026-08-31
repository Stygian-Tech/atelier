FROM rust:1.91-bookworm AS builder
WORKDIR /workspace

COPY packages/rust packages/rust
COPY services/notes-sync-anchor services/notes-sync-anchor
RUN cargo build \
  --manifest-path services/notes-sync-anchor/Cargo.toml \
  --locked \
  --release \
  --package notes-sync-anchor

FROM debian:bookworm-slim AS runtime
RUN apt-get update \
  && apt-get install --yes --no-install-recommends ca-certificates \
  && rm -rf /var/lib/apt/lists/*
COPY --from=builder /workspace/services/notes-sync-anchor/target/release/notes-sync-anchor /usr/local/bin/notes-sync-anchor
USER 65532:65532
ENV PORT=8080
EXPOSE 8080
ENTRYPOINT ["notes-sync-anchor"]
