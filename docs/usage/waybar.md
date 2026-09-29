# Waybar Actions

The status bar is interactive. Use these actions to manage your system quickly.

## Mouse Actions

| Module | Action | Result |
|--------|--------|--------|
| **Workspaces** | **Click** | Focus that workspace (`pimarchy-workspace focus N`). |
| **Clock** | **Click** | Toggle the date and time format. |
| **Update Icon** | **Click** | Open a terminal running `pimarchy update` (icon visible only when updates are available). |
| **WiFi / Network** | **Right-click** | Open **nmtui** in a terminal (not the GTK NetworkManager applet). |
| **Bluetooth** | **Click** | Open **bluetoothctl** in a terminal. |
| **Bluetooth** | **Right-click** | Toggle Bluetooth radio (`rfkill`). |
| **Volume** | **Click** | Open the audio mixer (**pavucontrol**). |
| **Volume** | **Scroll** | Increase or decrease the volume level. |
| **Memory** | **Click** | Open the **btop** system monitor. |
| **Power Icon** | **Click** | Open the **Rofi Power Menu**. |

!!! note "No nm-applet"
    Waybar owns the network icon. `network-manager-gnome` is not in the core package set, and any leftover nm-applet autostart is masked so Xwayland is not kept resident.

## Customizing Waybar

Waybar's appearance is controlled by `config/theme.conf` and processed through the template in `config/waybar/style.css.template`.

### Modifying Modules
If you want to add or remove modules from the bar:
1.  Edit `config/waybar/config.jsonc.template`.
2.  Add or remove module names from the `"modules-left"`, `"modules-center"`, or `"modules-right"` arrays.
3.  Re-run `bash install.sh`.

!!! info "Reloading Waybar"
    Waybar runs as a systemd user service. Prefer:
    ```bash
    systemctl --user restart waybar.service
    ```
    (or `pimarchy reload` / the `pimarchy-restart-waybar` alias after install).
