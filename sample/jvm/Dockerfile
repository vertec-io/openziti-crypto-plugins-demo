# syntax=docker/dockerfile:1

# --- Stock builder: upstream org.openziti:ziti from Maven Central ---
FROM gradle:8.14-jdk21-jammy AS stock-builder

COPY src/ /build/src/
COPY build.gradle.kts settings.gradle.kts /build/
WORKDIR /build

RUN --mount=type=cache,target=/home/gradle/.gradle/caches \
    gradle clientJar hostJar -Pvariant=stock -PsdkVersion=0.33.0 \
      --no-daemon --no-build-cache

# --- Hook builder: vertec-io/ziti-sdk-jvm fork ---
FROM gradle:8.14-jdk21-jammy AS hook-builder

ARG ZITI_SDK_JVM_SHA
RUN test -n "$ZITI_SDK_JVM_SHA" || { echo "ERROR: ZITI_SDK_JVM_SHA build arg is required"; exit 1; }

USER root
RUN apt-get update && apt-get install -y --no-install-recommends git && rm -rf /var/lib/apt/lists/*
USER gradle

# Shallow-clone + .git-strip
RUN git clone --depth 1 --branch feature/crypto-extensibility \
      https://github.com/vertec-io/ziti-sdk-jvm /tmp/sdk && \
    cd /tmp/sdk && \
    git fetch --depth 1 origin "$ZITI_SDK_JVM_SHA" && \
    git checkout "$ZITI_SDK_JVM_SHA" && \
    rm -rf .git

RUN --mount=type=cache,target=/home/gradle/.gradle/caches \
    cd /tmp/sdk && gradle :ziti:publishToMavenLocal --no-daemon --no-build-cache

RUN SDK_VER=$(ls /home/gradle/.m2/repository/org/openziti/ziti/ 2>/dev/null | head -1) && \
    echo "Detected SDK version: $SDK_VER" && \
    echo "$SDK_VER" > /tmp/sdk-version.txt

COPY src/ /build/src/
COPY build.gradle.kts settings.gradle.kts /build/
WORKDIR /build

RUN --mount=type=cache,target=/home/gradle/.gradle/caches \
    SDK_VER=$(cat /tmp/sdk-version.txt) && \
    gradle clientJar hostJar -Pvariant=hook -PsdkVersion="$SDK_VER" \
      --no-daemon --no-build-cache

# --- Final image ---
FROM eclipse-temurin:21-jre-jammy

COPY --from=stock-builder /build/build/libs/stock-client.jar /app/stock-client.jar
COPY --from=stock-builder /build/build/libs/stock-host.jar /app/stock-host.jar
COPY --from=hook-builder /build/build/libs/hook-client.jar /app/hook-client.jar
COPY --from=hook-builder /build/build/libs/hook-host.jar /app/hook-host.jar

WORKDIR /app

LABEL org.opencontainers.image.title="openziti-jvm-sdk-samples"
LABEL org.opencontainers.image.source="https://github.com/vertec-io/openziti-crypto-plugins-demo"
