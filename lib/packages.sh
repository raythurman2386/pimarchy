#!/bin/bash
#
# Pimarchy Library — Packages (list-driven, Quattro module system)
#
# Package modules live in config/packages/<module>.list with tagged lines:
#   apt:<pkg>        — install from the default (stable/Trixie) repo
#   sid:<pkg>        — install from the Debian sid repo (Hyprland set)
#   script:<label>   — non-apt installer handled by a post-install hook
#
# core.list is always installed by install.sh. ai.list / extras.list / dev.list /
# office.list are lazy modules installed via `pimarchy install <module>`.
#

# read_package_list <module> — print non-comment, non-blank lines of the list.
read_package_list() {
    local module="$1"
    local list_file="$PACKAGE_LIST_DIR/$module.list"

    if [ ! -f "$list_file" ]; then
        log_error "No package list for module: $module (expected $list_file)"
        return 1
    fi

    grep -vE '^[[:space:]]*(#|$)' "$list_file"
}

# list_apt_packages <module> <tag> — apt or sid package names for the module.
list_apt_packages() {
    local module="$1"
    local tag="$2"
    read_package_list "$module" | sed -n "s/^${tag}://p" | grep -vE '^[[:space:]]*$'
}

# list_script_labels <module> — script-installed tool labels for the module.
list_script_labels() {
    local module="$1"
    read_package_list "$module" | sed -n "s/^script://p" | grep -vE '^[[:space:]]*$'
}

# install_dev_root_hook — keep /dev/root valid for later kernel upgrades.
install_dev_root_hook() {
    local helper="/usr/local/sbin/pimarchy-ensure-dev-root"
    local hook="/etc/kernel/preinst.d/zz-pimarchy-dev-root"

    sudo install -m 0755 "$PIMARCHY_ROOT/lib/ensure-dev-root.sh" "$helper"
    sudo mkdir -p /etc/kernel/preinst.d
    printf '%s\n' '#!/bin/sh' "$helper" | sudo tee "$hook" >/dev/null
    sudo chmod 755 "$hook"
    sudo "$helper" || true
}

# remove_dev_root_hook — drop the helper installed by install_dev_root_hook.
remove_dev_root_hook() {
    sudo rm -f \
        /usr/local/sbin/pimarchy-ensure-dev-root \
        /etc/kernel/preinst.d/zz-pimarchy-dev-root \
        /etc/needrestart/conf.d/pimarchy.conf \
        /etc/sudoers.d/pimarchy-apt
}

