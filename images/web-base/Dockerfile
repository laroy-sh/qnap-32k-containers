# Reusable static-web base for the qnap-run skill (32K-page-safe).
FROM ubuntu:22.04

LABEL org.opencontainers.image.source="https://github.com/laroy-sh/qnap-32k-containers"
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends nginx-light \
    && rm -rf /var/lib/apt/lists/* && ln -sf /dev/stdout /var/log/nginx/access.log && ln -sf /dev/stderr /var/log/nginx/error.log
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
