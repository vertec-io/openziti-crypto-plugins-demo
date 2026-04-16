# syntax=docker/dockerfile:1

# --- Stock builder: upstream openziti/sdk-golang ---
FROM golang:1.26 AS stock-builder

WORKDIR /build
COPY client/ client/
COPY host/ host/

RUN go mod init sample-go && \
    go mod edit -go=1.25 -require=github.com/openziti/sdk-golang@v1.6.0 && \
    go mod tidy

RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go build -trimpath -ldflags='-s -w -buildid=' -o /out/stock-client ./client/

RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go build -trimpath -ldflags='-s -w -buildid=' -o /out/stock-host ./host/

# --- Hook builder: vertec-io/sdk-golang fork ---
FROM golang:1.26 AS hook-builder

ARG SDK_GOLANG_SHA
RUN test -n "$SDK_GOLANG_SHA" || { echo "ERROR: SDK_GOLANG_SHA build arg is required"; exit 1; }

# Shallow-clone + .git-strip
RUN git clone --depth 1 --branch feature/crypto-extensibility \
      https://github.com/vertec-io/sdk-golang /src/sdk-golang && \
    cd /src/sdk-golang && \
    git fetch --depth 1 origin "$SDK_GOLANG_SHA" && \
    git checkout "$SDK_GOLANG_SHA" && \
    rm -rf .git

WORKDIR /build
COPY client/ client/
COPY host/ host/
COPY --from=plugin / plugin/

ENV GONOSUMCHECK=github.com/vertec-io/*
ENV GONOSUMDB=github.com/vertec-io/*
ENV GOPRIVATE=github.com/vertec-io/*

RUN go mod init sample-go && \
    go mod edit -go=1.25 \
      -require=github.com/openziti/sdk-golang@v1.6.0 \
      -replace=github.com/openziti/sdk-golang=/src/sdk-golang \
      -replace=github.com/openziti/secretstream=github.com/vertec-io/secretstream@v0.1.50-ext.0 && \
    go mod tidy

RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go build -tags hook -trimpath -ldflags='-s -w -buildid=' -o /out/hook-client ./client/

RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go build -tags hook -trimpath -ldflags='-s -w -buildid=' -o /out/hook-host ./host/

# --- Final image ---
FROM debian:bookworm-slim

COPY --from=stock-builder /out/stock-client /usr/local/bin/stock-client
COPY --from=stock-builder /out/stock-host /usr/local/bin/stock-host
COPY --from=hook-builder /out/hook-client /usr/local/bin/hook-client
COPY --from=hook-builder /out/hook-host /usr/local/bin/hook-host

LABEL org.opencontainers.image.title="openziti-go-sdk-samples"
LABEL org.opencontainers.image.source="https://github.com/vertec-io/openziti-crypto-plugins-demo"
