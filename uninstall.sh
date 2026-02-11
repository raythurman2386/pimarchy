#!/bin/bash
#
# Pimarchy Uninstaller for Raspberry Pi 5
# Reverts the system back to the default Raspberry Pi desktop.
#
# Usage: bash uninstall.sh
#

set -e

# Get script directory
PIMARCHY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source library functions
source "$PIMARCHY_ROOT/lib/functions.sh"

echo "=== Pimarchy Uninstaller ==="
echo ""
echo "This will revert your desktop to the default Raspberry Pi configuration."
echo ""
read -p "Continue? [y/N] " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Cancelled."
    exit 0
fi

# -------------------------------------------------------------
# 1. Stop Pimarchy services
# -------------------------------------------------------------
echo "[1/5] Stopping Pimarchy services..."
stop_services

# -------------------------------------------------------------
# 2. Remove Pimarchy config files
# -------------------------------------------------------------
echo "[2/5] Removing Pimarchy configuration..."
remove_pimarchy_files

# -------------------------------------------------------------
# 3. Restore backups
# -------------------------------------------------------------
echo "[3/5] Restoring original configuration..."
if ! restore_configs; then
    log_warn "Restoring default system behavior..."
    # Remove the autostart override so system autostart takes effect
    rm -f ~/.config/labwc/autostart
fi

# Additional cleanup: ensure no duplicate autostart
if [ -f ~/.config/labwc/autostart ] && [ -f /etc/xdg/labwc/autostart ]; then
    if diff -q ~/.config/labwc/autostart /etc/xdg/labwc/autostart > /dev/null 2>&1; then
        log_info "Removing duplicate user autostart (identical to system)"
        rm -f ~/.config/labwc/autostart
    fi
fi

# Reset gsettings
reset_gsettings

# Restore trash icon
show_trash_icon

# -------------------------------------------------------------
# 4. Optionally remove packages
# -------------------------------------------------------------
echo ""
read -p "Remove packages installed by Pimarchy? (waybar, wofi, mako, arc-theme, etc.) [y/N] " remove_pkgs
if [ "$remove_pkgs" = "y" ] || [ "$remove_pkgs" = "Y" ]; then
    echo "[4/5] Removing packages..."
    remove_packages
    echo "  Packages removed."
else
    echo "[4/5] Keeping packages (skipped)."
fi

# -------------------------------------------------------------
# 5. Clean up backup directory
# -------------------------------------------------------------
echo ""
read -p "Remove backup files in $BACKUP_DIR? [y/N] " remove_backup
if [ "$remove_backup" = "y" ] || [ "$remove_backup" = "Y" ]; then
    rm -rf "$BACKUP_DIR"
    echo "[5/5] Backup directory removed."
else
    echo "[5/5] Keeping backup directory."
fi

echo ""
echo "=== Pimarchy has been uninstalled ==="
echo ""
echo "Log out and log back in to restore the default Raspberry Pi desktop."
echo "The default wf-panel-pi bottom bar will return on next login."
echo ""
echo "Note: If you see duplicate panels after logging back in, run:"
echo "  rm ~/.config/labwc/autostart"
echo "  pkill -f wf-panel-pi"
echo "Then log out and back in again."
