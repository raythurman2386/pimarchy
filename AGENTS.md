# AGENTS.md - Pimarchy Developer Guide

This document provides guidelines for AI agents working on the Pimarchy codebase.

## Project Overview

Pimarchy is a Raspberry Pi 5/500 Debian/Pi OS provisioning tool. It transforms a barebones Pi OS Lite installation into a modern, aesthetic "Omarchy-inspired" environment using Hyprland (compositor), Waybar (status bar), Rofi (launcher), and related tools.

## Build/Test Commands

```bash
# Validate all scripts and configurations
bash validate.sh

# Dry run (preview changes without installing)
bash install.sh --dry-run

# Lazy package modules
pimarchy install dev
pimarchy install office

# Syntax check a specific script
bash -n install.sh
bash -n uninstall.sh
bash -n lib/common.sh

# Full install/uninstall test cycle
bash install.sh    # Install Pimarchy
bash uninstall.sh  # Restore original configs
```

## Code Style Guidelines

### Shell Script Standards

- **Shebang**: Use `#!/bin/bash` at the top of all scripts
- **set -e**: Start scripts with `set -e` to exit on error
- **Indentation**: 4 spaces (no tabs)
- **Line length**: Keep lines under 100 characters when possible

### Naming Conventions

- **Constants/Environment variables**: `UPPER_CASE` (e.g., `FONT_FAMILY`, `BACKUP_DIR`)
- **Function names**: `snake_case` (e.g., `load_config`, `process_template`)
- **Local variables**: `snake_case` (e.g., `template_path`, `var_name`)
- **Boolean flags**: Descriptive names ending in meaningful words (e.g., `DRY_RUN`)

### Function Definitions

```bash
# Use descriptive names with parentheses
descriptive_function_name() {
    local local_var="value"
    # function body
}

# Logging functions follow this pattern
log_info() {
    echo "[INFO] $1"
}
```

### Variable Declaration

- Always use `local` for variables inside functions
- Use `readonly` for constants that shouldn't change
- Quote variables when using them: `"$variable"` not `$variable`

### Error Handling

- Always check if files exist before reading: `if [ -f "$file" ]; then`
- Redirect errors appropriately: `2>/dev/null || true` for optional operations
- Use meaningful error messages with log_error

### Logging Standards

Use these prefixes consistently:
- `[INFO]` - General information
- `[OK]` - Success messages (log_success)
- `[WARN]` - Warnings (log_warn)
- `[ERROR]` - Errors to stderr (log_error)

### Template Processing

Templates use `{{VARIABLE}}` syntax. Variables are defined in:
- `config/theme.conf` - Theme colors, fonts, icons, Rofi settings
- `config/theme/colors.toml.template` - GPUI Kit palette → `~/.local/state/{omarchy,pimarchy}/current/theme/`
- Environment variables exported by `install.sh` (e.g., `PIMARCHY_ROOT`)
- Derived variables (e.g., `COLOR_PRIMARY_HEX`)

## Project Structure

```
├── install.sh              # Thin orchestrator
├── uninstall.sh            # Uninstaller (restores backups)
├── validate.sh             # Configuration validator (includes image/*.sh syntax)
├── netinstall.sh           # Curl | bash bootstrap → ~/.local/share/pimarchy
├── lib/
│   ├── functions.sh        # Aggregator — sources modules below
│   ├── common.sh           # Shared paths & constants
│   ├── log.sh              # Logging
│   ├── template.sh         # {{VARIABLE}} template engine
│   ├── backup.sh           # Config backup/restore
│   ├── repos.sh            # External apt repos (sid, Docker CE)
│   ├── packages.sh         # List-driven package modules
│   ├── services.sh         # systemd/greetd/firewall/keyboard/nm-applet
│   ├── pi-perf.sh          # Pi 5 governor/overclock
│   ├── pi-firmware.sh      # Safe boot-firmware edits
│   ├── ensure-dev-root.sh  # /dev/root for initramfs rebuilds
│   ├── apps.sh             # App installs, gsettings, cleanup
│   ├── defaults.sh         # Default app policy (Quattro)
│   └── upgrade.sh          # Safe upgrade model (Quattro)
├── image/                  # Custom SD-card image + first-boot pipeline
│   ├── build-image.sh
│   ├── write-imager-manifest.sh
│   ├── firstboot.sh / firstboot-console.sh
│   ├── wifi-country.sh / sync-clock.sh
│   └── work/               # Build artifacts (gitignored)
├── bin/
│   ├── pimarchy            # Main CLI (install/defaults/agent/update/...)
│   ├── pimarchy-agent      # Default agent launcher
│   ├── pimarchy-default-agent
│   ├── pimarchy-install    # Lazy module installer
│   └── pimarchy-upgrade    # Safe upgrade applier
├── config/
│   ├── theme.conf          # Theme configuration (Ravenwood/Everforest palette)
│   ├── modules.conf        # Module registry (source → target mappings)
│   ├── packages/           # core.list / ai.list / dev.list / office.list / retired.conf
│   ├── theme/              # GPUI colors.toml + theme.conf templates
│   ├── hypr/               # Hyprland Lua config, keybinds, wallpaper
│   ├── waybar/ / rofi/ / mako/ / terminal/ / shell/ / starship/
│   ├── gtk/ / btop/ / zed/ / raven/ / chromium/ / cargo/ / fontconfig / polkit
├── tests/                  # Functional tests (run by validate.sh)
└── .github/workflows/      # CI/CD automation
```

