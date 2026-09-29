# Troubleshooting

Common issues and how to solve them when using Pimarchy on your Raspberry Pi 5.

## Installation Errors

### `apt` lock errors
If you see an error like `Could not get lock /var/lib/dpkg/lock-frontend`, another process (like the automatic update service) is using `apt`.

**Solution:** Wait 30 seconds and try again. If it persists, reboot your Pi.

### Missing packages
Pimarchy uses the **Debian Sid** repository for Hyprland. If a package is not found:
1.  Check your internet connection.
2.  Ensure you ran `sudo apt update` before the installation.
3.  Check if Debian Sid is correctly added to `/etc/apt/sources.list.d/debian-sid.list`.

## Display & Graphics

### Screen flickering or artifacts
Hyprland on the Pi 5 uses the `vc4-kms-v3d` driver. If you experience flickering:
1.  Check your HDMI cable (use the official Micro-HDMI to HDMI cable if possible).
2.  Ensure your power supply is 5V 5A. Low power can cause GPU instability.

### Resolution is too high/low
You can adjust the monitor configuration in `~/.config/hypr/hyprland.conf`:

```bash
# Example: Lock resolution to 1080p at 60Hz
monitor=HDMI-A-1, 1920x1080@60, 0x0, 1
```

## Input Devices

### Keyboard layout is incorrect
Pimarchy defaults to the US keyboard layout. To change it, edit `~/.config/hypr/hyprland.conf`:

```bash
input {
    kb_layout = gb  # Change 'us' to 'gb', 'de', etc.
}
```

## Performance

### System feels sluggish
- **Power:** Ensure you are using the official 27W USB-C PSU.
- **Cooling:** Check if your Pi is throttling due to heat (`vcgencmd get_throttled`).
- **Overclocking:** If you set `arm_freq=2600`, keep cooling active. Cores throttle between 80°C and 85°C. Firmware scales voltage for that clock.

## NVMe boot stops after an older install

Pimarchy no longer writes a PCIe generation. An older install added this block to the NVMe FAT boot partition (`config.txt`, often `/boot/firmware/config.txt`):

```ini
# Pimarchy: NVMe at PCIe Gen 3 (drive trains at 8 GT/s)
dtparam=pciex1_gen=3
```

Boot a rescue microSD, mount that FAT partition, and remove the comment and the `dtparam=pciex1_gen=3` line under it. Remove an `[all]` header only when that block is the whole section. When the drive still does not boot, also remove a `dtparam=pciex1_gen=3` line that has no Pimarchy comment. Leave `dtparam=pciex1_gen=2` in place. The same lines are listed in [Uninstallation & Recovery](../uninstall.md).

## Audio

### No sound output
Pimarchy uses **PipeWire** for audio.
1.  Open the volume control with **SUPER + V** (or click the volume icon in Waybar).
2.  Check the output device settings in the `pavucontrol` mixer.
3.  Ensure your user is in the `audio` group: `sudo usermod -aG audio $USER`.

---

## Still having trouble?

If your issue isn't listed here, please:
1.  Check the installation logs: `tail -f ~/pimarchy_install.log` (if you redirected output).
2.  Run the validation script: `bash validate.sh`.
3.  [Open an issue](https://github.com/raythurman2386/pimarchy/issues) on GitHub.
