# Pimarchy

A lightweight, aesthetic Omarchy-inspired desktop transformation for Raspberry Pi 5 / Pi 500 running **Pi OS Lite (Debian Bookworm)**.

![Screenshot](screenshot.png)

## Overview

Pimarchy provisions a barebones Pi OS Lite installation into a fully configured, modern Wayland desktop environment:

| Component | Tool |
|-----------|------|
| Window manager | Hyprland (Wayland) |
| Status bar | Waybar |
| App launcher | Rofi (+ power menu) |
| Notifications | Mako |
| Terminal | Alacritty |
| Login manager | Greetd + Tuigreet |
| Shell | Bash + Starship + custom aliases |
| File manager | Thunar |
| Containers | Docker CE + Docker Compose v2 |
| AI coding agent | OpenCode |
| System monitor | btop (Ravenwood theme) |

All components are themed with the **Ravenwood** palette — a refined dark forest aesthetic based on Everforest.

---

## Requirements

- Raspberry Pi 5 or Pi 500
- MicroSD card / USB drive flashed with **Pi OS Lite (64-bit, Debian Bookworm)**
- Active internet connection
- At least 8 GB of storage (16 GB+ recommended)

---

## Step-by-Step Setup

### 1. Flash Pi OS Lite

Download and flash **Raspberry Pi OS Lite (64-bit)** using the [Raspberry Pi Imager](https://www.raspberrypi.com/software/).

In the Imager's advanced settings (click the gear icon) before flashing:
- Set a hostname (e.g. `pimarchy`)
- Create a user account (e.g. `ret`) with a password
- Enable SSH if you want to connect remotely
- Configure your Wi-Fi credentials if needed

### 2. First Boot — Update the OS

Boot into Pi OS Lite (you will land at a TTY prompt). Log in and fully update the system:

```bash
sudo apt update && sudo apt full-upgrade -y
sudo reboot
```

> `full-upgrade` is required (not just `upgrade`) to allow Debian to resolve dependency changes correctly. This is important because Pimarchy adds the Debian Sid repository for Hyprland.

### 3. Install Git

Git is not installed on Pi OS Lite by default:

```bash
sudo apt install -y git
```

### 4. Clone Pimarchy

```bash
git clone https://github.com/raythurman2386/pimarchy.git
cd pimarchy
```

### 5. (Optional) Preview the Install

Run a dry run to see exactly what will be installed and deployed without making any changes:

```bash
bash install.sh --dry-run
```

### 6. Run the Installer

```bash
bash install.sh
```

The installer will:

1. **Back up** your existing configs to `~/.config/Pimarchy-backup/`
2. **Update the system** and add the required apt repositories:
   - Debian Sid (for the latest Hyprland)
   - Official Docker CE repository (for `docker-compose-plugin`)
3. **Install all packages:** Hyprland, Waybar, Rofi, Mako, Alacritty, Greetd, Tuigreet, Starship, Thunar, btop, Docker CE, and more
4. **Deploy all configuration files** using the Ravenwood theme
5. **Install OpenCode** (AI coding agent) to `~/.opencode/`
6. **Configure Greetd** as the login manager, replacing the default console login
7. **Prompt for CPU performance mode** (optional):
   - `g` — Governor only: keeps CPU at max clock, safe on all units, no reboot needed
   - `o` — Overclock: `arm_freq=2600` (2.6 GHz, up from 2.4 GHz) — requires active cooling and a reboot
   - `N` — Skip: leave CPU settings unchanged

Or pass flags directly to skip the interactive prompt:

```bash
bash install.sh --performance   # Governor only, no overclock
bash install.sh --overclock     # Governor + arm_freq=2600 (requires cooling)
```

### 7. Reboot

```bash
sudo reboot
```

Greetd will launch at startup. Log in with your username and password — Hyprland will start automatically.

---

## Keybinds

| Shortcut | Action |
|----------|--------|
| `SUPER + D` | App launcher (Rofi) |
| `SUPER + Return` | Terminal (Alacritty) |
| `SUPER + E` | File manager (Thunar) |
| `SUPER + M` | System monitor (btop) |
| `SUPER + W` | Close window |
| `SUPER + SHIFT + B` | Open Chromium |
| `SUPER + F` | Toggle fullscreen |
| `SUPER + V` | Toggle floating window |
| `SUPER + Arrow keys` | Move focus |
| `SUPER + 1–0` | Switch to workspace 1–10 |
| `SUPER + SHIFT + 1–0` | Move window to workspace 1–10 |
| `Print` | Screenshot — select region → `~/Pictures/Screenshots/` |
| `SHIFT + Print` | Screenshot — full screen → `~/Pictures/Screenshots/` |

## Waybar Actions

| Action | Result |
|--------|--------|
| Click clock | Toggle date/time format |
| Click workspaces | Cycle to next workspace |
| Right-click workspaces | Cycle to previous workspace |
| Right-click WiFi | Open network settings |
| Click volume | Open audio mixer (pavucontrol) |
| Scroll on volume | Adjust volume |
| Click CPU / Memory | Open system monitor (btop) |
| Click power icon | Power menu (shutdown / reboot / logout) |

---

## Configuration

All theming is driven by a single file:

```
config/theme.conf   # colours, fonts, icons, spacing
```

Edit it and re-run `bash install.sh` to regenerate and apply every configuration file. Individual configs can also be edited directly under `~/.config/` after install.

---

## Uninstallation

```bash
bash uninstall.sh
```

Restores your original configuration backups, optionally removes installed packages, and reverts the boot environment to standard Pi OS console defaults.

---

## Validation

```bash
bash validate.sh
```

Checks script syntax, template variables, and file existence. Run this before every commit.

---

## Project Structure

```
├── install.sh                  # Main provisioning script
├── uninstall.sh                # Reverts everything
├── validate.sh                 # Pre-commit validator
├── lib/
│   └── functions.sh            # All shared library functions
├── config/
│   ├── theme.conf              # Centralised theme variables
│   ├── modules.conf            # Module registry (template → target)
│   ├── hypr/                   # Hyprland + wallpaper + screenshot helper
│   ├── waybar/                 # Waybar config + CSS
│   ├── rofi/                   # Rofi launcher + power menu
│   ├── mako/                   # Notification daemon config
│   ├── terminal/               # Alacritty config
│   ├── shell/                  # Bash aliases
│   ├── starship/               # Starship prompt
│   ├── gtk/                    # GTK2 / GTK3 theme settings
│   ├── btop/                   # btop config + Ravenwood colour theme
│   └── opencode/               # OpenCode agent config
└── .github/workflows/          # CI — syntax + permission checks
```

---

## Backup System

- First install backs up original configs to `~/.config/Pimarchy-backup/`
- Subsequent installs create timestamped snapshots: `previous-YYYYMMDD-HHMMSS/`
- `uninstall.sh` restores from the original backup

---

## Acknowledgements

Inspired by [Omarchy](https://github.com/basecamp/omarchy) by Basecamp / DHH.
