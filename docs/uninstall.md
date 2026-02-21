# Uninstallation & Recovery

Pimarchy is designed to be fully reversible. If you need to revert your Raspberry Pi to its original state, follow these steps.

## The `uninstall.sh` Script

The `uninstall.sh` script is the primary tool for removing Pimarchy. It handles several key tasks:

1.  **Backs up current configs:** Before making changes, it creates a final snapshot of your configuration.
2.  **Restores original backups:** It looks for the `.original-backup` marker and restores your pre-Pimarchy configurations to `~/.config/`.
3.  **Removes packages (Optional):** You will be prompted to choose whether to remove the packages installed by Pimarchy.
4.  **Reverts Boot Settings:** It removes the overclocking and performance settings from `/boot/firmware/config.txt`.
5.  **Disables Greetd:** It disables the login manager and reverts the system to a standard TTY console login.

## How to Uninstall

1.  Navigate to your `pimarchy` directory:
    ```bash
    cd ~/pimarchy
    ```
2.  Run the uninstaller:
    ```bash
    bash uninstall.sh
    ```
3.  Follow the interactive prompts:
    - **Remove packages?** (y/N) — If you select **y**, Hyprland, Waybar, Alacritty, and other packages will be removed.
    - **Remove Docker?** (y/N) — Choose whether to remove Docker and its repositories.
    - **Remove OpenCode?** (y/N) — Choose whether to remove the OpenCode AI agent.

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

### 2. Remove CPU Performance Mode
Edit `/boot/firmware/config.txt` and remove the following lines:
```ini
# PIMARCHY PERFORMANCE MODE
arm_freq=2600
# or
governor=performance
```

### 3. Restore Backups
Your original configurations are stored in `~/.config/Pimarchy-backup/original/`. You can copy them back to `~/.config/`.

```bash
cp -r ~/.config/Pimarchy-backup/original/* ~/.config/
```

## Need a Fresh Start?

If you want to completely wipe Pimarchy and start over, the fastest way is to **re-flash your MicroSD card** with a fresh copy of Pi OS Lite using the Raspberry Pi Imager.
