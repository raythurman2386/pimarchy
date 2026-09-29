#!/bin/bash
# Link /dev/root at the booted root disk.
#
# Pi OS often lists the root filesystem as /dev/root in /proc/mounts. That
# name is not a block device. initramfs-tools (MODULES=dep) then aborts with
# "mkinitramfs: failed to determine device for /", and dpkg leaves the kernel
# packages unconfigured. Creating the symlink before apt fixes that.
#
#   ensure-dev-root.sh
#   ensure-dev-root.sh --resolve MOUNTS CMDLINE
set -eu

root_spec_from() {
    local mounts="$1"
    local cmdline="$2"
    local dev="" mp="" fs="" spec="" arg="" value=""

    while read -r dev mp fs _; do
        if [ "$mp" = "/" ] && [ "$fs" != "rootfs" ]; then
            spec="$dev"
            break
        fi
    done < "$mounts"

    if [ -n "$spec" ] && [ "$spec" != "/dev/root" ]; then
        printf '%s\n' "$spec"
        return 0
    fi

    for arg in $(cat "$cmdline"); do
        case "$arg" in
            root=PARTUUID=*)
                value="${arg#root=PARTUUID=}"
                printf '/dev/disk/by-partuuid/%s\n' "$value"
                return 0
                ;;
            root=UUID=*)
                value="${arg#root=UUID=}"
                printf '/dev/disk/by-uuid/%s\n' "$value"
                return 0
                ;;
            root=LABEL=*)
                value="${arg#root=LABEL=}"
                printf '/dev/disk/by-label/%s\n' "$value"
                return 0
                ;;
            root=/dev/*)
                printf '%s\n' "${arg#root=}"
                return 0
                ;;
        esac
    done
    return 1
}

if [ "${1:-}" = "--resolve" ]; then
    root_spec_from "${2:?mounts file}" "${3:?cmdline file}"
    exit 0
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "pimarchy-ensure-dev-root: run as root" >&2
    exit 1
fi

if [ -b /dev/root ]; then
    exit 0
fi

spec="$(root_spec_from /proc/mounts /proc/cmdline || true)"
if [ -z "$spec" ] || [ ! -e "$spec" ]; then
    echo "pimarchy-ensure-dev-root: root block device was not found" >&2
    exit 0
fi

real="$(readlink -f "$spec")"
if [ ! -b "$real" ]; then
    echo "pimarchy-ensure-dev-root: $real is not a block device" >&2
    exit 0
fi

ln -sfn "$real" /dev/root
