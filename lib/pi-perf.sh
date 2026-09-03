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
# Pi 5 / Pi 500 only. REQUIRES REBOOT. arm_freq=2600 is a mild overclock
# (stock 2400 MHz) that needs no extra voltage; active cooling is strongly
# recommended — sustained load without cooling throttles at 80°C.
configure_overclock() {
    log_info "Configuring CPU overclock (arm_freq=2600)..."

    if ! is_pi5; then
        log_warn "Not running on a Raspberry Pi 5 / Pi 500 — skipping overclock"
        log_warn "arm_freq=2600 is only validated for Pi 5 and may be unsafe on other boards"
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

    if sudo grep -q "^\[all\]" "$config_txt"; then
        # Insert after only the FIRST [all] line (sed would match every one)
        local tmp
        tmp=$(mktemp)
        trap 'rm -f "$tmp"' RETURN
        sudo awk '
            /^\[all\]/ && !inserted {
                print; print "arm_freq=2600"; inserted=1; next
            }
            { print }
        ' "$config_txt" > "$tmp"
        sudo cp "$tmp" "$config_txt"
    else
        printf '\n# Pimarchy: Pi 5 mild overclock (2600 MHz, no extra voltage required)\n[all]\narm_freq=2600\n' \
            | sudo tee -a "$config_txt" > /dev/null
    fi

    log_success "arm_freq=2600 written to $config_txt"
    log_warn "COOLING REQUIRED: ensure an active cooler or adequate ventilation before rebooting"
    log_warn "A reboot is required for the overclock to take effect"
}

# revert_overclock — remove the arm_freq line written by configure_overclock.
revert_overclock() {
    local config_txt="/boot/firmware/config.txt"
    if [ ! -f "$config_txt" ]; then
        return 0
    fi

    if sudo grep -q "^arm_freq=" "$config_txt"; then
        log_info "Removing arm_freq from $config_txt..."
        sudo sed -i '/^# Pimarchy: Pi 5 mild overclock.*/d' "$config_txt"
        sudo sed -i '/^arm_freq=/d' "$config_txt"
        log_success "arm_freq removed from $config_txt — reboot required to take effect"
    fi
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