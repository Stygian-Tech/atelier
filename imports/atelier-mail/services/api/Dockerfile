FROM swift:6.0-jammy AS builder
WORKDIR /app
COPY Package.swift ./
COPY packages/swift packages/swift
COPY services/api services/api
RUN swift build -c release --product AtelierAPI

FROM ubuntu:22.04 AS runner
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl libicu70 libxml2 tzdata \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=builder /app/.build/release/AtelierAPI /app/AtelierAPI
ENV ATELIER_API_HOST=0.0.0.0
ENV ATELIER_API_PORT=8080
EXPOSE 8080
CMD ["/app/AtelierAPI"]
