# Stage 1: Build Elm frontend
FROM node:20-alpine AS frontend-builder

WORKDIR /app

# Install elm-land
RUN npm install -g elm-land@0.20.1

# Copy frontend source
COPY frontend/ ./frontend/

# Build
WORKDIR /app/frontend
RUN elm-land build

# Stage 2: PocketBase
FROM alpine:3.19

ARG PB_VERSION=0.36.3
ARG TARGETARCH

RUN apk add --no-cache ca-certificates unzip wget

# Download PocketBase
RUN wget -q "https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_${TARGETARCH}.zip" -O /tmp/pb.zip \
    && unzip /tmp/pb.zip -d /pb/ \
    && rm /tmp/pb.zip \
    && chmod +x /pb/pocketbase

# Copy frontend build output into PocketBase public dir
COPY --from=frontend-builder /app/frontend/dist /pb/pb_public

# Copy migrations and hooks
COPY backend/pb_migrations /pb/pb_migrations
COPY backend/pb_hooks /pb/pb_hooks

EXPOSE 8090

CMD ["/pb/pocketbase", "serve", "--http=0.0.0.0:8090", "--dir=/pb/pb_data", "--migrationsDir=/pb/pb_migrations", "--hooksDir=/pb/pb_hooks", "--publicDir=/pb/pb_public"]
