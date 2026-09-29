# Manual Configuration

While the **Pimarchy Template System** handles the bulk of the work, you can always make manual tweaks directly to your system.

## 1. Edit User Configs
All configuration files are deployed to their standard locations in `~/.config/` (plus a few outside it).

| Component | Path |
|-----------|------|
| **Hyprland** | `~/.config/hypr/hyprland.lua` |
| **Keybinds** | `~/.config/hypr/bindings.lua` |
| **Waybar** | `~/.config/waybar/config.jsonc` |
| **Foot** | `~/.config/foot/foot.ini` |
| **Rofi** | `~/.config/rofi/config.rasi` |
| **Mako** | `~/.config/mako/config` |
| **Starship** | `~/.config/starship.toml` |
| **Zed** | `~/.config/zed/settings.json` |
| **GPUI theme** | `~/.local/state/{omarchy,pimarchy}/current/theme/` |

!!! warning "Installer Overwrites"
    `bash install.sh` / `pimarchy install` always overwrite shipped targets (that's the theme re-apply workflow). `pimarchy update` leaves user-modified files alone (hash-gated). To make permanent changes that survive both install and update, edit the templates under `~/.local/share/pimarchy/config/` (or your clone) and re-install, or edit after install and accept that `install.sh` will clobber until you stop re-running it.

## 2. Shell Aliases
Pimarchy adds aliases via `~/.bashrc.pimarchy` (from `config/shell/aliases.sh.template`), sourced from your bashrc.

Common aliases:
- `update`: `sudo apt update && sudo apt upgrade -y`
- `a`: `pimarchy agent --inline`
- `pimarchy-edit`: `cd` into the install root
- `pi-temp` / `pi-clock` / `pi-throttled`: `vcgencmd` helpers
- `ll` / `la` / `lt`: available when `lsd` is installed; otherwise stick with `ls --color=auto`

## 3. GTK Theme
Pimarchy sets a consistent GTK2 and GTK3 theme using the Ravenwood color palette. This ensures that GTK applications look at home in your desktop environment.

You can modify these settings in:
- `~/.gtkrc-2.0`
- `~/.config/gtk-3.0/settings.ini`

## 4. Environment Variables
Wayland session environment variables are set in `~/.config/hypr/hyprland.lua` via `hl.env(...)`, for example:

```lua
hl.env("GDK_BACKEND", "wayland")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")
hl.env("WLR_NO_HARDWARE_CURSORS", "1")
hl.env("AQ_NO_HARDWARE_CURSORS", "1")
```

DRM device selection for the Pi GPU is handled at launch by `~/.config/hypr/start-hyprland.sh` (when that wrapper is in use).
