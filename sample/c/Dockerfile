# syntax=docker/dockerfile:1

# --- Base builder: Ubuntu + cmake + vcpkg ---
FROM ubuntu:22.04 AS base

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake ninja-build git curl zip unzip tar pkg-config \
    ca-certificates python3 autoconf automake libtool \
    && rm -rf /var/lib/apt/lists/*

# Pin vcpkg to the SDK's builtin-baseline era (2026.02.27) for cmake compat
RUN git clone https://github.com/microsoft/vcpkg /opt/vcpkg && \
    cd /opt/vcpkg && git checkout 62159a45e18f3a9ac0548628dcaf74fcb60c6ff9 && \
    ./bootstrap-vcpkg.sh -disableMetrics

ENV VCPKG_ROOT=/opt/vcpkg

# Static triplet so final binaries are self-contained
RUN printf 'set(VCPKG_TARGET_ARCHITECTURE x64)\nset(VCPKG_CRT_LINKAGE dynamic)\nset(VCPKG_LIBRARY_LINKAGE static)\nset(VCPKG_CMAKE_SYSTEM_NAME Linux)\n' \
    > /opt/vcpkg/triplets/community/x64-linux-static.cmake

# --- Stock builder: upstream openziti/ziti-sdk-c ---
FROM base AS stock-builder

RUN git clone --depth 1 --branch 1.14.3 \
      https://github.com/openziti/ziti-sdk-c /src/sdk

WORKDIR /src/sdk
COPY client/main.c harness_client.c
COPY host/main.c harness_host.c

RUN cat >> CMakeLists.txt <<'HARNESS'

add_executable(harness-client harness_client.c)
target_link_libraries(harness-client PUBLIC ziti)
add_executable(harness-host harness_host.c)
target_link_libraries(harness-host PUBLIC ziti)
HARNESS

RUN cmake -B build -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_TOOLCHAIN_FILE=$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake \
      -DVCPKG_TARGET_TRIPLET=x64-linux-static

RUN cmake --build build --target harness-client harness-host

RUN mkdir -p /out && \
    cp build/harness-client /out/stock-client && \
    cp build/harness-host /out/stock-host

# --- Hook builder: vertec-io/ziti-sdk-c fork ---
FROM base AS hook-builder

ARG ZITI_SDK_C_SHA
RUN test -n "$ZITI_SDK_C_SHA" || { echo "ERROR: ZITI_SDK_C_SHA build arg is required"; exit 1; }

# Shallow-clone + .git-strip
RUN git clone --depth 1 --branch feature/crypto-extensibility \
      https://github.com/vertec-io/ziti-sdk-c /src/sdk && \
    cd /src/sdk && \
    git fetch --depth 1 origin "$ZITI_SDK_C_SHA" && \
    git checkout "$ZITI_SDK_C_SHA" && \
    VER=$(git describe --always --match '[0-9].*' 2>/dev/null || echo '0.0.0') && \
    BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'detached') && \
    HASH=$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown') && \
    printf '%s\nref: %s\nhash: %s\n' "$VER" "$BRANCH" "$HASH" > version.txt && \
    rm -rf .git

WORKDIR /src/sdk
COPY client/main.c harness_client.c
COPY host/main.c harness_host.c

RUN cat >> CMakeLists.txt <<'HARNESS'

add_executable(harness-client harness_client.c)
target_link_libraries(harness-client PUBLIC ziti)
add_executable(harness-host harness_host.c)
target_link_libraries(harness-host PUBLIC ziti)
HARNESS

RUN cmake -B build -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_TOOLCHAIN_FILE=$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake \
      -DVCPKG_TARGET_TRIPLET=x64-linux-static \
      -DZITI_CRYPTO_BACKEND=openssl

RUN cmake --build build --target harness-client harness-host

RUN mkdir -p /out && \
    cp build/harness-client /out/hook-client && \
    cp build/harness-host /out/hook-host

# --- Final image ---
FROM debian:bookworm-slim

COPY --from=stock-builder /out/stock-client /usr/local/bin/stock-client
COPY --from=stock-builder /out/stock-host /usr/local/bin/stock-host
COPY --from=hook-builder /out/hook-client /usr/local/bin/hook-client
COPY --from=hook-builder /out/hook-host /usr/local/bin/hook-host

LABEL org.opencontainers.image.title="openziti-c-sdk-samples"
LABEL org.opencontainers.image.source="https://github.com/vertec-io/openziti-crypto-plugins-demo"
