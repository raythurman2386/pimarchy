# GEMINI.md - Pimarchy Context

## Project Overview
**Pimarchy** is a modular, aesthetic desktop transformation for the Raspberry Pi 5 running Debian Bookworm. It transforms the default environment into a modern, minimal Wayland-based desktop inspired by Omarchy and themed with Catppuccin Mocha.

### Core Technologies
- **Compositor:** `labwc` (Wayland)
- **Status Bar:** `waybar`
- **Application Launcher:** `wofi`
- **Notifications:** `mako`
- **Theming:** Catppuccin Mocha, Arc-Dark GTK, Papirus-Dark Icons
- **Scripting:** Bash (for installation, uninstallation, and template processing)
- **Fonts:** CaskaydiaCove Nerd Font

## Project Structure
The project uses a template-based system where configuration files are generated from templates in `config/` using variables defined in `theme.conf` and `keybinds.conf`.

- `install.sh`: Main installer. Performs backups, installs dependencies, and processes templates.
- `uninstall.sh`: Reverts changes, restores original configurations, and optionally removes packages.
- `validate.sh`: Utility to check for syntax errors and missing template variables.
- `config/`: Contains all configuration logic.
    - `modules.conf`: Manifest defining which components get installed and where.
    - `theme.conf`: Centralized styling variables (colors, fonts, icons).
    - `keybinds/keybinds.conf`: Keyboard shortcut definitions.
    - `*.template`: Template files for various components (Waybar, Wofi, Labwc, etc.).
- `lib/functions.sh`: Shared logic for template processing, package management, and backups.
- `bin/`: (Optional) Custom executables and scripts.

## Development & Usage Workflows

### Installation
To apply the transformation:
```bash
bash install.sh
```
Use `--dry-run` to see changes without applying them.

### Customization
1. **Modify Settings:** Edit `config/theme.conf` for visuals or `config/keybinds/keybinds.conf` for shortcuts.
2. **Validate:** Run `bash validate.sh` to ensure no template variables are missing.
3. **Apply:** Re-run `bash install.sh`.
4. **Refresh:** Log out and back in, or use `pkill -HUP labwc` to reload the compositor configuration.

### Adding New Modules
1. Create a template file in `config/`.
2. Use `{{VARIABLE_NAME}}` for any values defined in `theme.conf` or `keybinds.conf`.
3. Add an entry to `config/modules.conf` following the format: `module_name|template_path|target_path|description`.

## Key Conventions
- **Template Processing:** The `process_template` function in `lib/functions.sh` handles variable substitution.
- **Backups:** Original user configurations are saved to `~/.config/Pimarchy-backup/` during the first installation.
- **State Management:** Workspace state is tracked via `/tmp/pimarchy-workspace`.
- **Modularity:** Modules can be disabled by commenting them out in `config/modules.conf`.

## Building and Running
This is a script-based project; no compilation is required. 
- **Validation:** `bash validate.sh`
- **Install:** `bash install.sh`
- **Uninstall:** `bash uninstall.sh`
- **Diagnostics:** `bash diagnose.sh` (if available)
