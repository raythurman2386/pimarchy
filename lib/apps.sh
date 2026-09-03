#!/bin/bash
#
# Pimarchy Library — App Installs, GSettings, and File Cleanup
#

# run_module_script_hooks <module> — run the installers for every
# `script:<label>` entry in the module's package list. Idempotent.
run_module_script_hooks() {
    local module="$1"
    local label

    while IFS= read -r label; do
        [ -z "$label" ] && continue
        case "$label" in
            zed)        install_zed ;;
            raven)      install_raven ;;
            ollama)     install_ollama ;;
            rustup)     install_rustup ;;
            node)       configure_nodejs ;;
            go)         install_go ;;
            python-dev) install_python_dev ;;
            docker-group)
                if ! id -nG "$USER" | grep -qw docker 2>/dev/null; then
                    sudo usermod -aG docker "$USER"
                    log_info "Added $USER to docker group (re-login required)"
                fi
                ;;
            *)
                log_warn "Unknown script label in $module.list: $label — skipping"
                ;;
        esac
    done < <(list_script_labels "$module")
}

# ---- Official-script installers (all idempotent) ---------------------------

# install_zed — Zed editor via the official zed.dev script. Zed is not in
# Debian repos. Lands at ~/.local/zed.app/bin/zed, symlinked to ~/.local/bin.
install_zed() {
    if command -v zed &>/dev/null; then
        log_info "Zed already installed ($(zed --version 2>/dev/null || echo 'unknown version')) — skipping"
        return 0
    fi

    log_info "Installing Zed editor..."

    if ! command -v curl &>/dev/null; then
        sudo apt install -y curl
    fi

    curl -f https://zed.dev/install.sh | sh

    if command -v zed &>/dev/null; then
        log_success "Zed installed successfully"
    else
        log_warn "Zed installer ran but 'zed' not found in PATH — may need to re-login or source ~/.bashrc"
    fi
}

remove_zed() {
    local zed_bin="$HOME/.local/bin/zed"

    if [ -f "$zed_bin" ]; then
        "$zed_bin" --uninstall >/dev/null 2>&1 || true
        log_success "Zed installation removed"
    else
        log_info "Zed not found at $zed_bin — nothing to remove"
    fi

    if [ -f "$HOME/.config/zed/settings.json" ]; then
        rm -f "$HOME/.config/zed/settings.json"
        log_info "Removed Zed config (~/.config/zed/settings.json)"
    fi
}

# install_ollama — Ollama inference server via the official ollama.com script.
# Raven's default model backend; listens on 127.0.0.1:11434.
install_ollama() {
    if command -v ollama &>/dev/null; then
        log_info "Ollama already installed ($(ollama --version 2>/dev/null || echo 'unknown version')) — skipping"
        return 0
    fi

    log_info "Installing Ollama..."

    if ! command -v curl &>/dev/null; then
        sudo apt install -y curl
    fi

    curl -fsSL https://ollama.com/install.sh | sh

    if command -v ollama &>/dev/null; then
        log_success "Ollama installed successfully"
    else
        log_warn "Ollama installer ran but 'ollama' not found in PATH — may need to re-login or source ~/.bashrc"
    fi
}

remove_ollama() {
    if systemctl list-unit-files 2>/dev/null | grep -q '^ollama.service'; then
        sudo systemctl stop ollama 2>/dev/null || true
        sudo systemctl disable ollama 2>/dev/null || true
        sudo rm -f /etc/systemd/system/ollama.service
        sudo systemctl daemon-reload 2>/dev/null || true
        log_info "Stopped and removed Ollama systemd service"
    fi

    sudo rm -f /usr/local/bin/ollama
    sudo rm -rf /usr/local/lib/ollama
    log_success "Ollama installation removed"

    if id ollama &>/dev/null 2>&1; then
        sudo userdel -r ollama 2>/dev/null || true
        log_info "Removed ollama system user"
    fi
}

# install_raven — Raven AI coding agent via its official install script.
# Lands at ~/.cargo/bin/raven.
install_raven() {
    if command -v raven &>/dev/null; then
        log_info "Raven already installed ($(raven --version 2>/dev/null || echo 'unknown version')) — skipping"
        return 0
    fi

    log_info "Installing Raven..."

    if ! command -v curl &>/dev/null; then
        sudo apt install -y curl
    fi

    curl -fsSL https://raw.githubusercontent.com/raythurman2386/raven/master/install.sh | sh

    if command -v raven &>/dev/null; then
        log_success "Raven installed successfully"
    else
        log_warn "Raven installer ran but 'raven' not found in PATH — may need to re-login or source ~/.bashrc"
    fi
}

