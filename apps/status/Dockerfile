FROM oven/bun:1.3.14-alpine AS builder
WORKDIR /app
ARG ATELIER_STATUS_ORIGIN=http://localhost:4323
ARG ATELIER_MARKETING_ORIGIN=http://localhost:4321
ARG ATELIER_DOCS_ORIGIN=http://localhost:4322
ENV ATELIER_STATUS_ORIGIN=$ATELIER_STATUS_ORIGIN
ENV ATELIER_MARKETING_ORIGIN=$ATELIER_MARKETING_ORIGIN
ENV ATELIER_DOCS_ORIGIN=$ATELIER_DOCS_ORIGIN
COPY . .
RUN bun install --frozen-lockfile
RUN bunx turbo run build --filter=@stygian/atelier-status

FROM oven/bun:1.3.14-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=4323
ENV STATIC_ROOT=/app/dist
COPY --from=builder /app/apps/status/dist /app/dist
COPY infra/static-server/server.ts /app/server.ts
EXPOSE 4323
CMD ["bun", "run", "/app/server.ts"]
