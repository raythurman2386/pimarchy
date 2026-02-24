# Requirements

To ensure a smooth experience with Pimarchy, ensure your hardware and software meet the following requirements.

## Hardware

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **Device** | Raspberry Pi 5 / Pi 500 | Raspberry Pi 5 (8GB) |
| **Cooling** | Active Cooling (Fan) | Official Active Cooler |
| **Storage** | 8 GB MicroSD / USB | 16 GB+ NVMe or High Speed USB |
| **Power** | 5V 5A (Official PSU) | 27W Official Raspberry Pi PSU |

!!! info "Target Hardware"
    While Pimarchy is designed to work on the Raspberry Pi 5 series (including 4GB and 8GB models), the lead developer (Ray) is building and testing exclusively on a **16GB Raspberry Pi 500+**.

!!! question "Will it work on a Pi 4?"
    Technically, much of the configuration is compatible with the Raspberry Pi 4. However, the installer is specifically tuned for the **Pi 5's VC4/V3D graphics** and performance profiles. We do not officially support the Pi 4 at this time, but we welcome community feedback if you attempt an installation on older hardware.

!!! warning "Cooling is Essential"
    Pimarchy is designed to push the Pi 5 to its full potential. Without active cooling, the system may throttle or become unstable during high-performance tasks or if you choose the [Overclocking](../advanced/overclocking.md) option.

## Software

Pimarchy is built specifically for:
- **Operating System:** Raspberry Pi OS Lite (64-bit)
- **Codename:** Debian Trixie
- **Kernel Version:** 6.6+ (Standard in Trixie)

!!! danger "Do Not Use Pi OS Desktop"
    Pimarchy is an **automated transformation tool** for **Pi OS Lite**. Running it on a system that already has a desktop environment (like GNOME or KDE) may lead to conflicting configurations and broken packages.

## Network

An active internet connection is required during installation to:
-   Update the system packages.
-   Add the Debian Sid (unstable) repository (for the latest Hyprland).
-   Download Docker CE and OpenCode.
