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

# configure_docker_repo — adds the official Docker CE apt repository so that
# docker-ce, docker-compose-plugin, and docker-buildx-plugin can be installed
# at their latest upstream versions. Idempotent: skips if already configured.
# Follows the official Docker docs for Debian (arm64 / Pi OS Bookworm).
configure_docker_repo() {
    if [ -f /etc/apt/sources.list.d/docker.list ]; then
        log_info "Docker apt repository already configured — skipping"
        return 0
    fi

    log_info "Adding official Docker CE apt repository..."

    # Install prerequisites for adding the repo
    sudo apt install -y ca-certificates curl gnupg

    # Import Docker's official GPG key
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg \
        | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # Pi OS Bookworm reports VERSION_CODENAME="bookworm" — use that for the repo
    local codename
    codename=$(. /etc/os-release && echo "$VERSION_CODENAME")
    # Fallback: Pi OS may set only DEBIAN_CODENAME
    if [ -z "$codename" ]; then
        codename=$(. /etc/os-release && echo "$DEBIAN_CODENAME")
    fi
    if [ -z "$codename" ]; then
        codename="bookworm"
    fi

    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/debian ${codename} stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Pin Docker packages so they always come from the official repo, not Debian
    cat <<'EOF' | sudo tee /etc/apt/preferences.d/docker-pin > /dev/null
Package: docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
Pin: origin download.docker.com
Pin-Priority: 1001
EOF

    sudo apt update
    log_success "Docker CE repository added"
}

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

    # Add official Docker CE repository (provides docker-ce + docker-compose-plugin)
    configure_docker_repo

    # Add official VS Code repository
    if [ ! -s /etc/apt/sources.list.d/vscode.list ]; then
        log_info "Adding Microsoft VS Code repository..."
        curl -sSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/packages.microsoft.gpg
        sudo install -D -o root -g root -m 644 /tmp/packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
        echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
        rm -f /tmp/packages.microsoft.gpg
        sudo apt update
    fi

    # Base packages from the stable/testing repository
    local base_packages=(
        fonts-font-awesome
        fonts-jetbrains-mono
        fonts-noto-color-emoji
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
        curl
        fontconfig
        chromium
        code
        btop
    )

    sudo apt install -y "${base_packages[@]}"

    # Docker CE + Compose v2 from the official Docker repository
    local docker_packages=(
        docker-ce
        docker-ce-cli
        containerd.io
        docker-buildx-plugin
        docker-compose-plugin
    )

    sudo apt install -y "${docker_packages[@]}"

    # Add current user to the docker group so Docker works without sudo
    if ! id -nG "$USER" | grep -qw docker 2>/dev/null; then
        sudo usermod -aG docker "$USER"
        log_info "Added $USER to docker group (re-login required to take effect)"
    fi

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

    # Rebuild the system-wide fontconfig cache so newly installed fonts
    # (e.g. fonts-noto-color-emoji) are available to all applications.
    sudo fc-cache -fv > /dev/null

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
        docker-ce
        docker-ce-cli
        containerd.io
        docker-buildx-plugin
        docker-compose-plugin
    )
    
    sudo apt remove --purge -y "${packages[@]}" 2>/dev/null || true
    sudo apt autoremove -y

    # Remove Docker CE repository and GPG key
    sudo rm -f /etc/apt/sources.list.d/docker.list
    sudo rm -f /etc/apt/keyrings/docker.gpg
    sudo rm -f /etc/apt/preferences.d/docker-pin
    sudo apt update 2>/dev/null || true

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
    mkdir -p "$HOME/.config/btop/themes"
    mkdir -p "$HOME/.config/opencode"
    
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
    
    pkill -f mako 2>/dev/null || true
    
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
    # Use a single sudo tee command with wildcard expansion to avoid multiple sudo calls
    ls /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 && \
        echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null || true

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
    # Use a single sudo tee command with wildcard expansion to avoid multiple sudo calls
    ls /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 && \
        echo ondemand | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null 2>/dev/null || true
}

