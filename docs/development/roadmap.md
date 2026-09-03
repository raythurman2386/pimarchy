# Roadmap & Future Thoughts

Pimarchy is a living project. This page outlines our current goals, planned features, and future ideas for the Raspberry Pi 5 desktop transformation.

## Phase 1: Core Stability (Done)
- [x] **Automated Installer:** Provisioning Pi OS Lite to Hyprland.
- [x] **Ravenwood Theme:** Centralized variables and templates.
- [x] **Backup System:** Safe and reversible installations.
- [x] **Core Components:** Hyprland, Waybar, Rofi, Mako, Foot.

## Phase 2: The Quattro Overhaul (Current)
- [x] **Library split:** `lib/functions.sh` decomposed into focused modules; `install.sh` is a thin orchestrator.
- [x] **Package lists as data:** `config/packages/{core,dev,office}.list` — core is the always-installed lean set; dev and office are lazy modules.
- [x] **Default app policy:** `pimarchy defaults`, `pimarchy default <agent|browser|editor|terminal>` — Raven (agent), Zed (editor), Foot (terminal), Chromium (browser).
- [x] **Agent integration:** `pimarchy agent` launcher (Quattro-style) + Super+Shift+Ctrl+A binding with a themed raven window class; Raven installs lazily.
- [x] **Safe upgrade model:** `pimarchy update` hashes shipped files — pristine ones refresh, user-modified ones are left untouched and reported; retired files are cleaned up.
- [x] **De-cluttered default install:** VS Code, OpenCode, and LibreOffice dropped from the default path (LibreOffice moved to the office module).
- [x] **Sid pin policy:** documented in [sid-policy.md](sid-policy.md).
- [ ] **Pi OS Lite Trixie test pass:** fresh-image + existing-install verification on real hardware.

## Phase 3: User Experience (Next)
- [ ] **Quick Theme Switcher:** A script to switch between predefined color palettes (e.g., Gruvbox, Nord, Catppuccin) without a full re-install.
- [ ] **GUI Configurator:** A simple terminal UI (`whiptail` or `gum`) for modifying `theme.conf` variables.
- [ ] **Lock Screen Enhancement:** Integrating `swaylock-effects` for blurred background and custom layout.
- [ ] **Bluetooth Support:** Built-in menu or shortcut for managing Bluetooth connections on the Pi 5.

## Phase 4: Advanced Features (Planned)
- [ ] **Pimarchy-Hub:** A light dashboard or menu for managing system performance, Docker containers, and Raven tasks.
- [ ] **Extension Support:** A structured way for users to add and share "Pimarchy Modules."
- [ ] **Official Support for Pi 4:** Exploring compatibility and performance for the previous generation.

## Future Ideas & Brainstorming
- **Game Mode:** A one-click configuration for maximizing gaming performance (e.g., stopping non-essential services, max GPU clock).
- **Home Server Mode:** A module to quickly deploy Pi-hole, Home Assistant, and a media server alongside the desktop.
- **Pi 500 Specific Optimizations:** Tailoring the desktop experience specifically for the Pi 500 keyboard form factor.
- **More agents in the default allowlist:** e.g. Codex-style or local-only agents selectable via `pimarchy default agent <name>`.

---

!!! info "Get Involved"
    Do you have an idea for Pimarchy? We'd love to hear it! Please [open a feature request](https://github.com/raythurman2386/pimarchy/issues/new?template=feature_request.md) or join the discussion in the repository.