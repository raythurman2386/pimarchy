# Troubleshooting

Common issues and how to solve them when using Pimarchy on your Raspberry Pi 5.

## Custom-image first boot

### Shell prompt instead of installer on tty1
The image masks getty while `pimarchy-firstboot` owns the screen. A prompt means the install stopped (or never started). Check:

```bash
sudo tail -n 80 /var/log/pimarchy-firstboot.log
systemctl status pimarchy-firstboot.service
```

Typical causes: no login user from Imager yet, no default route (Wi-Fi), or `install.sh` failed. Fix network/user, reboot; firstboot runs again until `/var/lib/pimarchy/firstboot.done` exists. If getty stayed masked after a failed run, `firstboot-console.sh` should have unmasked it — `sudo systemctl start getty@tty1` restores a login if needed.

### Wi-Fi rfkill / "wireless country not set"
Image build/firstboot set a regulatory country (default **US**). Override with `PIMARCHY_WIFI_COUNTRY=XX` when building, or run `/opt/pimarchy/image/wifi-country.sh XX` on the Pi, then reconnect.

## Installation Errors

### `apt` lock errors
If you see an error like `Could not get lock /var/lib/dpkg/lock-frontend`, another process (like the automatic update service) is using `apt`.

**Solution:** Wait 30 seconds and try again. If it persists, reboot your Pi.

### Missing packages
Pimarchy uses the **Debian Sid** repository for Hyprland (and Wayland rofi). If a package is not found:
1.  Check your internet connection.
2.  Let the installer run its own `apt update` / full-upgrade (or run `sudo apt update` yourself).
3.  Check if Debian Sid is correctly added under `/etc/apt/sources.list.d/` and pinned in `/etc/apt/preferences.d/sid-pin`.

### `/dev/root` / initramfs rebuild failures
Pi OS names the root disk `/dev/root` in `/proc/mounts`. The installer links the real block device before upgrading. If you upgrade the kernel yourself first:

```bash
part=$(sed -n 's/.*root=PARTUUID=\([^ ]*\).*/\1/p' /proc/cmdline)
sudo ln -sfn "$(readlink -f "/dev/disk/by-partuuid/$part")" /dev/root
```

## Display & Graphics

### Screen flickering or artifacts
Hyprland on the Pi 5 uses the `vc4-kms-v3d` driver. If you experience flickering:
1.  Check your HDMI cable (use the official Micro-HDMI to HDMI cable if possible).
2.  Ensure your power supply is 5V 5A. Low power can cause GPU instability.

### Resolution is too high/low
Edit `~/.config/hypr/hyprland.lua` (Lua is the supported format):

```lua
hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60", position = "0x0", scale = 1 })
```

### An X11-only app will not start
Xwayland is **off** by design (decided). Prefer Wayland builds (e.g. sid rofi). There is **no supported escape hatch** to turn it back on — editing `xwayland.enabled` locally is unsupported and brings back a resident ~90 MB X server. See [Architecture — open decisions](../development/architecture.md#open-decisions).

## Input Devices

### Keyboard layout is incorrect
Pimarchy detects the system layout at install time and writes it into Hyprland. To change it, edit `~/.config/hypr/hyprland.lua`:

```lua
hl.config({
    input = {
        kb_layout = "gb",  -- change "us" to "gb", "de", etc.
    },
})
```

Then reload Hyprland (or log out/in).

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
1.  Open the volume control by clicking the Waybar volume icon (**pavucontrol**), or launch `pavucontrol` from Rofi.
2.  Check the output device settings in the mixer.
3.  Ensure your user is in the `audio` group: `sudo usermod -aG audio $USER`.

---

## Still having trouble?

If your issue isn't listed here, please:
1.  Check install logs you captured (`tee ~/pimarchy_install.log`) or, on a custom image, `/var/log/pimarchy-firstboot.log`.
2.  Run the validation script: `bash validate.sh` from the install root.
3.  [Open an issue](https://github.com/raythurman2386/pimarchy/issues) on GitHub.
