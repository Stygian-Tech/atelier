FROM oven/bun:1.3.14-alpine AS builder
WORKDIR /app
COPY . .
RUN bun install --frozen-lockfile
ENV NEXT_TELEMETRY_DISABLED=1
RUN bunx turbo run build --filter=@stygian/atelier-mail-web

FROM oven/bun:1.3.14-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV HOSTNAME=0.0.0.0
COPY --from=builder /app ./
EXPOSE 3000
CMD ["bun", "run", "--cwd", "apps/web/mail", "start"]
