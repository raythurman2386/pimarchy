#!/bin/bash
#
# Pimarchy Installer for Raspberry Pi 500 (Pi OS/Debian + Hyprland)
# A lightweight, aesthetic Omarchy-inspired desktop transformation.
#
# This modular installer reads configuration from config/ directory
# and applies templates with user-customizable settings.
#
# Usage: bash install.sh [--dry-run]
#

set -e

# Parse arguments
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --dry-run    Show what would be installed without making changes"
            echo "  -h, --help   Show this help message"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Get script directory
PIMARCHY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PIMARCHY_ROOT

# Source library functions
source "$PIMARCHY_ROOT/lib/functions.sh"

# Load configurations
load_config "$PIMARCHY_ROOT/config/theme.conf"

# Set derived variables
SCRIPT_DIR="$HOME/.config/hypr"
export COLOR_PRIMARY_HEX="${COLOR_PRIMARY#\#}"
export COLOR_SURFACE_HEX="${COLOR_SURFACE#\#}"
export COLOR_BASE_HEX="${COLOR_BASE#\#}"

# Detect keyboard layout
export KEYBOARD_LAYOUT=$(detect_keyboard_layout)
log_info "Detected keyboard layout: $KEYBOARD_LAYOUT"

if [ "$DRY_RUN" = true ]; then
    echo "=== Pimarchy Installer (DRY RUN) ==="
    echo ""
    echo "This is a dry run. No changes will be made."
    echo ""
else
    echo "=== Pimarchy Installer ==="
    echo ""
    read -p "This will install Pimarchy and modify your desktop configuration. Continue? [y/N] " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "Cancelled."
        exit 0
    fi
fi

echo "[1/6] Backing up current configuration..."
if [ "$DRY_RUN" = false ]; then
    backup_configs
else
    log_info "Would backup current configs to $BACKUP_DIR"
fi

# -------------------------------------------------------------
# 2. Install dependencies
# -------------------------------------------------------------
echo "[2/6] Installing packages..."
if [ "$DRY_RUN" = false ]; then
    install_packages
else
    log_info "Would install: waybar, rofi-wayland, mako, and other packages"
fi

# -------------------------------------------------------------
# 3. Create config directories
# -------------------------------------------------------------
echo "[3/6] Creating config directories..."
if [ "$DRY_RUN" = false ]; then
    create_config_dirs
else
    log_info "Would create config directories in ~/.config/"
fi

# -------------------------------------------------------------
# 4. Process and install module configurations
# -------------------------------------------------------------
echo "[4/6] Installing module configurations..."

