#!/bin/bash
#
# Pimarchy Library Functions
# Shared functions used by install.sh and uninstall.sh
#

# ============================================================================
# Configuration Paths
# ============================================================================

PIMARCHY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="$PIMARCHY_DIR/config"
LIB_DIR="$PIMARCHY_DIR/lib"
BACKUP_DIR="$HOME/.config/Pimarchy-backup"

# System paths
HYPRLAND_DIR="$HOME/.config/hypr"
WAYBAR_DIR="$HOME/.config/waybar"
ROFI_DIR="$HOME/.config/rofi"
MAKO_DIR="$HOME/.config/mako"
GTK3_DIR="$HOME/.config/gtk-3.0"
TERMINAL_DIR="$HOME/.config/alacritty"

# ============================================================================
# Logging Functions
# ============================================================================

log_info() {
    echo "[INFO] $1"
}

log_success() {
    echo "[OK] $1"
}

log_warn() {
    echo "[WARN] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

# ============================================================================
# Backup Functions
# ============================================================================

backup_configs() {
    log_info "Creating backup directory: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    
    # Check if we already have original backups (from first install)
    # If so, preserve them by renaming
    if [ -f "$BACKUP_DIR/.original-backup" ]; then
        log_info "Original backups already exist, creating timestamped backup..."
        local timestamp=$(date +%Y%m%d-%H%M%S)
        local new_backup_dir="$BACKUP_DIR/previous-${timestamp}"
        mkdir -p "$new_backup_dir"
        
        # Move current configs to timestamped backup
        local items=("hypr" "waybar" "rofi" "mako" "gtk-3.0" "alacritty")
        
        for item in "${items[@]}"; do
            if [ -d "$HOME/.config/$item" ]; then
                log_info "Backing up current ~/.config/$item"
                cp -r "$HOME/.config/$item" "$new_backup_dir/${item}.bak" 2>/dev/null || true
            fi
        done
        
        if [ -f "$HOME/.gtkrc-2.0" ]; then
            cp "$HOME/.gtkrc-2.0" "$new_backup_dir/gtkrc-2.0.bak" 2>/dev/null || true
        fi
        
        log_success "Current configs backed up to $new_backup_dir"
    else
        # First time install - backup original configs
        log_info "Creating original backup of system configs..."
        local items=("hypr" "waybar" "rofi" "mako" "gtk-3.0" "alacritty")
        
        for item in "${items[@]}"; do
            if [ -d "$HOME/.config/$item" ]; then
                log_info "Backing up ~/.config/$item"
                cp -r "$HOME/.config/$item" "$BACKUP_DIR/${item}.bak" 2>/dev/null || true
            fi
        done
        
        if [ -f "$HOME/.gtkrc-2.0" ]; then
            log_info "Backing up ~/.gtkrc-2.0"
            cp "$HOME/.gtkrc-2.0" "$BACKUP_DIR/gtkrc-2.0.bak" 2>/dev/null || true
        fi
        
        # Mark this as the original backup
        echo "Original system configuration backup" > "$BACKUP_DIR/.original-backup"
        date >> "$BACKUP_DIR/.original-backup"
        
        log_success "Original backups saved to $BACKUP_DIR"
    fi
}

restore_configs() {
    log_info "Restoring configurations from backup..."
    
    if [ ! -d "$BACKUP_DIR" ]; then
        log_warn "No backup directory found at $BACKUP_DIR"
        return 0
    fi
    
    # Check if we have original backups
    if [ ! -f "$BACKUP_DIR/.original-backup" ]; then
        log_warn "No original backup marker found - backup may not contain original configs"
    fi
    
    local items=("hypr" "waybar" "rofi" "mako" "gtk-3.0" "alacritty")

    for item in "${items[@]}"; do
        if [ -d "$BACKUP_DIR/${item}.bak" ]; then
            log_info "Restoring ~/.config/$item"
            rm -rf "$HOME/.config/$item"
            cp -r "$BACKUP_DIR/${item}.bak" "$HOME/.config/$item"
        fi
    done
    
    # Restore GTK2 config
    if [ -f "$BACKUP_DIR/gtkrc-2.0.bak" ]; then
        log_info "Restoring ~/.gtkrc-2.0"
        cp "$BACKUP_DIR/gtkrc-2.0.bak" "$HOME/.gtkrc-2.0"
    fi
    
    log_success "Configuration restore complete"
}

# ============================================================================
# Template Processing
# ============================================================================

load_config() {
    local config_file="$1"
    if [ -f "$config_file" ]; then
        # Source the config file
        set -a
        source "$config_file"
        set +a
    else
        log_error "Config file not found: $config_file"
        return 1
    fi
}

process_template() {
    local template_file="$1"
    local output_file="$2"
    local max_iterations=100
    local iteration=0
    
    if [ ! -f "$template_file" ]; then
        log_error "Template file not found: $template_file"
        return 1
    fi
    
    # Create output directory if it doesn't exist
    mkdir -p "$(dirname "$output_file")"
    
    # Process template by replacing {{VARIABLE}} with actual values
    local content
    content=$(<"$template_file")
    
    # Replace all {{VAR}} patterns with their corresponding environment variables
    # Declare loop variables before the loop so `local` doesn't mask exit codes
    local var_name var_value
    while [[ $content =~ \{\{([A-Za-z_][A-Za-z0-9_]*)\}\} ]]; do
        var_name="${BASH_REMATCH[1]}"

        # Check if variable is set before reading its value
        if [ -z "${!var_name+x}" ]; then
            log_warn "Undefined variable in template: $var_name"
            var_value=""
        else
            var_value="${!var_name}"
        fi
        
        content="${content//\{\{$var_name\}\}/$var_value}"
        
        # Safety check to prevent infinite loops
        iteration=$((iteration + 1))
        if [ $iteration -gt $max_iterations ]; then
            log_error "Too many template variables or infinite loop detected"
            return 1
        fi
    done
    
    # Write processed content to output file
    printf '%s\n' "$content" > "$output_file"
    log_success "Generated: $output_file"
}

# ============================================================================
# Package Management (Debian/Ubuntu/Pi OS)
# ============================================================================

install_packages() {
    log_info "Updating system and installing packages..."
    
    sudo apt update
    sudo apt upgrade -y

    # Set up Debian sid (unstable) repository for Hyprland
    if [ ! -s /etc/apt/sources.list.d/sid.list ]; then
        log_info "Adding Debian Sid (unstable) repository for Hyprland..."
        echo "deb http://deb.debian.org/debian/ sid main contrib non-free" | sudo tee /etc/apt/sources.list.d/sid.list
        
        log_info "Configuring APT pinning to prefer current release but allow sid..."
        cat <<EOF | sudo tee /etc/apt/preferences.d/sid-pin
Package: *
Pin: release n=sid
Pin-Priority: 100
EOF
        sudo apt update
    fi

    # Remove conflicting bookworm list if it was added previously
    if [ -f /etc/apt/sources.list.d/bookworm.list ]; then
        sudo rm -f /etc/apt/sources.list.d/bookworm.list
        sudo apt update
    fi

    # Base packages from the stable/testing repository
    local base_packages=(
        fonts-font-awesome
        fonts-jetbrains-mono
        pavucontrol
        network-manager-gnome
        arc-theme
        papirus-icon-theme
        alacritty
        rofi
        greetd
        tuigreet
        starship
        thunar
        gsettings-desktop-schemas
        lxpolkit
        bluez
        bluez-tools
        alsa-utils
        unzip
        wget
        fontconfig
        chromium
        btop
    )

    sudo apt install -y "${base_packages[@]}"

    # Wayland/Hyprland specific packages from sid
    local hypr_packages=(
        hyprland
        waybar
        mako-notifier
        swaybg
        grim
        slurp
        wl-clipboard
        xdg-desktop-portal-hyprland
    )

    sudo apt install -t sid -y "${hypr_packages[@]}"

    if ! fc-list | grep -iq "CaskaydiaCove Nerd Font"; then
        log_info "Installing CaskaydiaCove Nerd Font..."
        mkdir -p "$HOME/.local/share/fonts"
        wget -qO /tmp/CascadiaCode.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/CascadiaCode.zip
        unzip -qo /tmp/CascadiaCode.zip -d "$HOME/.local/share/fonts/" || true
        fc-cache -fv "$HOME/.local/share/fonts" > /dev/null
        rm -f /tmp/CascadiaCode.zip
    fi

    log_success "Packages installed"
}

remove_packages() {
    log_info "Removing packages..."

    local packages=(
        hyprland
        waybar
        mako-notifier
        swaybg
        grim
        slurp
        wl-clipboard
        fonts-font-awesome
        fonts-jetbrains-mono
        xdg-desktop-portal-hyprland
        pavucontrol
        network-manager-gnome
        arc-theme
        papirus-icon-theme
        alacritty
        rofi
        greetd
        tuigreet
        starship
        thunar
        gsettings-desktop-schemas
        lxpolkit
        bluez
        bluez-tools
        alsa-utils
        chromium
        btop
    )
    
    sudo apt remove --purge -y "${packages[@]}" 2>/dev/null || true
    sudo apt autoremove -y
    
    log_success "Packages removed"
}

# ============================================================================
# Directory Setup
# ============================================================================

create_config_dirs() {
    log_info "Creating config directories..."
    
    mkdir -p "$HYPRLAND_DIR"
    mkdir -p "$WAYBAR_DIR"
    mkdir -p "$ROFI_DIR"
    mkdir -p "$MAKO_DIR"
    mkdir -p "$GTK3_DIR"
    mkdir -p "$TERMINAL_DIR"
    
    log_success "Config directories created"
}

# ============================================================================
# Service Management
# ============================================================================

detect_keyboard_layout() {
    local layout=""
    
    if command -v localectl &> /dev/null; then
        layout=$(localectl status --no-pager 2>/dev/null | awk -F': ' '/X11 Layout/{gsub(/^[[:space:]]+/,"",$2); print $2; exit}')
        if [ -n "$layout" ]; then
            echo "$layout"
            return 0
        fi
    fi
    
    if [ -f /etc/vconsole.conf ]; then
        layout=$(grep -E "^KEYMAP=" /etc/vconsole.conf | cut -d= -f2)
        if [ -n "$layout" ]; then
            echo "$layout"
            return 0
        fi
    fi
    
    if [ -d /usr/share/X11/xkb/symbols ]; then
        for layout_file in /etc/X11/xorg.conf.d/*; do
            if [ -f "$layout_file" ]; then
                layout=$(grep -E "XkbLayout" "$layout_file" | head -1 | awk '{print $2}' | tr -d '"')
                if [ -n "$layout" ]; then
                    echo "$layout"
                    return 0
                fi
            fi
        done
    fi
    
    echo "us"
    return 0
}

stop_services() {
    log_info "Stopping Pimarchy services..."
    
    pkill -f waybar 2>/dev/null || true
    pkill -f mako 2>/dev/null || true
    pkill -f swaybg 2>/dev/null || true
    
    # Disable greetd and restore Pi OS getty
    if systemctl is-enabled greetd &>/dev/null; then
        sudo systemctl disable greetd 2>/dev/null || true
    fi
    sudo systemctl unmask getty@tty1.service 2>/dev/null || true
    sudo systemctl enable getty@tty1.service 2>/dev/null || true
    
    # Restore default target (multi-user.target is standard for Pi OS Lite)
    sudo systemctl set-default multi-user.target 2>/dev/null || true

    # Remove system files written by install.sh
    sudo rm -f /usr/local/bin/start-hyprland
    sudo rm -f /etc/greetd/config.toml
    sudo rm -f /etc/X11/xorg.conf.d/00-keyboard.conf

    # Revert CPU governor and overclock settings
    revert_governor
    revert_overclock
    
    log_success "Services stopped and Pi OS boot environment restored"
}

# ============================================================================
# Performance Configuration (Raspberry Pi 5)
# ============================================================================

# Returns 0 if running on a Raspberry Pi 5 or Pi 500, 1 otherwise.
# Reads /proc/device-tree/compatible which lists the board identifiers.
is_pi5() {
    if [ -f /proc/device-tree/compatible ]; then
        if tr '\0' '\n' < /proc/device-tree/compatible 2>/dev/null | grep -qE "raspberrypi,5|raspberrypi,500"; then
            return 0
        fi
    fi
    return 1
}

# configure_governor — sets the CPU scaling governor to 'performance'.
# This keeps the CPU at maximum frequency without disabling DVFS voltage
# scaling. Safe on any Pi 5 / Pi 500, takes effect immediately, and
# persists across reboots via a systemd oneshot service (no extra packages
# required — cpufrequtils is not available in Pi OS / Debian Bookworm repos).
configure_governor() {
    log_info "Setting CPU governor to 'performance'..."

    local service_file="/etc/systemd/system/pimarchy-governor.service"

    # Install a oneshot systemd unit that sets the governor on every boot
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

    # Apply immediately to all cores without waiting for reboot
    for gov_path in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        [ -f "$gov_path" ] && echo performance | sudo tee "$gov_path" > /dev/null || true
    done

    log_success "CPU governor set to 'performance' (persists across reboots via systemd)"
}

# configure_overclock — adds arm_freq=2600 to /boot/firmware/config.txt.
# REQUIRES REBOOT. Only runs on confirmed Pi 5 / Pi 500 hardware.
# arm_freq=2600 is a mild overclock (stock is 2400 MHz) that does not
# require extra voltage on Pi 5 — the firmware's DVFS handles it.
# COOLING NOTE: An active cooler or adequate passive cooling is strongly
# recommended. Sustained load without cooling will trigger thermal
# throttling at 80°C and may cause instability.
configure_overclock() {
    log_info "Configuring CPU overclock (arm_freq=2600)..."

    # Safety: only proceed on Pi 5 hardware
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

    # Only add if not already present anywhere in the file (idempotent)
    if sudo grep -q "^arm_freq=" "$config_txt"; then
        log_info "arm_freq already set in $config_txt — skipping"
        return 0
    fi

    log_info "Adding arm_freq=2600 to $config_txt"

    if sudo grep -q "^\[all\]" "$config_txt"; then
        # Insert after only the FIRST [all] line using awk (not sed, which
        # would match every [all] occurrence)
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

# revert_overclock — removes the arm_freq line written by configure_overclock.
revert_overclock() {
    local config_txt="/boot/firmware/config.txt"
    if [ ! -f "$config_txt" ]; then
        return 0
    fi

    if sudo grep -q "^arm_freq=" "$config_txt"; then
        log_info "Removing arm_freq from $config_txt..."
        # Remove the arm_freq line and the Pimarchy comment above it (if present)
        sudo sed -i '/^# Pimarchy: Pi 5 mild overclock.*/d' "$config_txt"
        sudo sed -i '/^arm_freq=/d' "$config_txt"
        log_success "arm_freq removed from $config_txt — reboot required to take effect"
    fi
}

# revert_governor — removes the Pimarchy governor service and resets to 'ondemand'.
revert_governor() {
    local service_file="/etc/systemd/system/pimarchy-governor.service"

    if [ -f "$service_file" ]; then
        sudo systemctl disable pimarchy-governor.service 2>/dev/null || true
        sudo rm -f "$service_file"
        sudo systemctl daemon-reload
        log_success "Removed pimarchy-governor.service"
    fi

    # Apply immediately
    for gov_path in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        [ -f "$gov_path" ] && echo ondemand | sudo tee "$gov_path" > /dev/null 2>/dev/null || true
    done
}

# ============================================================================
# GSettings Management
# ============================================================================

apply_gsettings() {
    log_info "Applying gsettings..."
    
    gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR_THEME" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface cursor-size "$CURSOR_SIZE" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface font-name "$FONT_FAMILY $FONT_SIZE" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface color-scheme "$COLOR_SCHEME" 2>/dev/null || true
    
    log_success "GSettings applied"
}

reset_gsettings() {
    log_info "Resetting gsettings to defaults..."
    
    gsettings reset org.gnome.desktop.interface gtk-theme 2>/dev/null || true
    gsettings reset org.gnome.desktop.interface icon-theme 2>/dev/null || true
    gsettings reset org.gnome.desktop.interface cursor-theme 2>/dev/null || true
    gsettings reset org.gnome.desktop.interface cursor-size 2>/dev/null || true
    gsettings reset org.gnome.desktop.interface font-name 2>/dev/null || true
    gsettings reset org.gnome.desktop.interface color-scheme 2>/dev/null || true
    
    log_success "GSettings reset"
}

# ============================================================================
# File Management
# ============================================================================

remove_pimarchy_files() {
    log_info "Removing Pimarchy configuration files..."
    
    # Hyprland files
    rm -rf "$HYPRLAND_DIR"
    
    # Waybar, rofi, mako
    rm -rf "$WAYBAR_DIR"
    rm -rf "$ROFI_DIR"
    rm -rf "$MAKO_DIR"
    
    # GTK configs
    rm -f "$GTK3_DIR/settings.ini"
    rm -f "$HOME/.gtkrc-2.0"
    
    # Terminal config
    rm -rf "$TERMINAL_DIR"
    
    # Shell & Starship
    rm -f "$HOME/.bashrc.pimarchy"
    rm -f "$HOME/.config/starship.toml"
    
    # Chromium dark mode flags
    rm -f "$HOME/.config/chromium-flags.conf"
    
    # Debian-specific
    sudo rm -f /etc/apt/sources.list.d/bookworm.list
    sudo rm -f /etc/apt/sources.list.d/sid.list
    sudo rm -f /etc/apt/preferences.d/sid-pin
    
    log_success "Pimarchy files removed"
}

