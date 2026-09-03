# Default Apps & Package Modules (Quattro)

Pimarchy ships a **default app policy**: a small set of pre-selected applications recorded in `~/.config/pimarchy/defaults/`, plus **lazy package modules** so the base install stays lean.

## Default Apps

| Category | Default | Set with |
|----------|---------|----------|
| Coding agent | **Raven** | `pimarchy default agent raven` |
| Editor | **Zed** | `pimarchy default editor zed` |
| Terminal | **Foot** | `pimarchy default terminal foot` |
| Browser | **Chromium** | `pimarchy default browser chromium` |

```bash
pimarchy defaults                      # show all four
pimarchy default browser chromium      # set one (validated against an allowlist)
pimarchy default agent                 # show one
```

The default files are plain `key=value` files in `~/.config/pimarchy/defaults/`:

```text
# ~/.config/pimarchy/defaults/agent
# Written by: pimarchy default agent <name>
# Read by:    pimarchy agent
agent=raven
```

Values are validated against a fixed allowlist before being written — and again when read — because launchers consume these files. An unknown value falls back to the shipped default instead of ever being executed.

After changing a default, re-run `bash install.sh` (or `pimarchy update`) so templates (e.g. Hyprland keybinds) pick up the new value.

## The Agent Keybind (Quattro-style)

**SUPER + SHIFT + CTRL + A** launches the default coding agent in its own Hyprland window class:

```text
bindd = $mainMod SHIFT CTRL, A, Coding Agent, exec, pimarchy agent
windowrule = match:class ^(raven)$, float 1, size 900 600, center 1
```

Any extra arguments are passed as the agent prompt:

```bash
pimarchy agent "fix the failing test in lib/upgrade.sh"
```

Raven installs lazily on first selection — if the binary is missing, `pimarchy default agent raven` fetches it via Raven's official install script.

## Package Modules

Packages are declared as data in `config/packages/*.list` with three tags:

- `apt:<pkg>` — from the default (stable/Trixie) repositories
- `sid:<pkg>` — from Debian sid (pinned; see the [Sid policy](sid-policy.md))
- `script:<label>` — installed by an official-script hook (Zed, Raven, Ollama, rustup, Node, Go...)

### core.list — always installed

| Tag | Packages |
|-----|----------|
| apt | foot, starship, fonts-font-awesome, fonts-jetbrains-mono, fonts-noto-color-emoji, arc-theme, papirus-icon-theme, fontconfig, rofi, greetd, tuigreet, thunar, lxpolkit, pavucontrol, network-manager-gnome, bluez, bluez-tools, alsa-utils, wireplumber, grim, slurp, wl-clipboard, btop, ufw, jq, fd-find, ripgrep, unzip, wget, curl, gh, chromium |
| sid | hyprland, hyprland-guiutils, waybar, mako-notifier, swaybg, xdg-desktop-portal-hyprland, uwsm |
| script | zed, raven, ollama |

**Not in core** (deliberately): LibreOffice, VS Code, OpenCode, Node, Go, Rust, Python dev tools, Docker. Memory efficiency on a 4 GB Pi is the priority — no heavy GUI apps in the default path.

### dev.list — `pimarchy install dev`

| Tag | Packages |
|-----|----------|
| script | rustup (Rust, official rustup.rs — not apt), node (Node.js v22 LTS via NodeSource), go (latest stable from golang.org), python-dev (pip, venv, pipx) |
| apt | ca-certificates, gnupg, docker-ce, docker-ce-cli, containerd.io, docker-buildx-plugin, docker-compose-plugin, build-essential, pkg-config, libssl-dev, git-lfs, shellcheck |

Docker CE comes from the official download.docker.com repository (pinned 1001), never Debian's `docker.io` — it lacks `docker-compose-plugin`. **Docker group membership is opt-in**:

```bash
pimarchy install dev --with-docker-group
# or manually: sudo usermod -aG docker $USER
```

### office.list — `pimarchy install office`

| Tag | Packages |
|-----|----------|
| apt | libreoffice-writer, libreoffice-calc, libreoffice-impress, libreoffice-gtk3, libreoffice-help-en-us |

## Safe Upgrade Policy

`pimarchy update` never clobbers your edits. For every shipped config file:

1. **Missing file** → installed (this includes all new Quattro-only files).
2. **Hash matches the manifest** (pristine, unchanged since Pimarchy wrote it) → refreshed from the new default.
3. **Hash differs** (user-modified) → left untouched, and reported.
4. **No manifest entry** (pre-Quattro file or user-created) → left untouched, and reported.

Hashes live in `~/.config/pimarchy/manifest`. `pimarchy update` snapshots pristine hashes *before* `git pull` (with the old code checked out), so files unchanged since your last install are recognized as refreshable even if the manifest was missing entries.

**Retired files** (previously shipped, now removed from the set — e.g. `~/.config/chromium-flags.conf`, OpenCode/VS Code leftovers) are renamed to `<file>.pimarchy-upgrade.bak` and then removed.

`bash install.sh` (and `pimarchy install`) intentionally **always overwrite** — that's the "re-apply my theme.conf" workflow — and record fresh hashes, so the next `pimarchy update` is gated against the new baseline. If you want install-time protection for a file, edit it *after* installing.

!!! tip "Prefer installing with your edits already made?"
    Install first, then edit. The manifest records what Pimarchy wrote; your subsequent edits are what the safe upgrade protects.

## Migration for Pre-Quattro Users

If you installed Pimarchy before the Quattro overhaul:

- Run `pimarchy update` (or re-run `bash install.sh`) to get the new structure.
- Your packages are **not removed**. The old full set is preserved behind a flag: `bash install.sh --legacy-packages` reinstalls dev + office toolchains (Node, Go, Python, Docker, LibreOffice) if you want them.
- Config files you never touched are refreshed; anything you edited is left alone and reported by `pimarchy update`.
- Stale files from the VS Code / OpenCode era are retired automatically (backed up as `*.pimarchy-upgrade.bak`, then removed).
- New keybinds live in `~/.config/hypr/bindings.conf` (sourced by `hyprland.conf`). If you customized keybinds before, your old `hyprland.conf` is user-modified — the update will skip it. Merge your binds into the new file at your leisure.

## Where Defaults Are Consumed

- `config/hypr/bindings.conf.template` — `{{DEFAULT_TERMINAL}}`, `{{DEFAULT_BROWSER}}`, `{{DEFAULT_EDITOR}}`, `{{DEFAULT_AGENT}}`
- `bin/pimarchy-agent` — reads `~/.config/pimarchy/defaults/agent` directly (no templates involved)
- `pimarchy defaults` / `pimarchy default <what> [name]` — show/set

Adding a new default category means: extend `defaults_allowlist`/`defaults_default_for` in `lib/defaults.sh`, add a template variable in `install.sh` (via `defaults_export_vars`), and register any new launcher in `config/modules.conf`.