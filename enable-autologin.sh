#!/bin/bash
# enable-autologin.sh - Configure greetd for automatic login
# Usage: sudo bash enable-autologin.sh [username]

set -e

# Get username - use $SUDO_USER if running with sudo, otherwise $USER or first argument
USERNAME="${1:-${SUDO_USER:-$USER}}"

if [ "$USERNAME" = "root" ] || [ -z "$USERNAME" ]; then
    echo "Error: Please specify a non-root username"
    echo "Usage: sudo bash enable-autologin.sh [username]"
    exit 1
fi

echo "Enabling auto-login for user: $USERNAME"

# Create greetd config with auto-login
cat << EOF | sudo tee /etc/greetd/config.toml > /dev/null
[terminal]
# Use vt7 to avoid systemd boot messages bleeding into the greeter
vt = 7

[initial_session]
# Auto-login this user on boot
command = "/usr/local/bin/start-hyprland"
user = "$USERNAME"

[default_session]
# Fallback if initial_session fails - allows manual login
command = "tuigreet --time --remember --remember-session --cmd /usr/local/bin/start-hyprland"
user = "_greetd"
EOF

echo "Auto-login configured!"
echo ""
echo "The system will now automatically login as '$USERNAME' on boot."
echo "If you need to login as a different user, you can:"
echo "  - Hold Shift during boot to skip auto-login (if tuigreet supports it)"
echo "  - Or temporarily disable greetd: sudo systemctl disable greetd"
echo "  - Or restore getty: sudo systemctl unmask getty@tty1 && sudo systemctl enable getty@tty1"
