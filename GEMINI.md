# GEMINI.md - Pimarchy Instructional Context

This file provides foundational context and instructions for AI agents working on the Pimarchy project.

## Project Overview

**Pimarchy** is an automated desktop transformation tool designed for the Raspberry Pi 5 and Pi 500. It converts a barebones Linux installation (primarily **Raspberry Pi OS / Debian Lite**) into a modern, aesthetic, and functional Wayland-based desktop environment.

### Core Architecture
- **Compositor:** Hyprland (Wayland)
- **Status Bar:** Waybar
- **App Launcher:** Rofi (with Wayland support)
- **Notifications:** Mako
- **Terminal:** Alacritty
- **Login Manager:** Greetd + Tuigreet
- **Shell:** Bash with Starship prompt and custom aliases
- **SSH Support:** Automated installation and enablement of `openssh-server`.
- **Theme Engine:** A custom template system (`{{VARIABLE}}`) that generates configuration files from `.template` files. Non-template files (like `background.jpg`) are directly copied to their target paths.

> **Note on OS Compatibility:** While the `README.md` mentions Arch Linux ARM, the current implementation (`lib/functions.sh`) specifically uses `apt` and targets **Debian Bookworm / Pi OS**. Always prioritize the Debian-based workflow unless explicitly tasked with porting to Arch.

## Key Workflows

### Installation & Deployment
- **Full Install:** `bash install.sh`
- **Preview Changes:** `bash install.sh --dry-run`
- **Uninstallation:** `bash uninstall.sh` (reverts configs and optionally removes packages)

### Development & Validation
- **Global Validation:** `bash validate.sh` (checks script syntax and template variables)
- **Syntax Check:** `bash -n <script_name>`
- **Theme Customization:** Edit `config/theme.conf` and re-run `install.sh`.

## Project Structure

- `install.sh`: The main entry point for provisioning the system.
- `uninstall.sh`: Reverts system changes and restores backups.
- `validate.sh`: Ensures all templates and configurations are valid before deployment.
- `lib/functions.sh`: Core logic library containing shared functions for logging, backup, template processing, and package management.
- `config/`:
    - `theme.conf`: Centralized theme variables (colors, fonts, icons).
    - `modules.conf`: Registry mapping templates to their target system paths.
    - `*/*.template`: Configuration templates for various system components.

## Engineering Standards

### Shell Scripting
- **Interpreter:** Always use `#!/bin/bash`.
- **Safety:** Always include `set -e` at the start of scripts.
- **Scoping:** Use `local` for all variables within functions.
- **Quoting:** Always quote variables (e.g., `"$var"`) to prevent word splitting.
- **Indentation:** Use 4 spaces (no tabs).

### Naming Conventions
- **Constants/Globals:** `UPPER_CASE` (e.g., `PIMARCHY_ROOT`, `COLOR_PRIMARY`)
- **Functions:** `snake_case` (e.g., `process_template`, `log_info`)
- **Locals:** `snake_case` (e.g., `target_path`, `var_name`)

### Logging
Always use the provided logging functions in `lib/functions.sh`:
- `log_info "message"`: General status.
- `log_success "message"`: Successful operations.
- `log_warn "message"`: Non-critical warnings.
- `log_error "message"`: Critical errors (output to stderr).

### Template System
Templates use double curly braces: `{{VARIABLE_NAME}}`.
- Variables must be defined in `config/theme.conf` or exported in `install.sh`.
- New modules must be registered in `config/modules.conf` in the format: `module|template|target|description`.

## Safety & Backups
- **Backup Location:** `~/.config/Pimarchy-backup/`
- **Persistence:** The first installation creates an `.original-backup` marker to ensure the base system state is preserved.
- **Reinstallation:** Subsequent installs create timestamped backups in the backup directory.
