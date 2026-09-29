# Installation Guide

Setting up Pimarchy is a simple, automated process. Follow these steps to transform your Raspberry Pi 5.

There are two install paths:

1. **Stock Pi OS Lite + netinstall** (below) — flash Lite, log in, run the curl installer.
2. **Custom first-boot image** ([optional section](#optional-flash-a-first-boot-image)) — flash a Pimarchy-built image; the desktop installs on the HDMI console without a login prompt.

## Step 1: Flash Pi OS Lite

Download and flash **Raspberry Pi OS Lite (64-bit)** using the [Raspberry Pi Imager](https://www.raspberrypi.com/software/).

1.  Select **OS**: Raspberry Pi OS (other) → **Raspberry Pi OS Lite (64-bit)**.
2.  Select **Storage**: Choose your MicroSD or SSD.
3.  Click the **Gear Icon** (Advanced Settings) / OS customisation:
    -   Set **Hostname**: (e.g., `pimarchy`)
    -   Set **Username and Password**: (e.g., `ret`)
    -   **Configure Wi-Fi**: Enter your SSID and password.
    -   **Set Locale Settings**: (e.g., Timezone and Keyboard layout).
    -   **Enable SSH**: (Optional, if you want to connect remotely).

## Optional: flash a first-boot image

`image/build-image.sh` writes a flashable disk image and an Imager repository manifest:

- `image/work/pimarchy-lite-arm64.img`
- `image/work/pimarchy.rpi-imager-manifest`

Build (from a clone of this repo, on a Linux host with `sudo`, `curl`, `xz`, `losetup`, `rsync`, and `python3`):

```bash
sudo bash image/build-image.sh
```

Open the manifest so Imager offers the username, password, Wi-Fi, locale, and SSH step:

```bash
rpi-imager --repo image/work/pimarchy.rpi-imager-manifest
```

Choose **Pimarchy**. Imager 2 hides that customisation step for **Use custom**, because a file picked that way has no `init_format`. This image is Trixie Lite with cloud-init; the manifest declares `init_format: cloudinit-rpi`, which is the format that image reads.

What the image does on first boot:

- Does **not** open the stock Pi user/keyboard wizard (masked).
- Expands the root filesystem on its own (`resize` in cmdline).
- Defaults the keyboard to **US** unless you pick another layout in Imager (`~` is Shift plus the key left of `1` on a US layout).
- Sets a Wi-Fi regulatory country so the radio is not left rfkill-blocked (default **US**; override at build/firstboot with `PIMARCHY_WIFI_COUNTRY`).
- Waits for the Imager-created login user and a default route, syncs the clock, then runs `install.sh --yes --performance` on tty1.
- Owns the HDMI console (getty on tty1 is masked during install). A shell prompt means the install has stopped; see `/var/log/pimarchy-firstboot.log`.
- On success, reboots into greetd / the desktop.

A Pi has no battery clock, so firstboot syncs time before apt trusts repository signatures.

!!! warning "Open decisions (custom image)"
    These are intentional current defaults, not finished product policy:

    - **Wi-Fi country:** build/firstboot default is `US` via `PIMARCHY_WIFI_COUNTRY`. Non-US builds must set that variable when building (or at first boot).
    - **Imager image URL:** `write-imager-manifest.sh` embeds a local `file://` URI for the `.img`. Hosting the image over HTTP(S) for remote Imager use is not decided yet.
    - **Xwayland:** the installed session keeps Xwayland **off** (Wayland-only; decided — no supported escape hatch). See [Architecture — open decisions](../development/architecture.md#open-decisions).

## Step 2: Install Pimarchy (stock Lite path)

Boot the Pi, log in, and connect to the network (`nmtui` if Wi-Fi was not set in the Imager). The installer updates Pi OS, then adds the desktop. This command configures Git (prompting for a name and email if they are not set), downloads Pimarchy to `~/.local/share/pimarchy`, and launches the installer.

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

## Step 3: Final Reboot

Once the script completes, perform one last reboot:

```bash
sudo reboot
```

After rebooting, you will be greeted by the **Tuigreet** login manager. Log in with your username and password, and **Hyprland** will start automatically.

## Optional: Enable Auto-Login

If you want your Pi to automatically login and start Hyprland on boot (useful for headless setups or ensuring services always start after a reboot), run:

```bash
cd ~/.local/share/pimarchy
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
2.  **Repo Setup:** Adds Debian Sid (for Hyprland and Wayland rofi — pinned, see the [sid policy](../development/sid-policy.md)) and the Docker CE repository (used only by the dev module).
3.  **Package Management:** Installs the **core module** from `config/packages/core.list` — the lean, always-installed set (Hyprland stack, Foot, sid Rofi, Chromium, Zed, Pifile, Raven, Ollama). No LibreOffice, no Node/Go/Rust/Docker unless you install the dev/office modules. `network-manager-gnome` / nm-applet is not installed (Waybar owns the network icon; the applet would keep Xwayland resident).
4.  **Defaults:** Writes the default app policy (`~/.config/pimarchy/defaults/`): agent=raven, editor=zed, terminal=foot, browser=chromium, filemanager=pifile.
5.  **Theming:** Deploys configurations based on the Ravenwood palette in `config/theme.conf`, including GPUI Kit `colors.toml` / `theme.conf` under both `~/.local/state/omarchy/current/theme/` and `~/.local/state/pimarchy/current/theme/` (dual paths; standardization is an [open decision](../development/architecture.md#open-decisions)).
6.  **Services:** Enables and configures `greetd` as the system's login manager. Hyprland session is Wayland-only (`xwayland.enabled = false`).
7.  **AI Tools:** Raven and Ollama are installed via their official scripts (Zed likewise; Raven's default backend is local Ollama).
