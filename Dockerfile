FROM golang:1.26-alpine AS build

RUN apk add --no-cache alpine-sdk

WORKDIR /app

# Pinned to v1.3.1 (9c39e2f69f52) - fork from rw-r-r-0644/CookieFarm
COPY cookiefarm/ /app/

ARG VERSION=dev

# Build server binary
RUN GOOS="linux" GOARCH="amd64" \
  go build -trimpath \
  -ldflags="-s -w -X 'main.Version=${VERSION}'" \
  -o ./bin/cks ./server/main.go

# Build protocol plugins
RUN for file in $(find ./pkg/protocols -name '*.go' ! -name 'protocols.go'); do \
  if grep -q '^package main' "$file"; then \
   filename=$(basename "$file"); \
   pluginname="${filename%.go}"; \
   GOOS="linux" GOARCH="amd64" \
     go build -trimpath \
         -ldflags="-s -w -X 'main.Version=${VERSION}'" \
         -buildmode=plugin -o "./pkg/protocols/$pluginname.so" "$file"; \
  else \
   echo "Skipping $file: not a main package"; \
  fi; \
done

FROM oven/bun:1.3.0-alpine AS frontend

WORKDIR /app/server/frontend

COPY cookiefarm/server/frontend/ /app/server/frontend/

RUN bun install --frozen-lockfile --ignore-scripts
RUN bun run build

FROM python:3.14-alpine AS adapter

WORKDIR /adapter

COPY cookiefarm-adapter/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY cookiefarm-adapter/generate_config.py .

FROM alpine:3.23 AS prod

WORKDIR /app

RUN apk add --no-cache libc6-compat python3 py3-pip; \
    addgroup -S appuser && \
    adduser -S appuser -G appuser

RUN pip install --no-cache-dir --break-system-packages pyyaml

COPY --from=build /app/bin/cks /app/bin/cks
COPY --from=build /app/server/public /app/server/public
COPY --from=build /app/pkg/protocols /app/pkg/protocols
COPY --from=frontend /app/server/frontend/dist /app/server/frontend/dist
COPY --from=adapter /adapter/generate_config.py /app/generate_config.py
COPY cookiefarm/run.sh /app/run.sh

RUN touch /app/cookiefarm.db && \
    chmod +x /app/run.sh /app/generate_config.py && \
    chown -R appuser:appuser /app

USER appuser

ENTRYPOINT ["/bin/sh", "/app/run.sh"]
