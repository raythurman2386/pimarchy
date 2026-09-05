#!/bin/bash
#
# Pimarchy VM test harness — Debian Trixie (Pi OS Lite base) under QEMU/KVM.
#
# Provides a throwaway (or snapshot-restorable) Debian Trixie VM for testing
# Pimarchy installs without touching a physical Pi.
#
# Usage: vm/testvm.sh <command>
#
# Commands:
#   setup          Download image, build cloud-init seed, first boot, snapshot
#   boot           Boot the VM (GUI window, Hyprland-capable)
#   boot-headless  Boot with serial console on the current terminal (no window)
#   ssh            SSH into the running VM
#   validate       Copy repo into VM and run validate.sh
#   dry-run        Copy repo into VM and run install.sh --dry-run
#   install        Copy repo into VM and run a full install.sh (y, skip CPU perf)
#   test-all       validate + dry-run + install in one go
#   snapshot       Save the current disk state as a named snapshot
#   restore        Restore the pristine snapshot (fresh "barebones" state)
#   status         Show whether the VM is running and reachable
#   poweroff       Power the VM off cleanly (over SSH)
#   clean          Remove everything (disk, snapshot, seed, pidfile)
#
# Typical loop:
#   vm/testvm.sh setup       # once (~10 min incl. first boot)
#   vm/testvm.sh restore     # back to barebones Pi-OS-like state
#   vm/testvm.sh test-all    # validate + dry-run + full install
#   vm/testvm.sh boot        # look at the (attempted) desktop
#   vm/testvm.sh restore     # wipe it and try again
#
# This VM is x86_64 (fast KVM). Pimarchy's install logic is
# architecture-independent shell; for an exact-arm64/Pi-faithful run see
# the ARCH override note next to IMAGE_URL below (much slower under TCG).
#
set -euo pipefail

PIMARCHY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VM_DIR="${PIMARCHY_VM_DIR:-$PIMARCHY_ROOT/vm/.vm}"

# x86_64 VM. Pimarchy's scripts are architecture-independent; the desktop
# packages resolve fine on amd64, and KVM makes it fast. For an exact-Pi
# arm64 build use: PIMARCHY_VM_QEMU=qemu-system-aarch64 PIMARCHY_VM_ARCH=arm64 \
# with the -generic-arm64 image (needs qemu-efi-aarch64 UEFI + TCG, much slower).
ARCH="${PIMARCHY_VM_ARCH:-amd64}"
IMAGE_URL="${PIMARCHY_VM_IMAGE_URL:-https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-${ARCH}.qcow2}"
IMAGE_NAME="${PIMARCHY_VM_IMAGE_NAME:-debian-13-generic-${ARCH}.qcow2}"
QEMU_BIN="${PIMARCHY_VM_QEMU:-qemu-system-x86_64}"

DISK_SIZE="${PIMARCHY_VM_DISK_SIZE:-20G}"
MEM="${PIMARCHY_VM_MEM:-4G}"
CPUS="${PIMARCHY_VM_CPUS:-4}"

VM_USER="${PIMARCHY_VM_USER:-pim}"
# Login password (greeter/ssh-with-password). Kept trivial on purpose — this
# VM is a local test target, not a security boundary. SSH also always works
# with the generated key, and sudo is passwordless.
VM_PASS="${PIMARCHY_VM_PASS:-pimarchy}"
SSH_PORT="${PIMARCHY_VM_SSH_PORT:-2222}"
SPICE_PORT="${PIMARCHY_VM_SPICE_PORT:-5930}"

SNAPSHOT_NAME="${PIMARCHY_VM_SNAPSHOT:-pristine}"
SSH_KEY="$VM_DIR/id_ed25519"
DISK="$VM_DIR/disk.qcow2"
SEED_ISO="$VM_DIR/seed.iso"
PID_FILE="$VM_DIR/qemu.pid"
LOG_FILE="$VM_DIR/console.log"

# -----------------------------------------------------------------------------
# helpers

log_info()  { echo "[INFO] $*"; }
log_ok()    { echo "[OK] $*"; }
log_error() { echo "[ERROR] $*" >&2; }

need() {
    command -v "$1" >/dev/null 2>&1 || {
        log_error "Missing dependency: $1"
        exit 1
    }
}

check_deps() {
    need "$QEMU_BIN"
    need qemu-img
    need cloud-localds
    if [ "$QEMU_BIN" = "qemu-system-x86_64" ] && [ ! -w /dev/kvm ]; then
        log_info "/dev/kvm not writable — running with TCG emulation (slow)"
    fi
}

