#!/bin/bash
#
# Pimarchy Library — Pi 5 Performance Configuration
#

# is_pi5 — 0 on Pi 5 / Pi 500, 1 otherwise. Reads /proc/device-tree/compatible.
is_pi5() {
    if [ -f /proc/device-tree/compatible ]; then
        if tr '\0' '\n' < /proc/device-tree/compatible 2>/dev/null | grep -qE "raspberrypi,5|raspberrypi,500"; then
            return 0
        fi
    fi
    return 1
}

# configure_governor — 'performance' governor via a systemd oneshot unit.
# Safe on any Pi 5 / Pi 500; DVFS still manages voltage. Takes effect
# immediately and persists across reboots (no extra packages required —
# cpufrequtils is not in Pi OS / Debian repos).
configure_governor() {
    log_info "Setting CPU governor to 'performance'..."

    local service_file="/etc/systemd/system/pimarchy-governor.service"

    sudo tee "$service_file" > /dev/null <<'EOF'
[Unit]
Description=Pimarchy CPU performance governor
After=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c 'for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo performance > "$f"; done'

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable pimarchy-governor.service 2>/dev/null || true

    ls /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 && \
        echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null || true

    log_success "CPU governor set to 'performance' (persists across reboots via systemd)"
}

# configure_overclock — arm_freq=2600 in /boot/firmware/config.txt.
# Pi 5 / Pi 500 only. REQUIRES REBOOT. Stock arm_freq is 2400. Firmware
# raises voltage to hold 2600. A hand-set over_voltage disables that
# scaling. Active cooling is required. Cores throttle between 80°C and 85°C.
# An existing arm_freq= line is left untouched.
configure_overclock() {
    log_info "Configuring CPU overclock (arm_freq=2600)..."

    if ! is_pi5; then
        log_warn "Not running on a Raspberry Pi 5 / Pi 500 — skipping overclock"
        log_warn "arm_freq=2600 is only applied on Pi 5 and Pi 500"
        return 0
    fi

    local config_txt="/boot/firmware/config.txt"
    if [ ! -f "$config_txt" ]; then
        log_warn "$config_txt not found — skipping overclock configuration"
        return 0
    fi

    if sudo grep -q "^arm_freq=" "$config_txt"; then
        log_info "arm_freq already set in $config_txt — skipping"
        return 0
    fi

    log_info "Adding arm_freq=2600 to $config_txt"
    run_pi_firmware --overclock
    if [ "${PI_BOOT_CHANGED:-0}" -eq 1 ]; then
        log_success "arm_freq=2600 written to $config_txt"
        log_warn "Firmware raises voltage to hold 2600 MHz. Active cooling is required."
        log_warn "Cores throttle between 80°C and 85°C. A reboot is required."
    fi
}

# revert_overclock — remove only the overclock block this install marked.
revert_overclock() {
    revert_pi_boot_lines
}

# revert_governor — remove the governor unit and reset to 'ondemand'.
revert_governor() {
    local service_file="/etc/systemd/system/pimarchy-governor.service"

    if [ -f "$service_file" ]; then
        sudo systemctl disable pimarchy-governor.service 2>/dev/null || true
        sudo rm -f "$service_file"
        sudo systemctl daemon-reload
        log_success "Removed pimarchy-governor.service"
    fi

    ls /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 && \
        echo ondemand | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null 2>/dev/null || true
}

# configure_pi_firmware — leave Pi firmware defaults in place.
# PCIe stays at the 2712 Gen 2 default. camera_auto_detect is not rewritten.
# cmdline cma= is not appended. A change from the editor is refused.
configure_pi_firmware() {
    local fw="/boot/firmware"

    if ! is_pi5; then
        log_info "Not a Pi 5 / Pi 500 — Pi firmware files are left unchanged"
        return 0
    fi
    if [ ! -f "$fw/config.txt" ] || [ ! -f "$fw/cmdline.txt" ]; then
        log_warn "$fw is missing config.txt or cmdline.txt — firmware files left unchanged"
        return 0
    fi

    log_info "Leaving Pi firmware defaults (PCIe Gen 2, camera autodetect, no cma=)"
    run_pi_firmware
    log_success "Pi firmware defaults left unchanged"
}

# revert_pi_firmware — undo boot lines a previous Pimarchy install marked.
revert_pi_firmware() {
    revert_pi_boot_lines
}

# revert_pi_boot_lines — shared by the overclock and firmware reverts.
revert_pi_boot_lines() {
    if [ ! -f /boot/firmware/config.txt ]; then
        return 0
    fi
    run_pi_firmware --revert
    if [ "${PI_BOOT_CHANGED:-0}" -eq 1 ]; then
        log_success "Removed Pimarchy-owned lines from /boot/firmware"
        log_warn "A reboot is required for the boot-file revert to take effect"
    fi
}

# run_pi_firmware [mode] — copy /boot/firmware, run lib/pi-firmware.sh, and
# write back only when mode is --overclock or --revert and the copy changed.
# The default mode must leave both files identical; a diff is an error and
# is not installed. Sets PI_BOOT_CHANGED to 1 when a write-back happened.
run_pi_firmware() {
    local mode="${1:-}"
    local fw="/boot/firmware"
    local script="$PIMARCHY_ROOT/lib/pi-firmware.sh"
    local tmp
    local config_changed=0
    local cmdline_changed=0

    PI_BOOT_CHANGED=0

    if [ ! -f "$script" ]; then
        log_error "Missing $script"
        return 1
    fi
    if [ ! -f "$fw/config.txt" ]; then
        log_warn "$fw/config.txt not found — skipping boot-file edit"
        return 0
    fi

    tmp=$(mktemp -d)
    cp "$fw/config.txt" "$tmp/config.txt"
    if [ -f "$fw/cmdline.txt" ]; then
        cp "$fw/cmdline.txt" "$tmp/cmdline.txt"
    elif [ -z "$mode" ]; then
        rm -rf "$tmp"
        log_warn "$fw/cmdline.txt not found — firmware files left unchanged"
        return 0
    fi

    if [ -n "$mode" ]; then
        bash "$script" "$mode" "$tmp"
    else
        bash "$script" "$tmp"
    fi

    if ! cmp -s "$tmp/config.txt" "$fw/config.txt"; then
        config_changed=1
    fi
    if [ -f "$tmp/cmdline.txt" ] && [ -f "$fw/cmdline.txt" ] \
        && ! cmp -s "$tmp/cmdline.txt" "$fw/cmdline.txt"; then
        cmdline_changed=1
    fi

    if [ "$config_changed" -eq 0 ] && [ "$cmdline_changed" -eq 0 ]; then
        rm -rf "$tmp"
        return 0
    fi

    if [ -z "$mode" ]; then
        rm -rf "$tmp"
        log_error "Default firmware editor changed boot files; not written"
        return 1
    fi

    if [ "$config_changed" -eq 1 ]; then
        sudo cp "$tmp/config.txt" "$fw/config.txt"
    fi
    if [ "$cmdline_changed" -eq 1 ]; then
        sudo cp "$tmp/cmdline.txt" "$fw/cmdline.txt"
    fi
    rm -rf "$tmp"
    PI_BOOT_CHANGED=1
}