remove_raven() {
    local raven_bin="$HOME/.cargo/bin/raven"

    if [ -f "$raven_bin" ]; then
        rm -f "$raven_bin"
        log_success "Raven installation removed ($raven_bin)"
    else
        log_info "Raven not found at $raven_bin — nothing to remove"
    fi

    if [ -f "$HOME/.raven/config.toml" ]; then
        rm -f "$HOME/.raven/config.toml"
        log_info "Removed Raven config (~/.raven/config.toml)"
    fi
}

# ---- Dev toolchains (dev module, official scripts — not apt) ---------------

# install_rustup — Rust toolchain via the official rustup.rs script.
# rustup is not in Debian repos at the version we want; the official script
# is the supported install path and keeps rustc/cargo upgradable via rustup.
install_rustup() {
    if command -v rustup &>/dev/null; then
        log_info "rustup already installed ($(rustup --version 2>/dev/null | head -1 || echo 'unknown')) — skipping"
        return 0
    fi

    log_info "Installing Rust via rustup..."

    if ! command -v curl &>/dev/null; then
        sudo apt install -y curl
    fi

    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

    # Make cargo/rustup available in this shell even before re-login
    if [ -f "$HOME/.cargo/env" ]; then
        # shellcheck disable=SC1091
        source "$HOME/.cargo/env"
    fi

    if command -v rustup &>/dev/null; then
        log_success "rustup installed ($(rustup --version 2>/dev/null | head -1))"
    else
        log_warn "rustup installer ran but not found — re-login and check ~/.cargo/env"
    fi
}

# configure_nodejs — Node.js v22 LTS from NodeSource (dev module only).
configure_nodejs() {
    if command -v node &> /dev/null; then
        log_info "Node.js already installed ($(node --version)) — skipping"
        return 0
    fi

    log_info "Installing Node.js from NodeSource..."
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - >/dev/null
    sudo apt install -y nodejs
    log_success "Node.js installed ($(node --version))"
}

