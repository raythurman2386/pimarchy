#!/bin/bash
# Runs after pimarchy-firstboot stops. A finished install reboots into
# greetd. A stopped install would otherwise leave tty1 with no login,
# because the image masks getty while the installer owns the screen.
set -eu

if [ -f /var/lib/pimarchy/firstboot.done ]; then
    exit 0
fi

systemctl unmask getty@tty1.service 2>/dev/null || true
systemctl enable getty@tty1.service 2>/dev/null || true
systemctl reset-failed pimarchy-getty-restore.timer 2>/dev/null || true
systemctl reset-failed pimarchy-getty-restore.service 2>/dev/null || true
systemd-run --collect --on-active=2s --unit=pimarchy-getty-restore \
    /bin/systemctl start getty@tty1.service >/dev/null 2>&1 || \
    systemctl start getty@tty1.service 2>/dev/null || true