# Guest prep so automated installs behave like a real desktop run:
# 1. debconf answers non-interactively (a pty is fine for install.sh's own
#    /dev/tty prompts, but dpkg dialogs would block unattended automation).
# 2. sudo keeps DEBIAN_FRONTEND across the sudo boundary — install.sh sets
#    DEBIAN_FRONTEND=noninteractive but stock sudoers drops it before apt.
prepare_guest() {
    ensure_vm_running
    vm_exec "grep -qs 'pimarchy-vm-harness' /etc/apt/apt.conf.d/90pimarchy-vm || \
        printf '# pimarchy-vm-harness\nDPkg::Options { \"--force-confdef\"; \"--force-confold\"; };\n' \
        | sudo tee /etc/apt/apt.conf.d/90pimarchy-vm >/dev/null"
    vm_exec "grep -qs 'DEBIAN_FRONTEND' /etc/sudoers.d/pimarchy-vm 2>/dev/null || \
        printf '# pimarchy-vm-harness\nDefaults env_keep += \"DEBIAN_FRONTEND DEBCONF_NONINTERACTIVE_SEEN\"\n' \
        | sudo tee /etc/sudoers.d/pimarchy-vm >/dev/null && sudo chmod 440 /etc/sudoers.d/pimarchy-vm" \
        2>/dev/null || true
    log_ok "Guest prepared (noninteractive dpkg, sudo env_keep)"
}

# Boot in the background without a window (serial → console.log), used by
# the automated commands so validate/dry-run/install work on a stopped VM.
cmd_boot_bg() {
    if [ ! -f "$DISK" ]; then
        log_error "No disk found. Run: vm/testvm.sh setup"
        exit 1
    fi
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        log_info "VM already running"
        return 0
    fi
    build_qemu_args
    "${QEMU_ARGS[@]}" -display none -pidfile "$PID_FILE" -daemonize \
        || { log_error "QEMU failed to start"; exit 1; }
    log_ok "VM booting in background (console: $LOG_FILE)"
}

# Boot the VM if it is not reachable, then wait for SSH.
ensure_vm_running() {
    if vm_exec true 2>/dev/null; then
        return 0
    fi
    cmd_boot_bg
    wait_for_ssh 120 || exit 1
}

# Copy the Pimarchy repo into the VM over rsync-over-ssh (skips vm/ and .git)
sync_repo() {
    ensure_vm_running
    local ssh_opts=(-i "$SSH_KEY" -p "$SSH_PORT" -o StrictHostKeyChecking=no
                    -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)

    rsync -az --delete \
        --exclude 'vm/' --exclude '.git/' --exclude '.vm/' \
        -e "ssh ${ssh_opts[*]}" \
        "$PIMARCHY_ROOT/" "$VM_USER@127.0.0.1:/home/$VM_USER/pimarchy/"

    log_ok "Repo synced to VM"
}

# Run a command inside the VM as the normal user
vm_exec() {
    ssh -i "$SSH_KEY" -p "$SSH_PORT" \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR -o BatchMode=yes \
        "$VM_USER@127.0.0.1" "$*"
}

wait_for_ssh() {
    local tries="${1:-120}"
    log_info "Waiting for SSH (max $tries probes)..."
    for _ in $(seq "$tries"); do
        if vm_exec true 2>/dev/null; then
            log_ok "SSH is up"
            return 0
        fi
        sleep 3
    done
    log_error "SSH did not come up; check the console: tail $LOG_FILE"
    return 1
}

qemu_base_args() {
    printf '%s\n' \
        -machine q35 -m "$MEM" -smp "$CPUS" \
        -display none -serial "file:$LOG_FILE" \
        -monitor unix:"$VM_DIR/monitor.sock",server,nowait \
        -device virtio-net-pci,netdev=n0 -netdev user,id=n0,hostfwd=tcp:127.0.0.1:$SSH_PORT-:22 \
        -drive file="$DISK",if=virtio,format=qcow2 \
        -drive file="$SEED_ISO",if=virtio,media=cdrom,readonly=on \
        -pidfile "$PID_FILE" -daemonize
}

# Build the common qemu invocation in "$QEMU_ARGS" (array). Callers append
# mode-specific flags (-daemonize, -spice, -nographic, ...).
build_qemu_args() {
    KVM_ARGS=()
    # shellcheck disable=SC2153
    if [ "$QEMU_BIN" = "qemu-system-x86_64" ] && [ -w /dev/kvm ]; then
        KVM_ARGS=(-enable-kvm -cpu host)
    fi
    QEMU_ARGS=(
        "$QEMU_BIN" "${KVM_ARGS[@]}"
        -machine q35 -m "$MEM" -smp "$CPUS"
        -device virtio-net-pci,netdev=n0
        -netdev "user,id=n0,hostfwd=tcp:127.0.0.1:$SSH_PORT-:22"
        -drive "file=$DISK,if=virtio,format=qcow2"
        -drive "file=$SEED_ISO,if=virtio,media=cdrom,readonly=on"
        -serial "file:$LOG_FILE"
        -monitor "unix:$VM_DIR/monitor.sock,server,nowait"
    )
}

