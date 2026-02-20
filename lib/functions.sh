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
        return 1
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
    while [[ $content =~ \{\{([A-Za-z_][A-Za-z0-9_]*)\}\} ]]; do
        local var_name="${BASH_REMATCH[1]}"
        local var_value="${!var_name}"
        
        # Check if variable is set
        if [ -z "${!var_name+x}" ]; then
            log_warn "Undefined variable in template: $var_name"
            # Replace with empty string to prevent infinite loop
            var_value=""
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
# Package Management
# ============================================================================

install_yay() {
    if ! command -v yay &> /dev/null; then
        log_info "Installing yay (AUR helper)..."
        
        if ! command -v git &> /dev/null; then
            log_info "Installing git..."
            sudo pacman -S --needed --noconfirm git
        fi
        
        if ! command -v makepkg &> /dev/null; then
            log_info "Installing base-devel..."
            sudo pacman -S --needed --noconfirm base-devel
        fi
        
        local yay_dir="/tmp/yay-bin"
        git clone https://aur.archlinux.org/yay-bin.git "$yay_dir"
        
        if [ $? -ne 0 ]; then
            log_error "Failed to clone yay repository"
            return 1
        fi
        
        cd "$yay_dir"
        makepkg -si --noconfirm
        
        if [ $? -ne 0 ]; then
            log_error "Failed to build yay"
            cd - > /dev/null
            rm -rf "$yay_dir"
            return 1
        fi
        
        cd - > /dev/null
        rm -rf "$yay_dir"
        log_success "yay installed"
    else
        log_info "yay is already installed"
    fi
}

install_packages() {
    log_info "Updating system and installing packages..."
    
    sudo pacman -Syu --noconfirm

    install_yay

    local packages=(
        hyprland waybar mako swaybg grim slurp
        wl-clipboard ttf-font-awesome ttf-jetbrains-mono-nerd xdg-desktop-portal-hyprland
        pavucontrol network-manager-applet
        arc-gtk-theme papirus-icon-theme
        alacritty rofi-wayland greetd greetd-tuigreet nwg-look
        polkit-gnome starship thunar
        linux-firmware bluez bluez-utils alsa-utils
    )

    yay -S --needed --noconfirm "${packages[@]}"

    log_success "Packages installed"
}

remove_packages() {
    log_info "Removing packages..."

    local packages=(
        hyprland waybar mako swaybg grim slurp
        wl-clipboard ttf-font-awesome ttf-jetbrains-mono-nerd xdg-desktop-portal-hyprland
        pavucontrol network-manager-applet
        arc-gtk-theme papirus-icon-theme
        alacritty rofi-wayland greetd greetd-tuigreet nwg-look
        polkit-gnome starship thunar
        linux-firmware bluez bluez-utils alsa-utils
    )
    
    yay -Rns --noconfirm "${packages[@]}" 2>/dev/null || true
    
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
        layout=$(localectl status --no-pager 2>/dev/null | grep "X11 Layout" | awk '{print $3}')
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
    
    log_success "Services stopped"
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
    
    log_success "Pimarchy files removed"
}

