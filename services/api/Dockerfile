FROM swift:6.0-jammy AS build
WORKDIR /workspace
COPY packages/swift packages/swift
COPY services/api services/api
RUN swift build --package-path services/api -c release --product atelier-api

FROM ubuntu:jammy
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates libatomic1 libcurl4 libxml2 tzdata && rm -rf /var/lib/apt/lists/*
COPY --from=build /workspace/services/api/.build/release/atelier-api /usr/local/bin/atelier-api
ENV PORT=8080
EXPOSE 8080
CMD ["atelier-api"]
