#!/bin/bash

# Options
shutdown="󰐥  Shutdown"
reboot="󰜉  Reboot"
logout="󰍃  Logout"
suspend="󰒲  Suspend"

options="$shutdown\n$reboot\n$logout\n$suspend"

# Power menu uses the shared theme but overrides layout for a compact,
# no-searchbar popup. All background/transparency rules are inherited.
chosen="$(echo -e "$options" | rofi -dmenu -i -p "  Power" \
    -theme-str '
        window {
            width: 220px;
        }
        inputbar {
            enabled: false;
        }
        listview {
            lines:   4;
            padding: 4px 0px;
        }
        element {
            padding: 10px 14px;
            spacing: 12px;
        }
    ')"

case $chosen in
    $shutdown)
        systemctl poweroff
        ;;
    $reboot)
        systemctl reboot
        ;;
    $logout)
        hyprctl dispatch exit
        ;;
    $suspend)
        systemctl suspend
        ;;
esac
