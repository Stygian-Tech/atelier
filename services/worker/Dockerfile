FROM swift:6.2-jammy AS build
WORKDIR /workspace
COPY packages/swift packages/swift
COPY services/worker services/worker
RUN swift build --package-path services/worker -c release --product atelier-worker

FROM ubuntu:jammy
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates libatomic1 libcurl4 libxml2 tzdata && rm -rf /var/lib/apt/lists/*
COPY --from=build /workspace/services/worker/.build/release/atelier-worker /usr/local/bin/atelier-worker
CMD ["atelier-worker"]
