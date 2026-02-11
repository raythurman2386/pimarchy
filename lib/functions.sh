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
LABWC_DIR="$HOME/.config/labwc"
WAYBAR_DIR="$HOME/.config/waybar"
WOFI_DIR="$HOME/.config/wofi"
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
        local items=("labwc" "waybar" "wofi" "mako" "gtk-3.0" "alacritty" "pcmanfm")
        
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
        local items=("labwc" "waybar" "wofi" "mako" "gtk-3.0" "alacritty" "pcmanfm")
        
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
    
    local items=("labwc" "waybar" "wofi" "mako" "pcmanfm" "gtk-3.0" "alacritty")

    for item in "${items[@]}"; do
        if [ -d "$BACKUP_DIR/${item}.bak" ]; then
            log_info "Restoring ~/.config/$item"

            if [ "$item" = "labwc" ]; then
                # For labwc, merge back individual files
                for f in "$BACKUP_DIR/${item}.bak"/*; do
                    if [ -e "$f" ]; then
                        base=$(basename "$f")
                        # Special handling for autostart - don't restore if it's identical to system
                        if [ "$base" = "autostart" ]; then
                            if [ -f "/etc/xdg/labwc/autostart" ]; then
                                if diff -q "$f" "/etc/xdg/labwc/autostart" > /dev/null 2>&1; then
                                    log_info "Skipping autostart (identical to system default)"
                                    rm -f "$HOME/.config/labwc/autostart"
                                    continue
                                fi
                            fi
                        fi
                        cp -r "$f" "$HOME/.config/labwc/$base"
                    fi
                done
            else
                rm -rf "$HOME/.config/$item"
                cp -r "$BACKUP_DIR/${item}.bak" "$HOME/.config/$item"
            fi
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

install_packages() {
    log_info "Installing packages..."
    
    local packages=(
        waybar wofi mako-notifier swaybg grim slurp
        wl-clipboard fonts-font-awesome xdg-desktop-portal-wlr
        pavucontrol network-manager-gnome wtype
        arc-theme papirus-icon-theme gtk2-engines-murrine
        alacritty
    )

    sudo apt-get update -qq
    sudo apt-get install -y -qq "${packages[@]}"

    log_success "Packages installed"
}

remove_packages() {
    log_info "Removing packages..."

    local packages=(
        waybar wofi mako-notifier swaybg grim slurp
        wl-clipboard pavucontrol network-manager-gnome wtype
        arc-theme papirus-icon-theme gtk2-engines-murrine
        alacritty
    )
    
    sudo apt-get remove -y "${packages[@]}" 2>/dev/null || true
    sudo apt-get autoremove -y 2>/dev/null || true
    
    log_success "Packages removed"
}

# ============================================================================
# Directory Setup
# ============================================================================

create_config_dirs() {
    log_info "Creating config directories..."
    
    mkdir -p "$LABWC_DIR"
    mkdir -p "$WAYBAR_DIR"
    mkdir -p "$WOFI_DIR"
    mkdir -p "$MAKO_DIR"
    mkdir -p "$GTK3_DIR"
    mkdir -p "$TERMINAL_DIR"
    
    log_success "Config directories created"
}

# ============================================================================
# Service Management
# ============================================================================

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
    
    # Labwc files
    rm -f "$LABWC_DIR/rc.xml"
    rm -f "$LABWC_DIR/autostart"
    rm -f "$LABWC_DIR/power-menu.sh"
    rm -f "$LABWC_DIR/workspace-display.sh"
    rm -f "$LABWC_DIR/workspace-click.sh"
    rm -f /tmp/pimarchy-workspace
    
    # Waybar, wofi, mako
    rm -rf "$WAYBAR_DIR"
    rm -rf "$WOFI_DIR"
    rm -rf "$MAKO_DIR"
    
    # GTK configs
    rm -f "$GTK3_DIR/settings.ini"
    rm -f "$HOME/.gtkrc-2.0"
    
    # Terminal config
    rm -f "$TERMINAL_DIR/alacritty.toml"
    
    # Environment (clean up pimarchy lines or remove if we created it)
    if [ -f "$LABWC_DIR/environment" ]; then
        sed -i '/^# Pimarchy theming$/d' "$LABWC_DIR/environment"
        sed -i '/^XCURSOR_THEME=/d' "$LABWC_DIR/environment"
        sed -i '/^XCURSOR_SIZE=/d' "$LABWC_DIR/environment"
        # Remove file if it's now empty (Pimarchy created it)
        if [ ! -s "$LABWC_DIR/environment" ] || ! grep -q '[^[:space:]]' "$LABWC_DIR/environment" 2>/dev/null; then
            rm -f "$LABWC_DIR/environment"
        fi
    fi
    
    # Chromium dark mode flags
    sudo rm -f /etc/chromium.d/pimarchy-dark
    
    log_success "Pimarchy files removed"
}

# ============================================================================
# Desktop Settings
# ============================================================================

hide_trash_icon() {
    log_info "Hiding desktop trash icon..."
    
    for conf in "$HOME/.config/pcmanfm/LXDE-pi"/desktop-items-*.conf; do
        if [ -f "$conf" ]; then
            sed -i 's/show_trash=1/show_trash=0/g' "$conf"
        fi
    done
}

show_trash_icon() {
    log_info "Restoring desktop trash icon..."
    
    for conf in "$HOME/.config/pcmanfm/LXDE-pi"/desktop-items-*.conf; do
        if [ -f "$conf" ]; then
            sed -i 's/show_trash=0/show_trash=1/g' "$conf"
        fi
    done
}
