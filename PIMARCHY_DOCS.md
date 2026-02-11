# Pimarchy for Raspberry Pi 5

> A lightweight, aesthetic desktop transformation for Raspberry Pi 5 running Debian Bookworm with labwc.

![Pimarchy Preview](screenshot.png)

Pimarchy transforms the default Raspberry Pi desktop into a modern, minimal floating-bar experience inspired by Omarchy and Catppuccin themes. It replaces the stock bottom panel with a translucent pill-shaped top bar, adds a beautiful app launcher, and provides intuitive keyboard-driven window management.

---

## ✨ Features

- **🎨 Modern Aesthetic**: Catppuccin-inspired dark theme with translucent floating bar
- **⌨️ Keyboard-Driven**: Comprehensive shortcuts for window management and app launching
- **📊 System Monitoring**: Real-time CPU, memory, and network display
- **🔊 Audio Control**: Integrated volume with visual feedback and mixer access
- **📸 Screenshots**: Built-in full-screen and region capture
- **🔄 Fully Reversible**: Complete uninstall script restores original desktop
- **💾 Non-Destructive**: Backs up all original configurations

---

## 🚀 Quick Start

### Installation

```bash
bash ~/pimarchy/install.sh
```

**Then log out and log back in** to activate the new desktop environment.

### Uninstallation

```bash
bash ~/pimarchy/uninstall.sh
```

Follow the prompts to optionally remove packages and backup files. Log out and back in to restore the default Raspberry Pi desktop.

---

## ⌨️ Keyboard Shortcuts

### Application Launching

| Shortcut | Action |
|----------|--------|
| `Win + D` | Open app launcher (Wofi) |
| `Win + Enter` | Open terminal (lxterminal) |
| `Win + Shift + B` | Open browser (chromium-browser) |

### Window Management

| Shortcut | Action |
|----------|--------|
| `Win + Q` or `Win + W` | Close focused window |
| `Win + F` | Toggle fullscreen |
| `Alt + Tab` | Switch to next window |
| `Alt + Shift + Tab` | Switch to previous window |
| `Win + Tab` | Switch windows (all desktops) |
| `Win + M` | Minimize window |
| `Win + Up` | Maximize window |
| `Win + Down` | Minimize window |

### Tiling (Window Snapping)

| Shortcut | Action |
|----------|--------|
| `Win + Left` | Snap window to left half |
| `Win + Right` | Snap window to right half |
| `Win + C` | Center window |
| `Win + Ctrl + Left` | Edge snap left |
| `Win + Ctrl + Right` | Edge snap right |
| `Win + Ctrl + Up` | Edge snap up |
| `Win + Ctrl + Down` | Edge snap down |

### Workspaces

| Shortcut | Action |
|----------|--------|
| `Win + 1` through `Win + 6` | Switch to workspace 1-6 |
| `Win + Shift + 1` through `Win + Shift + 6` | Move focused window to workspace 1-6 |

### Screenshots

| Shortcut | Action |
|----------|--------|
| `Print` | Screenshot full screen (saved to `~/Pictures/`) |
| `Win + Shift + S` | Screenshot selected region |

---

## 🎛️ Top Bar (Waybar) Guide

The floating pill-shaped bar at the top of the screen provides system information and quick actions.

### Layout

```
[ 󰀻 ] [1][2][3][4][5][6]          [ 󰥔 2:30 PM ]          [ 󰻠 12% ] [ 󰍛 45% ] [ 󰤨 MyWiFi ] [ 󰕾 75% ] [tray] [ 󰐥 ]
```

### Modules

#### Left Side

**󰀻 Launcher** (`custom/launcher`)
- **Click**: Opens Wofi app launcher
- **Icon**: Nerd Font `nf-md-apps` (󰀻)

