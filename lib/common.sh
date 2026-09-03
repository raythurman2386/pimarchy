#!/bin/bash
#
# Pimarchy Library — Shared Paths & Constants
# Sourced by lib/functions.sh (the aggregator); safe to source directly.
#

# Repo layout (resolved from this file's location so symlinks work)
PIMARCHY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PIMARCHY_ROOT="${PIMARCHY_ROOT:-$PIMARCHY_DIR}"
CONFIG_DIR="$PIMARCHY_DIR/config"
LIB_DIR="$PIMARCHY_DIR/lib"

# Package module lists (config/packages/*.list)
PACKAGE_LIST_DIR="$CONFIG_DIR/packages"

# User state (XDG-aware — must match the resolution in bin/pimarchy-* wrappers)
BACKUP_DIR="$HOME/.config/Pimarchy-backup"
PIMARCHY_USER_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/pimarchy"
PIMARCHY_DEFAULTS_DIR="$PIMARCHY_USER_DIR/defaults"
PIMARCHY_MANIFEST_FILE="$PIMARCHY_USER_DIR/manifest"

# System config paths
HYPRLAND_DIR="$HOME/.config/hypr"
WAYBAR_DIR="$HOME/.config/waybar"
ROFI_DIR="$HOME/.config/rofi"
MAKO_DIR="$HOME/.config/mako"
GTK3_DIR="$HOME/.config/gtk-3.0"
TERMINAL_DIR="$HOME/.config/foot"