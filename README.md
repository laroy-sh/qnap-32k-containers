# qnap-32k-containers

**Fixed Docker images for QNAP 32-bit ARM NAS devices whose containers crash with `exit code 139` and empty logs** — Pi-hole v6, Syncthing, and a recipe to fix almost anything else.

```
docker pull ghcr.io/laroy-sh/pihole-qnap:latest      # Pi-hole v6, works on TS-x31P3
docker pull ghcr.io/laroy-sh/syncthing-qnap:latest   # Syncthing, works on TS-x31P3
docker pull ghcr.io/laroy-sh/ladder-qnap:latest      # ladder paywall proxy, works on TS-x31P3
docker pull ghcr.io/laroy-sh/stirling-qnap:latest    # Stirling PDF web tools, works on TS-x31P3
```

## The problem

On QNAP models like the **TS-431P3 / TS-231P3** (and other TS-x31X / TS-431KX / TS-1635-class 32-bit ARM devices), most modern Docker images fail instantly:

- Container Station shows the container stopping immediately, **exit code 139** (SIGSEGV)
- `docker logs` is **completely empty**
- glibc-based images may print: `error while loading shared libraries: libc.so.6: ELF load command address/offset not page-aligned`

Two independent causes:

1. **The CPU is 32-bit ARMv7** (Annapurna Labs AL314, Cortex-A15). `arm64` and `amd64` images can never run — only `linux/arm/v7` (or `arm/v6`).
2. **QNAP built the kernel for these models with a 32 KB memory page size** (standard Linux uses 4 KB — QNAP documents this in their [container debugging tutorial](https://www.qnap.com/en/how-to/tutorial/article/how-to-debug-and-fix-common-container-issues-in-container-station)). Any binary whose ELF segments are aligned for 4 K pages segfaults at load. Modern **Alpine (≥ 3.18), Debian bookworm, and Ubuntu 24.04** userlands are all built that way — which is why "even the arm/v7 image crashes". The latest firmware (QTS 5.2.9, kernel 4.2.8) still ships 32 K pages; this will not be fixed.

### Base image compatibility (verified on a TS-431P3)

| Works | Segfaults (exit 139) |
|---|---|
| `ubuntu:22.04` | `ubuntu:24.04` |
| `debian:bullseye-slim` | `debian:bookworm-slim` and newer |
| `alpine:3.17` and older | `alpine:3.18` and newer |
| static Go binaries (any base) | prebuilt native modules assuming 4K pages (better-sqlite3, jemalloc, …) |

## The fix used here

Most upstream images are Alpine-based, but their core binaries are **static and page-size-safe** — only the userland around them crashes. So these Dockerfiles keep the official upstream binaries and assets **unchanged** and rebuild only the userland on `ubuntu:22.04`. No forks, no source compiles: rebuilding against a new upstream release takes ~2 minutes, even natively on the NAS.

## Images

### Pi-hole v6 — `ghcr.io/laroy-sh/pihole-qnap`

The official `pihole/pihole` v6 image segfaults on 32K-page QNAPs (its Alpine 3.24 userland). This image = official FTL binary + official web UI + official entrypoint scripts, on Ubuntu 22.04.

Container Station → *Applications* → *Create* with a compose file like (adjust subnet/IP/interface):

```yaml
networks:
  qnet-static:
    driver: qnet
    ipam:
      driver: qnet
      options:
        iface: "eth0"
      config:
        - subnet: 192.168.1.0/24
          gateway: 192.168.1.1

services:
  pihole:
    image: ghcr.io/laroy-sh/pihole-qnap:latest
    container_name: pihole
    hostname: pihole
    restart: unless-stopped
    networks:
      qnet-static:
        ipv4_address: 192.168.1.250   # the IP your clients will use as DNS
    environment:
      TZ: "Europe/Berlin"
      FTLCONF_webserver_api_password: "changeme"
    volumes:
      - pihole_etc:/etc/pihole
      - pihole_dnsmasq:/etc/dnsmasq.d

volumes:
  pihole_etc:
  pihole_dnsmasq:
```

**Migrating from a v5 container** (e.g. the last-working `pihole/pihole:2022.12.1`): point the new container at a *copy* of your old `/etc/pihole` + `/etc/dnsmasq.d` volumes — v6 migrates settings, gravity lists, and the admin password automatically on first boot. Keep the old container stopped-but-present until you're happy.
**Gotcha:** if your v5 had *no* password, v6's login screen may still appear. Fix: `docker exec pihole pihole setpassword ""`.

Verify: `dig @<pihole-ip> doubleclick.net` → `0.0.0.0`, and the admin UI at `http://<pihole-ip>/admin/`.

### Syncthing — `ghcr.io/laroy-sh/syncthing-qnap`

The official image's Go binary is fine; its Alpine shell entrypoint isn't. This image = official binary + the entrypoint ported to Ubuntu (`su-exec` → `setpriv`).

```bash
docker run -d --name syncthing \
  -p 8384:8384 -p 22000:22000/tcp -p 22000:22000/udp -p 21027:21027/udp \
  -v syncthing_config:/var/syncthing/config \
  -v /share/Container/syncthing-data:/var/syncthing/data \
  -e TZ=Europe/Berlin --restart unless-stopped \
  ghcr.io/laroy-sh/syncthing-qnap:latest
```

Web UI: `http://<nas-ip>:8384`.

### Ladder — `ghcr.io/laroy-sh/ladder-qnap`

[everywall/ladder](https://github.com/everywall/ladder), a selfhosted 1ft.io/12ft.io-style proxy for reading articles behind soft paywalls. Upstream publishes **no `linux/arm/v7` image at all**, so this one is built from source: the static Go binary (page-size-agnostic) on `ubuntu:22.04`, with the upstream `rulesets/` directory baked in (`RULESET=/app/rulesets`).

```bash
docker run -d --name ladder -p 8081:8080 --restart unless-stopped \
  ghcr.io/laroy-sh/ladder-qnap:latest
```

Open `http://<nas-ip>:8081` and paste an article URL, or prefix directly: `http://<nas-ip>:8081/https://<article-url>`. All upstream env vars work (`PORT`, `RULESET`, `USERPASS`, `ALLOWED_DOMAINS`, …). Note: the optional FlareSolverr companion (Cloudflare bypass) is amd64/arm64-only and cannot run on these devices — point `FLARESOLVERR_HOST` at another machine if you need it.

### Stirling PDF — `ghcr.io/laroy-sh/stirling-qnap`

[Stirling-PDF](https://github.com/Stirling-Tools/Stirling-PDF), a self-hosted web app for PDF manipulation (merge, split, rotate, compress, sign, …). Upstream publishes **no `linux/arm/v7` image**, but the release ships an arch-independent JAR with the web UI embedded, so this image is just `ubuntu:22.04` + jammy's armhf OpenJDK 21 + that JAR.

Two quirks worth knowing (details in the Dockerfile):

- **Pinned to v2.5.3**, the last release targeting Java 17. Stirling ≥ v2.6 requires Java 25, and jammy's `openjdk-25` armhf build is Zero VM (interpreter-only, unusably slow on a Cortex-A15) — `openjdk-21` is a real JIT Server VM. Starts in ~60 s on a TS-431P3.
- Use `Stirling-PDF.jar`, **not** `Stirling-PDF-server.jar` — the latter is API-only and serves no web UI.

Ultra-lite: no Tesseract/LibreOffice, so OCR and Office conversions are unavailable; `apt-get install` them into the image if needed.

```bash
docker run -d --name stirling -p 8082:80 --restart unless-stopped \
  -v stirling_configs:/configs \
  ghcr.io/laroy-sh/stirling-qnap:latest
```

Web UI: `http://<nas-ip>:8082`.

### Static web base — `ghcr.io/laroy-sh/qnap-web-base`

`ubuntu:22.04` + nginx-light. For instantly serving static sites from the NAS:

```dockerfile
FROM ghcr.io/laroy-sh/qnap-web-base:latest
COPY . /var/www/html/
```

## Works without fixing

Some upstream images need no rebase — worth knowing before you fix what isn't broken:

- **[Dozzle](https://github.com/amir20/dozzle)** (`amir20/dozzle`, real-time Docker log viewer): a single static Go binary `FROM scratch` — no userland to break — and upstream publishes `linux/arm/v7`. Verified unmodified on a TS-431P3 (v10.6.7):

  ```bash
  docker run -d --name dozzle -p 8083:8080 --restart unless-stopped \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    amir20/dozzle:latest
  ```

  Web UI: `http://<nas-ip>:8083`.

## Fix any other image yourself

1. **Check the architecture**: `docker manifest inspect <image>` must list `linux/arm/v7` (or v6).
2. **30-second page-size test** on the NAS: `docker run --rm <image> <version-command>; echo $?` — exit `139` means it's a 32K-page victim.
3. **Rebase it** if the main binary is static (Go, Rust-musl-static, or vendor-shipped static like Pi-hole's FTL):

   ```dockerfile
   FROM <official-image> AS official
   FROM ubuntu:22.04
   RUN apt-get update && apt-get install -y --no-install-recommends <runtime deps> && rm -rf /var/lib/apt/lists/*
   COPY --from=official /path/to/binary /path/to/binary
   # replicate ENV / ENTRYPOINT / HEALTHCHECK from `docker image inspect <official-image>`
   ```

4. If the binary is dynamically linked or ships 4K-assuming native modules, rebuild it from source with `-Wl,-z,max-page-size=32768` (see [javiocu/pihole-qnap-32k](https://github.com/javiocu/pihole-qnap-32k) for a full static-compile example), or run that app on different hardware.

**Building natively on the NAS** (no cross-compiling, no registry): Container Station → Preferences → Docker Certificate → Download, then on your PC:

```bash
docker context create qnap --docker "host=tcp://<nas-ip>:2376,ca=ca.pem,cert=cert.pem,key=key.pem"
docker --context qnap build -t myimage images/myimage/
```

## Updates

Images are rebuilt **weekly** in CI against upstream `:latest` (plus on every push). Version tags mirror the upstream release (e.g. `pihole-qnap:2026.06.0`). To rebuild yourself: `docker build --pull`.

## Credits & licenses

- Repo contents: MIT. The published images bundle unmodified upstream software under their own licenses: [Pi-hole](https://github.com/pi-hole/pi-hole) (EUPL-1.2; *Pi-hole is a registered trademark of Pi-hole LLC — this project is not affiliated with or endorsed by Pi-hole*), [Syncthing](https://github.com/syncthing/syncthing) (MPL-2.0), [ladder](https://github.com/everywall/ladder) (GPL-3.0, built from unmodified source), [Stirling-PDF](https://github.com/Stirling-Tools/Stirling-PDF) (MIT with proprietary portions — see upstream LICENSE; unmodified release JAR), nginx (BSD-2-Clause).
- [javiocu/pihole-qnap-32k](https://github.com/javiocu/pihole-qnap-32k) — prior art that identified the 32K page-size root cause for Pi-hole v6 on these devices.
- [albertogeniola/homeassistant-qnap-32k](https://hub.docker.com/r/albertogeniola/homeassistant-qnap-32k) — Home Assistant fixed for the same 32K-page QNAP family; use it if you need HA on these devices.
- QNAP's [container debugging KB article](https://www.qnap.com/en/how-to/tutorial/article/how-to-debug-and-fix-common-container-issues-in-container-station) documenting the 4K→32K page change.
