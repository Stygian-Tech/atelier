FROM swift:6.0-jammy AS build
WORKDIR /workspace
COPY packages/swift packages/swift
COPY services/worker services/worker
COPY services/calendar-sync services/calendar-sync
RUN swift build --package-path services/calendar-sync -c release --product atelier-calendar-sync

FROM ubuntu:jammy
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates libatomic1 libcurl4 libxml2 tzdata && rm -rf /var/lib/apt/lists/*
COPY --from=build /workspace/services/calendar-sync/.build/release/atelier-calendar-sync /usr/local/bin/atelier-calendar-sync
CMD ["atelier-calendar-sync"]
