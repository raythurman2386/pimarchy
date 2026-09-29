# Uninstallation & Recovery

Pimarchy is designed to be fully reversible. If you need to revert your Raspberry Pi to its original state, follow these steps.

## The `uninstall.sh` Script

The `uninstall.sh` script is the primary tool for removing Pimarchy. It handles several key tasks:

1.  **Backs up current configs:** Before making changes, it creates a final snapshot of your configuration.
2.  **Restores original backups:** It looks for the `.original-backup` marker and restores your pre-Pimarchy configurations to `~/.config/`.
3.  **Removes packages (Optional):** You will be prompted to choose whether to remove the packages installed by Pimarchy.
4.  **Reverts Boot Settings:** It removes boot lines Pimarchy added in `/boot/firmware/config.txt` and `/boot/firmware/cmdline.txt`. Lines you wrote yourself stay in place. GPUI theme state under `~/.local/state/{omarchy,pimarchy}/current/theme/` is removed.
5.  **Disables Greetd:** It disables the login manager and reverts the system to a standard TTY console login.

## How to Uninstall

1.  Navigate to the install root (netinstall uses `~/.local/share/pimarchy`):
    ```bash
    cd ~/.local/share/pimarchy
    # or: pimarchy uninstall
    ```
2.  Run the uninstaller:
    ```bash
    bash uninstall.sh
    ```
3.  Follow the interactive prompts:
    - **Remove packages?** (y/N) — If you select **y**, Hyprland, Waybar, Foot, and other core packages will be removed (dev/office module packages you installed separately are untouched except for the shared core set). `network-manager-gnome` (the transitional `nm-applet` package) is not installed again. Wi-Fi stays available through `nmcli` and `nmtui`.
    - **Remove backup files?** (y/N) — Choose whether to delete the config backups in `~/.config/Pimarchy-backup/`.

    The Ollama polkit rule `/etc/polkit-1/rules.d/50-pimarchy-ollama.rules` is removed either way. Declining package removal still deletes that rule.

4.  **Final Reboot:**
    ```bash
    sudo reboot
    ```

## Manual Recovery

If for some reason `uninstall.sh` fails, you can manually revert your system:

### 1. Disable Greetd
```bash
sudo systemctl disable greetd
sudo systemctl enable getty@tty1
```

### 2. Remove Pimarchy boot lines

The CPU governor is the systemd unit `pimarchy-governor.service`, not a line in `config.txt`:

```bash
sudo systemctl disable --now pimarchy-governor.service
sudo rm -f /etc/systemd/system/pimarchy-governor.service
sudo systemctl daemon-reload
```

If you accepted the overclock prompt, `/boot/firmware/config.txt` contains this comment and the `arm_freq` line under it:

```ini
# Pimarchy: Pi 5 overclock arm_freq=2600 (stock 2400; firmware scales voltage)
arm_freq=2600
```

An older install that had no `[all]` section wrote this block instead. Remove the comment, the `[all]` header that belongs to it, and `arm_freq=2600`:

```ini
# Pimarchy: Pi 5 mild overclock (2600 MHz, no extra voltage required)
[all]
arm_freq=2600
```

Leave any other `arm_freq=` line in the file. An older install that already had an `[all]` section wrote a bare `arm_freq=2600` under that header and no comment. `uninstall.sh` leaves that line in place. Remove it when it came from the overclock prompt.

A previous Pimarchy version also wrote a PCIe Gen 3 block. Remove the comment and the `dtparam` line under it. When that block is the whole `[all]` section, remove the `[all]` header with it:

```ini
# Pimarchy: NVMe at PCIe Gen 3 (drive trains at 8 GT/s)
dtparam=pciex1_gen=3
```

Leave a `dtparam=pciex1_gen=3` or `dtparam=pciex1_gen=2` line that has no Pimarchy comment above it.

The same version added `# Pimarchy: Pi 500 has no camera` above `camera_auto_detect`. Remove the comment and leave the `camera_auto_detect` value as it is. On a Pi 5 with a CSI camera, set `camera_auto_detect=1` when you want firmware autodetect back.

On `/boot/firmware/cmdline.txt`, delete a trailing `cma=512M` token that version appended (the line ends in ` cma=512M`, or the line is only `cma=512M`). Leave `cma=64M`, `cma=128M`, `cma=256M`, and a `cma=512M` that is not at the end of the line.

`uninstall.sh` removes those owned lines. It unmasks `NetworkManager-wait-online.service` when a previous install masked it, and it does not enable the unit.

### 3. Restore Backups
Your original configurations are stored in `~/.config/Pimarchy-backup/original/`. You can copy them back to `~/.config/`.

```bash
cp -r ~/.config/Pimarchy-backup/original/* ~/.config/
```

## Need a Fresh Start?

If you want to completely wipe Pimarchy and start over, the fastest way is to **re-flash your MicroSD card** with a fresh Pi OS Lite image, or rebuild/flash the [custom first-boot image](getting-started/installation.md#optional-flash-a-first-boot-image).
