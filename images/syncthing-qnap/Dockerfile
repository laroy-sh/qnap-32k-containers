# Syncthing for QNAP 32-bit ARM NAS with 32K-page kernel (TS-x31P3 family).
# Official image is Alpine >=3.18 whose userland segfaults on 32K pages;
# the static Go syncthing binary itself is fine. Rebase onto Ubuntu 22.04.
# Rebuild for a new release: docker --context qnap build --pull ...

FROM syncthing/syncthing:latest AS official

FROM ubuntu:22.04

LABEL org.opencontainers.image.source="https://github.com/laroy-sh/qnap-32k-containers"

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates curl libcap2-bin tzdata \
    && rm -rf /var/lib/apt/lists/*

COPY --from=official /bin/syncthing /bin/syncthing
COPY entrypoint.sh /bin/entrypoint.sh
RUN chmod 755 /bin/entrypoint.sh && mkdir -p /var/syncthing

ENV PUID=1000 PGID=1000 HOME=/var/syncthing \
    STGUIADDRESS=0.0.0.0:8384 STHOMEDIR=/var/syncthing/config

HEALTHCHECK --interval=1m --timeout=10s \
    CMD curl -fkLsS -m 2 127.0.0.1:8384/rest/noauth/health | grep -o OK || exit 1

EXPOSE 8384 22000/tcp 22000/udp 21027/udp
VOLUME ["/var/syncthing"]

ENTRYPOINT ["/bin/entrypoint.sh", "/bin/syncthing"]
