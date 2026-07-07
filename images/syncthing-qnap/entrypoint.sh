#!/bin/bash
# Ubuntu port of the official syncthing entrypoint (su-exec -> setpriv).
set -eu

[ -n "${UMASK:-}" ] && umask "$UMASK"

if [ "$(id -u)" = '0' ]; then
  binary="$1"
  if [ -z "${PCAP:-}" ]; then
    setcap -r "$binary" 2>/dev/null || true
  else
    setcap "$PCAP" "$binary"
  fi
  chown -R "${PUID}:${PGID}" "${HOME}" || true
  exec setpriv --reuid "$PUID" --regid "$PGID" --clear-groups \
       env HOME="$HOME" "$@"
else
  exec "$@"
fi
