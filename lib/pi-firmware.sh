#!/bin/bash
# Edit a directory that holds config.txt and, for the default path, cmdline.txt.
# Does not use sudo — the caller owns the files.
#
#   pi-firmware.sh DIR
#       Leave firmware defaults alone. No PCIe generation line, no
#       camera_auto_detect change, no cmdline cma= token.
#   pi-firmware.sh --overclock DIR
#       Opt-in arm_freq=2600, marked with a Pimarchy comment. Skips the file
#       when any arm_freq= line is already present.
#   pi-firmware.sh --revert DIR
#       Delete only blocks this install marked. User-owned arm_freq,
#       dtparam=pciex1_gen, camera_auto_detect, and cma= lines stay.
#
# Gen 3 is not a mode of this script. Pi firmware stays at Gen 2 unless the
# user adds dtparam=pciex1_gen=3 themselves.
set -eu

OC_COMMENT="# Pimarchy: Pi 5 overclock arm_freq=2600 (stock 2400; firmware scales voltage)"
OC_COMMENT_OLD="# Pimarchy: Pi 5 mild overclock (2600 MHz, no extra voltage required)"
GEN3_COMMENT="# Pimarchy: NVMe at PCIe Gen 3 (drive trains at 8 GT/s)"
CAMERA_COMMENT="# Pimarchy: Pi 500 has no camera"

usage() {
    echo "usage: pi-firmware.sh [--revert|--overclock] FIRMWARE_DIR" >&2
}

is_oc_comment() {
    [ "$1" = "$OC_COMMENT" ] || [ "$1" = "$OC_COMMENT_OLD" ]
}

# True when lines[start]..end are blank or the next config section.
section_empty_from() {
    local start="$1"
    local j="$start"
    local n="${#lines[@]}"
    local item

    while [ "$j" -lt "$n" ]; do
        item="${lines[$j]}"
        if [ -z "$item" ]; then
            j=$((j + 1))
            continue
        fi
        case "$item" in
            \[*\]) return 0 ;;
            *) return 1 ;;
        esac
    done
    return 0
}

write_lines() {
    local file="$1"
    shift
    if [ "$#" -eq 0 ]; then
        : > "$file"
        return 0
    fi
    printf '%s\n' "$@" > "$file"
}

read_lines() {
    lines=()
    if [ -s "$1" ]; then
        mapfile -t lines < "$1"
    fi
}

revert_config() {
    local file="$1"
    local -a lines=()
    local -a out=()
    local i=0 n cur next1 next2

    read_lines "$file"
    n="${#lines[@]}"
    while [ "$i" -lt "$n" ]; do
        cur="${lines[$i]}"
        next1=""
        next2=""
        if [ $((i + 1)) -lt "$n" ]; then
            next1="${lines[$((i + 1))]}"
        fi
        if [ $((i + 2)) -lt "$n" ]; then
            next2="${lines[$((i + 2))]}"
        fi

        if is_oc_comment "$cur" && [ "$next1" = "[all]" ] \
            && [ "$next2" = "arm_freq=2600" ]; then
            if section_empty_from $((i + 3)); then
                i=$((i + 3))
                continue
            fi
            out+=("[all]")
            i=$((i + 3))
            continue
        fi

        if is_oc_comment "$cur" && [ "$next1" = "arm_freq=2600" ]; then
            i=$((i + 2))
            continue
        fi

        if [ "$cur" = "[all]" ] && [ "$next1" = "$GEN3_COMMENT" ] \
            && [ "$next2" = "dtparam=pciex1_gen=3" ] \
            && section_empty_from $((i + 3)); then
            i=$((i + 3))
            continue
        fi

        if [ "$cur" = "$GEN3_COMMENT" ] \
            && [ "$next1" = "dtparam=pciex1_gen=3" ]; then
            i=$((i + 2))
            continue
        fi

        if [ "$cur" = "$CAMERA_COMMENT" ]; then
            i=$((i + 1))
            continue
        fi

        out+=("$cur")
        i=$((i + 1))
    done

    write_lines "$file" "${out[@]}"
}

# Drop cma=512M only in the shape the old writer appended: a trailing token,
# or a line that is nothing but that token. Other cma= values stay.
revert_cmdline() {
    local file="$1"
    local -a lines=()
    local -a out=()
    local line

    read_lines "$file"
    for line in "${lines[@]}"; do
        if [[ "$line" =~ ^[[:space:]]*cma=512M[[:space:]]*$ ]]; then
            continue
        fi
        if [[ "$line" =~ ^(.*)[[:space:]]cma=512M[[:space:]]*$ ]]; then
            line="${BASH_REMATCH[1]}"
        fi
        out+=("$line")
    done
    write_lines "$file" "${out[@]}"
}

apply_overclock() {
    local config_txt="$1"

    if grep -q '^arm_freq=' "$config_txt"; then
        return 0
    fi

    if grep -q '^\[all\]$' "$config_txt"; then
        awk -v comment="$OC_COMMENT" '
            /^\[all\]$/ && !inserted {
                print
                print comment
                print "arm_freq=2600"
                inserted = 1
                next
            }
            { print }
        ' "$config_txt" > "$config_txt.tmp"
        mv "$config_txt.tmp" "$config_txt"
        return 0
    fi

    printf '\n%s\n[all]\narm_freq=2600\n' "$OC_COMMENT" >> "$config_txt"
}

mode="apply"
case "${1:-}" in
    --revert)
        mode="revert"
        shift
        ;;
    --overclock)
        mode="overclock"
        shift
        ;;
    -h|--help)
        usage
        exit 0
        ;;
    --*)
        usage
        exit 1
        ;;
esac

if [ "$#" -ne 1 ]; then
    usage
    exit 1
fi

fw="$1"
config_txt="$fw/config.txt"
cmdline="$fw/cmdline.txt"

if [ ! -f "$config_txt" ]; then
    echo "pi-firmware: $fw is missing config.txt" >&2
    exit 1
fi

case "$mode" in
    apply)
        if [ ! -f "$cmdline" ]; then
            echo "pi-firmware: $fw is missing cmdline.txt" >&2
            exit 1
        fi
        ;;
    overclock)
        apply_overclock "$config_txt"
        ;;
    revert)
        revert_config "$config_txt"
        if [ -f "$cmdline" ]; then
            revert_cmdline "$cmdline"
        fi
        ;;
esac
