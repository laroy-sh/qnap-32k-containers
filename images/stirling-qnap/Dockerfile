# Stirling PDF for QNAP 32-bit ARM NAS with 32K-page kernels.
#
# Upstream stirlingtools/stirling-pdf publishes only amd64/arm64 — no linux/arm/v7.
# But the release ships an arch-independent Stirling-PDF-server.jar, so nothing
# needs rebasing: ubuntu:22.04 (survives 32K pages) + jammy's armhf OpenJDK runs it.
#
# Version pin is deliberate: Stirling ≥v2.6 requires Java 25, and jammy's
# openjdk-25 armhf build is Zero VM (interpreter-only — unusably slow on this
# Cortex-A15). openjdk-21/17 armhf are real Server VMs with JIT, so we run the
# last Java-17-target release, v2.5.3 (2026-02-23), on openjdk-21.
#
# Jar choice: the release's Stirling-PDF.jar embeds the React web UI;
# Stirling-PDF-server.jar is API-only (serves just an "API Server" landing page).
#
# Ultra-lite variant: JRE + JAR only. No tesseract/LibreOffice — OCR and Office
# conversions are disabled in the UI. Add them later via apt if missed.
#
# Build natively on the NAS (JAR downloads at build time, ~193 MB — never commit it):
#   docker --context qnap build --pull -t stirling-qnap:2.5.3 images/stirling-qnap/
# Pin a release with: --build-arg STIRLING_VERSION=<tag>

ARG STIRLING_VERSION=v2.5.3

FROM ubuntu:26.04
RUN apt-get update && apt-get install -y --no-install-recommends \
    openjdk-21-jre-headless ca-certificates curl fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/*
ARG STIRLING_VERSION
RUN mkdir -p /app /configs /logs /pipeline && \
    curl -fL -o /app/Stirling-PDF.jar \
    https://github.com/Stirling-Tools/Stirling-PDF/releases/download/${STIRLING_VERSION}/Stirling-PDF.jar
ENV SERVER_PORT=80 SECURITY_ENABLELOGIN=false SYSTEM_DEFAULTLOCALE=en-GB \
    JAVA_OPTS="-Xmx1g"
EXPOSE 80
WORKDIR /app
CMD java $JAVA_OPTS -jar /app/Stirling-PDF.jar