**[1-6] Workspaces** (`custom/workspaces`)
- **Display**: Numbered indicators for each workspace (1-6), rendered via custom script
- **Active workspace**: Shown in blue (#89b4fa) bold text
- **Inactive workspaces**: Shown in gray (#6c7086)
- **Click**: Cycle to next workspace
- **Right-click**: Cycle to previous workspace
- **Update**: Polls every 1 second (there may be a brief delay after switching)
- **How it works**: A state file (`/tmp/pimarchy-workspace`) is updated by keybinds; `workspace-display.sh` reads it and outputs Pango markup as JSON for waybar

#### Center

**󰥔 Clock** (`clock`)
- **Display**: Current time in 12-hour format (e.g., "2:30 PM")
- **Click**: Toggle between time and full date format
- **Alt format**: Shows "Monday, January 15"
- **Tooltip**: Calendar view on hover
- **Icons**: Clock (󰥔) and calendar (󰃭)

#### Right Side

**󰻠 CPU** (`cpu`)
- **Display**: CPU usage percentage
- **Update**: Every 5 seconds
- **Color**: Pink (#f38ba8)
- **Icon**: Nerd Font `nf-md-cpu_64_bit` (󰻠)

**󰍛 Memory** (`memory`)
- **Display**: RAM usage percentage
- **Update**: Every 5 seconds
- **Color**: Green (#a6e3a1)
- **Icon**: Nerd Font `nf-md-memory` (󰍛)

**󰤨 Network** (`network`)
- **WiFi connected**: `󰤨 NetworkName`
- **Ethernet**: `󰈀 eth0`
- **Disconnected**: `󰤭 Disconnected`
- **Right-click**: Opens network settings (nm-connection-editor)
- **Alt-click**: Shows IP address and CIDR
- **Color**: Teal (#94e2d5), gray when disconnected
- **Icons**: WiFi (󰤨), Ethernet (󰈀), Disconnected (󰤭)

**󰕾 Volume** (`pulseaudio`)
- **Display**: Volume icon + percentage level
- **Icons**:
  - `󰕿` Low volume
  - `󰖀` Medium volume
  - `󰕾` High volume
  - `󰝟` Muted
- **Click**: Opens PulseAudio mixer (pavucontrol)
- **Scroll**: Adjust volume up/down (5% steps)
- **Color**: Purple (#cba6f7), gray when muted

**Tray** (`tray`)
- **Purpose**: System tray for application icons
- **Icon size**: 16px
- **Features**: Supports passive dimming and attention highlighting

**󰐥 Power** (`custom/power`)
- **Click**: Opens power menu (shutdown/reboot/logout)
- **Color**: Red (#f38ba8)
- **Icon**: Nerd Font `nf-md-power` (󰐥)

### Power Menu

Clicking the power icon opens a menu with three options:

```
  Shutdown
  Reboot
  Logout
```

- **Shutdown**: Powers off the system
- **Reboot**: Restarts the system
- **Logout**: Exits the current session (returns to login screen)

---

## 🎨 Customization

### Application Theming

Pimarchy applies a consistent dark theme across all applications using multiple mechanisms:

#### GTK Theme: Arc-Dark

- **GTK3 Wayland apps**: Themed via `gsettings` commands in the autostart file (the primary mechanism for Wayland-native apps)
- **GTK3 XWayland apps**: Themed via `~/.config/gtk-3.0/settings.ini` (fallback for X11 apps)
- **GTK2 apps**: Themed via `~/.gtkrc-2.0`

**To change the GTK theme**, update all three locations:
1. Edit the `gsettings` lines in `~/.config/labwc/autostart`
2. Edit `~/.config/gtk-3.0/settings.ini`
3. Edit `~/.gtkrc-2.0`

#### Icon Theme: Papirus-Dark

Dark variant of the Papirus icon set. To change, update the same three locations as above (replace `Papirus-Dark` with your preferred icon theme).

#### Cursor Theme: Adwaita

Set in two places:
- `~/.config/labwc/environment` (for the compositor)
- `gsettings` / `settings.ini` / `.gtkrc-2.0` (for applications)

#### Terminal: Catppuccin Mocha

LXTerminal uses a custom Catppuccin Mocha color palette:
- **Background**: #1e1e2e (dark base)
- **Foreground**: #cdd6f4 (light lavender)
- **Font**: CaskaydiaCove Nerd Font Mono, size 11
- **Config**: `~/.config/lxterminal/lxterminal.conf`

To customize terminal colors, edit the `palette_color_*`, `bgcolor`, and `fgcolor` values in the config file.

#### Browser: Chromium Dark Mode

Chromium is forced into dark mode via flags in `/etc/chromium.d/pimarchy-dark`:
- `--force-dark-mode`: Dark browser chrome
- `--enable-features=WebUIDarkMode`: Dark internal pages (settings, new tab, etc.)

To disable Chromium dark mode, remove the file:
```bash
sudo rm /etc/chromium.d/pimarchy-dark
```

#### Font: CaskaydiaCove Nerd Font

- **Window titles**: CaskaydiaCove Nerd Font Mono, size 12 (set in `rc.xml`)
- **Applications / GTK**: CaskaydiaCove Nerd Font, size 11 (set via gsettings and settings.ini)
- **Terminal**: CaskaydiaCove Nerd Font Mono, size 11 (set in lxterminal.conf)
- **Waybar / Notifications**: CaskaydiaCove Nerd Font, size 13/11 (set in respective CSS/config files)

### Changing the Theme Colors

The default theme uses Catppuccin Mocha colors. To customize:

1. **Waybar colors**: Edit `~/.config/waybar/style.css`
2. **Wofi colors**: Edit `~/.config/wofi/style.css`
3. **Mako colors**: Edit `~/.config/mako/config`

### Setting a Wallpaper

1. Uncomment the wallpaper line in `~/.config/labwc/autostart`:
   ```bash
   swaybg -i ~/Pictures/wallpaper.jpg -m fill &
   ```

2. Replace `~/Pictures/wallpaper.jpg` with your image path

3. Log out and back in

### Adding/Removing Bar Modules

Edit `~/.config/waybar/config.jsonc`:

```json
"modules-left": ["custom/launcher", "your-module"],
"modules-center": ["clock"],
"modules-right": ["cpu", "memory", "network", "pulseaudio", "tray", "custom/power"]
```

Available modules include: `battery`, `disk`, `temperature`, `backlight`, etc.

### Changing Icons

All icons use the Nerd Font. Find alternative icons at:
- https://www.nerdfonts.com/cheat-sheet

Example: Change the launcher icon
```json
"custom/launcher": {
    "format": "󰣆",  // Change this Unicode character
    ...
}
```

---

## 🔧 Troubleshooting

### Icons Not Showing (Boxes/Squares)

**Problem**: Waybar shows empty boxes or squares instead of icons

**Solution**:
```bash
fc-cache -fv
```

Then log out and back in. This refreshes the font cache.

### Waybar Not Appearing

**Problem**: Top bar doesn't show after login

**Solution**:
1. Check if waybar is running: `ps aux | grep waybar`
2. Try launching manually: `waybar &`
3. Check for errors: `waybar -l debug`

### Window Switching Not Working

**Problem**: Alt+Tab doesn't switch windows

**Solution**:
```bash
pkill -HUP labwc
```

This reloads the labwc configuration without logging out.

### Screenshots Not Saving

**Problem**: Screenshots fail to save

**Solution**:
Ensure the Pictures directory exists:
```bash
mkdir -p ~/Pictures
```

### Network Icon Shows Disconnected

**Problem**: WiFi is connected but icon shows disconnected

**Solution**:
This is usually a permissions issue. Ensure your user is in the `netdev` group:
```bash
sudo usermod -aG netdev $USER
```

Then log out and back in.

### Volume Scroll Not Working

**Problem**: Scrolling on volume doesn't change it

**Solution**:
Ensure PulseAudio is running:
```bash
pulseaudio --check || pulseaudio --start
```

### Workspace Boxes Not Appearing in Bar

**Problem**: The workspace indicators don't show in waybar

**Solution**:
1. Check the display script works: `~/.config/labwc/workspace-display.sh` (should output JSON)
2. Check the state file exists: `cat /tmp/pimarchy-workspace` (should show a number 1-6)
3. If state file is missing, create it: `echo 1 > /tmp/pimarchy-workspace`
4. Restart waybar: `pkill waybar && waybar &`
5. Check waybar logs for errors: `waybar -l debug`

**Note**: The workspace indicator updates via polling (every 1 second), so there may be a brief delay after switching workspaces with keyboard shortcuts.

### Workspace Switching Not Working

**Problem**: Win+1-6 doesn't switch workspaces

**Solution**:
```bash
pkill -HUP labwc
```
This reloads the labwc configuration. If that doesn't work, log out and back in.

### Tiling/Snapping Not Working

**Problem**: Win+Left/Right doesn't snap windows

**Solution**:
```bash
pkill -HUP labwc
```
Ensure you have a window focused before using snap keybinds. The window must not be in fullscreen mode.

---

## 📁 File Locations

### Configuration Files

| File | Purpose |
|------|---------|
| `~/.config/labwc/rc.xml` | Window manager theme and keybindings |
| `~/.config/labwc/autostart` | Startup applications and gsettings |
| `~/.config/labwc/environment` | Keyboard layout and cursor theme |
| `~/.config/labwc/power-menu.sh` | Power menu script |
| `~/.config/labwc/workspace-display.sh` | Workspace indicator script for waybar |
| `~/.config/labwc/workspace-click.sh` | Workspace click/cycle handler for waybar |
| `~/.config/waybar/config.jsonc` | Top bar configuration |
| `~/.config/waybar/style.css` | Top bar styling |
| `~/.config/wofi/config` | App launcher configuration |
| `~/.config/wofi/style.css` | App launcher styling |
| `~/.config/mako/config` | Notification daemon configuration |
| `~/.config/gtk-3.0/settings.ini` | GTK3 theme, icons, cursor, font |
| `~/.gtkrc-2.0` | GTK2 theme settings |
| `~/.config/lxterminal/lxterminal.conf` | Terminal colors and font |
| `/etc/chromium.d/pimarchy-dark` | Chromium dark mode flags |

### Scripts

| Script | Purpose |
|--------|---------|
| `~/pimarchy/install.sh` | Installation script |
| `~/pimarchy/uninstall.sh` | Uninstallation script |
| `~/pimarchy/config/` | Configuration templates and settings |
| `~/pimarchy/config/keybinds/` | Keyboard shortcut configuration |
| `~/pimarchy/config/theme.conf` | Theme and color configuration |
| `~/pimarchy/lib/functions.sh` | Shared library functions |

### Backups

| Location | Contents |
|----------|----------|
| `~/.config/Pimarchy-backup/` | Original configuration backups |

---

## 🎭 Icon Reference

All icons use **Nerd Font** (CaskaydiaCove Nerd Font):

| Icon | Name | Unicode | Usage |
|------|------|---------|-------|
| 󰀻 | Apps | `nf-md-apps` | Launcher |
| 󰥔 | Clock | `nf-md-clock` | Time |
| 󰃭 | Calendar | `nf-md-calendar` | Date |
| 󰻠 | CPU | `nf-md-cpu_64_bit` | Processor |
| 󰍛 | Memory | `nf-md-memory` | RAM |
| 󰤨 | WiFi | `nf-md-wifi` | Wireless |
| 󰈀 | Ethernet | `nf-md-ethernet` | Wired |
| 󰤭 | WiFi Off | `nf-md-wifi_off` | Disconnected |
| 󰕿 | Volume Low | `nf-md-volume_low` | Audio (low) |
| 󰖀 | Volume Medium | `nf-md-volume_medium` | Audio (med) |
| 󰕾 | Volume High | `nf-md-volume_high` | Audio (high) |
| 󰝟 | Volume Mute | `nf-md-volume_mute` | Audio (muted) |
| 󰐥 | Power | `nf-md-power` | Power menu |

---

## 🔄 Workflow Tips

### Recommended Workflow

1. **Launch apps**: `Win + D` -> type app name -> Enter
2. **Manage windows**: Use `Alt + Tab` to switch, `Win + Q` to close
3. **Tile windows**: `Win + Left` and `Win + Right` for side-by-side work
4. **Use workspaces**: `Win + 1-6` to organize different tasks on different desktops
5. **Move windows between workspaces**: `Win + Shift + 1-6` to send a window elsewhere
6. **Minimize/restore**: `Win + M` to minimize, `Alt + Tab` to restore
7. **Quick terminal**: `Win + Enter` anytime
8. **Screenshots**: `Print` for full screen, `Win + Shift + S` for region

### Productivity Shortcuts

- Keep your most-used apps in the launcher history (Wofi remembers frequent apps)
- Use `Win + F` for distraction-free fullscreen mode
- Use `Win + Left` / `Win + Right` to tile two apps side by side for reference
- Dedicate workspaces to different tasks (e.g., 1=browser, 2=terminal, 3=editor)
- Click workspace indicator in the bar to cycle forward, right-click to cycle backward
- Right-click WiFi icon to quickly open network settings
- Scroll on volume to adjust without opening the mixer

---

## 📝 Changelog

### v1.0 (Initial Release)
- Floating pill-shaped Waybar with Catppuccin theme
- Wofi app launcher with Win+D
- Mako notification daemon
- Comprehensive keyboard shortcuts
- Nerd Font icons throughout
- Screenshot capabilities (grim + slurp)
- Window tiling/snapping (left/right/center/edges)
- 6 workspaces with keyboard switching and workspace boxes in the bar
- Full install/uninstall scripts with backups
- Application theming: Arc-Dark GTK theme, Papirus-Dark icons, Adwaita cursor
- Catppuccin Mocha terminal colors (lxterminal)
- Chromium dark mode integration

---

## 🤝 Contributing

Pimarchy is designed for personal use on Raspberry Pi 5. If you'd like to modify it for your needs:

1. Fork the install script
2. Modify the configuration heredocs
3. Test on your system
4. Share your customizations!

---

## 📄 License

Pimarchy configuration files are provided as-is for personal use. The individual components (labwc, waybar, wofi, mako, etc.) maintain their respective licenses.

---

## 🙏 Credits

- **Omarchy**: Inspiration for the aesthetic and workflow
- **Catppuccin**: Color palette and theme inspiration
- **Nerd Fonts**: Icon font (CaskaydiaCove)
- **labwc**: Wayland compositor for Raspberry Pi 5
- **Waybar**: Highly customizable status bar
- **Wofi**: Application launcher
- **Mako**: Notification daemon

---

## 💡 Tips for New Users

- **Give it time**: The keyboard-driven workflow takes a few days to feel natural
- **Customize gradually**: Start with the defaults, then tweak as needed
- **Check the bar**: Your system info is always visible at the top
- **Use the power menu**: Click the power icon instead of using the terminal for shutdown
- **Keep backups**: The uninstall script makes it safe to experiment

---

**Enjoy your new desktop!** 🎉

For issues or questions, check the Troubleshooting section above or review the configuration files in `~/.config/`.
