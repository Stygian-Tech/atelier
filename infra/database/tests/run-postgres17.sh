#!/usr/bin/env bash
set -euo pipefail

database_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
container_name="atelier-postgres17-test-${RANDOM}-$$"
database_name="atelier_isolation_test"
database_user="postgres"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required to run the PostgreSQL 17 isolation tests." >&2
  exit 1
fi

cleanup() {
  docker rm --force "${container_name}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker run \
  --detach \
  --rm \
  --name "${container_name}" \
  --env POSTGRES_DB="${database_name}" \
  --env POSTGRES_PASSWORD="atelier-test-only" \
  postgres:17-alpine >/dev/null

ready=0
for _ in $(seq 1 60); do
  # pg_isready reports that the server accepts connections even while the
  # requested database is still being created by the image entrypoint. Probe
  # the exact database so migrations cannot race initialization.
  if docker exec "${container_name}" \
    psql --username "${database_user}" --dbname "${database_name}" --no-psqlrc \
      --tuples-only --no-align --command "SELECT 1" >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done

if [[ "${ready}" != "1" ]]; then
  echo "PostgreSQL 17 did not become ready." >&2
  docker logs "${container_name}" >&2
  exit 1
fi

server_major="$(docker exec "${container_name}" psql --username "${database_user}" --dbname "${database_name}" --tuples-only --no-align --command "SHOW server_version_num" | cut -c1-2)"
if [[ "${server_major}" != "17" ]]; then
  echo "Expected PostgreSQL 17, received major version ${server_major}." >&2
  exit 1
fi

for migration in "${database_root}"/migrations/*.sql; do
  echo "Applying $(basename "${migration}")"
  docker exec --interactive "${container_name}" \
    psql --username "${database_user}" --dbname "${database_name}" --set ON_ERROR_STOP=1 \
    < "${migration}"
done

echo "Running tenant isolation fixtures"
docker exec --interactive "${container_name}" \
  psql --username "${database_user}" --dbname "${database_name}" --set ON_ERROR_STOP=1 \
  < "${database_root}/tests/tenant_isolation.sql"