# Read module manifest and process each template
# Use fd 3 to avoid consuming stdin (which may be piped for the confirmation prompt)
while IFS='|' read -r module template target description <&3; do
    # Skip empty lines and comments
    [[ -z "$module" || "$module" =~ ^# ]] && continue
    
    template_path="$PIMARCHY_ROOT/config/$template"
    target_path="${target/#\~/$HOME}"
    
    if [ "$DRY_RUN" = false ]; then
        log_info "Installing: $description"
        process_template "$template_path" "$target_path"
        
        # Make scripts executable
        if [[ "$target" == *.sh ]]; then
            chmod +x "$target_path"
        fi
    else
        log_info "Would install: $description -> $target_path"
        # Check template for undefined variables in dry-run mode
        undefined_vars=()
        while IFS= read -r line; do
            remaining="$line"
            while [[ $remaining =~ \{\{([A-Za-z_][A-Za-z0-9_]*)\}\} ]]; do
                var_name="${BASH_REMATCH[1]}"
                if [ -z "${!var_name+x}" ]; then
                    undefined_vars+=("$var_name")
                fi
                remaining="${remaining#*\}\}}"
            done
        done < "$template_path"
        
        if [ ${#undefined_vars[@]} -gt 0 ]; then
            log_warn "Undefined variables in template: ${undefined_vars[*]}"
        fi
    fi
done 3< "$PIMARCHY_ROOT/config/modules.conf"

# -------------------------------------------------------------
# 5. Install additional scripts and settings
# -------------------------------------------------------------
echo "[5/6] Installing additional components..."

if [ "$DRY_RUN" = false ]; then
    # Initialize workspace state file (not used by hyprland but keep for compatibility)
    echo "1" > /tmp/pimarchy-workspace
    
    # Apply gsettings
    apply_gsettings
    
    # Ensure Pictures directory exists for screenshots
    mkdir -p ~/Pictures
    
    # Chromium dark mode flags
    mkdir -p "$HOME/.config"
    echo '--force-dark-mode' > "$HOME/.config/chromium-flags.conf"
    echo '--enable-features=WebUIDarkMode' >> "$HOME/.config/chromium-flags.conf"

    # Configure Shell (source pimarchy aliases and start starship)
    if ! grep -q "bashrc.pimarchy" "$HOME/.bashrc"; then
        echo "" >> "$HOME/.bashrc"
        echo "# Pimarchy configuration" >> "$HOME/.bashrc"
        echo "[[ -f ~/.bashrc.pimarchy ]] && . ~/.bashrc.pimarchy" >> "$HOME/.bashrc"
        echo 'eval "$(starship init bash)"' >> "$HOME/.bashrc"
    fi
    
    # Set console keyboard layout
    if command -v localectl &> /dev/null; then
        sudo localectl set-keymap "$KEYBOARD_LAYOUT" 2>/dev/null || true
    fi
    
    # Create X11 keyboard configuration
    sudo mkdir -p /etc/X11/xorg.conf.d
    sudo tee /etc/X11/xorg.conf.d/00-keyboard.conf > /dev/null << EOF
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "$KEYBOARD_LAYOUT"
EndSection
EOF
    
    # Enable essential services
    sudo systemctl enable NetworkManager.service 2>/dev/null || true
    sudo systemctl enable bluetooth.service 2>/dev/null || true
else
    log_info "Would initialize workspace state, apply gsettings, and configure .bashrc"
fi


# -------------------------------------------------------------
# 5.5 Greetd Configuration
# -------------------------------------------------------------
echo "[5.5/6] Configuring greetd..."

if [ "$DRY_RUN" = false ]; then
    # Disable getty on tty1 to prevent conflict with greetd
    sudo systemctl disable getty@tty1.service 2>/dev/null || true
    sudo systemctl mask getty@tty1.service 2>/dev/null || true
    
    sudo mkdir -p /etc/greetd
    cat << 'GREETD' | sudo tee /etc/greetd/config.toml > /dev/null
[terminal]
vt = 1

[default_session]
command = "tuigreet --cmd Hyprland"
user = "_greetd"
GREETD
    sudo systemctl enable greetd 2>/dev/null || true
    sudo systemctl set-default graphical.target 2>/dev/null || true
    log_success "greetd configured and enabled"
else
    log_info "Would configure greetd and disable getty@tty1"
fi

# -------------------------------------------------------------
# 6. Finalize
# -------------------------------------------------------------
echo "[6/6] Finalizing installation..."

if [ "$DRY_RUN" = false ]; then
    echo ""
    echo "=== Pimarchy installation complete! ==="
    echo ""
    echo "Log out and log back in to activate."
    echo ""
    echo "Keyboard shortcuts:"
    echo "  SUPER+D        App launcher (Rofi)"
    echo "  SUPER+Return   Terminal"
    echo "  SUPER+E        File Manager"
    echo "  SUPER+Q        Close window"
    echo "  SUPER+F        Toggle fullscreen"
    echo "  SUPER+V        Toggle floating window"
    echo "  SUPER+Arrows   Move focus"
    echo "  SUPER+1-0      Switch to workspace 1-10"
    echo "  SUPER+SHIFT+1-0 Move window to workspace 1-10"
    echo "  Print          Screenshot (Select region)"
    echo "  SHIFT+Print    Screenshot (Full screen)"
    echo ""
    echo "Bar actions:"
    echo "  Click clock          Toggle date/time format"
    echo "  Click workspaces     Cycle to next workspace"
    echo "  Right-click workspaces Cycle to previous workspace"
    echo "  Right-click WiFi     Open network settings"
    echo "  Click volume         Open audio mixer"
    echo "  Scroll on volume    Adjust volume"
    echo "  Click power icon     Power menu (shutdown/reboot/logout)"
    echo ""
    echo "To customize keybinds:   Edit ~/.config/hypr/hyprland.conf"
    echo "To customize theme:      Edit config/theme.conf and run install.sh"
    echo "To uninstall:            bash uninstall.sh"
    echo ""
else
    echo ""
    echo "=== Dry run complete ==="
    echo ""
    echo "No changes were made. Run without --dry-run to install."
    echo ""
fi


