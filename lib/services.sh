#!/bin/bash
#
# Pimarchy Library — Service & System Configuration
#

# remove_user_service — disable, stop, and remove a systemd user service.
remove_user_service() {
    local service_name="$1"
    local display_name="$2"
    local service_file="$HOME/.config/systemd/user/$service_name"

    if [ -f "$service_file" ]; then
        systemctl --user disable "$service_name" 2>/dev/null || true
        systemctl --user stop "$service_name" 2>/dev/null || true
        rm -f "$service_file"
        systemctl --user daemon-reload
        log_success "${display_name:-$service_name} removed"
    fi
}

detect_keyboard_layout() {
    local layout=""

    if command -v localectl &> /dev/null; then
        layout=$(localectl status --no-pager 2>/dev/null | awk -F': ' '/X11 Layout/{gsub(/^[[:space:]]+/,"",$2); print $2; exit}')
        if [ -n "$layout" ]; then
            echo "$layout"
            return 0
        fi
    fi

    if [ -f /etc/vconsole.conf ]; then
        layout=$(grep -E "^KEYMAP=" /etc/vconsole.conf | cut -d= -f2)
        if [ -n "$layout" ]; then
            echo "$layout"
            return 0
        fi
    fi

    if [ -d /usr/share/X11/xkb/symbols ]; then
        local layout_file
        for layout_file in /etc/X11/xorg.conf.d/*; do
            if [ -f "$layout_file" ]; then
                layout=$(grep -E "XkbLayout" "$layout_file" | head -1 | awk '{print $2}' | tr -d '"')
                if [ -n "$layout" ]; then
                    echo "$layout"
                    return 0
                fi
            fi
        done
    fi

    echo "us"
    return 0
}

configure_firewall() {
    log_info "Configuring firewall (ufw)..."

    if ! command -v ufw &> /dev/null; then
        log_warn "ufw is not installed, skipping firewall configuration."
        return 0
    fi

    echo "y" | sudo ufw reset > /dev/null
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw limit ssh
    echo "y" | sudo ufw enable > /dev/null

    log_success "Firewall configured and enabled (Default: Deny Incoming, Allow Outgoing, Limit SSH)"
}

revert_firewall() {
    log_info "Reverting firewall configuration..."

    if command -v ufw &> /dev/null; then
        sudo ufw disable > /dev/null
        echo "y" | sudo ufw reset > /dev/null
        log_success "Firewall disabled and rules reset"
    else
        log_info "ufw not found, skipping firewall revert."
    fi
}

stop_services() {
    log_info "Stopping Pimarchy services..."

    pkill -f mako 2>/dev/null || true

    if systemctl is-enabled greetd &>/dev/null; then
        sudo systemctl disable greetd 2>/dev/null || true
    fi
    sudo systemctl unmask getty@tty1.service 2>/dev/null || true
    sudo systemctl enable getty@tty1.service 2>/dev/null || true

    sudo systemctl set-default multi-user.target 2>/dev/null || true

    sudo rm -f /usr/local/bin/start-hyprland
    sudo rm -f /etc/greetd/config.toml
    sudo rm -f /etc/X11/xorg.conf.d/00-keyboard.conf

    revert_governor
    revert_overclock

    log_success "Services stopped and Pi OS boot environment restored"
}

# configure_swaybg / configure_waybar / configure_mako — systemd user services
# (graphical-session.target). Running these as user services (instead of
# exec-once) ensures they start after the session is ready under UWSM.

configure_swaybg() {
    log_info "Configuring swaybg user service..."
    local systemd_dir="$HOME/.config/systemd/user"
    mkdir -p "$systemd_dir"

    cat << 'EOF' > "$systemd_dir/swaybg.service"
[Unit]
Description=swaybg wallpaper daemon
Documentation=man:swaybg(1)
PartOf=graphical-session.target
After=graphical-session.target

[Service]
Type=simple
# swaybg requires wayland; UWSM sets WAYLAND_DISPLAY
ExecStart=/usr/bin/swaybg -i %h/.config/hypr/background.jpg -m fill
Restart=on-failure
RestartSec=1

[Install]
WantedBy=graphical-session.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable swaybg.service
}

configure_waybar() {
    log_info "Configuring waybar user service..."
    local systemd_dir="$HOME/.config/systemd/user"
    mkdir -p "$systemd_dir"

    cat << 'EOF' > "$systemd_dir/waybar.service"
[Unit]
Description=Waybar status bar
Documentation=man:waybar(1)
PartOf=graphical-session.target
After=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/waybar
Restart=on-failure
RestartSec=1

[Install]
WantedBy=graphical-session.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable waybar.service
}

configure_mako() {
    log_info "Configuring mako user service..."
    local systemd_dir="$HOME/.config/systemd/user"
    mkdir -p "$systemd_dir"

    cat << 'EOF' > "$systemd_dir/mako.service"
[Unit]
Description=mako notification daemon
Documentation=man:mako(1)
PartOf=graphical-session.target
After=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/mako
Restart=on-failure
RestartSec=1

[Install]
WantedBy=graphical-session.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable mako.service
}

revert_swaybg() {
    remove_user_service "swaybg.service" "swaybg wallpaper service"
}

revert_waybar() {
    remove_user_service "waybar.service" "waybar service"
}

revert_mako() {
    remove_user_service "mako.service" "mako notification service"
}