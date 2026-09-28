#!/bin/bash
# A Pi has no battery clock. A fresh image boots at the image timestamp,
# and apt then rejects repository signatures that are "not live" yet.
# Wait for systemd-timesyncd, then fall back to the Date header from
# deb.debian.org.
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "sync-clock: run as root" >&2
    exit 1
fi

systemctl enable --now systemd-timesyncd 2>/dev/null || true

synced=0
if command -v timedatectl >/dev/null 2>&1; then
    for _ in $(seq 1 30); do
        if [ "$(timedatectl show -p NTPSynchronized --value 2>/dev/null || true)" = "yes" ]; then
            synced=1
            break
        fi
        sleep 1
    done
fi

if [ "$synced" -ne 1 ] && command -v curl >/dev/null 2>&1; then
    hdr="$(curl -fsSI --max-time 15 https://deb.debian.org \
        | awk 'BEGIN{IGNORECASE=1} /^date:/ {
            sub(/^date:[[:space:]]*/, "")
            print
            exit
        }')"
    if [ -n "$hdr" ]; then
        date -u -s "$hdr" >/dev/null
        synced=1
    fi
fi

if command -v fake-hwclock >/dev/null 2>&1; then
    fake-hwclock save || true
fi

if [ "$synced" -eq 1 ]; then
    printf 'Pimarchy: clock is %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
else
    printf 'Pimarchy: clock was not synchronized\n'
fi