# configure_swaybg — installs and enables a systemd user service that sets the
# desktop wallpaper via swaybg. Running swaybg as a user service (instead of
# exec-once in hyprland.conf) ensures it starts after graphical-session.target
# is fully ready, preventing the silent connection failure that causes a black
# desktop when Hyprland is launched via UWSM.
configure_swaybg() {
    log_info "Configuring swaybg user service..."
    local systemd_dir="$HOME/.config/systemd/user"
    mkdir -p "$systemd_dir"
    
    cat << 'EOF' > "$systemd_dir/swaybg.service"
[Unit]
Description=swaybg wallpaper daemon
Documentation=man:swaybg(1)
PartOf=graphical-session.target
After=graphical-session.target

[Service]
Type=simple
# swaybg requires wayland; UWSM sets WAYLAND_DISPLAY
ExecStart=/usr/bin/swaybg -i %h/.config/hypr/background.jpg -m fill
Restart=on-failure
RestartSec=1

[Install]
WantedBy=graphical-session.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable swaybg.service
}

configure_vscode_extensions() {
    if command -v code &> /dev/null; then
        log_info "Installing VS Code extensions..."
        code --install-extension RaymondThurman.ravenwood --force >/dev/null 2>&1 || true
    fi
}

# revert_swaybg — disables and removes the swaybg user service written by
# configure_swaybg.
revert_swaybg() {
    local service_file="$HOME/.config/systemd/user/swaybg.service"

    systemctl --user disable swaybg.service 2>/dev/null || true
    systemctl --user stop swaybg.service 2>/dev/null || true
    rm -f "$service_file"
    systemctl --user daemon-reload
    log_success "swaybg wallpaper service removed"
}

# ============================================================================
# OpenCode Installation
# ============================================================================

# install_opencode — installs the OpenCode AI coding agent using the official
# install script from opencode.ai. Idempotent: skips if already installed.
install_opencode() {
    if command -v opencode &>/dev/null; then
        log_info "OpenCode already installed ($(opencode --version 2>/dev/null || echo 'unknown version')) — skipping"
        return 0
    fi

    log_info "Installing OpenCode..."

    if ! command -v curl &>/dev/null; then
        sudo apt install -y curl
    fi

    curl -fsSL https://opencode.ai/install | bash

    if command -v opencode &>/dev/null; then
        log_success "OpenCode installed successfully"
    else
        log_warn "OpenCode installer ran but 'opencode' not found in PATH — may need to re-login or source ~/.bashrc"
    fi
}

# remove_opencode — removes the OpenCode installation written by install_opencode.
# The official install script places everything under ~/.opencode/ and adds
# ~/.opencode/bin to PATH in ~/.bashrc.
remove_opencode() {
    local opencode_dir="$HOME/.opencode"

    if [ -d "$opencode_dir" ]; then
        rm -rf "$opencode_dir"
        log_success "OpenCode installation removed ($opencode_dir)"
    else
        log_info "OpenCode not found at $opencode_dir — nothing to remove"
    fi

    # Remove the PATH entry added by the installer to ~/.bashrc (if present)
    if grep -q '\.opencode/bin' "$HOME/.bashrc" 2>/dev/null; then
        sed -i '/\.opencode\/bin/d' "$HOME/.bashrc"
        log_info "Removed OpenCode PATH entry from ~/.bashrc"
    fi
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

    # btop theme and config
    rm -f "$HOME/.config/btop/btop.conf"
    rm -f "$HOME/.config/btop/themes/ravenwood.theme"

    # OpenCode config
    rm -f "$HOME/.config/opencode/opencode.json"

    # Debian-specific
    sudo rm -f /etc/apt/sources.list.d/bookworm.list
    sudo rm -f /etc/apt/sources.list.d/sid.list
    sudo rm -f /etc/apt/preferences.d/sid-pin
    
    log_success "Pimarchy files removed"
}