# -----------------------------------------------------------------------------
# commands

cmd_setup() {
    mkdir -p "$VM_DIR"
    need wget

    if [ -f "$VM_DIR/$IMAGE_NAME" ] && [ -f "$DISK" ] && [ -f "$SEED_ISO" ]; then
        log_info "Image, disk and seed already present — skipping download"
    else
        log_info "Downloading Debian Trixie generic cloud image ($ARCH)..."
        wget -q --show-progress -c -O "$VM_DIR/$IMAGE_NAME" "$IMAGE_URL"
        log_ok "Image downloaded"

        log_info "Creating $DISK_SIZE system disk (copy-on-write from image)..."
        qemu-img create -f qcow2 -F qcow2 -b "$VM_DIR/$IMAGE_NAME" "$DISK" "$DISK_SIZE" >/dev/null
        log_ok "Disk created"
    fi

    log_info "Building cloud-init seed (user: $VM_USER, passwordless sudo, ssh key)..."
    local pubkey
    [ -f "$SSH_KEY" ] || ssh-keygen -t ed25519 -N '' -f "$SSH_KEY" -C pimarchy-vm -q
    pubkey=$(cat "$SSH_KEY.pub")

    local tmpd
    tmpd=$(mktemp -d)
    trap 'rm -rf "$tmpd"' RETURN

    cat > "$tmpd/user-data" <<EOF
#cloud-config
users:
  - name: $VM_USER
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    ssh_authorized_keys:
      - $pubkey
chpasswd:
  expire: false
  users:
    - name: $VM_USER
      password: $VM_PASS
      type: text
packages:
  - sudo
  - rsync
hostname: pimarchy-vm
# No packages: cloud-init's package step holds the apt lock for minutes and
# races our own apt calls; rsync is installed in the setup phase instead.
package_update: false
EOF
    cat > "$tmpd/meta-data" <<EOF
instance-id: pimarchy-vm-001
local-hostname: pimarchy-vm
EOF

    cloud-localds "$SEED_ISO" "$tmpd/user-data" "$tmpd/meta-data"
    log_ok "Seed built"

    log_info "First boot: booting VM in background (console: $LOG_FILE)..."
    build_qemu_args
    "${QEMU_ARGS[@]}" -display none -pidfile "$PID_FILE" -daemonize \
        || { log_error "QEMU failed to start"; exit 1; }

    wait_for_ssh 150 || exit 1

    log_info "Waiting for cloud-init/first-boot apt activity to settle..."
    if ! vm_exec 'for i in $(seq 1 150); do
            if [ -e /run/cloud-init/result.json ] \
               && ! pgrep -x apt-get >/dev/null \
               && ! pgrep -x dpkg >/dev/null \
               && ! pgrep -x unattended-upgr >/dev/null; then
                exit 0
            fi
            sleep 2
        done
        exit 1'; then
        log_info "(settle wait timed out — apt Lock::Timeout below will handle residual locks)"
    fi

    log_info "Ensuring rsync is present in the VM (used by sync_repo)..."
    # DPkg::Lock::Timeout makes apt wait for first-boot locks instead of failing
    vm_exec "sudo DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=600 update -qq \
        && sudo DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=600 install -y -qq rsync" >/dev/null
    log_ok "rsync installed in VM"

    log_info "Powering VM off for pristine snapshot..."
    vm_exec "sudo poweroff" 2>/dev/null || true
    local qemu_pid
    qemu_pid=$(cat "$PID_FILE")
    for _ in $(seq 1 60); do
        kill -0 "$qemu_pid" 2>/dev/null || break
        sleep 2
    done
    if kill -0 "$qemu_pid" 2>/dev/null; then
        log_error "VM did not power off in time; kill it manually and re-run setup"
        exit 1
    fi
    rm -f "$PID_FILE"
    log_ok "VM powered off"

    log_info "Creating pristine snapshot: $SNAPSHOT_NAME"
    cmd_snapshot

    log_ok "Setup complete. Try: vm/testvm.sh test-all"
}

cmd_boot() {
    check_deps
    if [ ! -f "$DISK" ]; then
        log_error "No disk found. Run: vm/testvm.sh setup"
        exit 1
    fi
    log_info "Booting VM with graphical window (SPICE on $SPICE_PORT)..."
    log_info "Connect with: remote-viewer spice://127.0.0.1:$SPICE_PORT"
    build_qemu_args
    "${QEMU_ARGS[@]}" \
        -device virtio-vga \
        -display gtk,gl=off \
        -pidfile "$PID_FILE" &
    echo $! > "$PID_FILE"
    log_ok "VM booting in background (window should open)"
}

