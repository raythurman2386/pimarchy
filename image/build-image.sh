#!/bin/bash
# Build a flashable Raspberry Pi OS Lite image that installs Pimarchy
# on first boot. The Pi firmware boots a disk image, not an optical ISO.
#
#   sudo bash image/build-image.sh
#
# Output: image/work/pimarchy-lite-arm64.img
#
# Flash with the manifest from image/write-imager-manifest.sh:
#   rpi-imager --repo image/work/pimarchy.rpi-imager-manifest
# Choose Pimarchy, then set the username, password, Wi-Fi, and SSH.
# "Use custom" has no init_format, so Imager hides that step.
# The image does not show the stock Pi user/keyboard wizard. The disk
# expands on its own. The first boot that has a login user and a
# network installs Pimarchy with the performance governor and a US
# keyboard unless Imager set another.
# Open decisions (see docs/development/architecture.md): Wi-Fi country
# default US, Imager file:// image URL, Xwayland off, dual GPUI theme paths.
set -eu

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$ROOT/image/work"
URL="${PIMARCHY_IMAGE_URL:-https://downloads.raspberrypi.com/raspios_lite_arm64_latest}"
OUT="$WORK/pimarchy-lite-arm64.img"

if [ "$(id -u)" -ne 0 ]; then
    echo "build-image.sh: run with sudo" >&2
    exit 1
fi

mkdir -p "$WORK"
archive="$WORK/raspios-lite-arm64.img.xz"
if [ ! -s "$archive" ]; then
    echo "Downloading Raspberry Pi OS Lite (64-bit)..."
    curl -fL --retry 3 -o "$archive.partial" "$URL"
    mv "$archive.partial" "$archive"
fi

base="$WORK/raspios-lite-arm64.img"
if [ ! -s "$base" ]; then
    echo "Decompressing image..."
    xz -dkc "$archive" > "$base.partial"
    mv "$base.partial" "$base"
fi

cp -a "$base" "$OUT.partial"
loop="$(losetup --find --show --partscan "$OUT.partial")"
cleanup() {
    local part
    for part in "$WORK/boot" "$WORK/root"; do
        if mountpoint -q "$part"; then
            umount "$part" || true
        fi
    done
    if [ -n "${loop:-}" ]; then
        losetup -d "$loop" || true
    fi
}
trap cleanup EXIT

mkdir -p "$WORK/boot" "$WORK/root"
# Partition scan can lag losetup.
sleep 1
part1="${loop}p1"
part2="${loop}p2"
if [ ! -b "$part1" ]; then
    part1="${loop}1"
    part2="${loop}2"
fi
mount "$part1" "$WORK/boot"
mount "$part2" "$WORK/root"

mkdir -p "$WORK/root/opt/pimarchy" "$WORK/root/usr/local/sbin" \
    "$WORK/root/etc/kernel/preinst.d" "$WORK/root/etc/systemd/system/multi-user.target.wants"
rsync -a \
    --exclude '/image/work/' \
    --exclude '/vm/' \
    --exclude '/.raven/' \
    --exclude '/.git/' \
    "$ROOT/" "$WORK/root/opt/pimarchy/"

install -m 0755 "$ROOT/lib/ensure-dev-root.sh" \
    "$WORK/root/usr/local/sbin/pimarchy-ensure-dev-root"
printf '%s\n' '#!/bin/sh' '/usr/local/sbin/pimarchy-ensure-dev-root' \
    > "$WORK/root/etc/kernel/preinst.d/zz-pimarchy-dev-root"
chmod 755 "$WORK/root/etc/kernel/preinst.d/zz-pimarchy-dev-root"
chmod 755 "$WORK/root/opt/pimarchy/image/firstboot.sh" \
    "$WORK/root/opt/pimarchy/image/firstboot-console.sh" \
    "$WORK/root/opt/pimarchy/install.sh"

