# Stage 1: Build SvelteKit (Node bundle via adapter-node)
FROM node:20-slim AS web-builder

WORKDIR /app/web

COPY web/package.json web/package-lock.json ./
RUN npm ci

COPY web/ ./
RUN npm run build && npm prune --omit=dev

# Stage 2: Download PocketBase binary in isolation
FROM alpine:3.19 AS pb-fetcher

ARG PB_VERSION=0.36.3
ARG TARGETARCH

RUN apk add --no-cache ca-certificates unzip wget \
	&& wget -q "https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_${TARGETARCH}.zip" -O /tmp/pb.zip \
	&& unzip /tmp/pb.zip -d /usr/local/bin/ \
	&& rm /tmp/pb.zip \
	&& chmod +x /usr/local/bin/pocketbase

# Stage 3: Final runtime image
FROM alpine:3.19

RUN apk add --no-cache ca-certificates nodejs caddy tini

COPY --from=pb-fetcher /usr/local/bin/pocketbase /usr/local/bin/pocketbase

COPY --from=web-builder /app/web/build /app/web/build
COPY --from=web-builder /app/web/package.json /app/web/package.json
COPY --from=web-builder /app/web/node_modules /app/web/node_modules

COPY backend/pb_migrations /pb/pb_migrations
COPY backend/pb_hooks /pb/pb_hooks
COPY backend/Caddyfile /etc/caddy/Caddyfile
COPY backend/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 8090

ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/entrypoint.sh"]
