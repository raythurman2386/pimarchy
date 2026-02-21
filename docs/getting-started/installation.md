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

## Step 3: Clone and Install

Once your Pi has rebooted, install Git and clone the repository:

```bash
sudo apt install -y git
git clone https://github.com/raythurman2386/pimarchy.git
cd pimarchy
```

### Dry Run (Recommended)

Before applying any changes, you can run a dry run to see exactly what will be installed:

```bash
bash install.sh --dry-run
```

### Run the Installer

Start the transformation:

```bash
bash install.sh
```

## Step 4: Installation Options

During the installation, you will be prompted with several options:

### 1. Performance and Overclocking

The installer will ask how you want to handle CPU performance:

| Key | Mode | Description |
|-----|------|-------------|
| **g** | **Governor Only** | Keeps CPU at max clock (2.4 GHz). Safe for all units, no reboot required. |
| **o** | **Overclock** | Sets `arm_freq=2600` (2.6 GHz). **Requires active cooling** and a reboot. |
| **N** | **Skip** | Leaves all CPU settings at their defaults. |

### 2. Quiet Mode (Flags)

If you prefer to skip the interactive prompt, you can pass flags directly:

```bash
bash install.sh --performance   # Governor only
bash install.sh --overclock     # Governor + 2.6 GHz Overclock
```

## Step 5: Final Reboot

Once the script completes, perform one last reboot:

```bash
sudo reboot
```

After rebooting, you will be greeted by the **Tuigreet** login manager. Log in with your username and password, and **Hyprland** will start automatically.

---

## What Happens During Installation?

1.  **Backup:** Backs up your existing configs to `~/.config/Pimarchy-backup/`.
2.  **Repo Setup:** Adds Debian Sid (for Hyprland) and Docker CE repositories.
3.  **Package Management:** Installs over 30 packages including Wayland, Hyprland, and Alacritty.
4.  **Theming:** Deploys configurations based on the Ravenwood palette in `config/theme.conf`.
5.  **Services:** Enables and configures `greetd` as the system's login manager.
6.  **AI Tools:** Installs the OpenCode agent into `~/.opencode/`.