# install_packages — installs the core module (default path). Pre-Quattro
# behavior (dev + office toolchains) is preserved behind --legacy-packages.
install_packages() {
    log_info "Updating system and installing core packages..."

    export DEBIAN_FRONTEND=noninteractive
    export DEBCONF_NONINTERACTIVE_SEEN=true
    export NEEDRESTART_MODE=a
    export APT_LISTCHANGES_FRONTEND=none
    export APT_LISTBUGS_FRONTEND=none

    # sudo drops those variables. First boot attaches apt to a terminal
    # so progress is visible, and libc6 then waits on a blue dialog:
    # "Restart services during package upgrades without asking?"
    sudo tee /etc/sudoers.d/pimarchy-apt >/dev/null <<'EOF'
Defaults env_keep += "DEBIAN_FRONTEND DEBCONF_NONINTERACTIVE_SEEN NEEDRESTART_MODE APT_LISTCHANGES_FRONTEND APT_LISTBUGS_FRONTEND"
EOF
    sudo chmod 440 /etc/sudoers.d/pimarchy-apt

    clean_stale_apt_sources
    # A Pi boots with a stale clock. apt rejects signatures that are not
    # live yet, so set the time before the first update.
    if [ -x "$PIMARCHY_ROOT/image/sync-clock.sh" ]; then
        sudo "$PIMARCHY_ROOT/image/sync-clock.sh" || true
    fi
    # Stock upgrade first, before the sid pin, and only after /dev/root
    # exists. A kernel upgrade otherwise fails initramfs and dpkg.
    install_dev_root_hook
    sudo mkdir -p /etc/needrestart/conf.d
    printf '%s\n' "\$nrconf{restart} = 'a';" \
        | sudo tee /etc/needrestart/conf.d/pimarchy.conf >/dev/null

    sudo apt update
    sudo dpkg --configure -a
    sudo apt full-upgrade -y \
        -o Dpkg::Options::=--force-confdef \
        -o Dpkg::Options::=--force-confold

    configure_sid_repo
    configure_docker_repo
    sudo apt update

    # Core module: stable repo packages, then sid Hyprland set
    local stable_pkgs
    mapfile -t stable_pkgs < <(list_apt_packages core apt)
    if [ ${#stable_pkgs[@]} -gt 0 ]; then
        sudo apt install -y "${stable_pkgs[@]}"
    fi

    local sid_pkgs
    mapfile -t sid_pkgs < <(list_apt_packages core sid)
    if [ ${#sid_pkgs[@]} -gt 0 ]; then
        sudo apt install -t sid -y "${sid_pkgs[@]}"
    fi

    # Non-apt core apps declared in core.list (zed, pifile, picalc)
    # via their official install scripts — all idempotent.
    run_module_script_hooks core

    install_nerd_font
    remove_replaced_apt_packages
    log_success "Core packages installed"
}

# remove_replaced_apt_packages — purge packages that used to be in core
# and have been replaced (e.g. Thunar → Pifile). Safe if already absent.
# network-manager-gnome is the transitional nm-applet package. The purge
# is one-way: uninstall does not reinstall it. nmcli and nmtui stay with
# network-manager, and Waybar draws the network icon.
remove_replaced_apt_packages() {
    local retired=(thunar thunar-volman thunar-data network-manager-gnome)
    local pkg to_remove=()

    for pkg in "${retired[@]}"; do
        if dpkg -s "$pkg" >/dev/null 2>&1; then
            to_remove+=("$pkg")
        fi
    done

    if [ ${#to_remove[@]} -eq 0 ]; then
        return 0
    fi

    log_info "Removing replaced packages: ${to_remove[*]}"
    sudo apt remove --purge -y "${to_remove[@]}" 2>/dev/null || true
}

# install_module_packages <module> — install a lazy module (ai, extras, dev, office).
# Idempotent: re-running only installs what is missing.
install_module_packages() {
    local module="$1"

    if [ ! -f "$PACKAGE_LIST_DIR/$module.list" ]; then
        log_error "Unknown module: $module (no $PACKAGE_LIST_DIR/$module.list)"
        return 1
    fi

    log_info "Installing '$module' module packages..."

    export DEBIAN_FRONTEND=noninteractive

    # Module prerequisites: sid repo is needed by hyprland deps; Docker repo
    # is needed by the dev module.
    if [ "$module" = "dev" ]; then
        configure_docker_repo
    fi

    sudo apt update

    local stable_pkgs
    mapfile -t stable_pkgs < <(list_apt_packages "$module" apt)
    if [ ${#stable_pkgs[@]} -gt 0 ]; then
        log_info "Installing apt packages for '$module'..."
        sudo apt install -y "${stable_pkgs[@]}"
    fi

    local sid_pkgs
    mapfile -t sid_pkgs < <(list_apt_packages "$module" sid)
    if [ ${#sid_pkgs[@]} -gt 0 ]; then
        log_info "Installing sid packages for '$module'..."
        sudo apt install -t sid -y "${sid_pkgs[@]}"
    fi

    # Non-apt installers (rustup, node, go, docker, zed, raven, ...)
    run_module_script_hooks "$module"

    # Module-specific post-install messaging
    case "$module" in
        ai)
            log_info "Raven + Ollama ready. Launch with: pimarchy agent"
            log_info "Ollama starts on demand when the agent launches (not at boot)."
            ;;
        dev)
            if ! id -nG "$USER" | grep -qw docker 2>/dev/null; then
                log_info "Docker installed. Add yourself with: sudo usermod -aG docker $USER"
                log_info "(Or run: pimarchy install dev --with-docker-group)"
            fi
            ;;
    esac

    log_success "Module '$module' installed."
}

# install_legacy_packages — pre-Quattro full set (core + dev + office).
# Retained so existing installs upgrading to Quattro don't lose packages.
install_legacy_packages() {
    log_info "Installing legacy (pre-Quattro) full package set..."
    install_packages
    install_module_packages dev
    install_module_packages office
}

# install_nerd_font — JetBrainsMono Nerd Font, fetched from the upstream
# release (needed by the Ravenwood theme; not packaged in Debian).
# Matches the live Omarchy terminal font choice.
install_nerd_font() {
    if fc-list 2>/dev/null | grep -iq "JetBrainsMono Nerd Font"; then
        return 0
    fi

    log_info "Installing JetBrainsMono Nerd Font..."
    mkdir -p "$HOME/.local/share/fonts"
    wget -qO /tmp/JetBrainsMono.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/JetBrainsMono.zip
    unzip -qo /tmp/JetBrainsMono.zip -d "$HOME/.local/share/fonts/" || true
    fc-cache -fv "$HOME/.local/share/fonts" > /dev/null
    rm -f /tmp/JetBrainsMono.zip
}

remove_packages() {
    log_info "Removing core packages..."

    local packages=(
        hyprland
        hyprland-guiutils
        waybar
        mako-notifier
        swaybg
        grim
        slurp
        wl-clipboard
        fonts-font-awesome
        fonts-jetbrains-mono
        fonts-liberation
        fonts-dejavu-core
        fonts-noto-color-emoji
        gnome-themes-extra
        yaru-theme-icon
        papirus-icon-theme
        fontconfig
        dconf-cli
        gsettings-desktop-schemas
        qt5ct
        xdg-desktop-portal-hyprland
        xdg-desktop-portal
        xdg-desktop-portal-gtk
        xdg-utils
        xdg-user-dirs
        libnotify-bin
        pavucontrol
        network-manager-gnome
        libspa-0.2-bluetooth
        pipewire
        pipewire-pulse
        wireplumber
        foot
        fd-find
        ripgrep
        rofi
        greetd
        tuigreet
        starship
        thunar
        thunar-volman
        lxpolkit
        bluez
        bluez-tools
        alsa-utils
        chromium
        btop
        ufw
        git
        gh
        libvulkan1
        mesa-vulkan-drivers
        sshfs
        docker-ce
        docker-ce-cli
        containerd.io
        docker-buildx-plugin
        docker-compose-plugin
    )

    sudo apt remove --purge -y "${packages[@]}" 2>/dev/null || true
    sudo apt autoremove -y

    remove_repos

    log_success "Packages removed"
}