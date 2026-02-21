# Waybar Actions

The status bar is interactive. Use these actions to manage your system quickly.

## Mouse Actions

| Module | Action | Result |
|--------|--------|--------|
| **Workspaces** | **Click** | Switch to the clicked workspace. |
| **Workspaces** | **Right-click** | Toggle window overview (if configured). |
| **Workspaces** | **Scroll** | Cycle through workspaces (Next/Previous). |
| **Clock** | **Click** | Toggle the date and time format. |
| **WiFi** | **Right-click** | Open the NetworkManager terminal UI (`nmtui`). |
| **Volume** | **Click** | Mute or unmute the audio output. |
| **Volume** | **Scroll** | Increase or decrease the volume level. |
| **CPU / RAM** | **Click** | Open the **btop** system monitor. |
| **Power Icon** | **Click** | Open the **Rofi Power Menu**. |

## Customizing Waybar

Waybar's appearance is controlled by `config/theme.conf` and processed through the template in `config/waybar/style.css.template`.

### Modifying Modules
If you want to add or remove modules from the bar:
1.  Edit `config/waybar/config.jsonc.template`.
2.  Add or remove module names from the `"modules-left"`, `"modules-center"`, or `"modules-right"` arrays.
3.  Re-run `bash install.sh`.

!!! info "Reloading Waybar"
    You can reload Waybar without a full system reboot by killing the process:
    ```bash
    pkill waybar && hyprctl dispatch exec waybar
    ```
