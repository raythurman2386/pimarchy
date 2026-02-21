#!/bin/bash
#
# Pimarchy Installer for Raspberry Pi 500 (Pi OS/Debian + Hyprland)
# A lightweight, aesthetic Omarchy-inspired desktop transformation.
#
# This modular installer reads configuration from config/ directory
# and applies templates with user-customizable settings.
#
# Usage: bash install.sh [OPTIONS]
#
# Options:
#   --dry-run         Show what would be installed without making changes
#   --performance     Set CPU governor to 'performance' (no overclock, safe default)
#   --overclock       Set CPU governor AND apply arm_freq=2600 overclock (requires cooling)
#   -h, --help        Show this help message
#

set -e

# Parse arguments
DRY_RUN=false
PERF_MODE=""   # "governor", "overclock", or "" (prompt interactively)

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --performance)
            PERF_MODE="governor"
            shift
            ;;
        --overclock)
            PERF_MODE="overclock"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --dry-run       Show what would be installed without making changes"
            echo "  --performance   Set CPU governor to 'performance' (no overclock)"
            echo "                  Keeps the CPU at max clock without disabling DVFS."
            echo "                  Safe on all Pi 5 / Pi 500 units."
            echo "  --overclock     Governor + arm_freq=2600 mild overclock (2.6 GHz)"
            echo "                  Requires an active cooler or adequate ventilation."
            echo "                  Only applies on Pi 5 / Pi 500 hardware."
            echo "  -h, --help      Show this help message"
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
    read -p "This will install Pimarchy and modify your desktop configuration. Continue? [y/N] " confirm || true
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "Cancelled."
        exit 0
    fi
fi

echo "[1/7] Backing up current configuration..."
if [ "$DRY_RUN" = false ]; then
    backup_configs
else
    log_info "Would backup current configs to $BACKUP_DIR"
fi

# -------------------------------------------------------------
# 2. Install dependencies
# -------------------------------------------------------------
echo "[2/7] Installing packages..."
if [ "$DRY_RUN" = false ]; then
    install_packages
else
    log_info "Would install: waybar, rofi, mako, hyprland, btop, and other packages"
fi

# -------------------------------------------------------------
# 3. Create config directories
# -------------------------------------------------------------
echo "[3/7] Creating config directories..."
if [ "$DRY_RUN" = false ]; then
    create_config_dirs
else
    log_info "Would create config directories in ~/.config/"
fi

# -------------------------------------------------------------
# 4. Process and install module configurations
# -------------------------------------------------------------
echo "[4/7] Installing module configurations..."

