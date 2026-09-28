#!/bin/bash
# Pi OS soft-blocks Wi-Fi until a regulatory country is set. The login
# banner checks cmdline for cfg80211.ieee80211_regdom=, and systemd-rfkill
# restores a blocked wlan state from /var/lib/systemd/rfkill.
#
#   wifi-country.sh [CC]
#   wifi-country.sh --root ROOT --boot BOOT [CC]
set -eu

country="${PIMARCHY_WIFI_COUNTRY:-US}"
root=""
boot=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --root)
            root="${2:?}"
            shift 2
            ;;
        --boot)
            boot="${2:?}"
            shift 2
            ;;
        *)
            country="$1"
            shift
            ;;
    esac
done

country="$(printf '%s' "$country" | tr '[:lower:]' '[:upper:]')"
if ! printf '%s' "$country" | grep -Eq '^[A-Z]{2}$'; then
    echo "wifi-country: country must be two letters" >&2
    exit 1
fi

if [ -z "$boot" ]; then
    if [ -n "$root" ] && [ -f "$root/boot/firmware/cmdline.txt" ]; then
        boot="$root/boot/firmware"
    elif [ -f /boot/firmware/cmdline.txt ]; then
        boot="/boot/firmware"
    elif [ -f /boot/cmdline.txt ]; then
        boot="/boot"
    fi
fi

cmdline=""
if [ -n "$boot" ] && [ -f "$boot/cmdline.txt" ]; then
    cmdline="$boot/cmdline.txt"
fi

if [ -n "$cmdline" ]; then
    if grep -q 'cfg80211.ieee80211_regdom=' "$cmdline"; then
        sed -i -E \
            "s/cfg80211\\.ieee80211_regdom=[^[:space:]]*/cfg80211.ieee80211_regdom=${country}/" \
            "$cmdline"
    else
        sed -i "s/[[:space:]]*\$/ cfg80211.ieee80211_regdom=${country}/" "$cmdline"
    fi
fi

rfkill_dir="${root}/var/lib/systemd/rfkill"
if [ -d "$rfkill_dir" ]; then
    for state in "$rfkill_dir"/*:wlan; do
        if [ -e "$state" ]; then
            printf '0\n' > "$state"
        fi
    done
fi

nm_state="${root}/var/lib/NetworkManager/NetworkManager.state"
if [ -f "$nm_state" ] && grep -q '^WirelessEnabled=' "$nm_state"; then
    sed -i 's/^WirelessEnabled=.*/WirelessEnabled=true/' "$nm_state"
fi

if [ -n "$root" ]; then
    exit 0
fi

if command -v iw >/dev/null 2>&1; then
    iw reg set "$country" || true
fi
if command -v rfkill >/dev/null 2>&1; then
    rfkill unblock wifi || true
fi
if command -v nmcli >/dev/null 2>&1; then
    nmcli radio wifi on || true
fi
