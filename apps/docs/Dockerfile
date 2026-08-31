FROM oven/bun:1.3.14-alpine AS builder
WORKDIR /app
ARG ATELIER_ENV=deployment-unconfigured
ARG ATELIER_DOCS_ORIGIN
ENV ATELIER_ENV=$ATELIER_ENV
ENV ATELIER_DOCS_ORIGIN=$ATELIER_DOCS_ORIGIN
COPY . .
RUN bun install --frozen-lockfile
RUN bunx turbo run build --filter=@stygian/atelier-docs
RUN bun run infra/web/release-artifacts.ts --root apps/docs/dist

FROM oven/bun:1.3.14-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=4322
ENV STATIC_ROOT=/app/dist
COPY --from=builder /app/apps/docs/dist /app/dist
COPY infra/static-server/server.ts /app/server.ts
EXPOSE 4322
CMD ["bun", "run", "/app/server.ts"]
