# Architecture & Design

Pimarchy is built for efficiency and modularity. This page explains the architectural choices and system design.

## Design Philosophy

-   **Zero Bloat:** Pimarchy does not install heavy desktop environments like GNOME or KDE. It builds a desktop from the ground up using specialized, lightweight components.
-   **Terminal-Centric:** Most system configuration and interaction are designed for the keyboard.
-   **Wayland-only session:** Xwayland stays disabled so an X server is not a resident ~90 MB process. GTK/Qt clients use Wayland backends; the launcher is sid rofi 2 (Wayland). Trixie rofi 1.7 is X11-only and is not used.
-   **Infrastructure-as-Code (IaC) for your Desktop:** The entire system state is defined by scripts and templates. This makes it reproducible across multiple Pis.

## Directory Structure

```text
├── install.sh                  # Main provisioning entry point (thin orchestrator)
├── uninstall.sh                # Reverts all system changes
├── validate.sh                 # Pre-commit template validator
├── netinstall.sh               # Curl | bash bootstrap → ~/.local/share/pimarchy
├── enable-autologin.sh         # Optional greetd autologin
├── bin/                        # CLI + wrapper scripts (pimarchy, pimarchy-agent, ...)
├── lib/                        # Library modules, sourced via lib/functions.sh
│   ├── common.sh               # Paths & constants
│   ├── log.sh / template.sh    # Logging, {{VARIABLE}} template engine
│   ├── backup.sh               # Config backup/restore
│   ├── repos.sh                # External apt repos (sid policy, Docker CE)
│   ├── packages.sh             # List-driven package modules
│   ├── services.sh             # systemd / greetd / firewall / keyboard / nm-applet mask
│   ├── pi-perf.sh              # Pi 5 governor & overclock
│   ├── pi-firmware.sh          # Safe boot-firmware edits (config.txt / cmdline)
│   ├── ensure-dev-root.sh      # /dev/root symlink for initramfs rebuilds
│   ├── apps.sh                 # App installers, gsettings, cleanup
│   ├── defaults.sh             # Default app policy (Quattro)
│   └── upgrade.sh              # Safe upgrade model (Quattro)
├── image/                      # Custom SD-card image + first-boot pipeline
│   ├── build-image.sh          # Bake Lite → pimarchy-lite-arm64.img
│   ├── write-imager-manifest.sh
│   ├── firstboot.sh            # tty1 installer (user + network + install.sh)
│   ├── firstboot-console.sh    # Restore getty if install stops
│   ├── wifi-country.sh         # Regulatory domain / rfkill unblock
│   └── sync-clock.sh           # Time sync before apt
├── config/
│   ├── theme.conf              # Single source of truth for variables
│   ├── modules.conf            # Registry for mapping templates to paths
│   ├── packages/               # core.list / ai.list / dev.list / office.list / retired.conf
│   ├── theme/                  # GPUI colors.toml + theme.conf templates
│   └── [component]/            # Individual component templates (e.g., hypr, rofi)
└── docs/                       # This documentation
```

## The Core Lifecycle

### 1. Research & Dependency Management
The installer first detects the hardware and software environment. It adds the required **APT repositories** (Sid for the Hyprland stack and Wayland rofi — pinned at priority 100, see the [sid policy](sid-policy.md)) and GPG keys. Package sets are data in `config/packages/*.list`, not code.

### 2. Package Provisioning
The **core module** (always installed) provides the desktop via `apt`, the pinned sid repo, and official install scripts for apps that aren't in Debian (Zed, Pifile). AI (Raven + Ollama), dev, and office toolchains are **lazy modules** (`pimarchy install ai|dev|office`). Pimarchy uses **Hyprland** as the compositor.

### 3. Template Processing (The "Brain")
The `process_template` function in `lib/template.sh` is the core of Pimarchy. It reads every file listed in `modules.conf`, replaces `{{VARIABLE}}` tags with values from `theme.conf` and the default-app policy, and deploys them to their final destination (usually under `~/.config/`, plus GPUI theme state under `~/.local/state/` — see `modules.conf` and [Open decisions](#open-decisions); theme path canonicalization is tracked separately from the lazy `ai` module).

### 4. Service Orchestration
Pimarchy configures and enables systemd services for:
-   **Greetd:** The login manager.
-   **UWSM:** Manages the Hyprland session as a systemd user session.
-   **NetworkManager:** For consistent networking (Waybar + `nmtui` / `nmcli`; nm-applet is masked).
-   **User services:** swaybg, waybar (+ workspace watch), mako under `graphical-session.target`.

### 5. Custom image path
`image/build-image.sh` rsyncs the repo into `/opt/pimarchy` on a Lite rootfs, masks the stock user wizard and getty@tty1, sets US keyboard + Wi-Fi country, and enables `pimarchy-firstboot.service`. On first boot with an Imager user and a network, `firstboot.sh` runs `install.sh --yes --performance` on tty1, then reboots.

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

## Open decisions

Documented unknowns — do not invent answers in docs or code comments:

| Topic | Current behavior | Status |
|-------|------------------|--------|
| **Wi-Fi regulatory country** | Default `US` (`PIMARCHY_WIFI_COUNTRY`) in image build + firstboot | Open — whether Imager locale should drive this automatically is undecided |
| **Imager image hosting** | Manifest uses a local `file://` URI for the `.img` | Open — HTTP(S) hosting / release artifacts not decided |
| **Xwayland** | Disabled in `hyprland.lua` (`xwayland.enabled = false`); sid rofi 2; no nm-applet; `GDK_BACKEND=wayland` in start-hyprland + hyprland.lua | **Decided:** stays off. No supported escape hatch — prefer Wayland builds. Editing `xwayland.enabled` locally is unsupported and costs ~90 MB resident X |
| **GPUI theme paths** | Both `~/.local/state/omarchy/...` and `.../pimarchy/...` are written | Open — standardize on one path once pisuite apps agree |
