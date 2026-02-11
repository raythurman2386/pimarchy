#!/bin/sh
# Pimarchy Power Menu
CHOICE=$(printf "  Shutdown\n  Reboot\n  Logout" | wofi --dmenu --prompt "Power" --width 250 --height 160 --cache-file /dev/null)

case "$CHOICE" in
    *Shutdown) systemctl poweroff ;;
    *Reboot)   systemctl reboot ;;
    *Logout)   labwc --exit ;;
esac
