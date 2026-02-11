# AGENTS.md - Pimarchy Developer Guide

This document provides guidelines for AI agents working on the Pimarchy codebase.

## Project Overview

Pimarchy is a Raspberry Pi 5 Wayland desktop environment configuration tool. It transforms the default Raspberry Pi desktop into a modern, aesthetic environment using Labwc (window manager), Waybar (status bar), and related tools.

## Build/Test Commands

```bash
# Validate all scripts and configurations
bash validate.sh

# Dry run (preview changes without installing)
bash install.sh --dry-run

# Syntax check a specific script
bash -n install.sh
bash -n uninstall.sh
bash -n lib/functions.sh

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
- `config/theme.conf` - Theme colors, fonts, icons
- `config/keybinds/keybinds.conf` - Keybindings and commands

## Project Structure

```
├── install.sh          # Main installer script
├── uninstall.sh        # Uninstaller (restores backups)
├── validate.sh         # Configuration validator
├── migrate.sh          # Migration utility
├── diagnose.sh         # Diagnostic tool
├── lib/
│   └── functions.sh    # Shared library functions
├── config/
│   ├── theme.conf      # Theme configuration
│   ├── keybinds/
│   │   └── keybinds.conf  # Keybinding definitions
│   ├── modules.conf    # Module registry
│   └── */*.template    # Configuration templates
└── .github/workflows/  # CI/CD automation
```

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

- Target: Raspberry Pi 5 with Debian Bookworm
- Window Manager: Labwc (Wayland)
- Status Bar: Waybar
- App Launcher: Wofi
- Notifications: Mako
- Terminal: Alacritty
