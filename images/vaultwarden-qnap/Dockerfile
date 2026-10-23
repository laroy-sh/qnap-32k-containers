# Vaultwarden for QNAP 32-bit ARM NAS with 32K-page kernel (TS-x31P3 family).
# No official variant can run there: the debian image's bookworm userland fails
# ELF page alignment, current release binaries require glibc 2.39 (jammy tops out
# at 2.35, so no rebase is possible), and the alpine static build is 4K-aligned
# (exit 139). Fix: cross-compile from source against jammy's armhf toolchain
# (glibc 2.35 sysroot) with -Wl,-z,max-page-size=32768, vendored OpenSSL and
# bundled SQLite statically linked into the binary. mimalloc stays disabled
# (allocator page-size assumptions). The build stage runs on the build host's
# native arch — no QEMU compile.
#
# Bump: update VW_VERSION + the web-vault tag pinned in upstream's
# docker/Dockerfile.debian for that release.

ARG VW_VERSION=1.36.0

FROM --platform=linux/amd64 docker.io/vaultwarden/web-vault:v2026.4.1 AS web_vault

FROM --platform=$BUILDPLATFORM ubuntu:26.04 AS build
ARG VW_VERSION
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates curl git build-essential gcc-arm-linux-gnueabihf libc6-dev-armhf-cross perl pkg-config \
    && rm -rf /var/lib/apt/lists/*
RUN curl -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain none
ENV PATH=/root/.cargo/bin:$PATH
RUN git clone --depth 1 --branch ${VW_VERSION} https://github.com/dani-garcia/vaultwarden /src
WORKDIR /src
# rustup auto-installs the release's pinned toolchain (rust-toolchain.toml)
RUN rustup target add armv7-unknown-linux-gnueabihf
ENV CARGO_TARGET_ARMV7_UNKNOWN_LINUX_GNUEABIHF_LINKER=arm-linux-gnueabihf-gcc \
    CC_armv7_unknown_linux_gnueabihf=arm-linux-gnueabihf-gcc \
    AR_armv7_unknown_linux_gnueabihf=arm-linux-gnueabihf-ar \
    RUSTFLAGS="-C link-arg=-Wl,-z,max-page-size=32768"
RUN cargo build --release --target armv7-unknown-linux-gnueabihf --features sqlite,vendored_openssl

FROM ubuntu:26.04
LABEL org.opencontainers.image.source="https://github.com/laroy-sh/qnap-32k-containers"
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates curl openssl \
    && rm -rf /var/lib/apt/lists/*
ENV ROCKET_ADDRESS=0.0.0.0 ROCKET_PORT=80 DATA_FOLDER=/data WEB_VAULT_FOLDER=/web-vault
COPY --from=web_vault /web-vault /web-vault
COPY --from=build /src/target/armv7-unknown-linux-gnueabihf/release/vaultwarden /vaultwarden
VOLUME /data
EXPOSE 80 443
HEALTHCHECK --interval=1m --timeout=10s \
    CMD curl -ksf https://localhost:${ROCKET_PORT}/alive || curl -sf http://localhost:${ROCKET_PORT}/alive || exit 1
ENTRYPOINT ["/vaultwarden"]