# Stock Pi OS Lite opens an interactive user and keyboard wizard, and
# its default layout is UK, so "~" is not where a US keyboard has it.
# Mask the wizard. Imager's customization script still creates the user.
ln -sfn /dev/null "$WORK/root/etc/systemd/system/userconfig.service"
rm -f "$WORK/root/etc/systemd/system/multi-user.target.wants/userconfig.service" \
    "$WORK/root/etc/systemd/system/graphical.target.wants/userconfig.service"

# Getty on tty1 prints a login prompt on the installer's screen. Mask it
# for the install. firstboot-console.sh brings it back if the install stops.
ln -sfn /dev/null "$WORK/root/etc/systemd/system/getty@tty1.service"
rm -f "$WORK/root/etc/systemd/system/getty.target.wants/getty@tty1.service"

if [ -f "$WORK/root/etc/default/keyboard" ]; then
    sed -i 's/^XKBLAYOUT=.*/XKBLAYOUT="us"/' "$WORK/root/etc/default/keyboard"
fi
if [ -f "$WORK/root/var/cache/debconf/config.dat" ]; then
    python3 - "$WORK/root/var/cache/debconf/config.dat" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text()
old = "Name: keyboard-configuration/layoutcode\nTemplate: keyboard-configuration/layoutcode\nValue: gb\n"
new = old.replace("Value: gb\n", "Value: us\n")
if old not in text:
    raise SystemExit("keyboard layoutcode stanza not found")
path.write_text(text.replace(old, new, 1))
PY
fi

# Silent root expansion is the "resize" token. Keep it, and quiet the
# boot log so the install message is what shows on the console.
# cfg80211.ieee80211_regdom unblocks Wi-Fi. Without it, rfkill stays on
# and the login banner says the wireless country is not set.
if [ -f "$WORK/boot/cmdline.txt" ]; then
    if ! grep -qw resize "$WORK/boot/cmdline.txt"; then
        sed -i 's/$/ resize/' "$WORK/boot/cmdline.txt"
    fi
    if ! grep -qw quiet "$WORK/boot/cmdline.txt"; then
        sed -i 's/$/ quiet/' "$WORK/boot/cmdline.txt"
    fi
fi
bash "$ROOT/image/wifi-country.sh" --root "$WORK/root" --boot "$WORK/boot" \
    "${PIMARCHY_WIFI_COUNTRY:-US}"
chmod 755 "$WORK/root/opt/pimarchy/image/wifi-country.sh"

cat > "$WORK/root/etc/issue" <<'EOF'
Pimarchy
The desktop install uses this screen and does not need a login.
If you see a shell prompt, the install has stopped.
The log is /var/log/pimarchy-firstboot.log
EOF

cat > "$WORK/root/etc/systemd/system/pimarchy-firstboot.service" <<'EOF'
[Unit]
Description=Install Pimarchy on first boot
After=systemd-user-sessions.service
Before=getty@tty1.service
Conflicts=getty@tty1.service
ConditionPathExists=!/var/lib/pimarchy/firstboot.done

[Service]
Type=oneshot
StandardInput=null
StandardOutput=tty
StandardError=tty
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes
ExecStart=/opt/pimarchy/image/firstboot.sh
ExecStopPost=-/opt/pimarchy/image/firstboot-console.sh
TimeoutStartSec=infinity

[Install]
WantedBy=multi-user.target
EOF
ln -sfn /etc/systemd/system/pimarchy-firstboot.service \
    "$WORK/root/etc/systemd/system/multi-user.target.wants/pimarchy-firstboot.service"

sync
umount "$WORK/boot"
umount "$WORK/root"
losetup -d "$loop"
loop=""
trap - EXIT
mv "$OUT.partial" "$OUT"
# Hash the image only after it is unmounted. Opening it with a
# writable loop updates the ext4 superblock and Imager then rejects
# the file with a SHA mismatch.
bash "$ROOT/image/write-imager-manifest.sh" "$OUT" \
    "$WORK/pimarchy.rpi-imager-manifest"
echo "Wrote $OUT"
echo "Flash with: rpi-imager --repo $WORK/pimarchy.rpi-imager-manifest"
