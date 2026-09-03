# Architecture & Design

Pimarchy is built for efficiency and modularity. This page explains the architectural choices and system design.

## Design Philosophy

-   **Zero Bloat:** Pimarchy does not install heavy desktop environments like GNOME or KDE. It builds a desktop from the ground up using specialized, lightweight components.
-   **Terminal-Centric:** Most system configuration and interaction are designed for the keyboard.
-   **Infrastructure-as-Code (IaC) for your Desktop:** The entire system state is defined by scripts and templates. This makes it reproducible across multiple Pis.

## Directory Structure

```text
├── install.sh                  # Main provisioning entry point (thin orchestrator)
├── uninstall.sh                # Reverts all system changes
├── validate.sh                 # Pre-commit template validator
├── bin/                        # CLI + wrapper scripts (pimarchy, pimarchy-agent, ...)
├── lib/                        # Library modules, sourced via lib/functions.sh
│   ├── common.sh               # Paths & constants
│   ├── log.sh / template.sh    # Logging, {{VARIABLE}} template engine
│   ├── backup.sh               # Config backup/restore
│   ├── repos.sh                # External apt repos (sid policy, Docker CE)
│   ├── packages.sh             # List-driven package modules
│   ├── services.sh             # systemd / greetd / firewall / keyboard
│   ├── pi-perf.sh              # Pi 5 governor & overclock
│   ├── apps.sh                 # App installers, gsettings, cleanup
│   ├── defaults.sh             # Default app policy (Quattro)
│   └── upgrade.sh              # Safe upgrade model (Quattro)
├── config/
│   ├── theme.conf              # Single source of truth for variables
│   ├── modules.conf            # Registry for mapping templates to paths
│   ├── packages/               # core.list / dev.list / office.list / retired.conf
│   └── [component]/            # Individual component templates (e.g., hypr, rofi)
└── docs/                       # This documentation
```

## The Core Lifecycle

### 1. Research & Dependency Management
The installer first detects the hardware and software environment. It adds the required **APT repositories** (Sid for the Hyprland stack — pinned at priority 100, see the [sid policy](sid-policy.md)) and GPG keys. Package sets are data in `config/packages/*.list`, not code.

### 2. Package Provisioning
The **core module** (always installed) provides the desktop via `apt`, the pinned sid repo, and official install scripts for apps that aren't in Debian (Zed, Raven, Ollama). Dev and office toolchains are **lazy modules** (`pimarchy install dev|office`). Pimarchy uses **Hyprland** as the compositor, which is a Wayland-native tiling window manager known for its performance and modern features.

### 3. Template Processing (The "Brain")
The `process_template` function in `lib/template.sh` is the core of Pimarchy. It reads every file listed in `modules.conf`, replaces `{{VARIABLE}}` tags with values from `theme.conf` and the default-app policy, and deploys them to their final destination in `~/.config/`.

### 4. Service Orchestration
Pimarchy configures and enables systemd services for:
-   **Greetd:** The login manager.
-   **UWSM:** Manages the Hyprland session as a systemd user session.
-   **NetworkManager:** For consistent networking.

## Safe Upgrades (Quattro)

`pimarchy update` never clobbers user edits. Every installed file's hash is recorded in `~/.config/pimarchy/manifest`; on update, pristine files refresh while user-modified files are left untouched and reported. Retired files are cleaned up via `config/packages/retired.conf`. Full policy: [defaults.md](defaults.md).

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
