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
        systemctl --user daemon-reload 2>/dev/null || true
        log_success "${display_name:-$service_name} removed"
    fi
}

# link_user_unit — enable a user unit from its WantedBy lines.
# systemctl --user needs a session bus. The first-boot service has none.
link_user_unit() {
    local unit="$1"
    local dir="$HOME/.config/systemd/user"
    local file="$dir/$unit"
    local wanted="" dest=""

    if [ ! -f "$file" ]; then
        log_warn "User unit not found: $file"
        return 0
    fi
    wanted=$(awk -F= '/^WantedBy=/ { print $2 }' "$file")
    if [ -z "$wanted" ]; then
        log_warn "No WantedBy in $file"
        return 0
    fi
    for dest in $wanted; do
        mkdir -p "$dir/${dest}.wants"
        ln -sfn "../$unit" "$dir/${dest}.wants/$unit"
    done
}

# user_systemctl — run systemctl --user, or write enable symlinks
# when this process has no session bus.
user_systemctl() {
    local runtime=""

    runtime="/run/user/$(id -u)"
    if [ -z "${XDG_RUNTIME_DIR:-}" ] && [ -S "$runtime/bus" ]; then
        export XDG_RUNTIME_DIR="$runtime"
        export DBUS_SESSION_BUS_ADDRESS="unix:path=${runtime}/bus"
    fi
    if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -S "${XDG_RUNTIME_DIR}/bus" ]; then
        systemctl --user "$@"
        return
    fi

    # No session bus (image firstboot): mirror enable/mask/unmask/disable on
    # the filesystem so units stick for the first graphical login.
    case "$1" in
        daemon-reload)
            return 0
            ;;
        enable)
            shift
            local unit
            for unit in "$@"; do
                case "$unit" in
                    --*) continue ;;
                esac
                link_user_unit "$unit"
            done
            ;;
        disable)
            shift
            local unit link
            for unit in "$@"; do
                case "$unit" in
                    --*) continue ;;
                esac
                while IFS= read -r link; do
                    [ -n "$link" ] && rm -f "$link"
                done < <(find "$HOME/.config/systemd/user" -type l -name "$unit" 2>/dev/null)
            done
            ;;
        mask)
            shift
            local unit
            for unit in "$@"; do
                case "$unit" in
                    --*) continue ;;
                esac
                mkdir -p "$HOME/.config/systemd/user"
                ln -sfn /dev/null "$HOME/.config/systemd/user/$unit"
            done
            ;;
        unmask)
            shift
            local unit path
            for unit in "$@"; do
                case "$unit" in
                    --*) continue ;;
                esac
                path="$HOME/.config/systemd/user/$unit"
                if [ -L "$path" ] && [ "$(readlink "$path")" = "/dev/null" ]; then
                    rm -f "$path"
                fi
            done
            ;;
        *)
            log_warn "No user session bus; skipped systemctl --user $*"
            ;;
    esac
}

detect_keyboard_layout() {
    local layout=""

    if command -v localectl &> /dev/null; then
        layout=$(localectl status --no-pager 2>/dev/null | awk -F': ' '/X11 Layout/{gsub(/^[[:space:]]+/,"",$2); print $2; exit}')
        # localectl prints the literal "(unset)" when no keymap is configured
        if [ -n "$layout" ] && [ "$layout" != "(unset)" ]; then
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
                # Option "XkbLayout" "us" → take the value (last quoted field)
                layout=$(grep -E "XkbLayout" "$layout_file" | head -1 | grep -oE '"[^"]+"' | tail -1 | tr -d '"')
                if [ -n "$layout" ] && [ "$layout" != "XkbLayout" ]; then
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

    # Re-running install must not wipe user-added UFW rules. Skip the entire
    # baseline (reset + policies + ssh limit + enable) when ufw is already
    # active, unless explicitly forced.
    if [ "${PIMARCHY_UFW_RESET:-0}" != "1" ]; then
        if sudo ufw status 2>/dev/null | grep -qiE '^Status:[[:space:]]+active'; then
            log_info "ufw already active — skipping entire baseline (reset + policies + ssh limit + enable); PIMARCHY_UFW_RESET=1 to force"
            return 0
        fi
    fi

    if ! echo "y" | sudo ufw reset > /dev/null; then
        log_warn "ufw could not be configured. The desktop install will continue."
        return 0
    fi
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw limit ssh
    if ! echo "y" | sudo ufw enable > /dev/null; then
        log_warn "ufw rules are loaded but the firewall is not enabled."
        log_warn "Enable it later with: sudo ufw enable"
        return 0
    fi

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
    revert_pi_firmware
    revert_boot_services
    revert_nm_applet

    log_success "Services stopped and Pi OS boot environment restored"
}

