# Customizing the Theme

Pimarchy features a unique, template-driven theming engine. Instead of manually editing dozens of CSS and configuration files, you define your aesthetic in a single file: `config/theme.conf`.

## The `theme.conf` File

The `theme.conf` file contains variables that control the appearance of **every** component in the system, including Waybar, Rofi, Foot, and Hyprland.

```bash
# Ravenwood Theme Variables
export COLOR_BG="#2b3339"     # Background color
export COLOR_FG="#d3c6aa"     # Foreground (Text) color
export COLOR_PRIMARY="#a7c080" # Primary accent color (Green)
export COLOR_ACCENT="#e67e80"  # Secondary accent (Red)
export FONT_MAIN="Inter"       # System-wide font
export FONT_MONO="JetBrainsMono Nerd Font" # Terminal and code font
```

## How the Template System Works

1.  **Variables:** You define variables in `config/theme.conf`.
2.  **Templates:** Files ending in `.template` (e.g., `waybar/style.css.template`) use double curly braces `{{VARIABLE_NAME}}`.
3.  **Processing:** When you run `bash install.sh`, the script:
    -   Reads the variables from `theme.conf`.
    -   Replaces `{{VARIABLE_NAME}}` in every template listed in `config/modules.conf`.
    -   Writes the final configuration to your system (e.g., `~/.config/waybar/style.css`).

## Applying Changes

To update your theme:
1.  Edit `config/theme.conf` in your `pimarchy` directory (`~/.local/share/pimarchy` after a netinstall).
2.  Run the installer again:
    ```bash
    bash install.sh
    ```
3.  The script will detect existing files, back them up, and deploy the new configurations.

!!! note "Restarting Components"
    Most changes require a restart of the component. You can reload Hyprland with **SUPER + SHIFT + R**, or simply log out and back in.

## Module Registry

New modules can be added to the system by registering them in `config/modules.conf`.

Format:
`module_name|source_path|target_path|Human description`

Example:
`waybar|waybar/style.css.template|~/.config/waybar/style.css|Waybar styling`

Non-template files (wallpapers, scripts, shipped confs) are copied as-is. Source paths are relative to `config/` (use `../bin/...` for helpers under `bin/`).

## GPUI Kit apps (pifile, picalc, piwrite, pisettings, …)

Pisuite GPUI apps read the Ravenwood palette from state paths under `~/.local/state/`:

- `~/.local/state/omarchy/current/theme/colors.toml` (Omarchy-compatible; required today by picalc/piwrite)
- `~/.local/state/pimarchy/current/theme/colors.toml` (preferred by newer apps such as pisettings)

`install.sh` (via `config/modules.conf`) renders `config/theme/colors.toml.template` and `config/theme/theme.conf.template` into **both** trees from `config/theme.conf`. After changing colors, re-run the installer and restart the app (or rely on its file watcher).

The checked-in `current/theme/` tree in the repo is a **reference render only** — live installs never read it from the repo.

!!! warning "Open decision: path standardization"
    Shipping both `omarchy` and `pimarchy` state trees is intentional compatibility, not a final layout. Whether pisuite apps standardize on one path (and which) is still open. Until that lands, keep both registered in `modules.conf`. Do not remove the Omarchy-compatible path without coordinating app updates.
