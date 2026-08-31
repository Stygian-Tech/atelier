FROM swift:6.0-jammy AS build
WORKDIR /workspace
COPY packages/swift packages/swift
COPY services/worker services/worker
COPY services/mail-sync services/mail-sync
RUN swift build --package-path services/mail-sync -c release --product atelier-mail-sync

FROM ubuntu:jammy
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates libatomic1 libcurl4 libxml2 tzdata && rm -rf /var/lib/apt/lists/*
COPY --from=build /workspace/services/mail-sync/.build/release/atelier-mail-sync /usr/local/bin/atelier-mail-sync
CMD ["atelier-mail-sync"]