# Read module manifest and process each template.
# Use fd 3 so the while-loop's stdin does not shadow the confirmation prompts
# above (which read from fd 0 / the terminal) or any future reads inside the loop.
while IFS='|' read -r module template target description <&3; do
    # Skip empty lines and comments
    [[ -z "$module" || "$module" =~ ^# ]] && continue
    
    template_path="$PIMARCHY_ROOT/config/$template"
    target_path="${target/#\~/$HOME}"
    
    if [ "$DRY_RUN" = false ]; then
        log_info "Installing: $description"
        if [[ "$template" == *.template ]]; then
            process_template "$template_path" "$target_path"
        else
            mkdir -p "$(dirname "$target_path")"
            cp "$template_path" "$target_path"
            log_success "Copied: $target_path"
        fi
        
        # Make scripts executable
        if [[ "$target" == *.sh ]]; then
            chmod +x "$target_path"
        fi
    else
        log_info "Would install: $description -> $target_path"
        if [[ "$template" == *.template ]]; then
            # Check template for undefined variables in dry-run mode
            local_undefined_vars=()
            while IFS= read -r line; do
                remaining="$line"
                while [[ $remaining =~ \{\{([A-Za-z_][A-Za-z0-9_]*)\}\} ]]; do
                    var_name="${BASH_REMATCH[1]}"
                    if [ -z "${!var_name+x}" ]; then
                        local_undefined_vars+=("$var_name")
                    fi
                    remaining="${remaining#*\}\}}"
                done
            done < "$template_path"
            
            if [ ${#local_undefined_vars[@]} -gt 0 ]; then
                log_warn "Undefined variables in template: ${local_undefined_vars[*]}"
            fi
        else
            log_info "Would copy: $template_path -> $target_path"
        fi
    fi
done 3< "$PIMARCHY_ROOT/config/modules.conf"

# -------------------------------------------------------------
# 5. Install additional scripts and settings
# -------------------------------------------------------------
echo "[5/7] Installing additional components..."

if [ "$DRY_RUN" = false ]; then
    # Initialize workspace state file
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
# 6. Greetd Configuration
# -------------------------------------------------------------
echo "[6/7] Configuring greetd..."

if [ "$DRY_RUN" = false ]; then
    # Install Hyprland startup wrapper to /usr/local/bin
    log_info "Installing Hyprland startup wrapper..."
    temp_wrapper=$(mktemp)
    # Ensure temp file is always cleaned up, even on error
    trap 'rm -f "$temp_wrapper"' EXIT
    process_template "$PIMARCHY_ROOT/config/hypr/start-hyprland.sh.template" "$temp_wrapper"
    sudo cp "$temp_wrapper" /usr/local/bin/start-hyprland
    # Ensure it is readable and executable by all users (including _greetd)
    sudo chmod 755 /usr/local/bin/start-hyprland
    # Trap has cleaned up by here; clear it so it doesn't fire on normal exit
    trap - EXIT
    rm -f "$temp_wrapper"

    # Disable getty on tty1 to prevent conflict with greetd
    sudo systemctl disable getty@tty1.service 2>/dev/null || true
    sudo systemctl mask getty@tty1.service 2>/dev/null || true
    
    sudo mkdir -p /etc/greetd
    cat << 'GREETD' | sudo tee /etc/greetd/config.toml > /dev/null
[terminal]
# Use vt7 to avoid systemd boot messages bleeding into the greeter
vt = 7

[default_session]
# --time forces a redraw every second to ensure the screen stays clean
command = "tuigreet --time --remember --remember-session --cmd /usr/local/bin/start-hyprland"
user = "_greetd"
GREETD
    sudo systemctl enable greetd 2>/dev/null || true
    sudo systemctl set-default graphical.target 2>/dev/null || true
    log_success "greetd and start-hyprland configured"
else
    log_info "Would install start-hyprland to /usr/local/bin and configure greetd"
fi

# -------------------------------------------------------------
# 6b. CPU Performance Configuration (opt-in)
# -------------------------------------------------------------
if [ "$DRY_RUN" = false ]; then
    # If no flag was passed, ask the user interactively
    if [ -z "$PERF_MODE" ]; then
        echo ""
        echo "--- CPU Performance Mode ---"
        echo "  g) Governor only  — CPU stays at max clock, DVFS still manages voltage."
        echo "                      Safe on all Pi 5 / Pi 500 units. No reboot needed."
        echo "  o) Overclock      — Governor + arm_freq=2600 (2.6 GHz, up from 2.4 GHz)."
        echo "                      Requires an active cooler. Reboot required."
        echo "  N) Skip           — Leave CPU settings unchanged."
        echo ""
        read -p "Configure CPU performance? [g/o/N] " perf_choice || true
        case "$perf_choice" in
            g|G) PERF_MODE="governor" ;;
            o|O) PERF_MODE="overclock" ;;
            *)   PERF_MODE="skip" ;;
        esac
    fi

    case "$PERF_MODE" in
        governor)
            configure_governor
            ;;
        overclock)
            configure_governor
            configure_overclock
            ;;
        skip|"")
            log_info "Skipping CPU performance configuration"
            ;;
    esac
else
    case "$PERF_MODE" in
        governor)  log_info "Would configure CPU governor to 'performance'" ;;
        overclock) log_info "Would configure CPU governor and apply arm_freq=2600 overclock" ;;
        *)         log_info "Would prompt for CPU performance mode" ;;
    esac
fi

# -------------------------------------------------------------
# 7. Finalize
# -------------------------------------------------------------
echo "[7/7] Finalizing installation..."

if [ "$DRY_RUN" = false ]; then
    echo ""
    echo "=== Pimarchy installation complete! ==="
    echo ""
    echo "Log out and log back in to activate."
    echo ""
    echo "Keyboard shortcuts:"
    echo "  SUPER+D          App launcher (Rofi)"
    echo "  SUPER+Return     Terminal"
    echo "  SUPER+E          File Manager"
    echo "  SUPER+M          System monitor (btop)"
    echo "  SUPER+W          Close window"
    echo "  SUPER+SHIFT+B    Open Chromium"
    echo "  SUPER+F          Toggle fullscreen"
    echo "  SUPER+V          Toggle floating window"
    echo "  SUPER+Arrows     Move focus"
    echo "  SUPER+1-0        Switch to workspace 1-10"
    echo "  SUPER+SHIFT+1-0  Move window to workspace 1-10"
    echo "  Print            Screenshot (Select region)"
    echo "  SHIFT+Print      Screenshot (Full screen)"
    echo ""
    echo "Bar actions:"
    echo "  Click clock          Toggle date/time format"
    echo "  Click workspaces     Cycle to next workspace"
    echo "  Right-click workspaces Cycle to previous workspace"
    echo "  Right-click WiFi     Open network settings"
    echo "  Click volume         Open audio mixer"
    echo "  Scroll on volume     Adjust volume"
    echo "  Click CPU/Memory     Open system monitor (btop)"
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
