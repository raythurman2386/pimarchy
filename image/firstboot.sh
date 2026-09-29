#!/bin/bash
# First boot of a Pimarchy image. systemd gives this process tty1, and
# getty is masked so a login prompt cannot share that screen.
set -eu

stamp="/var/lib/pimarchy/firstboot.done"
log="/var/log/pimarchy-firstboot.log"
sudoers="/etc/sudoers.d/99-pimarchy-firstboot"

if [ -f "$stamp" ]; then
    exit 0
fi
mkdir -p /var/lib/pimarchy
touch "$log"

say() {
    printf '%s\n' "$*" | tee -a "$log"
}

cleanup() {
    rm -f "$sudoers"
}
trap cleanup EXIT

login_user() {
    awk -F: '$3 >= 1000 && $3 < 65534 && $1 != "nobody" && $7 !~ /nologin$/ { print $1; exit }' \
        /etc/passwd
}

if [ -x /usr/local/sbin/pimarchy-ensure-dev-root ]; then
    /usr/local/sbin/pimarchy-ensure-dev-root || true
elif [ -x /opt/pimarchy/lib/ensure-dev-root.sh ]; then
    /opt/pimarchy/lib/ensure-dev-root.sh || true
fi

# Wi-Fi stays rfkill-blocked until a country code is set. Do this before
# waiting for a route, or the install sits at "waiting for a network".
if [ -x /opt/pimarchy/image/wifi-country.sh ]; then
    /opt/pimarchy/image/wifi-country.sh "${PIMARCHY_WIFI_COUNTRY:-US}" || true
fi

say "Pimarchy: installing the desktop on this screen."
say "Pimarchy: progress is also in $log"
say "Pimarchy: waiting for the account from Raspberry Pi Imager."

# cloud-init creates that account. This service starts before cloud-config
# so the console is claimed immediately; poll instead of blocking on it.
user=""
for _ in $(seq 1 60); do
    user="$(login_user)"
    if [ -n "$user" ]; then
        break
    fi
    sleep 5
done
if [ -z "$user" ]; then
    say "Pimarchy: no login user yet. Set the user in Raspberry Pi Imager, then boot again."
    exit 0
fi

say "Pimarchy: waiting for a network connection (up to 5 minutes)."
online=0
for _ in $(seq 1 60); do
    if ip route show default 2>/dev/null | grep -q .; then
        online=1
        break
    fi
    sleep 5
done
if [ "$online" -ne 1 ]; then
    say "Pimarchy: no network yet. Connect Wi-Fi and reboot to install."
    exit 0
fi

say "Pimarchy: synchronizing the clock."
if [ -x /opt/pimarchy/image/sync-clock.sh ]; then
    /opt/pimarchy/image/sync-clock.sh | tee -a "$log" || true
fi

printf '%s\n' "$user ALL=(ALL) NOPASSWD:ALL" > "$sudoers"
chmod 440 "$sudoers"

say "Pimarchy: installing."
set +e
# script allocates a terminal so apt shows progress, and appends a copy
# of that session to the log. stdout stays on tty1.
if command -v script >/dev/null 2>&1; then
    install_cmd="runuser -u ${user} -- /opt/pimarchy/install.sh --yes --performance"
    script -qaef -m classic -c "$install_cmd" "$log"
    code=$?
else
    runuser -u "$user" -- /opt/pimarchy/install.sh --yes --performance \
        > >(tee -a "$log") 2>&1
    code=$?
fi
set -e
if [ "$code" -ne 0 ]; then
    say "Pimarchy: install failed ($code). See $log"
    exit 0
fi

touch "$stamp"
systemctl disable pimarchy-firstboot.service 2>/dev/null || true
say "Pimarchy: install finished. Rebooting into the desktop."
sync
sleep 5
# systemd will not reboot until this oneshot exits, so a blocking
# reboot call waits forever and the Pi sits on this message.
systemctl --no-block reboot || true
