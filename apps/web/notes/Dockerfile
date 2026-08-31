FROM oven/bun:1.3.14-alpine AS builder
WORKDIR /app
ARG ATELIER_ENV=deployment-unconfigured
ARG NEXT_PUBLIC_HOME_URL
ARG NEXT_PUBLIC_NOTES_URL
ARG NEXT_PUBLIC_MAIL_URL
ARG NEXT_PUBLIC_CALENDAR_URL
ARG NEXT_PUBLIC_TASKS_URL
ENV ATELIER_ENV=$ATELIER_ENV
ENV NEXT_PUBLIC_HOME_URL=$NEXT_PUBLIC_HOME_URL
ENV NEXT_PUBLIC_NOTES_URL=$NEXT_PUBLIC_NOTES_URL
ENV NEXT_PUBLIC_MAIL_URL=$NEXT_PUBLIC_MAIL_URL
ENV NEXT_PUBLIC_CALENDAR_URL=$NEXT_PUBLIC_CALENDAR_URL
ENV NEXT_PUBLIC_TASKS_URL=$NEXT_PUBLIC_TASKS_URL
COPY . .
RUN bun install --frozen-lockfile
ENV NEXT_TELEMETRY_DISABLED=1
RUN bunx turbo run build --filter=@stygian/atelier-notes-web
RUN bun run infra/web/release-artifacts.ts --root apps/web/notes/.next/server/app --root apps/web/notes/.next/static

FROM oven/bun:1.3.14-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV HOSTNAME=0.0.0.0
COPY --from=builder /app ./
EXPOSE 3000
CMD ["bun", "run", "--cwd", "apps/web/notes", "start"]
