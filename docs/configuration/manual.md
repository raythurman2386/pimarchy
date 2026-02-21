# Manual Configuration

While the **Pimarchy Template System** handles the bulk of the work, you can always make manual tweaks directly to your system.

## 1. Edit User Configs
All configuration files are deployed to their standard locations in `~/.config/`.

| Component | Path |
|-----------|------|
| **Hyprland** | `~/.config/hypr/hyprland.conf` |
| **Waybar** | `~/.config/waybar/config.jsonc` |
| **Alacritty** | `~/.config/alacritty/alacritty.toml` |
| **Rofi** | `~/.config/rofi/config.rasi` |
| **Mako** | `~/.config/mako/config` |
| **Starship** | `~/.config/starship.toml` |

!!! warning "Installer Overwrites"
    If you edit files in `~/.config/` directly, they may be overwritten the next time you run `bash install.sh`. To make permanent changes that survive updates, edit the templates in the `pimarchy` repository.

## 2. Shell Aliases
Pimarchy adds several useful aliases to your `~/.bashrc`. These are defined in `config/shell/aliases.sh.template`.

Common aliases:
- `pau`: `sudo apt update && sudo apt full-upgrade -y` (Pi-specific update)
- `ll`: `ls -laF` (Detailed file listing)
- `grep`: `grep --color=auto` (Colored output)

## 3. GTK Theme
Pimarchy sets a consistent GTK2 and GTK3 theme using the Ravenwood color palette. This ensures that applications like **Thunar** or **GIMP** look at home in your desktop environment.

You can modify these settings in:
- `~/.gtkrc-2.0`
- `~/.config/gtk-3.0/settings.ini`

## 4. Environment Variables
System-wide environment variables for the Wayland session are set in `~/.config/hypr/hyprland.conf`.

Default settings:
```bash
env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_TYPE,wayland
env = XDG_SESSION_DESKTOP,Hyprland
env = QT_QPA_PLATFORM,wayland
```
