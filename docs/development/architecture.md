# Architecture & Design

Pimarchy is built for efficiency and modularity. This page explains the architectural choices and system design.

## Design Philosophy

-   **Zero Bloat:** Pimarchy does not install heavy desktop environments like GNOME or KDE. It builds a desktop from the ground up using specialized, lightweight components.
-   **Terminal-Centric:** Most system configuration and interaction are designed for the keyboard.
-   **Infrastructure-as-Code (IaC) for your Desktop:** The entire system state is defined by scripts and templates. This makes it reproducible across multiple Pis.

## Directory Structure

```text
├── install.sh                  # Main provisioning entry point
├── uninstall.sh                # Reverts all system changes
├── validate.sh                 # Pre-commit template validator
├── lib/
│   └── functions.sh            # Core logic (Logging, Backup, Packages)
├── config/
│   ├── theme.conf              # Single source of truth for variables
│   ├── modules.conf            # Registry for mapping templates to paths
│   └── [component]/            # Individual component templates (e.g., hypr, rofi)
└── docs/                       # This documentation
```

## The Core Lifecycle

### 1. Research & Dependency Management
The installer first detects the hardware and software environment. It adds the required **APT repositories** (Sid for Hyprland, Docker CE) and GPG keys.

### 2. Package Provisioning
Over **30 packages** are installed using `apt`. Pimarchy uses **Hyprland** as the compositor, which is a Wayland-native tiling window manager known for its performance and modern features.

### 3. Template Processing (The "Brain")
The `process_template` function in `lib/functions.sh` is the core of Pimarchy. It reads every file listed in `modules.conf`, replaces `{{VARIABLE}}` tags with values from `theme.conf`, and deploys them to their final destination in `~/.config/`.

### 4. Service Orchestration
Pimarchy configures and enables systemd services for:
-   **Greetd:** The login manager.
-   **UWSM:** Manages the Hyprland session as a systemd user session.
-   **NetworkManager:** For consistent networking.

## Why Hyprland?

Hyprland was chosen for Pimarchy because:
-   It provides a **smooth, hardware-accelerated experience** on the Pi 5.
-   It supports **Wayland**, which is the future of Linux desktops (replacing X11).
-   It has a **dynamic tiling** layout that maximizes screen real estate on small monitors.

## Backup & Safety

Pimarchy implements a "First-Write-Safety" system:
-   On the **first install**, it detects existing configs and saves them to a `.original-backup` folder.
-   Every subsequent install creates a **timestamped snapshot**.
-   The `uninstall.sh` script specifically looks for the original backup to ensure a clean restoration.
