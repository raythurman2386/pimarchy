#!/bin/bash
#
# Pimarchy Migration Helper
# Creates proper backups before migrating to the new modular system
#

set -e

BACKUP_DIR="$HOME/.config/Pimarchy-backup"
BETA_BACKUP_DIR="$BACKUP_DIR/beta-$(date +%Y%m%d-%H%M%S)"

echo "=== Pimarchy Migration Helper ==="
echo ""
echo "This will create proper backups of your current setup."
echo ""

# Create backup directories
mkdir -p "$BACKUP_DIR"
mkdir -p "$BETA_BACKUP_DIR"

echo "[1/3] Backing up your current 'beta' Pimarchy setup..."

# Backup current Pimarchy configs
for dir in labwc waybar wofi mako gtk-3.0 alacritty; do
    if [ -d "$HOME/.config/$dir" ]; then
        echo "  Backing up ~/.config/$dir (beta)"
        cp -r "$HOME/.config/$dir" "$BETA_BACKUP_DIR/${dir}.bak"
    fi
done

# Backup GTK2 config
if [ -f "$HOME/.gtkrc-2.0" ]; then
    echo "  Backing up ~/.gtkrc-2.0 (beta)"
    cp "$HOME/.gtkrc-2.0" "$BETA_BACKUP_DIR/gtkrc-2.0.bak"
fi

# Backup pcmanfm desktop config
if [ -d "$HOME/.config/pcmanfm" ]; then
    echo "  Backing up ~/.config/pcmanfm (beta)"
    cp -r "$HOME/.config/pcmanfm" "$BETA_BACKUP_DIR/pcmanfm.bak"
fi

echo ""
echo "[2/3] Creating 'original' system configuration backup..."

# Check if we already have an original backup
if [ -f "$BACKUP_DIR/.original-backup" ]; then
    echo "  Original backup already exists, skipping..."
else
    # Create original backup from system defaults + autostart.system
    
    # Labwc - use system defaults + autostart.system
    mkdir -p "$BACKUP_DIR/labwc.bak"
    
    # Copy system rc.xml and environment
    if [ -f /etc/xdg/labwc/rc.xml ]; then
        echo "  Saving system rc.xml"
        cp /etc/xdg/labwc/rc.xml "$BACKUP_DIR/labwc.bak/"
    fi
    
    if [ -f /etc/xdg/labwc/environment ]; then
        echo "  Saving system environment"
        cp /etc/xdg/labwc/environment "$BACKUP_DIR/labwc.bak/"
    fi
    
    # Save the autostart.system as the original autostart
    if [ -f "$HOME/.config/labwc/autostart.system" ]; then
        echo "  Saving original autostart from autostart.system"
        cp "$HOME/.config/labwc/autostart.system" "$BACKUP_DIR/labwc.bak/autostart"
    fi
    
    # Create the original backup marker
    cat > "$BACKUP_DIR/.original-backup" << EOF
Original Raspberry Pi System Configuration Backup
Created: $(date)

This backup contains the original system defaults before any Pimarchy installation.
It can be used to restore the default Raspberry Pi desktop.

Files backed up:
- /etc/xdg/labwc/rc.xml (system window manager config)
- /etc/xdg/labwc/environment (system environment)
- ~/.config/labwc/autostart.system (original autostart)
EOF
    
    echo "  Original backup created successfully"
fi

echo ""
echo "[3/3] Creating manifest of your beta tweaks..."

# Create a manifest showing what's different
cat > "$BETA_BACKUP_DIR/MANIFEST.txt" << EOF
Beta Pimarchy Configuration Backup
Created: $(date)

This backup contains your customized Pimarchy setup with all tweaks.

BACKUP LOCATION: $BETA_BACKUP_DIR

RESTORE BETA SETUP:
  To restore your beta configuration, run:
  cp -r $BETA_BACKUP_DIR/labwc.bak/* ~/.config/labwc/
  cp -r $BETA_BACKUP_DIR/waybar.bak/* ~/.config/waybar/
  cp -r $BETA_BACKUP_DIR/wofi.bak/* ~/.config/wofi/
  cp -r $BETA_BACKUP_DIR/mako.bak/* ~/.config/mako/
  
  # Also restore these if they exist:
  cp $BETA_BACKUP_DIR/gtkrc-2.0.bak ~/.gtkrc-2.0
  cp -r $BETA_BACKUP_DIR/gtk-3.0.bak/* ~/.config/gtk-3.0/
  cp -r $BETA_BACKUP_DIR/alacritty.bak/* ~/.config/alacritty/

FILES BACKED UP:
EOF

# List what was backed up
for item in labwc waybar wofi mako gtk-3.0 alacritty pcmanfm gtkrc-2.0; do
    if [ -e "$BETA_BACKUP_DIR/${item}.bak" ]; then
        echo "  - ${item}" >> "$BETA_BACKUP_DIR/MANIFEST.txt"
    fi
done

echo "  Manifest created at $BETA_BACKUP_DIR/MANIFEST.txt"

echo ""
echo "=== Migration Backup Complete ==="
echo ""
echo "Backup Locations:"
echo "  Original System: $BACKUP_DIR/"
echo "  Beta Tweaks:     $BETA_BACKUP_DIR/"
echo ""
echo "Your setup is now safe to migrate!"
echo ""
echo "Next steps:"
echo "  1. Review your current tweaks in $BETA_BACKUP_DIR/"
echo "  2. Edit the new modular config files to match your tweaks"
echo "  3. Run: bash install.sh"
echo "  4. If anything goes wrong, restore with:"
echo "     bash -c 'cp -r $BETA_BACKUP_DIR/labwc.bak/* ~/.config/labwc/'"
echo ""
