# Troubleshooting with Logs

When something goes wrong, logs are your best friend. Use these commands to find the source of errors.

## 1. Installation Logs
The `install.sh` script logs its output directly to your terminal. If you want to save it to a file for review:

```bash
bash install.sh 2>&1 | tee ~/pimarchy_install.log
```

## 2. Systemd Logs (Greetd & UWSM)
Pimarchy runs as a systemd user session. You can view logs for the desktop environment:

```bash
# View logs for the login manager (greetd)
sudo journalctl -u greetd -f

# View logs for the current Hyprland session
journalctl --user -u uwsm-session -f
```

## 3. Hyprland Internal Logs
Hyprland keeps its own detailed logs in `/tmp/hypr/`:

```bash
# Find the latest Hyprland log
ls -t /tmp/hypr/ | head -n 1
cat /tmp/hypr/[YOUR_INSTANCE_ID]/hyprland.log
```

## 4. XDG Desktop Portal
Issues with screen sharing, file pickers, or GTK themes are often related to the XDG Portal:

```bash
journalctl --user -u xdg-desktop-portal-hyprland -f
```

## 5. Audio Logs (PipeWire)
If you have no sound:

```bash
systemctl --user status pipewire.service
journalctl --user -u pipewire -f
```

---

## Shared Tools

### `vcgencmd` (Pi-Specific)
A powerful tool for checking the status of your Raspberry Pi hardware:

- **Check for Throttling:** `vcgencmd get_throttled`
- **Check CPU Temp:** `vcgencmd measure_temp`
- **Check CPU Clock:** `vcgencmd measure_clock arm`

!!! info "Common Throttled States"
    - `0x50000`: Throttling occurred due to temperature.
    - `0x50005`: Currently throttling due to temperature.
    - `0x10000`: Throttling occurred due to low voltage.
    - `0x10001`: Currently throttling due to low voltage (Check your PSU!).
