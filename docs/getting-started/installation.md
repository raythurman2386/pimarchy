# Installation Guide

Setting up Pimarchy is a simple, automated process. Follow these steps to transform your Raspberry Pi 5.

## Step 1: Flash Pi OS Lite

Download and flash **Raspberry Pi OS Lite (64-bit)** using the [Raspberry Pi Imager](https://www.raspberrypi.com/software/).

1.  Select **OS**: Raspberry Pi OS (other) → **Raspberry Pi OS Lite (64-bit)**.
2.  Select **Storage**: Choose your MicroSD or SSD.
3.  Click the **Gear Icon** (Advanced Settings):
    -   Set **Hostname**: (e.g., `pimarchy`)
    -   Set **Username and Password**: (e.g., `ret`)
    -   **Configure Wi-Fi**: Enter your SSID and password.
    -   **Set Locale Settings**: (e.g., Timezone and Keyboard layout).
    -   **Enable SSH**: (Optional, if you want to connect remotely).

## Optional: flash a first-boot image

`image/build-image.sh` writes `image/work/pimarchy-lite-arm64.img` and `image/work/pimarchy.rpi-imager-manifest`. Open that manifest so Imager offers the username, password, Wi-Fi, locale, and SSH step:

```bash
rpi-imager --repo image/work/pimarchy.rpi-imager-manifest
```

Choose **Pimarchy**. Imager 2 hides that step for **Use custom**, because a file picked that way has no `init_format`. This image is Trixie Lite with cloud-init, and the manifest declares `cloudinit-rpi`, which is the format that image reads. The image does not open the stock Pi user or keyboard wizard. The disk grows on its own. The keyboard default is US, so `~` is Shift plus the key left of `1`, unless you pick another layout in the Imager. Wi-Fi is allowed for the US regulatory domain, so the radio is not left blocked by rfkill. Set `PIMARCHY_WIFI_COUNTRY` when building the image if the Pi will be used in another country. The first boot that has that user and a network sets the clock, then installs the desktop with the performance governor. The installer owns the HDMI console and does not ask for a login. A shell prompt means that install has stopped; its log is `/var/log/pimarchy-firstboot.log`. When the install finishes, the Pi reboots into the desktop. A Pi has no battery clock, so apt waits for the time sync before it trusts repository signatures.

```bash
sudo bash image/build-image.sh
```

## Step 2: Install Pimarchy

Boot the Pi, log in, and connect to the network (`nmtui` if Wi-Fi was not set in the Imager). The installer updates Pi OS, then adds the desktop. This command configures Git (prompting for a name and email if they are not set), downloads Pimarchy, and launches the installer.

```bash
curl -sL https://raw.githubusercontent.com/raythurman2386/pimarchy/main/netinstall.sh | bash
```

### Dry Run (Recommended)

Before applying any changes, you can run a dry run to see exactly what will be installed by passing the `--dry-run` flag to the web installer:

```bash
curl -sL https://raw.githubusercontent.com/raythurman2386/pimarchy/main/netinstall.sh | bash -s -- --dry-run
```

## Installer options

During the installation, you will be prompted with several options. Alternatively, you can pass these flags directly to the web installer:

### 1. Performance and Overclocking

The installer will ask how you want to handle CPU performance:

| Key | Mode | Description |
|-----|------|-------------|
| **g** | **Governor Only** | Keeps CPU at max clock (2.4 GHz). Safe for all units, no reboot required. |
| **o** | **Overclock** | Sets `arm_freq=2600`. Stock is 2400 MHz. Firmware scales voltage. **Requires active cooling** and a reboot. |
| **N** | **Skip** | Leaves all CPU settings at their defaults. |

### 2. Quiet Mode (Flags)

If you prefer to skip the interactive prompt, you can pass flags directly to the installer:

```bash
curl -sL https://raw.githubusercontent.com/raythurman2386/pimarchy/main/netinstall.sh | bash -s -- --performance   # Governor only
curl -sL https://raw.githubusercontent.com/raythurman2386/pimarchy/main/netinstall.sh | bash -s -- --overclock     # Governor + arm_freq=2600 (firmware scales voltage)
```

## Step 5: Final Reboot

Once the script completes, perform one last reboot:

```bash
sudo reboot
```

After rebooting, you will be greeted by the **Tuigreet** login manager. Log in with your username and password, and **Hyprland** will start automatically.

## Optional: Enable Auto-Login

If you want your Pi to automatically login and start Hyprland on boot (useful for headless setups or ensuring services always start after a reboot), run:

```bash
sudo bash enable-autologin.sh
```

This configures `greetd` to skip the login prompt and automatically start the desktop environment for your user. To disable auto-login later, re-run the Pimarchy installer.

---

## Managing Pimarchy (CLI Tool)

Once installed, Pimarchy includes a global CLI tool to easily manage updates and configurations.

```bash
# Fetch the latest version from GitHub — safe upgrade:
# pristine configs refresh, user-modified files are left untouched
pimarchy update

# Validate your current template configurations
pimarchy validate

# Re-run the installer (e.g. to apply a new theme.conf)
pimarchy install

# Lazy package modules (not in the default install)
pimarchy install dev      # Rust, Node.js, Go, Python, Docker CE
pimarchy install office   # LibreOffice

# Default app policy
pimarchy defaults                       # show agent/browser/editor/terminal/filemanager
pimarchy default agent raven            # Raven is pre-selected
pimarchy default editor zed
pimarchy default terminal foot
pimarchy default browser chromium
pimarchy default filemanager pifile

# Launch the coding agent (Super+Shift+Ctrl+A does this too)
pimarchy agent "write a hello world in rust"

# Uninstall Pimarchy and restore original config backups
pimarchy uninstall
```

Upgrading from a pre-Quattro install? See the [migration note](../development/defaults.md#migration-for-pre-quattro-users).

---

## Advanced: Manual Setup

If you prefer to clone and run the installer manually:

```bash
sudo apt install -y git
git clone https://github.com/raythurman2386/pimarchy.git ~/.local/share/pimarchy
cd ~/.local/share/pimarchy
bash install.sh
```

---

## What Happens During Installation?

1.  **Backup:** Backs up your existing configs to `~/.config/Pimarchy-backup/`.
2.  **Repo Setup:** Adds Debian Sid (for Hyprland — pinned, see the [sid policy](../development/sid-policy.md)) and the Docker CE repository (used only by the dev module).
3.  **Package Management:** Installs the **core module** from `config/packages/core.list` — the lean, always-installed set (Hyprland stack, Foot, Rofi, Chromium, Zed, Pifile, Raven, Ollama). No LibreOffice, no Node/Go/Rust/Docker unless you install the dev/office modules.
4.  **Defaults:** Writes the default app policy (`~/.config/pimarchy/defaults/`): agent=raven, editor=zed, terminal=foot, browser=chromium, filemanager=pifile.
5.  **Theming:** Deploys configurations based on the Ravenwood palette in `config/theme.conf`, including GPUI Kit `colors.toml` under `~/.local/state/{omarchy,pimarchy}/current/theme/`.
6.  **Services:** Enables and configures `greetd` as the system's login manager.
7.  **AI Tools:** Raven and Ollama are installed via their official scripts (Zed likewise; Raven's default backend is local Ollama).
