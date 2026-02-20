#!/bin/bash

# Options
shutdown="󰐥 Shutdown"
reboot="󰜉 Reboot"
logout="󰍃 Logout"
suspend="󰒲 Suspend"

options="$shutdown\n$reboot\n$logout\n$suspend"

chosen="$(echo -e "$options" | rofi -dmenu -i -p "Power Menu" -theme-str 'listview {lines: 4;}')"

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
