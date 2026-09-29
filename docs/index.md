# Pimarchy

<p align="center">
  <img src="./img/screenshot.png" alt="Pimarchy Desktop" width="800">
</p>

## Overview

**Pimarchy** is an automated desktop transformation tool designed for the **Raspberry Pi 5 and Pi 500**. It converts a barebones **Pi OS Lite (Debian Trixie)** installation into a modern, aesthetic, and functional Wayland-based desktop environment.

Inspired by [Omarchy](https://github.com/basecamp/omarchy) by Basecamp, it focuses on extreme efficiency, beautiful aesthetics, and a keyboard-driven workflow.

[**Get Started**](getting-started/installation.md){ .md-button .md-button--primary }
[**View Source**](https://github.com/raythurman2386/pimarchy){ .md-button }

---

## Core Components

| Layer | Component | Description |
|-------|-----------|-------------|
| **Compositor** | Hyprland | Dynamic tiling Wayland compositor with live-tuned animations (workspace switching stays instant for Pi performance). |
| **Status bar** | Waybar | Highly customizable CSS-themed status bar. |
| **App launcher** | Rofi | Wayland-native launcher (sid rofi 2; Trixie rofi is X11-only and unused). |
| **Notifications** | Mako | Lightweight notification daemon. |
| **Terminal** | Foot | Fast, lightweight Wayland-native terminal emulator (default terminal). |
| **Login manager** | Greetd + Tuigreet | Sleek console-based login manager. |
| **Browser** | Chromium | Default browser, with Wayland flags pre-configured. |
| **Code editor** | Zed | Modern, Rust-based code editor (default editor). |
| **File manager** | Pifile | Keyboard-first default file manager (Super+E). |
| **CLI tools** | fd, ripgrep, gh | Fast, Rust-based file search and grep. |
| **AI Agent** | Raven + Ollama | Default coding agent (`pimarchy agent`, Super+Shift+Ctrl+A) with local inference. |

**Lazy modules:** Docker/Rust/Node/Go (`pimarchy install dev`) and LibreOffice (`pimarchy install office`) are opt-in — the base install stays lean. See [Default Apps & Package Modules](development/defaults.md).

---

## Why Pimarchy?

-   **Performance First:** Built specifically for the Raspberry Pi 5 hardware. Xwayland stays off; the session is Wayland-only.
-   **Aesthetic & Modern:** Driven by the Ravenwood color palette (Everforest-inspired).
-   **Automated:** One script (or a first-boot custom image) to provision everything from a clean install.
-   **Safe & Reversible:** Comprehensive backup and uninstallation system.
-   **Template-Driven:** Change one file (`theme.conf`) to re-theme the entire system.

---

## Quick Installation

On a stock Pi OS Lite card (user and network already set in Raspberry Pi Imager):

```bash
# The installer updates Pi OS itself — no separate full-upgrade step required.
curl -sL https://raw.githubusercontent.com/raythurman2386/pimarchy/main/netinstall.sh | bash
```

Alternatively, build a [custom first-boot image](getting-started/installation.md#optional-flash-a-first-boot-image) that installs the desktop on the HDMI console without a login prompt.

!!! success "Ready to go!"
    After installation, reboot and log in via Tuigreet to start your new Hyprland session.
