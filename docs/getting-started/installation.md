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

## Step 2: First Boot & Update

Boot your Pi. Log in at the TTY prompt and fully update the system:

```bash
sudo apt update && sudo apt full-upgrade -y
sudo reboot
```

!!! danger "Full Upgrade is Critical"
    A standard `sudo apt upgrade` is not sufficient. A `full-upgrade` is required because Pimarchy adds the **Debian Sid** repository for Hyprland, which often requires resolving new dependency chains.

## Step 3: Install Pimarchy

Once your Pi has rebooted, you can install Pimarchy using our automated web installer. This single command will configure Git (prompting for Name/Email if not set), download Pimarchy, and launch the installer.

```bash
curl -sL https://raw.githubusercontent.com/raythurman2386/pimarchy/main/netinstall.sh | bash
```

### Dry Run (Recommended)

Before applying any changes, you can run a dry run to see exactly what will be installed by passing the `--dry-run` flag to the web installer:

```bash
curl -sL https://raw.githubusercontent.com/raythurman2386/pimarchy/main/netinstall.sh | bash -s -- --dry-run
```

## Step 4: Installation Options

During the installation, you will be prompted with several options. Alternatively, you can pass these flags directly to the web installer:

### 1. Performance and Overclocking

The installer will ask how you want to handle CPU performance:

| Key | Mode | Description |
|-----|------|-------------|
| **g** | **Governor Only** | Keeps CPU at max clock (2.4 GHz). Safe for all units, no reboot required. |
| **o** | **Overclock** | Sets `arm_freq=2600` (2.6 GHz). **Requires active cooling** and a reboot. |
| **N** | **Skip** | Leaves all CPU settings at their defaults. |

### 2. Quiet Mode (Flags)

If you prefer to skip the interactive prompt, you can pass flags directly to the installer:

```bash
curl -sL https://raw.githubusercontent.com/raythurman2386/pimarchy/main/netinstall.sh | bash -s -- --performance   # Governor only
curl -sL https://raw.githubusercontent.com/raythurman2386/pimarchy/main/netinstall.sh | bash -s -- --overclock     # Governor + 2.6 GHz Overclock
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
5.  **Theming:** Deploys configurations based on the Ravenwood palette in `config/theme.conf`.
6.  **Services:** Enables and configures `greetd` as the system's login manager.
7.  **AI Tools:** Raven and Ollama are installed via their official scripts (Zed likewise; Raven's default backend is local Ollama).
