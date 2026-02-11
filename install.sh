#!/bin/bash
#
# Pimarchy Installer for Raspberry Pi 5 (Labwc + Waybar)
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

# Source library functions
source "$PIMARCHY_ROOT/lib/functions.sh"

# Load configurations
load_config "$PIMARCHY_ROOT/config/theme.conf"
load_config "$PIMARCHY_ROOT/config/keybinds/keybinds.conf"

# Set derived variables
SCRIPT_DIR="$HOME/.config/labwc"

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

# -------------------------------------------------------------
# 1. Backup existing configs
# -------------------------------------------------------------
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
    log_info "Would install: waybar, wofi, mako-notifier, and other packages"
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
    # Initialize workspace state file
    echo "1" > /tmp/pimarchy-workspace
    
    # Apply gsettings
    apply_gsettings
    
    # Hide desktop trash icon
    hide_trash_icon
    
    # Ensure Pictures directory exists for screenshots
    mkdir -p ~/Pictures
    
    # Chromium dark mode flags
    echo 'export CHROMIUM_FLAGS="$CHROMIUM_FLAGS --force-dark-mode --enable-features=WebUIDarkMode"' | \
        sudo tee /etc/chromium.d/pimarchy-dark > /dev/null
else
    log_info "Would initialize workspace state, apply gsettings, etc."
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
    echo "  $KEYBIND_LAUNCHER        App launcher (Wofi)"
    echo "  $KEYBIND_TERMINAL        Terminal"
    echo "  $KEYBIND_BROWSER         Browser (chromium)"
    echo "  $KEYBIND_CLOSE_1/$KEYBIND_CLOSE_2      Close window"
    echo "  $KEYBIND_FULLSCREEN        Toggle fullscreen"
    echo "  $KEYBIND_NEXT_WINDOW      Switch to next window"
    echo "  $KEYBIND_PREV_WINDOW      Switch to previous window"
    echo "  $KEYBIND_ALL_WINDOW      Switch windows (all desktops)"
    echo "  $KEYBIND_MINIMIZE        Minimize window"
    echo "  $KEYBIND_MAXIMIZE        Maximize window"
    echo "  W-Down       Minimize window"
    echo "  $KEYBIND_SNAP_LEFT       Snap window left (tile)"
    echo "  $KEYBIND_SNAP_RIGHT      Snap window right (tile)"
    echo "  $KEYBIND_CENTER        Center window"
    echo "  W-1-6        Switch to workspace 1-6"
    echo "  W-S-1-6      Move window to workspace 1-6"
    echo "  $KEYBIND_SCREENSHOT_FULL        Screenshot (full screen)"
    echo "  $KEYBIND_SCREENSHOT_REGION      Screenshot (select region)"
    echo ""
    echo "Bar actions:"
    echo "  Click clock          Toggle date/time format"
    echo "  Click workspaces     Cycle to next workspace"
    echo "  Right-click workspaces Cycle to previous workspace"
    echo "  Right-click WiFi     Open network settings"
    echo "  Click volume         Open PulseAudio mixer"
    echo "  Scroll on volume     Adjust volume"
    echo "  Click power icon     Power menu (shutdown/reboot/logout)"
    echo ""
    echo "To customize keybinds:   Edit config/keybinds/keybinds.conf"
    echo "To customize theme:      Edit config/theme.conf"
    echo "To uninstall:            bash uninstall.sh"
    echo ""
else
    echo ""
    echo "=== Dry run complete ==="
    echo ""
    echo "No changes were made. Run without --dry-run to install."
    echo ""
fi
