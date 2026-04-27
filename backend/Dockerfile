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
# Update both ARGs together when bumping PB_VERSION.
ARG PB_SHA256_AMD64=4582b94d7751e8dfe1e140e318bdc845b53bb85468fcf335f4501033825bfb66
ARG PB_SHA256_ARM64=df1af351322fed04de54730db56de2c5800869a49f467f545abee75deec1676d

RUN apk add --no-cache ca-certificates unzip wget \
	&& wget -q "https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_${TARGETARCH}.zip" -O /tmp/pocketbase.zip \
	&& sh -c 'case "$TARGETARCH" in \
		amd64) echo "${PB_SHA256_AMD64}  /tmp/pocketbase.zip" | sha256sum -c - ;; \
		arm64) echo "${PB_SHA256_ARM64}  /tmp/pocketbase.zip" | sha256sum -c - ;; \
		*) echo "Unsupported arch: $TARGETARCH" && exit 1 ;; \
	esac' \
	&& unzip /tmp/pocketbase.zip -d /usr/local/bin/ \
	&& rm /tmp/pocketbase.zip \
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
