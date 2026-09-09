# Debian Sid Repository Policy

Pimarchy adds **one** external apt source for the desktop stack: Debian sid (unstable), pinned at priority 100. This page documents why, what it covers, and the risks we accept.

## Why Sid at All?

The target platform is **Pi OS Lite (Debian Trixie, arm64)**. Trixie's Hyprland is either absent or too old for the feature set Pimarchy uses (current `bindd` descriptions, current windowrule `match:` syntax, UWSM integration). The options were:

1. **Build Hyprland from source** — heavy, slow on a Pi, and a maintenance burden (submodules, cmake, every update).
2. **Use Trixie's version** — not available/usable for our config syntax.
3. **Pull the Hyprland stack from Debian sid** — binary packages, maintained by Debian, same ABI ecosystem.

We chose (3): it is the only option that keeps the install a few minutes on a Pi 5 while staying inside Debian's packaging ecosystem (no Arch/Pacman tooling, no third-party Hyprland builds).

## The Pin

```text
# /etc/apt/preferences.d/sid-pin
Package: *
Pin: release n=sid
Pin-Priority: 100
```

Priority 100 < 500 means: **sid packages are only installed when explicitly requested** (`apt install -t sid ...`) or when nothing else can satisfy a dependency. A routine `sudo apt upgrade` will never silently pull a package from sid. Only the Hyprland session stack is installed this way — see `sid:` entries in `config/packages/core.list`.

## What Comes From Sid

Only the compositor/session stack, all installed explicitly with `-t sid`:

hyprland, hyprland-guiutils, waybar, mako-notifier, swaybg, xdg-desktop-portal-hyprland, uwsm

Everything else — including Chromium, Foot, Rofi — comes from Trixie.

The Hyprland stack currently pulls **Python 3.14** from sid as a dependency. Trixie `blueman` requires `python3 << 3.14`, so it cannot be installed. Sid `blueman` *would* install, but `-t sid` also upgrades NetworkManager and fontconfig off Pi OS — we do not do that. Waybar's Bluetooth click opens `bluetoothctl` instead.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Sid packages need newer libs than Trixie has | Pin 100 means apt only pulls the packages themselves plus strictly required deps; Hyprland's deps are satisfied within Trixie + sid as tested |
| A future sid update breaks the session | `apt upgrade` won't auto-upgrade sid packages (priority 100); upgrades happen only when you run `apt install -t sid` or a full-upgrade explicitly. Roll back with `sudo apt install <pkg>=<trixie-version>` |
| Repo churn | Debian sid is a rolling suite but the source entry is codename-stable (`sid`); no changes needed per Debian release |
| Debian release transitions (Trixie → Forky) | When Pi OS rebases, the pin keeps preferring the new stable; we re-test and drop sid entries if the new stable covers them |

## Removal

`uninstall.sh` removes `/etc/apt/sources.list.d/sid.list` and `/etc/apt/preferences.d/sid-pin`.

!!! note "full-upgrade on first boot"
    The install guide asks for `sudo apt full-upgrade -y` **before** installing Pimarchy — that resolves the stock Pi OS into a consistent state before the sid pin is introduced, which avoids resolver surprises.