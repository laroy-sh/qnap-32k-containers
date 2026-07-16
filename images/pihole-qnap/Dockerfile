# Pi-hole v6 for QNAP 32-bit ARM NAS with 32K-page kernel (TS-x31P3 family).
#
# The official image is Alpine >=3.18, whose userland is linked with
# -z max-page-size=4096 and segfaults on QNAP's 32KB-page kernel.
# The official pihole-FTL binary itself is static and 32K-safe (verified on
# a TS-431P3), so we reuse ALL official assets unchanged and only swap the
# userland for Ubuntu 22.04 (verified 32K-safe; supported until 2027).
#
# Rebuild for a new upstream release: docker --context qnap build --pull ...

FROM pihole/pihole:latest AS official

FROM ubuntu:26.04

LABEL org.opencontainers.image.source="https://github.com/laroy-sh/qnap-32k-containers"

ENV DNSMASQ_USER=pihole \
    FTL_CMD=no-daemon

# apt equivalents of upstream's apk list (src/Dockerfile in pi-hole/docker-pi-hole)
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        bash \
        bash-completion \
        binutils \
        ca-certificates \
        cron \
        curl \
        dnsutils \
        git \
        grep \
        iproute2 \
        iputils-ping \
        jq \
        libcap2-bin \
        logrotate \
        procps \
        psmisc \
        sudo \
        tzdata \
        unzip \
        wget \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -g 1000 pihole \
    && useradd -r -u 1000 -g pihole -s /usr/sbin/nologin pihole \
    && mkdir -p /etc/pihole /var/log/pihole /var/lib/logrotate /etc/dnsmasq.d

COPY --from=official /usr/bin/pihole-FTL /usr/bin/pihole-FTL
COPY --from=official /usr/bin/start.sh /usr/bin/start.sh
COPY --from=official /usr/bin/bash_functions.sh /usr/bin/bash_functions.sh
COPY --from=official /var/www/html /var/www/html
COPY --from=official /opt/pihole /opt/pihole
COPY --from=official /usr/local/bin/pihole /usr/local/bin/pihole
COPY --from=official /usr/local/bin/padd /usr/local/bin/padd
COPY --from=official /etc/.pihole /etc/.pihole
COPY --from=official /etc/pihole /etc/pihole
COPY --from=official /crontab.txt /crontab.txt
COPY --from=official /macvendor.db /macvendor.db
COPY --from=official /pihole.docker.tag /pihole.docker.tag

EXPOSE 53 53/udp 67/udp 80 123/udp 443

HEALTHCHECK CMD dig -p $(pihole-FTL --config dns.port) +short +norecurse +retry=0 @127.0.0.1 pi.hole || exit 1

ENTRYPOINT ["start.sh"]
