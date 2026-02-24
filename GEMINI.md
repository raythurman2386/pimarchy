# GEMINI.md - Pimarchy Instructional Context

This file provides foundational context and instructions for AI agents working on the Pimarchy project.

## Project Overview

**Pimarchy** is an automated desktop transformation tool designed for the Raspberry Pi 5 and Pi 500. It converts a barebones **Pi OS Lite (Debian Trixie)** installation into a modern, aesthetic, and functional Wayland-based desktop environment.

> **OS target:** Pi OS Lite (Debian Trixie / arm64). All package management uses `apt`. Do not introduce `pacman`, `yay`, or any Arch Linux tooling.

### Core Architecture

| Layer | Component |
|-------|-----------|
| Compositor | Hyprland (Wayland, launched via UWSM as a systemd session) |
| Status bar | Waybar |
| App launcher | Rofi (Wayland build) |
| Notifications | Mako |
| Terminal | Alacritty |
| Login manager | Greetd + Tuigreet |
| Shell | Bash + Starship + custom aliases |
| File manager | Thunar |
| Containers | Docker CE + Docker Compose v2 (from download.docker.com) |
| AI coding agent | OpenCode (installed via opencode.ai install script to `~/.opencode/`) |
| System monitor | btop (themed with `config/btop/ravenwood.theme`) |
| Wallpaper | swaybg (runs as a systemd user service, not exec-once) |
| Theme engine | `{{VARIABLE}}` template system — see Template System below |

## Key Workflows

### Installation & Deployment
- **Full install:** `bash install.sh`
- **Preview changes:** `bash install.sh --dry-run`
- **Uninstall:** `bash uninstall.sh` (reverts configs and optionally removes packages)

### Development & Validation
- **Global validation:** `bash validate.sh` (checks script syntax and template variables)
- **Syntax check:** `bash -n <script_name>`
- **Theme customisation:** Edit `config/theme.conf` and re-run `install.sh`

## Project Structure

- `install.sh` — Main entry point; orchestrates all install steps
- `uninstall.sh` — Reverts system changes and restores backups
- `validate.sh` — Verifies templates, configs, and script syntax before deployment
- `lib/functions.sh` — Core logic library (logging, backup, template processing, package management, service configuration)
- `config/`
    - `theme.conf` — Centralised theme variables (colours, fonts, icons, spacing)
    - `modules.conf` — Registry mapping source files to target system paths
    - `hypr/` — Hyprland config, wallpaper, screenshot helper
    - `waybar/` — Waybar config + CSS
    - `rofi/` — Launcher config, theme, power menu script
    - `mako/` — Notification daemon config
    - `terminal/` — Alacritty config
    - `shell/` — Bash aliases
    - `starship/` — Starship prompt config
    - `gtk/` — GTK2 / GTK3 theme settings
    - `btop/` — btop config (`btop.conf`) + Ravenwood colour theme (`ravenwood.theme`)
    - `opencode/` — OpenCode agent config (`opencode.json`)

## Engineering Standards

### Shell Scripting
- **Interpreter:** Always use `#!/bin/bash`
- **Safety:** Always include `set -e` at the start of scripts
- **Scoping:** Use `local` for all variables within functions
- **Quoting:** Always quote variables (`"$var"`) to prevent word splitting
- **Indentation:** 4 spaces (no tabs)
- **Line length:** Keep lines under 100 characters where possible

### Naming Conventions
- **Constants/Globals:** `UPPER_CASE` (e.g., `PIMARCHY_ROOT`, `COLOR_PRIMARY`)
- **Functions:** `snake_case` (e.g., `process_template`, `log_info`)
- **Locals:** `snake_case` (e.g., `target_path`, `var_name`)

### Logging
Always use the provided logging functions from `lib/functions.sh`:
- `log_info "message"` — General status
- `log_success "message"` — Successful operations
- `log_warn "message"` — Non-critical warnings
- `log_error "message"` — Critical errors (output to stderr)

### Template System
Templates use double curly braces: `{{VARIABLE_NAME}}`.
- Variables must be defined in `config/theme.conf` or exported in `install.sh`
- Non-template files (images, JSON, plain configs) are copied directly via `cp`
- New modules must be registered in `config/modules.conf`:
  `module_name|source_path|~/.config/target_path|Human description`

### Docker
- Docker CE packages come from the official `download.docker.com` apt repo
- `configure_docker_repo()` in `lib/functions.sh` handles GPG key, apt source, and pin — it is idempotent
- Do **not** use `docker.io` from Debian repos — it lacks `docker-compose-plugin`

### OpenCode
- Installed by piping the official script: `curl -fsSL https://opencode.ai/install | bash`
- Binary lands at `~/.opencode/bin/opencode`; the installer adds `~/.opencode/bin` to `PATH` in `~/.bashrc`
- Config lives at `~/.config/opencode/opencode.json`
- `install_opencode()` is idempotent — skips if `command -v opencode` succeeds
- `remove_opencode()` removes `~/.opencode/` and cleans the PATH line from `~/.bashrc`

### btop Theming
- Theme file: `config/btop/ravenwood.theme` → installed to `~/.config/btop/themes/ravenwood.theme`
- Activated by `color_theme = "ravenwood"` in `config/btop/btop.conf`
- All hex values in the theme match the Everforest/Ravenwood palette in `config/theme.conf`

## Safety & Backups
- **Backup location:** `~/.config/Pimarchy-backup/`
- **First install:** Creates `.original-backup` marker to preserve the original system state
- **Reinstallation:** Creates timestamped snapshots: `previous-YYYYMMDD-HHMMSS/`
- Always test with `--dry-run` before a real install
- Never commit secrets or credentials