# install_go — Go from golang.org (dev module only).
install_go() {
    if command -v go &> /dev/null; then
        log_info "Go already installed ($(go version 2>/dev/null | awk '{print $3}')) — skipping"
        return 0
    fi

    log_info "Installing Go..."
    local go_version
    go_version=$(curl -sSL https://go.dev/dl/?mode=json 2>/dev/null | jq -r '.[0].version' 2>/dev/null)

    if [ -z "$go_version" ] || [ "$go_version" = "null" ]; then
        go_version="go1.24.0"
    fi

    local go_arch="arm64"
    local go_pkg="${go_version}.linux-${go_arch}.tar.gz"

    log_info "Downloading ${go_pkg}..."
    wget -qO /tmp/go.tar.gz "https://golang.org/dl/${go_pkg}"
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf /tmp/go.tar.gz
    rm -f /tmp/go.tar.gz

    if ! grep -q '/usr/local/go/bin' "$HOME/.bashrc"; then
        echo 'export PATH=$PATH:/usr/local/go/bin' >> "$HOME/.bashrc"
    fi

    export PATH=$PATH:/usr/local/go/bin
    log_success "Go installed ($go_version)"
}

# install_python_dev — venv + pipx (PEP 668: no global pip --user installs).
install_python_dev() {
    log_info "Installing Python development tools..."

    sudo apt install -y python3-pip python3-venv pipx

    if command -v pipx &> /dev/null; then
        pipx ensurepath >/dev/null 2>&1 || true
    fi

    log_success "Python development tools ready (use python3 -m venv or pipx)"
}

# ---- GSettings --------------------------------------------------------------

apply_gsettings() {
    log_info "Applying desktop settings via dconf..."

    # Pi OS Lite ships dconf-cli but not the gsettings CLI; the xdg portal
    # reads dconf directly (that's how Chromium discovers the color scheme).
    if command -v dconf &>/dev/null; then
        dconf write /org/gnome/desktop/interface/gtk-theme "'$GTK_THEME'" 2>/dev/null || true
        dconf write /org/gnome/desktop/interface/icon-theme "'$ICON_THEME'" 2>/dev/null || true
        dconf write /org/gnome/desktop/interface/cursor-theme "'$CURSOR_THEME'" 2>/dev/null || true
        dconf write /org/gnome/desktop/interface/cursor-size "$CURSOR_SIZE" 2>/dev/null || true
        dconf write /org/gnome/desktop/interface/font-name "'$FONT_FAMILY $FONT_SIZE'" 2>/dev/null || true
        dconf write /org/gnome/desktop/interface/color-scheme "'$COLOR_SCHEME'" 2>/dev/null || true
    elif command -v gsettings &>/dev/null; then
        gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME" 2>/dev/null || true
        gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME" 2>/dev/null || true
        gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR_THEME" 2>/dev/null || true
        gsettings set org.gnome.desktop.interface cursor-size "$CURSOR_SIZE" 2>/dev/null || true
        gsettings set org.gnome.desktop.interface font-name "$FONT_FAMILY $FONT_SIZE" 2>/dev/null || true
        gsettings set org.gnome.desktop.interface color-scheme "$COLOR_SCHEME" 2>/dev/null || true
    else
        log_warn "Neither dconf nor gsettings found — skipping desktop settings"
        return
    fi

    log_success "Desktop settings applied (color-scheme=$COLOR_SCHEME)"
}

reset_gsettings() {
    log_info "Resetting desktop settings to defaults..."

    if command -v dconf &>/dev/null; then
        dconf reset /org/gnome/desktop/interface/gtk-theme 2>/dev/null || true
        dconf reset /org/gnome/desktop/interface/icon-theme 2>/dev/null || true
        dconf reset /org/gnome/desktop/interface/cursor-theme 2>/dev/null || true
        dconf reset /org/gnome/desktop/interface/cursor-size 2>/dev/null || true
        dconf reset /org/gnome/desktop/interface/font-name 2>/dev/null || true
        dconf reset /org/gnome/desktop/interface/color-scheme 2>/dev/null || true
    elif command -v gsettings &>/dev/null; then
        gsettings reset org.gnome.desktop.interface gtk-theme 2>/dev/null || true
        gsettings reset org.gnome.desktop.interface icon-theme 2>/dev/null || true
        gsettings reset org.gnome.desktop.interface cursor-theme 2>/dev/null || true
        gsettings reset org.gnome.desktop.interface cursor-size 2>/dev/null || true
        gsettings reset org.gnome.desktop.interface font-name 2>/dev/null || true
        gsettings reset org.gnome.desktop.interface color-scheme 2>/dev/null || true
    else
        log_warn "Neither dconf nor gsettings found — skipping reset"
        return
    fi

    log_success "Desktop settings reset"
}

# ---- File management ---------------------------------------------------------

create_config_dirs() {
    log_info "Creating config directories..."

    mkdir -p "$HYPRLAND_DIR"
    mkdir -p "$WAYBAR_DIR"
    mkdir -p "$ROFI_DIR"
    mkdir -p "$MAKO_DIR"
    mkdir -p "$GTK3_DIR"
    mkdir -p "$TERMINAL_DIR"
    mkdir -p "$HOME/.config/btop/themes"
    mkdir -p "$HOME/.config/zed"
    mkdir -p "$HOME/.raven"

    log_success "Config directories created"
}

remove_pimarchy_files() {
    log_info "Removing Pimarchy configuration files..."

    rm -rf "$HYPRLAND_DIR"
    rm -rf "$WAYBAR_DIR"
    rm -rf "$ROFI_DIR"
    rm -rf "$MAKO_DIR"

    rm -f "$GTK3_DIR/settings.ini"
    rm -f "$HOME/.gtkrc-2.0"

    rm -rf "$TERMINAL_DIR"
    rm -rf "$HOME/.config/zed"

    rm -f "$HOME/.bashrc.pimarchy"
    rm -f "$HOME/.config/starship.toml"

    sudo rm -f /etc/chromium.d/pimarchy

    # Stale pre-Quattro location (Debian Chromium ignores ~/.config/chromium-flags.conf)
    rm -f "$HOME/.config/chromium-flags.conf"

    rm -f "$HOME/.config/btop/btop.conf"
    rm -f "$HOME/.config/btop/themes/ravenwood.theme"

    rm -f "$HOME/.raven/config.toml"

    sudo rm -f /etc/apt/sources.list.d/bookworm.list
    sudo rm -f /etc/apt/sources.list.d/sid.list
    sudo rm -f /etc/apt/preferences.d/sid-pin

    log_success "Pimarchy files removed"
}

# remove_pimarchy_state — remove Quattro user state: the defaults directory
# (~/.config/pimarchy/defaults) and the safe-upgrade manifest.
remove_pimarchy_state() {
    # ~/.config/pimarchy is Pimarchy's namespace (defaults/, manifest)
    rm -rf "$PIMARCHY_USER_DIR"

    # Quattro helper scripts installed to ~/.local/bin by modules.conf
    local script
    for script in pimarchy-agent pimarchy-default-agent pimarchy-install pimarchy-upgrade; do
        rm -f "$HOME/.local/bin/$script"
    done

    log_success "Pimarchy user state removed"
}