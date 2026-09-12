# Pimarchy VM Test Harness

A throwaway Debian Trixie VM (the same base as Pi OS Lite) for testing
Pimarchy installs without touching a physical Pi. Boots in a graphical
window, so you can watch greetd and the Hyprland session come up.

## Logging in

Credentials (deliberately trivial — local test target only):

- User: `pim` (password `pimarchy`, overridable via `PIMARCHY_VM_PASS`)
- Passwordless sudo is enabled for `pim`
- SSH (no password needed): `vm/testvm.sh ssh` — port 2222 on 127.0.0.1

`vm/testvm.sh boot` opens the graphical window so you can log in at greetd
and watch the Hyprland session start.

## One-time setup

```bash
vm/testvm.sh setup
```

Downloads the Debian 13 generic cloud image (~420 MB), builds a 20 GB
copy-on-write disk, creates the cloud-init seed, does the first boot and
saves a `pristine` snapshot — a barebones, freshly-bootstrapped system.

Requires: `qemu-system-x86_64`, `qemu-img`, `cloud-localds` (from
`cloud-image-utils`), `rsync`, `wget`. On Arch: `sudo pacman -S qemu-desktop
cloud-image-utils`.

## The tweak/reinstall loop

```bash
vm/testvm.sh restore        # back to barebones state (wipes everything)
vm/testvm.sh install        # full install.sh run, unattended
vm/testvm.sh boot           # graphical window: greetd → Hyprland
vm/testvm.sh ssh            # poke around inside
vm/testvm.sh restore        # throw it all away and try again
```

Other commands: `validate` (run validate.sh in the VM), `dry-run`,
`test-all` (validate + dry-run + install), `boot-headless` (serial console
in the terminal, Ctrl-A X to quit), `snapshot <name>`, `restore <name>`,
`status`, `poweroff`, `clean` (delete everything).

The disk keeps named snapshots; `pristine` is always the untouched
cloud-init state. `sync_repo` (part of validate/dry-run/install) rsyncs the
working tree into the VM each time, so edits on the host are what gets
tested — no commits needed.

## What is verified to work

- `validate.sh` passes inside the VM.
- `install.sh --dry-run` completes all 7 stages.
- `install.sh` (full, `--performance`) completes end to end on a pristine
  VM: core packages (apt + Debian sid Hyprland set), Zed/Raven/Ollama
  script installers, nerd font, config templates, gsettings, bashrc hook,
  greetd + start-hyprland, firewall, pimarchy CLI symlink.
- An `installed` snapshot is saved after a successful run.

## Known limitations

- **x86_64, not arm64.** The VM uses the amd64 cloud image so it runs at
  full KVM speed. Pimarchy's shell logic is architecture-independent, and
  all packages resolve on amd64, but it is not byte-identical to a Pi.
  For a slower, Pi-faithful arm64 run: `qemu-system-aarch64` +
  `debian-13-generic-arm64.qcow2` + `qemu-efi-aarch64` UEFI (TCG
  emulation, ~5-10x slower).
- **Hardware steps are no-ops**, same as on any non-Pi host: the governor
  and overclock paths skip (no `/boot/firmware/config.txt`, no Pi
  device-tree). Use `--overclock` only on real hardware.
- **No real GPU.** `boot` uses virtio-vga; Hyprland may fall back to
  software rendering (llvmpipe/WLR_RENDERER). Enough to see the session
  start, not to judge animation smoothness.
- **Unattended runs need the guest prep** (`prepare_guest`, automatic in
  `install`/`test-all`): noninteractive debconf + `Defaults env_keep`
  for `DEBIAN_FRONTEND`, since sudo resets the environment and dpkg
  dialogs would otherwise block a piped run.
- **`ufw enable` may need a second try.** The installer's piped
  `echo "y" | sudo ufw enable` can leave the firewall inactive in the VM
  (works on real hardware with a real tty). Manual check:
  `sudo ufw status` — if inactive: `sudo ufw --force enable`.
- Ollama (~1 GB) and Zed (~150 MB) downloads make the install take
  10-20 min depending on bandwidth; the apt sid pull adds a few more.

## Files

Everything lives in `vm/.vm/` (gitignored): disk image, snapshot disk,
seed ISO, SSH key, console log. `vm/testvm.sh clean` removes it all.