#!/usr/bin/env sh
# Container entrypoint: optionally wait for PostgreSQL, apply migrations,
# collect static files, then hand off to the CMD (gunicorn).
set -e

# Only wait for Postgres when we are actually configured to use it. In the
# default SQLite mode (USE_SQLITE=1) there is nothing to wait for, so the pod
# starts serving immediately.
if [ "${USE_SQLITE:-1}" != "1" ] && [ -n "${POSTGRES_HOST:-}" ]; then
  DB_HOST="${POSTGRES_HOST}"
  DB_PORT="${POSTGRES_PORT:-5432}"
  RETRIES="${DB_WAIT_RETRIES:-30}"

  echo "Waiting for PostgreSQL at ${DB_HOST}:${DB_PORT} (up to ${RETRIES} tries)"
  i=0
  until python -c "import socket, os; socket.create_connection((os.environ['POSTGRES_HOST'], int(os.environ.get('POSTGRES_PORT', '5432'))), timeout=2)" 2>/dev/null; do
    i=$((i + 1))
    if [ "$i" -ge "$RETRIES" ]; then
      echo "PostgreSQL still not reachable after ${RETRIES} tries, continuing anyway"
      break
    fi
    sleep 2
  done
  echo "Continuing startup"
fi

# Migrations and static collection are safe for both SQLite and Postgres.
# They are non-fatal so a transient DB hiccup does not crash-loop the pod;
# the /healthz endpoint stays up regardless.
python manage.py migrate --noinput || echo "migrate failed, continuing"
python manage.py collectstatic --noinput || echo "collectstatic failed, continuing"

exec "$@"