Open decisions (do not invent answers): Wi-Fi country default, Imager image hosting (`file://` today), Xwayland long-term policy, omarchy vs pimarchy GPUI theme path standardization — see `docs/development/architecture.md#open-decisions`.
## Configuration System

1. **Load configs**: Use `load_config "path/to/file"` to source config files
2. **Config format**: `VARIABLE_NAME="value"` (shell-compatible)
3. **Templates**: Files ending in `.template` get variables replaced
4. **Processing**: `process_template "input.template" "output.file"`

## Backup System

- Original configs backed up to `~/.config/Pimarchy-backup/`
- `.original-backup` marker file tracks first install
- Timestamped backups created on reinstall: `previous-YYYYMMDD-HHMMSS/`

## GitHub Actions

CI validates on every push/PR:
- Script syntax (`bash -n`)
- Executable permissions
- Config file existence
- Template variable validation

## Commit Message Format

```
type: Brief description

Longer explanation if needed

- Bullet points for details
```

Types: `feat:`, `fix:`, `docs:`, `style:`, `refactor:`, `test:`, `chore:`

## Safety Guidelines

- Never commit secrets or credentials
- Always test with `--dry-run` first
- Back up user configs before modifying
- Ask before destructive operations
- Handle errors gracefully with fallbacks

## Platform Notes

- Target: Raspberry Pi 5 / Pi 500 running Pi OS Lite (Debian Trixie, arm64)
- CI: GitHub Actions runs `validate.sh` on ubuntu-latest only — **no arm64 image-build / SD artifact in GHA today** (manual/hardware verification)
- Session: Wayland-only — Hyprland `xwayland.enabled = false`; launcher is sid rofi 2 (Trixie rofi is X11-only)
- Custom image: `image/build-image.sh` + firstboot on tty1; Imager manifest uses `cloudinit-rpi` and a local `file://` image URL (hosting open)
- Wi-Fi country default for the image path: `US` via `PIMARCHY_WIFI_COUNTRY` (open whether Imager locale should drive this)
- GPUI theme state: write both `~/.local/state/omarchy/current/theme/` and `~/.local/state/pimarchy/current/theme/` until pisuite path standardization lands
- Window Manager: Hyprland (Wayland, launched via UWSM as a systemd session; from Debian sid, pinned — see docs/development/sid-policy.md)
- Status Bar: Waybar
- App Launcher: Rofi
- Shell: Bash + Pimarchy Aliases + Starship
- Notifications: Mako
- Terminal: Foot (default terminal; `pimarchy default terminal`)
- Wallpaper: swaybg (systemd user service — not exec-once)
- Containers: Docker CE + Docker Compose v2 (from download.docker.com — NOT docker.io) — lazy `dev` module only; docker group membership is opt-in
- Code Editor: Zed (installed to `~/.local/zed.app/`, config at `~/.config/zed/settings.json`) — default editor
- CLI Tools: fd, ripgrep (Rust-based)
- Rust builds (dev module): mold linker + shared target dir `~/.cache/cargo-target` via `~/.cargo/config.toml` (template `config/cargo/config.toml.template`, hook `script:cargo-config`); absolute paths only — cargo does not expand `~` in config files
- System Monitor: btop (themed with Ravenwood palette via `config/btop/ravenwood.theme`)
- AI Coding Agent: Raven (installed to `~/.cargo/bin/`, config at `~/.raven/config.toml`) + Ollama (inference at `localhost:11434`) — default agent policy, launched via `pimarchy agent` (Super+Shift+Ctrl+A) in a Foot window class `org.pimarchy.agent`; `a` is `--inline`; install with `pimarchy install ai` (lazy). Shipped default model is `glm-5.3-flash:cloud` via Ollama (no multi-GB local pull on firstboot)
- File manager: Pifile (installed to `~/.local/bin/pifile`) — default file manager, Super+E; `inode/directory` MIME handler
- Calculator: Picalc (installed to `~/.local/bin/picalc` via official netinstall) — Super+Ctrl+Q / XF86Calculator; Omarchy theme path
- Default app policy: `pimarchy defaults` / `pimarchy default <agent|browser|editor|terminal|filemanager> <name>` — files in `~/.config/pimarchy/defaults/`, values validated against an allowlist
- Package modules: `config/packages/{core,ai,dev,office}.list` — core is always installed; ai/dev/office are lazy (`pimarchy install ai|dev|office`); pre-Quattro full set behind `install.sh --legacy-packages`
- Safe upgrades: `pimarchy update` — sha256 manifest at `~/.config/pimarchy/manifest` gates refreshes (user-modified files are left untouched); retired files come from `config/packages/retired.conf`