# configure_boot_services — leave NetworkManager-wait-online in its packaged
# state. Remote /etc/fstab mounts are ordered after network-online.target,
# and this unit is the NetworkManager wait in front of that target.
configure_boot_services() {
    log_info "Leaving NetworkManager-wait-online in its packaged state"
}

# revert_boot_services — unmask a unit a previous install masked.
# Enabling is intentionally not done: that would start a unit that was
# disabled before the mask. is-enabled still prints "masked" when systemctl
# cat would fail on the /dev/null mask.
revert_boot_services() {
    local state
    state=$(systemctl is-enabled NetworkManager-wait-online.service 2>/dev/null || true)
    if [ "$state" = "masked" ]; then
        sudo systemctl unmask NetworkManager-wait-online.service 2>/dev/null || true
        log_success "Unmasked NetworkManager-wait-online without enabling it"
    fi
}

# disable_nm_applet — Waybar draws the network icon. The GTK applet is the
# session client that keeps Xwayland resident.
disable_nm_applet() {
    local autostart="$HOME/.config/autostart"
    mkdir -p "$autostart"
    cat > "$autostart/nm-applet.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=nm-applet
Hidden=true
EOF
    # user_systemctl works without a session bus (image firstboot).
    user_systemctl disable --now 'app-nm-applet@autostart.service' 2>/dev/null || true
    user_systemctl mask 'app-nm-applet@autostart.service' 2>/dev/null || true
    if pgrep -x nm-applet >/dev/null 2>&1; then
        pkill -x nm-applet 2>/dev/null || true
    fi
    log_success "nm-applet will not start with the session"
}

# revert_nm_applet — allow the applet autostart again.
revert_nm_applet() {
    rm -f "$HOME/.config/autostart/nm-applet.desktop"
    user_systemctl unmask 'app-nm-applet@autostart.service' 2>/dev/null || true
    user_systemctl daemon-reload 2>/dev/null || true
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

    user_systemctl daemon-reload
    user_systemctl enable swaybg.service
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

    # Instant workspace-chip refresh: Hyprland events → SIGRTMIN+9 → Waybar.
    # Companion to custom/ws* modules (see bin/pimarchy-workspace).
    cat << 'EOF' > "$systemd_dir/pimarchy-workspace-watch.service"
[Unit]
Description=Pimarchy Waybar workspace refresh
PartOf=waybar.service
After=waybar.service
BindsTo=waybar.service

[Service]
Type=simple
ExecStart=%h/.local/bin/pimarchy-workspace watch
Restart=on-failure
RestartSec=1

[Install]
WantedBy=waybar.service
EOF

    user_systemctl daemon-reload
    user_systemctl enable waybar.service
    user_systemctl enable pimarchy-workspace-watch.service
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

    user_systemctl daemon-reload
    user_systemctl enable mako.service
}

revert_swaybg() {
    remove_user_service "swaybg.service" "swaybg wallpaper service"
}

revert_waybar() {
    remove_user_service "pimarchy-workspace-watch.service" "workspace watch service"
    remove_user_service "waybar.service" "waybar service"
}

revert_mako() {
    remove_user_service "mako.service" "mako notification service"
}