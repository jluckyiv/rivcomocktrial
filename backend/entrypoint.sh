#!/bin/sh
set -e
trap 'kill 0' INT TERM

pocketbase serve \
	--http=127.0.0.1:8091 \
	--dir=/pb/pb_data \
	--migrationsDir=/pb/pb_migrations \
	--hooksDir=/pb/pb_hooks &

HOST=0.0.0.0 \
	PORT=3000 \
	ORIGIN="${ORIGIN:-http://localhost:8090}" \
	PB_INTERNAL_URL="${PB_INTERNAL_URL:-http://localhost:8091}" \
	node /app/web/build &

caddy run --config /etc/caddy/Caddyfile --adapter caddyfile &

wait -n
kill 0
