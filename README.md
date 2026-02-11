# Pimarchy for Raspberry Pi 5

A lightweight, aesthetic Omarchy-inspired desktop transformation for Raspberry Pi 5 running Debian Bookworm with labwc.

![Pimarchy Preview](screenshot.png)

**Full Documentation**: See [`PIMARCHY_DOCS.md`](./PIMARCHY_DOCS.md) for complete user guide, troubleshooting, and customization options.

---

## Quick Start

**Install:**
```bash
bash ~/pimarchy/install.sh
```

**Uninstall:**
```bash
bash ~/pimarchy/uninstall.sh
```

## Project Structure

Pimarchy now uses a modular, omarchy-style configuration structure:

```
pimarchy/
├── install.sh              # Main installer script
├── uninstall.sh            # Uninstaller script
├── README.md               # This file
├── PIMARCHY_DOCS.md        # Full documentation
├── config/                 # All configuration templates
│   ├── modules.conf        # Module manifest (what gets installed)
│   ├── theme.conf          # Theme settings (colors, fonts, icons)
│   ├── keybinds/           # Keybind configuration
│   │   └── keybinds.conf   # Customizable keyboard shortcuts
│   ├── labwc/              # Labwc window manager configs
│   │   ├── rc.xml.template
│   │   ├── autostart.template
│   │   ├── power-menu.sh
│   │   ├── workspace-display.sh.template
│   │   └── workspace-click.sh.template
│   ├── waybar/             # Waybar bar configs
│   │   ├── config.jsonc.template
│   │   └── style.css.template
│   ├── wofi/               # Wofi launcher configs
│   │   ├── config.template
│   │   └── style.css.template
│   ├── mako/               # Mako notification configs
│   │   └── config.template
│   ├── gtk/                # GTK theming configs
│   │   ├── settings.ini.template
│   │   ├── gtkrc-2.0.template
│   │   └── environment.template
│   └── terminal/           # Terminal configs
│       └── lxterminal.conf.template
├── lib/                    # Shared library functions
│   └── functions.sh        # Common install/uninstall functions
└── bin/                    # Additional executables (if needed)
```

## Customization

### Keybinds

Edit `config/keybinds/keybinds.conf` to customize keyboard shortcuts:

```bash
# Example: Change launcher from Win+D to Win+Space
KEYBIND_LAUNCHER="W-space"

# Example: Change terminal from Win+Enter to Win+T
KEYBIND_TERMINAL="W-t"
```

After editing, re-run `install.sh` to apply changes.

### Themes

Edit `config/theme.conf` to customize:
- Colors (Catppuccin Mocha by default)
- Fonts
- Icons
- Waybar appearance
- Notification styling

### Adding/Removing Components

Edit `config/modules.conf` to add or remove modules from installation:

```bash
# Comment out to skip a module:
# waybar|waybar/config.jsonc.template|~/.config/waybar/config.jsonc|Waybar configuration
```

## What's Included

- **Waybar**: Floating translucent pill-shaped top bar with Nerd Font icons
- **Workspace Boxes**: Clickable workspace indicators in the top bar
- **Wofi**: Centered app launcher (Win+D)
- **Mako**: Top-right notification daemon
- **Tiling**: Snap windows left/right/center like a tiling WM
- **Workspaces**: 6 workspaces with keyboard switching
- **Custom keybindings**: Window management, screenshots, app launching

## Keyboard Shortcuts

### Application Launching
- `Win + D` - App launcher (Wofi)
- `Win + Enter` - Open terminal (lxterminal)
- `Win + Shift + B` - Open browser (chromium-browser)

### Window Management
- `Win + Q` or `Win + W` - Close focused window
- `Win + F` - Toggle fullscreen
- `Alt + Tab` - Switch to next window
- `Alt + Shift + Tab` - Switch to previous window
- `Win + Tab` - Switch windows (all desktops)
- `Win + M` - Minimize window
- `Win + Up` - Maximize window
- `Win + Down` - Minimize window

### Tiling
- `Win + Left` - Snap window to left half
- `Win + Right` - Snap window to right half
- `Win + C` - Center window
- `Win + Ctrl + Up/Down/Left/Right` - Edge snap

### Workspaces
- `Win + 1-6` - Switch to workspace 1-6
- `Win + Shift + 1-6` - Move window to workspace 1-6

### Screenshots
- `Print` - Screenshot full screen (saved to ~/Pictures/)
- `Win + Shift + S` - Screenshot selected region

## Top Bar (Waybar)

**Left:**
- 󰀻 Launcher icon - Click to open Wofi app launcher
- [1][2][3][4][5][6] Workspace boxes - Click to switch, active glows blue

**Center:**
- 󰥔 Clock - Shows time (click to toggle date format)

**Right:**
- 󰻠 CPU usage percentage
- 󰍛 Memory usage percentage
- 󰤨 WiFi network name (󰈀 for ethernet, 󰤭 when disconnected)
- Volume icon with level - Click to open PulseAudio mixer, scroll to adjust
- System tray (for app icons)
- 󰐥 Power icon - Click for shutdown/reboot/logout menu

## Click Actions

- **Clock**: Toggle between time and date format
- **WiFi (right-click)**: Open network settings (nm-connection-editor)
- **Volume**: Open PulseAudio mixer (pavucontrol)
- **Power icon**: Open power menu (shutdown/reboot/logout)

## Icons Used (Nerd Font)

- 󰀻 - Launcher
- 󰥔 - Clock/Time
- 󰃭 - Calendar/Date
- 󰻠 - CPU
- 󰍛 - Memory
- 󰤨 - WiFi connected
- 󰈀 - Ethernet
- 󰤭 - Disconnected
- 󰕿 - Volume low
- 󰖀 - Volume medium
- 󰕾 - Volume high
- 󰝟 - Volume muted
- 󰐥 - Power

## Files Created

```
~/.config/labwc/rc.xml           # Window theme + keybindings
~/.config/labwc/autostart        # Startup script (replaces system)
~/.config/labwc/power-menu.sh    # Power menu script
~/.config/labwc/workspace-display.sh
~/.config/labwc/workspace-click.sh
~/.config/waybar/config.jsonc    # Bar configuration
~/.config/waybar/style.css       # Bar styling (Catppuccin theme)
~/.config/wofi/config            # Launcher configuration
~/.config/wofi/style.css         # Launcher styling
~/.config/mako/config            # Notification configuration
```

## Backup Location

Backups are saved to: `~/.config/Pimarchy-backup/`

## Requirements

- Raspberry Pi 5
- Debian Bookworm (64-bit)
- labwc compositor (default on Pi 5)
- CaskaydiaCove Nerd Font (should be installed)

## Documentation

- **Quick Reference** (this file): Essential shortcuts and features
- **Full Documentation**: [`PIMARCHY_DOCS.md`](./PIMARCHY_DOCS.md) - Complete guide with:
  - Detailed module descriptions
  - Troubleshooting section
  - Customization instructions
  - Icon reference
  - Workflow tips

## Migration from Old Version

If you were using the old single-file installer:
1. Run `bash uninstall.sh` first to clean up
2. Update your local repository with the new structure
3. Run `bash install.sh` to install with the new modular system

Your customizations from the old `keybinds.conf` and `theme.conf` files will be preserved if you copy them to the new `config/` directory.

## Notes

- Log out and back in after installation to activate
- The default wf-panel-pi bottom bar is replaced by Waybar
- Desktop icons remain functional via pcmanfm
- Screenshots are saved to ~/Pictures/
