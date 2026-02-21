#!/bin/bash
#
# Pimarchy Uninstaller for Raspberry Pi 500
# Reverts the system back to the default Pi OS/Debian state.
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
echo "This will revert your desktop to the pre-Pimarchy configuration."
echo ""
read -p "Continue? [y/N] " confirm || true
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Cancelled."
    exit 0
fi

# -------------------------------------------------------------
# 1. Stop Pimarchy services
# -------------------------------------------------------------
echo "[1/5] Stopping Pimarchy services..."
stop_services
revert_swaybg

# -------------------------------------------------------------
# 2. Remove Pimarchy config files
# -------------------------------------------------------------
echo "[2/5] Removing Pimarchy configuration..."
remove_pimarchy_files

# Clean up .bashrc — remove the entire Pimarchy block including the blank
# line prepended before the comment, and the starship eval line.
if grep -q "bashrc.pimarchy" "$HOME/.bashrc"; then
    # Remove from the blank line before "# Pimarchy configuration" through
    # the starship init line (inclusive). The /^$/{N;/# Pimarchy/...} pattern
    # catches the leading blank line inserted by install.sh.
    sed -i '/^# Pimarchy configuration/,/starship init bash/{d}' "$HOME/.bashrc"
    # Also remove a blank line that immediately precedes where the block was
    # (install.sh writes a blank line, then the comment). We target a trailing
    # blank line left at end-of-file or sequences of blank lines > 1.
    sed -i -e '/^[[:space:]]*$/{N;/^\n$/d}' "$HOME/.bashrc" 2>/dev/null || true
fi

# -------------------------------------------------------------
# 3. Restore backups
# -------------------------------------------------------------
echo "[3/5] Restoring original configuration..."
restore_configs

# Reset gsettings
reset_gsettings

# -------------------------------------------------------------
# 4. Optionally remove packages
# -------------------------------------------------------------
echo ""
read -p "Remove packages installed by Pimarchy? (hyprland, waybar, rofi, mako, etc.) [y/N] " remove_pkgs || true
if [ "$remove_pkgs" = "y" ] || [ "$remove_pkgs" = "Y" ]; then
    echo "[4/5] Removing packages..."
    remove_packages
    remove_opencode
    echo "  Packages removed."
else
    echo "[4/5] Keeping packages (skipped)."
fi

# -------------------------------------------------------------
# 5. Clean up backup directory
# -------------------------------------------------------------
echo ""
read -p "Remove backup files in $BACKUP_DIR? [y/N] " remove_backup || true
if [ "$remove_backup" = "y" ] || [ "$remove_backup" = "Y" ]; then
    rm -rf "$BACKUP_DIR"
    echo "[5/5] Backup directory removed."
else
    echo "[5/5] Keeping backup directory."
fi

echo ""
echo "=== Pimarchy has been uninstalled ==="
echo ""
echo "Reboot to return to your standard Raspberry Pi OS CLI environment."
echo ""
