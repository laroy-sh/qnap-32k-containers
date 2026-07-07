# ladder (everywall/ladder) for QNAP 32-bit ARM NAS with 32K-page kernels.
#
# Upstream ghcr.io/everywall/ladder publishes only amd64/arm64 — no linux/arm/v7
# at all — so unlike the other images here there is nothing to rebase. Instead,
# the static Go binary is cross-compiled from source (page-size-agnostic) and
# shipped on ubuntu:22.04 with CA certificates for outbound HTTPS.
#
# Build (from any machine, no QEMU needed — the Go stage runs natively):
#   docker buildx build --platform linux/arm/v7 -t ladder-qnap images/ladder-qnap/
# Pin a release with: --build-arg LADDER_REF=<tag-or-branch>

ARG LADDER_REF=main

FROM --platform=$BUILDPLATFORM golang:1.26 AS build
ARG LADDER_REF
RUN git clone --depth 1 --branch ${LADDER_REF} https://github.com/everywall/ladder /src
WORKDIR /src
RUN CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=7 \
    go build -ldflags="-s -w -X ladder/handlers.version=$(git rev-parse --short HEAD)" \
    -o ladder cmd/main.go

FROM ubuntu:22.04
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /src/ladder /app/ladder
COPY --from=build /src/rulesets /app/rulesets
ENV PORT=8080 RULESET=/app/rulesets
EXPOSE 8080
ENTRYPOINT ["/app/ladder"]
