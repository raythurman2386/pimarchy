# First Boot

Pimarchy has two first-boot stories. Pick the one that matches how you flashed the card.

## Custom Pimarchy image

The prebuilt image (`image/build-image.sh`) installs on the **HDMI console**. It does not ask you to log in while that install is running.

1. Flash with `rpi-imager --repo image/work/pimarchy.rpi-imager-manifest` and choose **Pimarchy** (not **Use custom**), so Imager can set user, Wi-Fi, locale, and SSH.
2. Boot. Progress appears on tty1 and is also written to `/var/log/pimarchy-firstboot.log`.
3. When the install finishes, the Pi reboots to the Tuigreet desktop login.

A shell prompt on first boot means the install stopped (no Imager user yet, no network, or `install.sh` failed). Fix the cause, reboot, and firstboot will try again until `/var/lib/pimarchy/firstboot.done` exists. Details: [Installation — custom image](installation.md#optional-flash-a-first-boot-image).

## Stock Pi OS Lite

After you flash a stock Pi OS Lite image, follow these steps to prepare for the netinstall path.

### 1. Login

When the Pi boots, you will see a text-based login prompt. Log in with the username and password you set in the Raspberry Pi Imager.

### 2. Connect to the Internet

If you didn't configure Wi-Fi in the Imager, use `nmtui` to connect:

```bash
sudo nmtui
```

Navigate to **Activate a connection**, select your Wi-Fi, and enter the password.

### 3. Next Step

You are ready to [Install Pimarchy](installation.md). The installer updates Pi OS before it adds the desktop. It links `/dev/root` to the real root disk first, so the initramfs rebuild during that upgrade can finish.

Git is installed by the installer. A separate `apt install git` step is not required for the curl netinstall (netinstall installs `git`/`curl` only if they are missing).
