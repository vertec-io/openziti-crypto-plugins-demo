# syntax=docker/dockerfile:1
FROM golang:1.26 AS builder

ARG ZITI_SHA
RUN test -n "$ZITI_SHA" || { echo "ERROR: ZITI_SHA build arg is required"; exit 1; }

RUN git clone --depth 1 --branch feature/crypto-extensibility https://github.com/vertec-io/ziti /src/ziti && \
    cd /src/ziti && \
    git fetch --depth 1 origin "$ZITI_SHA" && \
    git checkout "$ZITI_SHA" && \
    rm -rf .git

WORKDIR /src/ziti

RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go build -trimpath -ldflags='-s -w -buildid=' -o /usr/local/bin/ziti ./ziti/

FROM debian:bookworm-slim AS ziti-controller
COPY --from=builder /usr/local/bin/ziti /usr/local/bin/ziti
LABEL org.opencontainers.image.title="openziti-ziti-controller-from-harness"
LABEL org.opencontainers.image.source="https://github.com/vertec-io/openziti-crypto-plugins-demo"
ENTRYPOINT ["ziti"]

FROM debian:bookworm-slim AS ziti-router
COPY --from=builder /usr/local/bin/ziti /usr/local/bin/ziti
LABEL org.opencontainers.image.title="openziti-ziti-router-from-harness"
LABEL org.opencontainers.image.source="https://github.com/vertec-io/openziti-crypto-plugins-demo"
ENTRYPOINT ["ziti"]
