#!/bin/bash
#
# Pimarchy Library — Packages (list-driven, Quattro module system)
#
# Package modules live in config/packages/<module>.list with tagged lines:
#   apt:<pkg>        — install from the default (stable/Trixie) repo
#   sid:<pkg>        — install from the Debian sid repo (Hyprland set)
#   script:<label>   — non-apt installer handled by a post-install hook
#
# core.list is always installed by install.sh. dev.list / office.list are
# lazy modules installed via `pimarchy install <module>`.
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

# install_packages — installs the core module (default path). Pre-Quattro
# behavior (dev + office toolchains) is preserved behind --legacy-packages.
install_packages() {
    log_info "Updating system and installing core packages..."

    export DEBIAN_FRONTEND=noninteractive

    clean_stale_apt_sources
    configure_sid_repo
    configure_docker_repo

    sudo apt update
    sudo apt upgrade -y

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

    # Non-apt core apps declared in core.list (zed, raven, ollama) via
    # their official install scripts — all idempotent.
    run_module_script_hooks core

    install_nerd_font
    log_success "Core packages installed"
}

# install_module_packages <module> — install a lazy module (dev, office).
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

# install_nerd_font — CaskaydiaCove Nerd Font, fetched from the upstream
# release (needed by the Ravenwood theme; not packaged in Debian).
install_nerd_font() {
    if fc-list 2>/dev/null | grep -iq "CaskaydiaCove Nerd Font"; then
        return 0
    fi

    log_info "Installing CaskaydiaCove Nerd Font..."
    mkdir -p "$HOME/.local/share/fonts"
    wget -qO /tmp/CascadiaCode.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/CascadiaCode.zip
    unzip -qo /tmp/CascadiaCode.zip -d "$HOME/.local/share/fonts/" || true
    fc-cache -fv "$HOME/.local/share/fonts" > /dev/null
    rm -f /tmp/CascadiaCode.zip
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
        xdg-desktop-portal-hyprland
        pavucontrol
        network-manager-gnome
        arc-theme
        papirus-icon-theme
        foot
        fd-find
        ripgrep
        rofi
        greetd
        tuigreet
        starship
        thunar
        gsettings-desktop-schemas
        dconf-cli
        lxpolkit
        bluez
        bluez-tools
        alsa-utils
        chromium
        btop
        ufw
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