cmd_boot_headless() {
    check_deps
    if [ ! -f "$DISK" ]; then
        log_error "No disk found. Run: vm/testvm.sh setup"
        exit 1
    fi
    log_info "Booting VM headless (serial console attached to this terminal; Ctrl-A X to exit)..."
    build_qemu_args
    "${QEMU_ARGS[@]}" -nographic -monitor none -pidfile "$PID_FILE"
}

cmd_ssh() {
    exec ssh -i "$SSH_KEY" -p "$SSH_PORT" \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "$VM_USER@127.0.0.1"
}

cmd_validate() {
    sync_repo
    vm_exec "cd ~/pimarchy && bash validate.sh"
    log_ok "validate.sh PASSED in VM"
}

cmd_dry_run() {
    sync_repo
    vm_exec "cd ~/pimarchy && echo y | bash install.sh --dry-run"
    log_ok "Dry run complete (no changes made)"
}

cmd_install() {
    sync_repo
    prepare_guest
    log_info "Running full install.sh in the VM (unattended: single 'y' answer, --performance avoids the CPU prompt)..."
    # install.sh reads its prompts from /dev/tty → allocate a pty (-tt) and
    # pipe exactly the answers needed. A continuous 'yes' flood must NOT be
    # used: with use_pty sudo (Debian default) the pty input loop spins at
    # 100% CPU when sudo runs while the pty queue is full of unread input.
    printf 'y\n' | timeout 3600 ssh -i "$SSH_KEY" -p "$SSH_PORT" \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR -tt \
        "$VM_USER@127.0.0.1" "cd ~/pimarchy && bash install.sh --performance" | tail -60
    log_ok "install.sh finished in VM — try: vm/testvm.sh boot"
}

cmd_test_all() {
    cmd_validate
    echo ""
    cmd_dry_run
    echo ""
    prepare_guest
    cmd_install
}

cmd_snapshot() {
    local name="${1:-$SNAPSHOT_NAME}"
    need qemu-img
    if pgrep -f "file=$DISK" >/dev/null; then
        log_error "VM appears to be running; power off before snapshotting"
        exit 1
    fi
    log_info "Saving snapshot '$name'..."
    qemu-img snapshot -c "$name" "$DISK"
    log_ok "Snapshot '$name' saved"
}

cmd_restore() {
    local name="${1:-$SNAPSHOT_NAME}"
    need qemu-img
    if [ ! -f "$DISK" ]; then
        log_error "No disk found. Run: vm/testvm.sh setup"
        exit 1
    fi
    if pgrep -f "file=$DISK" >/dev/null; then
        log_error "VM is running; power off first: vm/testvm.sh poweroff"
        exit 1
    fi
    log_info "Restoring snapshot '$name' (discards all changes since then)..."
    qemu-img snapshot -a "$name" "$DISK"
    log_ok "Snapshot '$name' restored"
}

cmd_status() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        log_ok "VM running (pid $(cat "$PID_FILE"))"
    else
        log_info "VM not running"
    fi
    if vm_exec true 2>/dev/null; then
        log_ok "SSH reachable on 127.0.0.1:$SSH_PORT"
    else
        log_info "SSH not reachable"
    fi
    if [ -f "$DISK" ]; then
        # Skip snapshot listing while QEMU holds the disk write lock
        if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            log_info "(snapshot list skipped while VM is running)"
        else
            echo "Snapshots:"
            qemu-img snapshot -l "$DISK" | tail -n +3
        fi
    fi
}

cmd_poweroff() {
    if vm_exec true 2>/dev/null; then
        vm_exec "sudo poweroff" || true
        log_ok "Poweroff issued"
    else
        log_info "VM not reachable over SSH"
    fi
}

cmd_clean() {
    if pgrep -f "file=$DISK" >/dev/null; then
        log_error "VM is running; power it off first"
        exit 1
    fi
    rm -rf "$VM_DIR"
    log_ok "Removed $VM_DIR"
}

# -----------------------------------------------------------------------------
case "${1:-}" in
    setup)        cmd_setup ;;
    boot)         cmd_boot ;;
    boot-bg)      cmd_boot_bg ;;
    boot-headless) cmd_boot_headless ;;
    ssh)          cmd_ssh ;;
    validate)     cmd_validate ;;
    dry-run)      cmd_dry_run ;;
    install)      cmd_install ;;
    test-all)     cmd_test_all ;;
    snapshot)     shift; cmd_snapshot "$@" ;;
    restore)      shift; cmd_restore "$@" ;;
    status)       cmd_status ;;
    poweroff)     cmd_poweroff ;;
    clean)        cmd_clean ;;
    *)
        sed -n '3,50p' "$0" | sed 's/^# \{0,1\}//'
        exit 1
        ;;
esac