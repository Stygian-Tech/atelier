FROM swift:6.2-jammy AS build
WORKDIR /workspace
COPY packages/swift packages/swift
COPY services/mcp-backplane services/mcp-backplane
RUN swift build --package-path services/mcp-backplane -c release --product atelier-mcp-backplane

FROM ubuntu:jammy
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates libatomic1 libcurl4 libxml2 tzdata && rm -rf /var/lib/apt/lists/*
COPY --from=build /workspace/services/mcp-backplane/.build/release/atelier-mcp-backplane /usr/local/bin/atelier-mcp-backplane
ENV PORT=8080
EXPOSE 8080
CMD ["atelier-mcp-backplane"]
