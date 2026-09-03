#!/bin/bash
#
# Pimarchy Library — External apt Repositories
#
# Policy: Pimarchy is Debian-first. We add exactly two external apt sources,
# each pinned so stable/Trixie remains the default for everything else:
#   1. Debian sid (Hyprland + friends) — pin priority 100
#   2. Docker CE (download.docker.com) — pin priority 1001 (Docker only)
# See docs/development/sid-policy.md for the full rationale.
#

# configure_sid_repo — idempotent: adds sid sources + low pin only if missing.
configure_sid_repo() {
    if [ -s /etc/apt/sources.list.d/sid.list ]; then
        return 0
    fi

    log_info "Adding Debian Sid (unstable) repository for Hyprland..."
    echo "deb http://deb.debian.org/debian/ sid main contrib non-free" | sudo tee /etc/apt/sources.list.d/sid.list > /dev/null
    log_info "Configuring APT pinning to prefer current release but allow sid..."
    cat <<EOF | sudo tee /etc/apt/preferences.d/sid-pin > /dev/null
Package: *
Pin: release n=sid
Pin-Priority: 100
EOF
}

# configure_docker_repo — official Docker CE repository for arm64.
# Docker packages are pinned to download.docker.com (priority 1001) so
# docker-compose-plugin always comes from upstream, never Debian's docker.io.
configure_docker_repo() {
    if [ -f /etc/apt/sources.list.d/docker.list ]; then
        log_info "Docker apt repository already configured — skipping"
        return 0
    fi

    log_info "Adding official Docker CE apt repository..."

    sudo apt install -y ca-certificates curl gnupg

    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg \
        | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    local codename
    codename=$(. /etc/os-release && echo "$VERSION_CODENAME")
    if [ -z "$codename" ]; then
        codename=$(. /etc/os-release && echo "$DEBIAN_CODENAME")
    fi
    if [ -z "$codename" ]; then
        codename="bookworm"
    fi

    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/debian ${codename} stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    cat <<'EOF' | sudo tee /etc/apt/preferences.d/docker-pin > /dev/null
Package: docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
Pin: origin download.docker.com
Pin-Priority: 1001
EOF

    sudo apt update
    log_success "Docker CE repository added"
}

# clean_stale_apt_sources — remove sources written by pre-Quattro Pimarchy
# versions (VS Code repo, wrong-codename bookworm list). Harmless if absent.
clean_stale_apt_sources() {
    sudo rm -f \
        /etc/apt/sources.list.d/vscode.list \
        /etc/apt/sources.list.d/vscode.sources \
        /usr/share/keyrings/microsoft.gpg \
        /etc/apt/keyrings/packages.microsoft.gpg \
        /etc/apt/sources.list.d/bookworm.list
}

remove_repos() {
    sudo rm -f \
        /etc/apt/sources.list.d/docker.list \
        /etc/apt/keyrings/docker.gpg \
        /etc/apt/preferences.d/docker-pin \
        /etc/apt/sources.list.d/sid.list \
        /etc/apt/preferences.d/sid-pin
    sudo apt update 2>/dev/null || true
}